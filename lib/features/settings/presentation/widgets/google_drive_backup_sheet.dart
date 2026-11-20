import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/backup/google_drive_backup_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/ui/formatters.dart';
import '../../../../core/ui/user_message.dart';
import '../../../../shared/state/vault_insights_provider.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../../../shared/widgets/vault_sheet.dart';

/// The Drive backup status shown in Settings. Invalidate it after the sheet closes.
final googleDriveStatusProvider = FutureProvider.autoDispose<GoogleDriveBackupStatus>(
  (ref) => ref.watch(googleDriveBackupServiceProvider).status(),
);

/// Loads the current Drive status, then opens the Google Drive Backup sheet.
Future<void> showGoogleDriveBackupSheet(BuildContext context, WidgetRef ref) async {
  final status = await ref.read(googleDriveBackupServiceProvider).status();
  if (!context.mounted) return;
  await showVaultSheet<void>(
    context,
    builder: (_) => GoogleDriveBackupSheet(initialStatus: status),
  );
}

class GoogleDriveBackupSheet extends ConsumerStatefulWidget {
  final GoogleDriveBackupStatus initialStatus;

  const GoogleDriveBackupSheet({super.key, required this.initialStatus});

  @override
  ConsumerState<GoogleDriveBackupSheet> createState() => _GoogleDriveBackupSheetState();
}

enum _Action { connect, backUp, restore, disconnect }

class _GoogleDriveBackupSheetState extends ConsumerState<GoogleDriveBackupSheet> {
  final _passphrase = TextEditingController();
  final _confirm = TextEditingController();
  _Action? _working;
  String? _error;

  GoogleDriveBackupStatus get _status => widget.initialStatus;
  GoogleDriveBackupService get _service => ref.read(googleDriveBackupServiceProvider);

