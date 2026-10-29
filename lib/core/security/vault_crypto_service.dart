import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

class PasswordValidationResult {
  final bool isValid;
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSpecialChar;
  final bool passwordsMatch;
  final String? errorMessage;

  const PasswordValidationResult({
    required this.isValid,
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSpecialChar,
    required this.passwordsMatch,
    this.errorMessage,
  });
}

class DerivedKeyResult {
  final List<int> derivedKeyBytes;
  final List<int> verifierHashBytes;
  final List<int> saltBytes;
  final Map<String, dynamic> kdfParams;

  const DerivedKeyResult({
    required this.derivedKeyBytes,
    required this.verifierHashBytes,
    required this.saltBytes,
    required this.kdfParams,
  });
}

class VaultCryptoService {
  // Argon2id parameters calibrated for secure mobile execution without freezing UI
  static const int argon2Memory = 19456; // 19 MiB
  static const int argon2Iterations = 2;
  static const int argon2Parallelism = 1;
  static const int keyLength = 32; // 256 bits

  static const String verifierSaltTag = 'MyVault_Verifier_Tag_V1';

  final Argon2id _argon2id = Argon2id(
    parallelism: argon2Parallelism,
    memory: argon2Memory,
    iterations: argon2Iterations,
    hashLength: keyLength,
  );

  final Sha256 _sha256 = Sha256();

  /// Validates master password against all complexity criteria
  PasswordValidationResult validatePassword(String password, String confirmPassword) {
    final hasMinLength = password.length >= 8;
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    final hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    final passwordsMatch = password.isNotEmpty && password == confirmPassword;

    String? errorMessage;
    if (!hasMinLength) {
      errorMessage = 'Password must be at least 8 characters long.';
    } else if (!hasUppercase) {
      errorMessage = 'Password must include an uppercase letter.';
    } else if (!hasLowercase) {
      errorMessage = 'Password must include a lowercase letter.';
    } else if (!hasNumber) {
      errorMessage = 'Password must include a number.';
    } else if (!hasSpecialChar) {
      errorMessage = 'Password must include a special character.';
    } else if (!passwordsMatch) {
      errorMessage = 'Passwords do not match.';
    }

    final isValid = hasMinLength &&
        hasUppercase &&
        hasLowercase &&
        hasNumber &&
        hasSpecialChar &&
        passwordsMatch;

    return PasswordValidationResult(
      isValid: isValid,
      hasMinLength: hasMinLength,
      hasUppercase: hasUppercase,
      hasLowercase: hasLowercase,
      hasNumber: hasNumber,
      hasSpecialChar: hasSpecialChar,
      passwordsMatch: passwordsMatch,
      errorMessage: errorMessage,
    );
  }

  /// Generates 32 cryptographically secure random bytes
  List<int> generateSalt([int length = 32]) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  /// Derives Master Key and Verifier Hash from Master Password and Salt using Argon2id
  Future<DerivedKeyResult> deriveMasterKeyAndVerifier({
    required String password,
    List<int>? existingSalt,
  }) async {
    final salt = existingSalt ?? generateSalt(32);
    final passwordBytes = utf8.encode(password);

    final secretKey = SecretKey(passwordBytes);
    final derivedSecretKey = await _argon2id.deriveKey(
      secretKey: secretKey,
      nonce: salt,
    );

    final derivedBytes = await derivedSecretKey.extractBytes();

    // Verifier is computed as SHA-256(derivedBytes + verifierSaltTag)
    // This allows authenticating the user without keeping the master password in storage.
    final verifierInput = [...derivedBytes, ...utf8.encode(verifierSaltTag)];
    final verifierHash = await _sha256.hash(verifierInput);

    return DerivedKeyResult(
      derivedKeyBytes: derivedBytes,
      verifierHashBytes: verifierHash.bytes,
      saltBytes: salt,
      kdfParams: {
        'algorithm': 'Argon2id',
        'memory': argon2Memory,
        'iterations': argon2Iterations,
        'parallelism': argon2Parallelism,
        'keyLength': keyLength,
      },
    );
  }

  /// Verifies a candidate password against the stored salt and verifier hash in constant time
  Future<bool> verifyMasterPassword({
    required String candidatePassword,
    required List<int> storedSalt,
    required List<int> storedVerifierHash,
  }) async {
    final result = await deriveMasterKeyAndVerifier(
      password: candidatePassword,
      existingSalt: storedSalt,
    );

    return constantTimeEquals(result.verifierHashBytes, storedVerifierHash);
  }

  /// Constant-time comparison to prevent timing attacks
  bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
