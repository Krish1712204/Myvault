import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The ONLY secure-storage configuration the app may use. Every reader and writer (vault keys,
/// theme, profile) shares one underlying store, and the plugin's default `resetOnError: true`
/// would erase ALL of it, vault keys included, after a single read error anywhere.
const FlutterSecureStorage vaultSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    resetOnError: false,
    keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
    storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
  ),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

/// Secure storage service using platform-specific hardware keystore protection.
/// On Android, utilizes Android KeyStore backed storage with AES-GCM authenticated encryption.
class VaultStorageService {
  final FlutterSecureStorage _storage;

  VaultStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? vaultSecureStorage;

  static const String _keyVaultCreated = 'myvault_is_created';
  static const String _keyCredentials = 'myvault_credentials_v2';
  static const String _keySalt = 'myvault_salt';
  static const String _keyVerifier = 'myvault_verifier';
  static const String _keyKdfParams = 'myvault_kdf_params';
  static const String _keyWrappedVekKek = 'myvault_wrapped_vek_kek';
  // Legacy (pre-Keystore) biometric material, only read to detect and delete it.
  static const String _keyWrappedVekBiometric = 'myvault_wrapped_vek_biometric';
  static const String _keyBiometricWrappingKey = 'myvault_biometric_wrapping_key';
  static const String _keySealedVekBiometric = 'myvault_sealed_vek_biometric';
  static const String _keyBiometricUpgradePending = 'myvault_biometric_upgrade_pending';
  static const String _keyBiometricEnabled = 'myvault_biometric_enabled';
  static const String _keyAutoLockDuration = 'myvault_autolock_duration';
  static const String _keyFailedAttempts = 'myvault_failed_attempts';
  static const String _keyLockoutUntil = 'myvault_lockout_until';
  static const String _keyLockoutMonotonic = 'myvault_lockout_until_monotonic';
  static const String _keyLockOnBackground = 'myvault_lock_on_background';
  static const String _keyLastBackupAt = 'myvault_last_backup_at';
  static const String _keyDismissedAlerts = 'myvault_dismissed_alerts';
  static const String _keyGoogleDriveBackupEnabled = 'myvault_google_drive_backup_enabled';
  static const String _keyGoogleDriveBackupPassphrase = 'myvault_google_drive_backup_passphrase';
  static const String _keyGoogleDriveBackupFileId = 'myvault_google_drive_backup_file_id';
  static const String _keyGoogleDriveAccountEmail = 'myvault_google_drive_account_email';
  static const String _keyGoogleDriveBackupLocation =
      'myvault_google_drive_backup_location';
  static const String _keyGoogleDriveRestorePending = 'myvault_google_drive_restore_pending';
  static const String _keyGoogleDriveChangedAt = 'myvault_google_drive_changed_at';
  static const String _keyGoogleDriveLastError = 'myvault_google_drive_last_error';

  /// Checks if a vault has already been initialized on this device
  Future<bool> hasVault() async {
    final val = await _storage.read(key: _keyVaultCreated);
    if (val == 'true') return true;
    return await _storage.read(key: _keyCredentials) != null;
  }

  /// Persists salt, verifier hash, KDF metadata, and KEK-wrapped VEK as ONE record,
  /// so the set can never be left half-updated (e.g. new salt beside old wrapped VEK).
  /// Master password is NEVER stored.
  Future<void> saveVaultCredentials({
    required List<int> salt,
    required List<int> verifierHash,
    required Map<String, dynamic> kdfParams,
    required Map<String, String> wrappedVekKek,
  }) async {
    await _storage.write(
      key: _keyCredentials,
      value: jsonEncode({
        'salt': base64Encode(salt),
        'verifier': base64Encode(verifierHash),
        'kdf_params': kdfParams,
        'wrapped_vek': wrappedVekKek,
      }),
    );
    await _storage.write(key: _keyVaultCreated, value: 'true');

    // Legacy per-field keys are superseded by the combined record.
    for (final key in const [_keySalt, _keyVerifier, _keyKdfParams, _keyWrappedVekKek]) {
      await _storage.delete(key: key);
    }
  }

