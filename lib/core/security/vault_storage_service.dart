import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service using platform-specific hardware keystore protection.
/// On Android, utilizes Android KeyStore backed storage with AES-GCM authenticated encryption.
class VaultStorageService {
  final FlutterSecureStorage _storage;

  VaultStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: true,
                keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
                storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  static const String _keyVaultCreated = 'myvault_is_created';
  static const String _keySalt = 'myvault_salt';
  static const String _keyVerifier = 'myvault_verifier';
  static const String _keyKdfParams = 'myvault_kdf_params';
  static const String _keyBiometricEnabled = 'myvault_biometric_enabled';
  static const String _keyAutoLockDuration = 'myvault_autolock_duration';

  /// Checks if a vault has already been initialized on this device
  Future<bool> hasVault() async {
    final val = await _storage.read(key: _keyVaultCreated);
    return val == 'true';
  }

  /// Persists salt, verifier hash, and KDF metadata. Master password is NEVER stored.
  Future<void> saveVaultCredentials({
    required List<int> salt,
    required List<int> verifierHash,
    required Map<String, dynamic> kdfParams,
  }) async {
    await _storage.write(key: _keyVaultCreated, value: 'true');
    await _storage.write(key: _keySalt, value: base64Encode(salt));
    await _storage.write(key: _keyVerifier, value: base64Encode(verifierHash));
    await _storage.write(key: _keyKdfParams, value: jsonEncode(kdfParams));
  }

  /// Retrieves stored salt bytes
  Future<List<int>?> getSalt() async {
    final val = await _storage.read(key: _keySalt);
    if (val == null || val.isEmpty) return null;
    try {
      return base64Decode(val);
    } catch (_) {
      return null;
    }
  }

  /// Retrieves stored verifier hash bytes
  Future<List<int>?> getVerifier() async {
    final val = await _storage.read(key: _keyVerifier);
    if (val == null || val.isEmpty) return null;
    try {
      return base64Decode(val);
    } catch (_) {
      return null;
    }
  }

  /// Retrieves stored KDF metadata
  Future<Map<String, dynamic>?> getKdfParams() async {
    final val = await _storage.read(key: _keyKdfParams);
    if (val == null || val.isEmpty) return null;
    try {
      return jsonDecode(val) as Map<String, dynamic>;
    } catch (_) {
      return null;
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
