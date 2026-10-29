import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Wraps platform biometrics verification (Fingerprint, Face, Iris) via Android BiometricPrompt.
class VaultBiometricService {
  final LocalAuthentication _auth;

  VaultBiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  /// Determines if the device supports biometrics and has enrolled biometric credentials
  Future<bool> canAuthenticate() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return false;

      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;

      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Lists available/enrolled biometrics (e.g., fingerprint, face)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (_) {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Prompts the user to authenticate using biometric sensor
  Future<bool> authenticate({
    String reason = 'Authenticate to unlock your MyVault personal vault',
  }) async {
    try {
      final canAuth = await canAuthenticate();
      if (!canAuth) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
