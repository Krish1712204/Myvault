import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/security/password_generator.dart';
import '../../features/auth/domain/vault_auth_notifier.dart';
import '../../features/vault_items/data/vault_item_model.dart';
import 'vault_state_provider.dart';

enum VaultAlertLevel { warning, critical }

/// A real, data-derived alert shown in the Alerts sheet.
class VaultAlert {
  /// Stable identity of the underlying condition. It changes when the condition changes
  /// (e.g. a different number of weak passwords), so a cleared alert comes back only then.
  final String id;

  /// Points this condition costs the vault health score.
  final int penalty;
  final String title;
  final String description;
  final VaultAlertLevel level;
  final String? actionLabel;
  final String? actionRoute;

  const VaultAlert({
    required this.id,
    required this.penalty,
    required this.title,
    required this.description,
    required this.level,
    this.actionLabel,
    this.actionRoute,
  });
}

/// Days without a backup before a reminder appears.
const int backupReminderDays = 30;

/// Builds alerts from vault contents. Pure so it can be unit tested.
List<VaultAlert> buildVaultAlerts({
  required List<VaultItem> items,
  required DateTime? lastBackupAt,
  required DateTime now,
}) {
  final alerts = <VaultAlert>[];

  if (items.isNotEmpty) {
    if (lastBackupAt == null) {
      alerts.add(const VaultAlert(
        id: 'backup-none',
        penalty: 25,
        title: 'No backup yet',
        description: 'If this phone is lost or reset, your vault cannot be recovered without a backup.',
        level: VaultAlertLevel.critical,
        actionLabel: 'Back Up Now',
        actionRoute: '/backup-restore',
      ));
    } else {
      final days = now.difference(lastBackupAt).inDays;
      if (days >= backupReminderDays) {
        alerts.add(VaultAlert(
          id: 'backup-old:${lastBackupAt.millisecondsSinceEpoch}',
          penalty: 10,
          title: 'Backup is $days days old',
          description: 'Items added or changed since then are not in your backup.',
          level: VaultAlertLevel.warning,
          actionLabel: 'Back Up Now',
          actionRoute: '/backup-restore',
        ));
      }
    }
  }

  final passwords = items
      .where((i) => i.category == VaultCategory.passwords && (i.password ?? '').isNotEmpty)
      .toList();

  final weak = passwords.where((i) {
    final strength = PasswordGenerator.calculateStrength(i.password!);
    return strength == PasswordStrength.weak || strength == PasswordStrength.fair;
  }).length;
  if (weak > 0) {
    alerts.add(VaultAlert(
      id: 'weak:$weak',
      penalty: (weak * 6).clamp(6, 30),
      title: '$weak weak password${weak == 1 ? '' : 's'}',
      description: 'Use the generator to replace short or simple passwords.',
      level: VaultAlertLevel.warning,
      actionLabel: 'Review',
      actionRoute: '/category/${VaultCategory.passwords.keyName}',
    ));
  }

  final byValue = <String, int>{};
  for (final item in passwords) {
    byValue[item.password!] = (byValue[item.password!] ?? 0) + 1;
  }
  final reused = byValue.values.where((count) => count > 1).fold<int>(0, (sum, c) => sum + c);
  if (reused > 0) {
    alerts.add(VaultAlert(
      id: 'reused:$reused',
      penalty: (reused * 5).clamp(10, 25),
      title: '$reused accounts share a password',
      description: 'If one of these accounts is breached, the others are exposed too.',
      level: VaultAlertLevel.warning,
      actionLabel: 'Review',
      actionRoute: '/category/${VaultCategory.passwords.keyName}',
    ));
  }

  return alerts;
}

/// 0–100 score shown on the dashboard. Dismissing an alert hides it, but does not
/// improve the score: only fixing the underlying problem does.
int vaultHealthScore(List<VaultAlert> alerts) {
  final penalty = alerts.fold<int>(0, (sum, a) => sum + a.penalty);
  return (100 - penalty).clamp(0, 100);
}

String vaultHealthLabel(int score) {
  if (score >= 90) return 'Excellent';
  if (score >= 70) return 'Good';
  if (score >= 45) return 'Fair';
  return 'At risk';
}

/// Every current alert, including dismissed ones (used for the health score).
final vaultAlertsProvider = FutureProvider.autoDispose<List<VaultAlert>>((ref) async {
  final items = ref.watch(vaultItemsProvider);
  ref.watch(_backupRefreshProvider);
  final lastBackupAt = await ref.read(vaultStorageServiceProvider).getLastBackupAt();
  return buildVaultAlerts(items: items, lastBackupAt: lastBackupAt, now: DateTime.now());
});

/// Bumped after a backup so alerts recompute.
final _backupRefreshProvider = StateProvider<int>((ref) => 0);
void refreshVaultAlerts(WidgetRef ref) => ref.read(_backupRefreshProvider.notifier).state++;

/// Alert ids the user cleared, persisted in secure storage.
class AlertDismissalsNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;

  AlertDismissalsNotifier(this._ref) : super(const {}) {
    _load();
  }

  Future<void> _load() async {
    try {
      state = await _ref.read(vaultStorageServiceProvider).getDismissedAlerts();
    } catch (_) {}
  }

  Future<void> dismiss(Iterable<String> ids) async {
    state = {...state, ...ids};
    try {
      await _ref.read(vaultStorageServiceProvider).setDismissedAlerts(state);
    } catch (_) {}
  }
}

final alertDismissalsProvider = StateNotifierProvider<AlertDismissalsNotifier, Set<String>>((ref) {
  return AlertDismissalsNotifier(ref);
});

/// Alerts the user has not cleared: what the bell badge and the Alerts sheet show.
final visibleAlertsProvider = Provider.autoDispose<AsyncValue<List<VaultAlert>>>((ref) {
  final dismissed = ref.watch(alertDismissalsProvider);
  return ref.watch(vaultAlertsProvider).whenData(
        (alerts) => alerts.where((a) => !dismissed.contains(a.id)).toList(),
      );
});

class StorageUsage {
  final int databaseBytes;
  final int fileBytes;
  final int previewBytes;

  const StorageUsage({
    required this.databaseBytes,
    required this.fileBytes,
    required this.previewBytes,
  });

  int get totalBytes => databaseBytes + fileBytes + previewBytes;
}

final storageUsageProvider = FutureProvider.autoDispose<StorageUsage>((ref) async {
  ref.watch(vaultItemsProvider); // re-measure when items change
  final fileService = ref.read(encryptedFileServiceProvider);
  return StorageUsage(
    databaseBytes: await ref.read(vaultDatabaseProvider).fileSizeBytes(),
    fileBytes: await fileService.storedFilesBytes(),
    previewBytes: await fileService.previewBytes(),
  );
});

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