  @override
  void dispose() {
    _passphrase.clear();
    _confirm.clear();
    _passphrase.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Runs [action]; on success closes the sheet and shows [success] (if any).
  Future<void> _run(_Action kind, Future<String?> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _working = kind;
      _error = null;
    });
    try {
      final success = await action();
      if (!mounted) return;
      navigator.pop();
      if (success != null) {
        messenger.showSnackBar(SnackBar(content: Text(success), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  void _connect() {
    final passphrase = _passphrase.text;
    if (passphrase.trim().length < 8) {
      setState(() => _error = 'Use at least 8 characters for your recovery passphrase.');
      return;
    }
    if (passphrase != _confirm.text) {
      setState(() => _error = 'The two passphrases don’t match.');
      return;
    }
    _run(_Action.connect, () async {
      final connected = await _service.connect(recoveryPassphrase: passphrase);
      return connected.restorePending
          ? 'Connected. Google Drive already has a MyVault backup – open Google Drive Backup to restore it.'
          : 'Google Drive connected. Your vault will now back up automatically.';
    });
  }

  Future<void> _backUp() async {
    final replace = _status.restorePending;
    if (replace &&
        !await showConfirmDialog(
          context,
          icon: Icons.cloud_sync_rounded,
          title: 'Replace the Drive backup?',
          message: 'Google Drive has a MyVault backup that this device hasn’t restored. '
              'Backing up now permanently replaces it with this vault.\n\n'
              'To keep it, choose Cancel and restore it instead.',
          confirmLabel: 'Replace',
          destructive: true,
        )) {
      return;
    }
    await _run(_Action.backUp, () async {
      await _service.syncNow(replaceDriveBackup: replace);
      return 'Encrypted backup uploaded to Google Drive.';
    });
  }

  Future<void> _restore() async {
    if (!await showConfirmDialog(
      context,
      icon: Icons.settings_backup_restore_rounded,
      title: 'Restore from Google Drive?',
      message: 'Everything currently in this vault will be replaced with the latest Google Drive backup. '
          'This can’t be undone.',
      confirmLabel: 'Restore',
      destructive: true,
    )) {
      return;
    }
    await _run(_Action.restore, () async {
      await _service.restoreLatest(replaceExisting: true);
      await ref.read(vaultItemsProvider.notifier).loadItems();
      refreshVaultAlerts(ref);
      ref.invalidate(storageUsageProvider);
      return 'Your vault was restored from Google Drive.';
    });
  }

  Future<void> _disconnect() async {
    if (!await showConfirmDialog(
      context,
      icon: Icons.cloud_off_rounded,
      title: 'Turn off Drive backup?',
      message: 'Automatic backups stop and the recovery passphrase is removed from this device. '
          'The last backup stays in your Google Drive.',
      confirmLabel: 'Turn Off',
      destructive: true,
    )) {
      return;
    }
    await _run(_Action.disconnect, () async {
      await _service.disconnect();
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final connected = _status.enabled;
    return VaultSheet(
      icon: connected ? Icons.cloud_done_rounded : Icons.cloud_outlined,
      title: 'Google Drive Backup',
      subtitle: connected ? 'Encrypted backups to your own Drive' : 'Back up automatically to your own Drive',
      children: [
        if (connected) ..._connectedBody() else ..._setupBody(),
        if (_error != null) ...[
          const SizedBox(height: 14),
          NoticeBanner.error(_error!),
        ],
      ],
    );
  }

  // Not connected: what it does, then choose a recovery passphrase.
  List<Widget> _setupBody() {
    final busy = _working != null;
    return [
      const _Point(
        icon: Icons.lock_outline_rounded,
        title: 'Encrypted before it leaves your phone',
        body: 'Drive only ever receives a locked backup file. Your master password and readable data are never uploaded.',
      ),
      const _Point(
        icon: Icons.sync_rounded,
        title: 'Runs on its own',
        body: 'After you add or change something, MyVault updates the backup in the background.',
      ),
      const _Point(
        icon: Icons.phone_android_rounded,
        title: 'Restore on a new phone',
        body: 'Sign in with the same Google account and enter your recovery passphrase.',
      ),
      const SizedBox(height: 6),
      const NoticeBanner(
        tone: NoticeTone.info,
        icon: Icons.key_rounded,
        title: 'Choose a recovery passphrase',
        message: 'Keep it separate from your master password and write it down: without it, the Drive backup can’t be opened on another device.',
      ),
      const SizedBox(height: 16),
      PassphraseField(
        controller: _passphrase,
        label: 'Recovery passphrase',
        hint: 'At least 8 characters',
        enabled: !busy,
      ),
      const SizedBox(height: 14),
      PassphraseField(
        controller: _confirm,
        label: 'Confirm passphrase',
        hint: 'Type it again',
        icon: Icons.key_outlined,
        enabled: !busy,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _connect(),
      ),
      const SizedBox(height: 20),
      _ProgressLine(service: _service, visible: busy),
      BusyButton(
        label: 'Connect Google Drive',
        busyLabel: 'Connecting…',
        icon: Icons.add_to_drive_rounded,
        busy: _working == _Action.connect,
        onPressed: busy ? null : _connect,
      ),
    ];
  }

  // Connected: account and health, then the actions.
  List<Widget> _connectedBody() {
    final busy = _working != null;
    final pending = _status.restorePending;

    // When Drive holds a backup this device hasn't seen, restoring is the safe default,
    // so it becomes the primary action.
    final backUp = _ActionButton(
      primary: !pending,
      label: pending ? 'Replace Drive Backup' : 'Back Up Now',
      busyLabel: 'Backing up…',
      icon: Icons.cloud_upload_rounded,
      busy: _working == _Action.backUp,
      onPressed: busy ? null : _backUp,
    );
    final restore = _ActionButton(
      primary: pending,
      label: 'Restore from Drive',
      busyLabel: 'Restoring…',
      icon: Icons.settings_backup_restore_rounded,
      busy: _working == _Action.restore,
      onPressed: busy ? null : _restore,
    );

    return [
      _StatusCard(status: _status),
      const SizedBox(height: 20),
      _ProgressLine(service: _service, visible: busy && _working != _Action.disconnect),
      if (pending) ...[restore, const SizedBox(height: 10), backUp] else ...[backUp, const SizedBox(height: 10), restore],
      const SizedBox(height: 6),
      Center(
        child: TextButton.icon(
          onPressed: busy ? null : _disconnect,
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          icon: const Icon(Icons.cloud_off_rounded, size: 18),
          label: const Text('Turn Off Drive Backup'),
        ),
      ),
    ];
  }
}

/// Account, connection and last-backup health at a glance.
class _StatusCard extends StatelessWidget {
  final GoogleDriveBackupStatus status;

  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final last = status.lastBackupAt;
    final (IconData icon, Color color, String headline, String detail) = status.restorePending
        ? (
            Icons.pause_circle_rounded,
            AppColors.warning,
            'Automatic backups paused',
            'Google Drive has a backup this device hasn’t restored. '
                'Restore it to bring that vault here, or replace it with this vault.',
          )
        : status.lastError != null
            ? (Icons.error_rounded, AppColors.error, 'Last backup failed', status.lastError!)
            : last != null
                ? (
                    Icons.check_circle_rounded,
                    AppColors.success,
                    'Backed up ${relativeTime(last.millisecondsSinceEpoch, DateTime.now()).toLowerCase()}',
                    formatDateTime(last),
                  )
                : (Icons.schedule_rounded, AppColors.textMutedNavy, 'No backup yet', 'Tap Back Up Now to make the first one');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.subtleFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              children: [
                const IconTile(Icons.account_circle_rounded, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Google account', style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        status.accountEmail ?? 'Connected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textPrimaryNavy, fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const _Pill(label: 'Connected', color: AppColors.success),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, color: color, size: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: TextStyle(color: AppColors.textPrimaryNavy, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(detail, style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12.5, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Filled (primary) or outlined full-width action with an inline spinner.
class _ActionButton extends StatelessWidget {
  final bool primary;
  final String label;
  final String busyLabel;
  final IconData icon;
  final bool busy;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.primary,
    required this.label,
    required this.busyLabel,
    required this.icon,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return BusyButton(label: label, busyLabel: busyLabel, icon: icon, busy: busy, onPressed: onPressed);
    }
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2))
            : Icon(icon, size: 20),
        label: Text(busy ? busyLabel : label),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(AppColors.isDark ? 40 : 26), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _Point({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppColors.textPrimaryNavy, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The service's current step ("Encrypting…", "Uploading…") with a progress bar.
class _ProgressLine extends StatelessWidget {
  final GoogleDriveBackupService service;
  final bool visible;

  const _ProgressLine({required this.service, required this.visible});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return ValueListenableBuilder<GoogleDriveBackupProgress?>(
      valueListenable: service.progress,
      builder: (context, progress, _) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress?.fraction,
                minHeight: 5,
                color: AppColors.primaryOnSurface,
                backgroundColor: AppColors.border,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              progress?.message ?? 'Working…',
              style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
