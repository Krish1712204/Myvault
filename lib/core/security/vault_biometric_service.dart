import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

/// Why a biometric key operation did not complete.
enum BiometricKeyError {
  /// No strong biometrics enrolled, or no hardware.
  notAvailable,

  /// User dismissed the prompt or chose "Use master password".
  cancelled,

  /// Fingerprints were added or removed since the key was created; the key is gone.
  keyInvalidated,

  /// Too many failed fingerprint attempts; the sensor is temporarily locked.
  lockedOut,

  /// Anything else.
  failed,
}

class BiometricKeyException implements Exception {
  final BiometricKeyError error;
  final String? message;
  const BiometricKeyException(this.error, [this.message]);

  @override
  String toString() => 'BiometricKeyException($error, $message)';
}

/// Binds a secret to the device's strong biometrics.
///
/// On Android the secret is encrypted with an AES-256-GCM key held in the Android Keystore that
/// can only be used after a successful BiometricPrompt (see BiometricKeyChannel.kt). Nothing
/// readable from app storage alone can recover the secret, and enrolling a new fingerprint
/// permanently invalidates the key. Other platforms report biometrics as unavailable.
class VaultBiometricService {
  static const MethodChannel _channel = MethodChannel('myvault/biometric_key');

  /// Whether strong biometrics are enrolled and usable for key binding
  Future<bool> canAuthenticate() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Prompts for a fingerprint, then seals [secret] under a NEW Keystore key (replacing any
  /// previous one). Returns an opaque blob to store; only [unseal] after another successful
  /// fingerprint can turn it back into the secret.
  Future<String> seal(
    List<int> secret, {
    String title = 'Enable fingerprint unlock',
    String subtitle = 'Confirm your fingerprint',
    String cancel = 'Not now',
  }) async {
    final result = await _invoke('seal', {
      'secret': Uint8List.fromList(secret),
      'title': title,
      'subtitle': subtitle,
      'cancel': cancel,
    });
    final map = Map<Object?, Object?>.from(result as Map);
    return jsonEncode({
      'iv': base64Encode(map['iv'] as List<int>),
      'ciphertext': base64Encode(map['ciphertext'] as List<int>),
    });
  }

  /// Prompts for a fingerprint and returns the secret sealed by [seal].
  Future<List<int>> unseal(
    String sealed, {
    String title = 'Unlock MyVault',
    String subtitle = 'Touch the fingerprint sensor',
    String cancel = 'Use master password',
  }) async {
    final Map<String, dynamic> blob;
    try {
      blob = jsonDecode(sealed) as Map<String, dynamic>;
    } catch (_) {
      throw const BiometricKeyException(BiometricKeyError.keyInvalidated, 'Unreadable sealed data');
    }
    final result = await _invoke('unseal', {
      'iv': base64Decode(blob['iv'] as String),
      'ciphertext': base64Decode(blob['ciphertext'] as String),
      'title': title,
      'subtitle': subtitle,
      'cancel': cancel,
    });
    return List<int>.from(result as List);
  }

  /// Deletes the Keystore key, making any sealed blob permanently useless.
  Future<void> deleteKey() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('deleteKey');
    } catch (_) {}
  }

  Future<Object?> _invoke(String method, Map<String, Object?> args) async {
    if (!Platform.isAndroid) {
      throw const BiometricKeyException(BiometricKeyError.notAvailable);
    }
    try {
      return await _channel.invokeMethod<Object?>(method, args);
    } on PlatformException catch (e) {
      throw BiometricKeyException(_mapCode(e.code), e.message);
    }
  }

  static BiometricKeyError _mapCode(String code) {
    switch (code) {
      case 'NOT_AVAILABLE':
        return BiometricKeyError.notAvailable;
      case 'CANCELLED':
        return BiometricKeyError.cancelled;
      case 'KEY_INVALIDATED':
        return BiometricKeyError.keyInvalidated;
      case 'LOCKED_OUT':
        return BiometricKeyError.lockedOut;
      default:
        return BiometricKeyError.failed;
    }
  }
}