  /// Reads one credential field: the combined record wins, legacy per-field keys
  /// (vaults created before the combined record existed) are the fallback.
  Future<Object?> _readCredential(String field, String legacyKey) async {
    final combined = await _storage.read(key: _keyCredentials);
    if (combined != null && combined.isNotEmpty) {
      try {
        return (jsonDecode(combined) as Map<String, dynamic>)[field];
      } catch (_) {
        return null;
      }
    }
    final legacy = await _storage.read(key: legacyKey);
    if (legacy == null || legacy.isEmpty) return null;
    if (field == 'kdf_params' || field == 'wrapped_vek') {
      try {
        return jsonDecode(legacy);
      } catch (_) {
        return null;
      }
    }
    return legacy;
  }

  Future<List<int>?> _readBytes(String field, String legacyKey) async {
    final val = await _readCredential(field, legacyKey);
    if (val is! String || val.isEmpty) return null;
    try {
      return base64Decode(val);
    } catch (_) {
      return null;
    }
  }

  /// Retrieves stored salt bytes
  Future<List<int>?> getSalt() => _readBytes('salt', _keySalt);

  /// Retrieves stored verifier hash bytes
  Future<List<int>?> getVerifier() => _readBytes('verifier', _keyVerifier);

  /// Retrieves stored KDF metadata
  Future<Map<String, dynamic>?> getKdfParams() async {
    final val = await _readCredential('kdf_params', _keyKdfParams);
    return val is Map ? Map<String, dynamic>.from(val) : null;
  }

