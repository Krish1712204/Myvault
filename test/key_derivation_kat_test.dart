import 'package:flutter_test/flutter_test.dart';
import 'package:myvault/core/security/vault_crypto_service.dart';

/// Known-answer tests: the database and file keys derived from a vault key must never change,
/// or existing vaults could not be opened. These values were produced by the original
/// implementation; any library swap that alters them fails here instead of on a phone.
void main() {
  final vek = List<int>.generate(32, (i) => i);
  final crypto = VaultCryptoService();

  test('Database key derivation is unchanged', () async {
    expect(
      await crypto.deriveDatabaseKeyHex(vek),
      'e3cd9e0b006d73542047cef2b3eed64de585614ad03d5a6fc856805b2bedcaa8',
    );
  });

  test('File storage key derivation is unchanged', () async {
    final key = await crypto.deriveFileStorageKey(vek);
    expect(
      key.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      '313341615da751dbb93392ffc990c08799a8d901909954405de86dd4c82881ba',
    );
  });
}
