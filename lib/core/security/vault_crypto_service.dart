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
  static const String dbKeyDerivationTag = 'MyVault_SQLCipher_Database_Key_V1';
  static const String fileKeyDerivationTag = 'MyVault_File_Storage_AES256GCM_V1';

  final Argon2id _argon2id = Argon2id(
    parallelism: argon2Parallelism,
    memory: argon2Memory,
    iterations: argon2Iterations,
    hashLength: keyLength,
  );

  final Sha256 _sha256 = Sha256();
  final AesGcm _aesGcm = AesGcm.with256bits();

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

  /// Generates cryptographically secure random bytes
  List<int> generateRandomBytes([int length = 32]) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  /// Generates 32-byte salt
  List<int> generateSalt([int length = 32]) => generateRandomBytes(length);

  /// Generates a fresh 256-bit Vault Encryption Key (VEK)
  List<int> generateVek() => generateRandomBytes(32);

  /// Derives Master Key (KEK) and Verifier Hash from Master Password and Salt using Argon2id
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

  /// Verifies candidate password against stored salt and verifier hash in constant time
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

  /// Wraps Vault Encryption Key (VEK) using AES-256-GCM authenticated encryption
  Future<Map<String, String>> wrapVek({
    required List<int> vek,
    required List<int> wrappingKey,
  }) async {
    final secretKey = SecretKey(wrappingKey);
    final nonce = generateRandomBytes(12); // 96-bit GCM nonce

    final secretBox = await _aesGcm.encrypt(
      vek,
      secretKey: secretKey,
      nonce: nonce,
    );

    return {
      'iv': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'tag': base64Encode(secretBox.mac.bytes),
    };
  }

  /// Unwraps Vault Encryption Key (VEK) using AES-256-GCM. Fails if invalid or tampered.
  Future<List<int>> unwrapVek({
    required Map<String, String> wrappedVek,
    required List<int> wrappingKey,
  }) async {
    final iv = base64Decode(wrappedVek['iv']!);
    final ciphertext = base64Decode(wrappedVek['ciphertext']!);
    final tag = base64Decode(wrappedVek['tag']!);

    final secretKey = SecretKey(wrappingKey);
    final secretBox = SecretBox(
      ciphertext,
      nonce: iv,
      mac: Mac(tag),
    );

    return await _aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
  }

  /// Derives database key from VEK via HKDF-SHA256
  Future<List<int>> deriveDatabaseKey(List<int> vek) async {
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );

    final secretKey = SecretKey(vek);
    final derived = await hkdf.deriveKey(
      secretKey: secretKey,
      info: utf8.encode(dbKeyDerivationTag),
      nonce: const [],
    );

    return await derived.extractBytes();
  }

  /// Derives database key formatted as 64-char hexadecimal string for SQLCipher PRAGMA key
  Future<String> deriveDatabaseKeyHex(List<int> vek) async {
    final bytes = await deriveDatabaseKey(vek);
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Derives file storage key from VEK via HKDF-SHA256
  Future<List<int>> deriveFileStorageKey(List<int> vek) async {
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );

    final secretKey = SecretKey(vek);
    final derived = await hkdf.deriveKey(
      secretKey: secretKey,
      info: utf8.encode(fileKeyDerivationTag),
      nonce: const [],
    );

    return await derived.extractBytes();
  }

  /// Derives Backup Encryption Key (BEK) from user backup passphrase and salt via Argon2id
  Future<List<int>> deriveBackupKey({
    required String passphrase,
    required List<int> salt,
    int memory = argon2Memory,
    int iterations = argon2Iterations,
    int parallelism = argon2Parallelism,
  }) async {
    final kdf = Argon2id(
      parallelism: parallelism,
      memory: memory,
      iterations: iterations,
      hashLength: keyLength,
    );
    final secretKey = SecretKey(utf8.encode(passphrase));
    final derived = await kdf.deriveKey(
      secretKey: secretKey,
      nonce: salt,
    );
    return await derived.extractBytes();
  }

  /// Encrypts backup payload bytes with AES-256-GCM
  Future<SecretBox> encryptBackupPayload({
    required List<int> plaintext,
    required List<int> backupKey,
    required List<int> nonce,
  }) async {
    final secretKey = SecretKey(backupKey);
    return await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );
  }

  /// Decrypts and authenticates backup payload bytes with AES-256-GCM
  Future<List<int>> decryptBackupPayload({
    required List<int> ciphertext,
    required List<int> nonce,
    required List<int> mac,
    required List<int> backupKey,
  }) async {
    final secretKey = SecretKey(backupKey);
    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(mac),
    );
    return await _aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
  }

  /// Constant-time comparison to prevent timing side channels
  bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