  /// Retrieves KEK-wrapped VEK
  Future<Map<String, String>?> getWrappedVekKek() async {
    final val = await _readCredential('wrapped_vek', _keyWrappedVekKek);
    if (val is! Map) return null;
    return val.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  /// Saves the VEK sealed by the Keystore biometric key (opaque blob from VaultBiometricService.seal)
  Future<void> saveSealedBiometricVek(String sealed) async {
    await _storage.write(key: _keySealedVekBiometric, value: sealed);
    await _storage.write(key: _keyBiometricEnabled, value: 'true');
  }

  /// Retrieves the biometric-sealed VEK blob
  Future<String?> getSealedBiometricVek() async {
    final val = await _storage.read(key: _keySealedVekBiometric);
    return (val == null || val.isEmpty) ? null : val;
  }

  /// True if biometric unlock was set up by an older version that kept its wrapping key in
  /// plain app storage (not bound to the fingerprint). Such material must be discarded.
  Future<bool> hasLegacyBiometricKey() async {
    return await _storage.read(key: _keyBiometricWrappingKey) != null;
  }

  /// Clears all biometric key material (current and legacy)
  Future<void> clearBiometricKeys() async {
    await _storage.delete(key: _keySealedVekBiometric);
    await _storage.delete(key: _keyBiometricWrappingKey);
    await _storage.delete(key: _keyWrappedVekBiometric);
    await _storage.write(key: _keyBiometricEnabled, value: 'false');
  }

  /// Set when legacy biometric unlock was removed, so the user can be asked to re-enable it
  Future<bool> isBiometricUpgradePending() async {
    return await _storage.read(key: _keyBiometricUpgradePending) == 'true';
  }

  Future<void> setBiometricUpgradePending(bool pending) async {
    if (pending) {
      await _storage.write(key: _keyBiometricUpgradePending, value: 'true');
    } else {
      await _storage.delete(key: _keyBiometricUpgradePending);
    }
  }

  /// Retrieves biometric unlock preference
  Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _keyBiometricEnabled);
    if (val == null) return false;
    return val == 'true';
  }

  /// Saves biometric unlock preference
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometricEnabled, value: enabled ? 'true' : 'false');
  }

  /// Number of consecutive wrong master-password attempts
  Future<int> getFailedAttempts() async {
    return int.tryParse(await _storage.read(key: _keyFailedAttempts) ?? '') ?? 0;
  }

  /// Time before which password unlock is refused, or null if not locked out
  Future<DateTime?> getLockoutUntil() async {
    final millis = int.tryParse(await _storage.read(key: _keyLockoutUntil) ?? '');
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// The lockout end on the monotonic clock ("elapsedMs@bootCount"), or null.
  Future<({int untilElapsedMs, int bootCount})?> getLockoutUntilMonotonic() async {
    final parts = (await _storage.read(key: _keyLockoutMonotonic))?.split('@');
    if (parts == null || parts.length != 2) return null;
    final until = int.tryParse(parts[0]);
    final boot = int.tryParse(parts[1]);
    return until == null || boot == null ? null : (untilElapsedMs: until, bootCount: boot);
  }

  /// Records a failed attempt and the resulting lockout (null = no lockout). The lockout
  /// end is kept on the wall clock and, when available, on the monotonic clock.
  Future<void> setFailedAttempts(
    int count, {
    DateTime? lockoutUntil,
    ({int untilElapsedMs, int bootCount})? lockoutUntilMonotonic,
  }) async {
    await _storage.write(key: _keyFailedAttempts, value: count.toString());
    if (lockoutUntilMonotonic == null) {
      await _storage.delete(key: _keyLockoutMonotonic);
    } else {
      await _storage.write(
        key: _keyLockoutMonotonic,
        value: '${lockoutUntilMonotonic.untilElapsedMs}@${lockoutUntilMonotonic.bootCount}',
      );
    }
    if (lockoutUntil == null) {
      await _storage.delete(key: _keyLockoutUntil);
    } else {
      await _storage.write(
        key: _keyLockoutUntil,
        value: lockoutUntil.millisecondsSinceEpoch.toString(),
      );
    }
  }

  /// Clears failed-attempt tracking after a successful password unlock
  Future<void> resetFailedAttempts() async {
    await _storage.delete(key: _keyFailedAttempts);
    await _storage.delete(key: _keyLockoutUntil);
    await _storage.delete(key: _keyLockoutMonotonic);
  }

  /// Whether the vault locks as soon as the app leaves the foreground (defaults to on)
  Future<bool> getLockOnBackground() async {
    return await _storage.read(key: _keyLockOnBackground) != 'false';
  }

  Future<void> setLockOnBackground(bool enabled) async {
    await _storage.write(key: _keyLockOnBackground, value: enabled.toString());
  }

  /// When the last vault backup was exported, or null if never
  Future<DateTime?> getLastBackupAt() async {
    final millis = int.tryParse(await _storage.read(key: _keyLastBackupAt) ?? '');
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setLastBackupAt(DateTime time) async {
    await _storage.write(key: _keyLastBackupAt, value: time.millisecondsSinceEpoch.toString());
  }

  /// Ids of alerts the user cleared from the Alerts sheet
  Future<Set<String>> getDismissedAlerts() async {
    final raw = await _storage.read(key: _keyDismissedAlerts);
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> setDismissedAlerts(Set<String> ids) async {
    await _storage.write(key: _keyDismissedAlerts, value: jsonEncode(ids.toList()));
  }

  /// The recovery passphrase is stored only in OS-backed secure storage so scheduled
  /// Drive backups can run without retaining the vault master password in memory.
  /// The user must still remember it to recover a backup on a replacement device.
  Future<void> saveGoogleDriveBackupConfiguration({
    required String passphrase,
    required String accountEmail,
    String? fileId,
  }) async {
    await _storage.write(key: _keyGoogleDriveBackupPassphrase, value: passphrase);
    await _storage.write(key: _keyGoogleDriveAccountEmail, value: accountEmail);
    await _storage.write(key: _keyGoogleDriveBackupEnabled, value: 'true');
    if (fileId != null) {
      await _storage.write(key: _keyGoogleDriveBackupFileId, value: fileId);
    }
  }

  Future<bool> isGoogleDriveBackupEnabled() async =>
      await _storage.read(key: _keyGoogleDriveBackupEnabled) == 'true';

  Future<String?> getGoogleDriveBackupPassphrase() =>
      _storage.read(key: _keyGoogleDriveBackupPassphrase);

  Future<String?> getGoogleDriveBackupFileId() =>
      _storage.read(key: _keyGoogleDriveBackupFileId);

  Future<void> setGoogleDriveBackupFileId(String fileId) =>
      _storage.write(key: _keyGoogleDriveBackupFileId, value: fileId);

  Future<String?> getGoogleDriveBackupLocation() =>
      _storage.read(key: _keyGoogleDriveBackupLocation);

  Future<void> setGoogleDriveBackupLocation(String location) =>
      _storage.write(key: _keyGoogleDriveBackupLocation, value: location);

  Future<String?> getGoogleDriveAccountEmail() =>
      _storage.read(key: _keyGoogleDriveAccountEmail);

  /// True while Drive holds a backup this device has neither restored nor explicitly chosen
  /// to replace. Automatic uploads are held back so they can never overwrite it.
  Future<bool> isGoogleDriveRestorePending() async =>
      await _storage.read(key: _keyGoogleDriveRestorePending) == 'true';

  Future<void> setGoogleDriveRestorePending(bool pending) async {
    if (pending) {
      await _storage.write(key: _keyGoogleDriveRestorePending, value: 'true');
    } else {
      await _storage.delete(key: _keyGoogleDriveRestorePending);
    }
  }

  /// When the vault last changed without the change reaching Drive yet (null = up to date).
  /// Persisted so a change made just before the vault locks is uploaded after the next unlock.
  Future<DateTime?> getGoogleDriveChangedAt() async {
    final millis = int.tryParse(await _storage.read(key: _keyGoogleDriveChangedAt) ?? '');
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setGoogleDriveChangedAt(DateTime? time) async {
    if (time == null) {
      await _storage.delete(key: _keyGoogleDriveChangedAt);
    } else {
      await _storage.write(key: _keyGoogleDriveChangedAt, value: time.millisecondsSinceEpoch.toString());
    }
  }

  /// Why the last automatic Drive backup did not complete, or null if it did.
  Future<String?> getGoogleDriveLastError() => _storage.read(key: _keyGoogleDriveLastError);

  Future<void> setGoogleDriveLastError(String? message) async {
    if (message == null) {
      await _storage.delete(key: _keyGoogleDriveLastError);
    } else {
      await _storage.write(key: _keyGoogleDriveLastError, value: message);
    }
  }

  Future<void> clearGoogleDriveBackupConfiguration() async {
    for (final key in const [
      _keyGoogleDriveBackupEnabled,
      _keyGoogleDriveBackupPassphrase,
      _keyGoogleDriveBackupFileId,
      _keyGoogleDriveAccountEmail,
      _keyGoogleDriveBackupLocation,
      _keyGoogleDriveRestorePending,
      _keyGoogleDriveChangedAt,
      _keyGoogleDriveLastError,
    ]) {
      await _storage.delete(key: key);
    }
  }

  /// Retrieves auto-lock duration preference (defaults to '5 minutes')
  Future<String> getAutoLockDuration() async {
    final val = await _storage.read(key: _keyAutoLockDuration);
    return val ?? '5 minutes';
  }

  /// Saves auto-lock duration preference
  Future<void> setAutoLockDuration(String duration) async {
    await _storage.write(key: _keyAutoLockDuration, value: duration);
  }

  /// Clears all stored vault credentials and preferences
  Future<void> clearVault() async {
    await _storage.deleteAll();
  }
}
