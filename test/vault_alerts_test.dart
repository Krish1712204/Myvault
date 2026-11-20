import 'package:flutter_test/flutter_test.dart';
import 'package:myvault/features/vault_items/data/vault_item_model.dart';
import 'package:myvault/shared/state/vault_insights_provider.dart';

VaultItem password(String id, String value) => VaultItem(
      id: id,
      title: id,
      subtitle: '',
      category: VaultCategory.passwords,
      password: value,
    );

void main() {
  final now = DateTime(2026, 10, 31);

  test('Empty vault has no alerts', () {
    expect(buildVaultAlerts(items: const [], lastBackupAt: null, now: now), isEmpty);
  });

  test('Never backed up is critical; a recent backup is silent; an old one warns', () {
    final items = [password('a', 'Xk9#mP2\$vL7@qR4!')];

    final never = buildVaultAlerts(items: items, lastBackupAt: null, now: now);
    expect(never.single.level, VaultAlertLevel.critical);
    expect(never.single.actionRoute, '/backup-restore');

    final recent = buildVaultAlerts(
      items: items,
      lastBackupAt: now.subtract(const Duration(days: 3)),
      now: now,
    );
    expect(recent, isEmpty);

    final old = buildVaultAlerts(
      items: items,
      lastBackupAt: now.subtract(const Duration(days: 45)),
      now: now,
    );
    expect(old.single.title, 'Backup is 45 days old');
  });

  test('Counts weak and reused passwords', () {
    final alerts = buildVaultAlerts(
      items: [
        password('a', 'abc'),
        password('b', 'Xk9#mP2\$vL7@qR4!'),
        password('c', 'Xk9#mP2\$vL7@qR4!'),
      ],
      lastBackupAt: now,
      now: now,
    );
    final titles = alerts.map((a) => a.title).toList();
    expect(titles, contains('1 weak password'));
    expect(titles, contains('2 accounts share a password'));
  });
}
