import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:myvault/core/database/vault_database.dart';
import 'package:myvault/core/security/vault_crypto_service.dart';
import 'package:myvault/core/security/vault_session.dart';
import 'package:myvault/core/security/vault_storage_service.dart';
import 'package:myvault/core/security/vault_biometric_service.dart';
import 'package:myvault/features/auth/domain/vault_auth_notifier.dart';
import 'package:myvault/features/auth/domain/vault_auth_state.dart';

/// Mock biometric service for unit testing auth notifier
class MockBiometricService extends VaultBiometricService {
  final bool isSupported;
  final bool authSuccess;

  MockBiometricService({
    this.isSupported = true,
    this.authSuccess = true,
  });

  @override
  Future<bool> canAuthenticate() async => isSupported;

  /// Simulates the Keystore: sealed blobs only open while [authSuccess] is true,
  /// and [invalidateKey] mimics enrolling a new fingerprint.
  final Map<String, List<int>> _sealed = {};
  int _keyGeneration = 0;

  void invalidateKey() => _keyGeneration++;

  @override
  Future<String> seal(List<int> secret, {String title = '', String subtitle = '', String cancel = ''}) async {
    if (!authSuccess) throw const BiometricKeyException(BiometricKeyError.cancelled);
    final handle = 'gen$_keyGeneration';
    _sealed[handle] = List<int>.from(secret);
    return handle;
  }

  @override
  Future<List<int>> unseal(String sealed, {String title = '', String subtitle = '', String cancel = ''}) async {
    if (!authSuccess) throw const BiometricKeyException(BiometricKeyError.cancelled);
    if (sealed != 'gen$_keyGeneration') {
      throw const BiometricKeyException(BiometricKeyError.keyInvalidated);
    }
    return _sealed[sealed]!;
  }

  @override
  Future<void> deleteKey() async => _sealed.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('1. Password Validation & Complexity Rules', () {
    late VaultCryptoService crypto;

    setUp(() {
      crypto = VaultCryptoService();
    });

    test('Rejects passwords shorter than 8 characters', () {
      final res = crypto.validatePassword('Aa1!', 'Aa1!');
      expect(res.isValid, isFalse);
      expect(res.hasMinLength, isFalse);
      expect(res.errorMessage, contains('at least 8 characters'));
    });

    test('Rejects passwords without uppercase character', () {
      final res = crypto.validatePassword('alllowercase1!', 'alllowercase1!');
      expect(res.isValid, isFalse);
      expect(res.hasUppercase, isFalse);
      expect(res.errorMessage, contains('uppercase letter'));
    });

    test('Rejects passwords without lowercase character', () {
      final res = crypto.validatePassword('ALLUPPERCASE1!', 'ALLUPPERCASE1!');
      expect(res.isValid, isFalse);
      expect(res.hasLowercase, isFalse);
      expect(res.errorMessage, contains('lowercase letter'));
    });

    test('Rejects passwords without numbers', () {
      final res = crypto.validatePassword('NoNumbersHere!', 'NoNumbersHere!');
      expect(res.isValid, isFalse);
      expect(res.hasNumber, isFalse);
      expect(res.errorMessage, contains('a number'));
    });

    test('Rejects passwords without special characters', () {
      final res = crypto.validatePassword('NoSpecialChar123', 'NoSpecialChar123');
      expect(res.isValid, isFalse);
      expect(res.hasSpecialChar, isFalse);
      expect(res.errorMessage, contains('special character'));
    });

    test('Rejects mismatched confirm password', () {
      final res = crypto.validatePassword('ValidPass123!', 'Mismatched123!');
      expect(res.isValid, isFalse);
      expect(res.passwordsMatch, isFalse);
      expect(res.errorMessage, contains('do not match'));
    });

    test('Accepts valid password meeting all 5 requirements', () {
      final res = crypto.validatePassword('StrongMasterP@ss1', 'StrongMasterP@ss1');
      expect(res.isValid, isTrue);
      expect(res.hasMinLength, isTrue);
      expect(res.hasUppercase, isTrue);
      expect(res.hasLowercase, isTrue);
      expect(res.hasNumber, isTrue);
      expect(res.hasSpecialChar, isTrue);
      expect(res.passwordsMatch, isTrue);
      expect(res.errorMessage, isNull);
    });
  });

  group('2. Cryptographic Key Derivation & Verifier Tests', () {
    late VaultCryptoService crypto;

    setUp(() {
      crypto = VaultCryptoService();
    });

    test('Derives 256-bit key and verifier with Argon2id', () async {
      final result = await crypto.deriveMasterKeyAndVerifier(
        password: 'TestVaultPassword!1',
      );

      expect(result.derivedKeyBytes.length, equals(32));
      expect(result.verifierHashBytes.length, equals(32));
      expect(result.saltBytes.length, equals(32));
      expect(result.kdfParams['algorithm'], equals('Argon2id'));
    });

    test('Verifies correct password against salt and verifier', () async {
      const password = 'CorrectPassword#2026';
      final result = await crypto.deriveMasterKeyAndVerifier(password: password);

      final isMatch = await crypto.verifyMasterPassword(
        candidatePassword: password,
        storedSalt: result.saltBytes,
        storedVerifierHash: result.verifierHashBytes,
      );

      expect(isMatch, isTrue);
    });

    test('Rejects wrong password against salt and verifier', () async {
      const password = 'CorrectPassword#2026';
      final result = await crypto.deriveMasterKeyAndVerifier(password: password);

      final isMatch = await crypto.verifyMasterPassword(
        candidatePassword: 'WrongPassword#2026',
        storedSalt: result.saltBytes,
        storedVerifierHash: result.verifierHashBytes,
      );

      expect(isMatch, isFalse);
    });

    test('Constant-time equality comparison works accurately', () {
      final a = [1, 2, 3, 4, 5];
      final b = [1, 2, 3, 4, 5];
      final c = [1, 2, 3, 4, 6];
      final d = [1, 2, 3];

      expect(crypto.constantTimeEquals(a, b), isTrue);
      expect(crypto.constantTimeEquals(a, c), isFalse);
      expect(crypto.constantTimeEquals(a, d), isFalse);
    });
  });

  group('3. In-Memory Ephemeral Session & Zeroization', () {
    late VaultSession session;

    setUp(() {
      session = VaultSession();
    });

    test('Session starts inactive with null master key', () {
      expect(session.isActive, isFalse);
      expect(session.vek, isNull);
    });

    test('startSession activates session and holds master key', () {
      final key = List<int>.generate(32, (i) => i + 1);
      session.startSession(key);

      expect(session.isActive, isTrue);
      expect(session.vek, equals(key));
      expect(session.lastActivityTime, isNotNull);
    });

    test('updateActivity refreshes activity timestamp', () async {
      session.startSession(List<int>.filled(32, 1));
      final firstTime = session.lastActivityTime!;

      await Future.delayed(const Duration(milliseconds: 20));
      session.updateActivity();

      expect(session.lastActivityTime!.isAfter(firstTime), isTrue);
    });

    test('isExpired detects elapsed duration', () {
      session.startSession(List<int>.filled(32, 1));
      expect(session.isExpired(const Duration(seconds: 10)), isFalse);
      expect(session.isExpired(Duration.zero), isTrue);
    });

    test('clear zeroizes and terminates session', () {
      final key = List<int>.generate(32, (i) => 0xFF);
      session.startSession(key);

      session.clear();

      expect(session.isActive, isFalse);
      expect(session.vek, isNull);
      expect(session.lastActivityTime, isNull);
    });
  });

  group('4. Vault Storage Service with Hardware Keystore Abstraction', () {
    late VaultStorageService storage;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      storage = VaultStorageService(storage: const FlutterSecureStorage());
    });

    test('Initial vault status is false', () async {
      expect(await storage.hasVault(), isFalse);
    });

    test('saveVaultCredentials stores salt, verifier, kdf metadata and wrapped VEK but NEVER password', () async {
      final salt = [10, 20, 30, 40];
      final verifier = [50, 60, 70, 80];
      final kdfParams = {'algorithm': 'Argon2id', 'memory': 19456};
      final wrappedVek = {'iv': 'iv123', 'ciphertext': 'cipher123', 'tag': 'tag123'};

      await storage.saveVaultCredentials(
        salt: salt,
        verifierHash: verifier,
        kdfParams: kdfParams,
        wrappedVekKek: wrappedVek,
      );

      expect(await storage.hasVault(), isTrue);
      expect(await storage.getSalt(), equals(salt));
      expect(await storage.getVerifier(), equals(verifier));

      final retrievedKdf = await storage.getKdfParams();
      expect(retrievedKdf?['algorithm'], equals('Argon2id'));

      final retrievedVek = await storage.getWrappedVekKek();
      expect(retrievedVek?['ciphertext'], equals('cipher123'));

      // Verify that no plaintext password key exists in storage
      const secureStorage = FlutterSecureStorage();
      final allKeys = await secureStorage.readAll();
      for (final key in allKeys.keys) {
        expect(key.toLowerCase(), isNot(contains('password')));
      }
    });

    test('Auto-lock and biometric preferences get and set correctly', () async {
      expect(await storage.getAutoLockDuration(), equals('5 minutes'));
      await storage.setAutoLockDuration('15 minutes');
      expect(await storage.getAutoLockDuration(), equals('15 minutes'));

      expect(await storage.isBiometricEnabled(), isFalse);
      await storage.setBiometricEnabled(true);
      expect(await storage.isBiometricEnabled(), isTrue);
    });
  });

  group('5. Vault Auth Notifier & Lifecycle State Transitions', () {
    late VaultCryptoService crypto;
    late VaultStorageService storage;
    late MockBiometricService biometric;
    late VaultSession session;
    late VaultDatabase vaultDb;
    late VaultAuthNotifier notifier;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      crypto = VaultCryptoService();
      storage = VaultStorageService(storage: const FlutterSecureStorage());
      biometric = MockBiometricService(isSupported: true, authSuccess: true);
      session = VaultSession();
      vaultDb = VaultDatabase(customFactory: databaseFactoryFfi);

      notifier = VaultAuthNotifier(
        cryptoService: crypto,
        storageService: storage,
        biometricService: biometric,
        session: session,
        vaultDb: vaultDb,
      );
      await notifier.initialize();
    });

    tearDown(() async {
      await vaultDb.close();
    });

    test('Initializes to uninitialized when no vault exists', () async {
      await notifier.initialize();
      expect(notifier.state.status, equals(VaultStatus.uninitialized));
      expect(notifier.state.isVaultCreated, isFalse);
    });

    test('createVault fails on weak password and stays uninitialized', () async {
      final success = await notifier.createVault('weak', 'weak');
      expect(success, isFalse);
      expect(notifier.state.status, equals(VaultStatus.uninitialized));
      expect(notifier.state.errorMessage, isNotNull);
    });

    test('createVault succeeds with strong password and enters unlocked state', () async {
      final success = await notifier.createVault('StrongVault#Pass1', 'StrongVault#Pass1');
      expect(success, isTrue);
      expect(notifier.state.status, equals(VaultStatus.unlocked));
      expect(notifier.state.isVaultCreated, isTrue);
      expect(session.isActive, isTrue);
      expect(vaultDb.isOpen, isTrue);
    });

    test('lockVault explicitly locks, wipes session and closes database', () async {
      await notifier.createVault('StrongVault#Pass1', 'StrongVault#Pass1');
      expect(notifier.state.status, equals(VaultStatus.unlocked));

      await notifier.lockVault();

      expect(notifier.state.status, equals(VaultStatus.locked));
      expect(notifier.state.isUnlocked, isFalse);
      expect(session.isActive, isFalse);
      expect(vaultDb.isOpen, isFalse);
    });

    test('unlockWithPassword succeeds with correct password', () async {
      await notifier.createVault('StrongVault#Pass1', 'StrongVault#Pass1');
      await notifier.lockVault();
      expect(notifier.state.status, equals(VaultStatus.locked));

      final success = await notifier.unlockWithPassword('StrongVault#Pass1');
      expect(success, isTrue);
      expect(notifier.state.status, equals(VaultStatus.unlocked));
      expect(session.isActive, isTrue);
      expect(vaultDb.isOpen, isTrue);
    });

    test('unlockWithPassword fails with wrong password and leaves vault locked', () async {
      await notifier.createVault('StrongVault#Pass1', 'StrongVault#Pass1');
      await notifier.lockVault();

      final success = await notifier.unlockWithPassword('WrongVault#Pass9');
      expect(success, isFalse);
      expect(notifier.state.status, equals(VaultStatus.locked));
      expect(notifier.state.errorMessage, contains('Incorrect master password'));
      expect(session.isActive, isFalse);
      expect(vaultDb.isOpen, isFalse);
    });

    test('checkAutoLock locks vault when set to Immediately on backgrounding', () async {
      await notifier.createVault('StrongVault#Pass1', 'StrongVault#Pass1');
      await notifier.setAutoLockDuration('Immediately');

      await notifier.checkAutoLock(isBackgrounding: true);

      expect(notifier.state.status, equals(VaultStatus.locked));
      expect(vaultDb.isOpen, isFalse);
    });

    test('Creating a vault does not silently enable fingerprint unlock', () async {
      await notifier.createVault('StrongVault#Pass1', 'StrongVault#Pass1');
      expect(notifier.state.isBiometricEnabled, isFalse);
      expect(await storage.getSealedBiometricVek(), isNull);
    });

    test('Biometric unlock unlocks vault when enabled', () async {
      await notifier.createVault('StrongVault#Pass1', 'StrongVault#Pass1');
      expect(await notifier.setBiometricEnabled(true), isTrue);
      await notifier.lockVault();

      final success = await notifier.unlockWithBiometrics();
      expect(success, isTrue);
      expect(notifier.state.status, equals(VaultStatus.unlocked));
      expect(session.isActive, isTrue);
      expect(vaultDb.isOpen, isTrue);
    });

    test('Enrolling a new fingerprint invalidates the key and turns fingerprint unlock off', () async {
      await notifier.createVault('StrongVault#Pass1', 'StrongVault#Pass1');
      await notifier.setBiometricEnabled(true);
      await notifier.lockVault();

      biometric.invalidateKey();
      expect(await notifier.unlockWithBiometrics(), isFalse);
      expect(notifier.state.isBiometricEnabled, isFalse);
      expect(notifier.state.errorMessage, contains('Fingerprints on this phone changed'));
      expect(await storage.getSealedBiometricVek(), isNull);

      // Master password still works.
      expect(await notifier.unlockWithPassword('StrongVault#Pass1'), isTrue);
    });

    test('Cancelling the fingerprint prompt leaves fingerprint unlock off', () async {
      final cancelling = VaultAuthNotifier(
        cryptoService: crypto,
        storageService: storage,
        biometricService: MockBiometricService(isSupported: true, authSuccess: false),
        session: session,
        vaultDb: vaultDb,
      );
      await cancelling.initialize();
      await cancelling.createVault('StrongVault#Pass1', 'StrongVault#Pass1');

      expect(await cancelling.setBiometricEnabled(true), isFalse);
      expect(cancelling.state.isBiometricEnabled, isFalse);
      expect(cancelling.state.errorMessage, isNull);
      cancelling.dispose();
    });

    test('Legacy plain-storage biometric key is discarded and re-enrolment offered once', () async {
      await notifier.createVault('StrongVault#Pass1', 'StrongVault#Pass1');
      await notifier.lockVault();
      // Simulate what older versions stored.
      await const FlutterSecureStorage().write(key: 'myvault_biometric_wrapping_key', value: 'AAAA');
      await const FlutterSecureStorage().write(key: 'myvault_biometric_enabled', value: 'true');

      await notifier.initialize();
      expect(await storage.hasLegacyBiometricKey(), isFalse);
      expect(notifier.state.isBiometricEnabled, isFalse);
      expect(notifier.state.offerBiometricSetup, isTrue);

      expect(await notifier.unlockWithPassword('StrongVault#Pass1'), isTrue);
      expect(await notifier.takeBiometricSetupOffer(), isTrue);
      expect(await notifier.takeBiometricSetupOffer(), isFalse);
    });

    test('changeMasterPassword rejects a wrong current password and keeps the old one', () async {
      await notifier.createVault('StrongVault#Pass1', 'StrongVault#Pass1');

      final error = await notifier.changeMasterPassword(
        currentPassword: 'WrongVault#Pass1',
        newPassword: 'NewerVault#Pass2',
        confirmPassword: 'NewerVault#Pass2',
      );
      expect(error, equals('Current password is incorrect.'));

      await notifier.lockVault();
      expect(await notifier.unlockWithPassword('StrongVault#Pass1'), isTrue);
    });

    test('changeMasterPassword re-wraps the VEK: new password unlocks the same data', () async {
      await notifier.createVault('StrongVault#Pass1', 'StrongVault#Pass1');
      final originalVek = session.vek!;

      final error = await notifier.changeMasterPassword(
        currentPassword: 'StrongVault#Pass1',
        newPassword: 'NewerVault#Pass2',
        confirmPassword: 'NewerVault#Pass2',
      );
      expect(error, isNull);

      await notifier.lockVault();
      expect(await notifier.unlockWithPassword('StrongVault#Pass1'), isFalse);
      expect(await notifier.unlockWithPassword('NewerVault#Pass2'), isTrue);
      expect(session.vek, equals(originalVek));
    });
  });

  group('6. Credential storage format', () {
    test('Reads credentials stored in the legacy per-key format', () async {
      final crypto = VaultCryptoService();
      final derived = await crypto.deriveMasterKeyAndVerifier(password: 'StrongVault#Pass1');
      final vek = crypto.generateVek();
      final wrapped = await crypto.wrapVek(vek: vek, wrappingKey: derived.derivedKeyBytes);

      FlutterSecureStorage.setMockInitialValues({
        'myvault_is_created': 'true',
        'myvault_salt': base64Encode(derived.saltBytes),
        'myvault_verifier': base64Encode(derived.verifierHashBytes),
        'myvault_kdf_params': jsonEncode(derived.kdfParams),
        'myvault_wrapped_vek_kek': jsonEncode(wrapped),
      });
      final storage = VaultStorageService(storage: const FlutterSecureStorage());

      expect(await storage.hasVault(), isTrue);
      expect(await storage.getSalt(), equals(derived.saltBytes));
      expect(await storage.getVerifier(), equals(derived.verifierHashBytes));
      expect(await storage.getKdfParams(), equals(derived.kdfParams));
      expect(await storage.getWrappedVekKek(), equals(wrapped));
    });

    test('Saving credentials writes one combined record and drops legacy keys', () async {
      FlutterSecureStorage.setMockInitialValues({'myvault_salt': 'stale'});
      const secure = FlutterSecureStorage();
      final storage = VaultStorageService(storage: secure);

      await storage.saveVaultCredentials(
        salt: [1, 2, 3],
        verifierHash: [4, 5, 6],
        kdfParams: {'algorithm': 'Argon2id'},
        wrappedVekKek: {'iv': 'a', 'ciphertext': 'b', 'tag': 'c'},
      );

      final all = await secure.readAll();
      expect(all.containsKey('myvault_credentials_v2'), isTrue);
      expect(all.containsKey('myvault_salt'), isFalse);
      expect(await storage.getSalt(), equals([1, 2, 3]));
      expect(await storage.getWrappedVekKek(), equals({'iv': 'a', 'ciphertext': 'b', 'tag': 'c'}));
    });
  });

  group('7. Brute-force limits, KDF parameters and auto-lock policy', () {
    late VaultStorageService storage;
    late VaultDatabase vaultDb;
    late DateTime now;
    late VaultAuthNotifier notifier;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      storage = VaultStorageService(storage: const FlutterSecureStorage());
      vaultDb = VaultDatabase(customFactory: databaseFactoryFfi);
      now = DateTime(2026, 10, 31, 12);
      notifier = VaultAuthNotifier(
        cryptoService: VaultCryptoService(),
        storageService: storage,
        biometricService: MockBiometricService(isSupported: false, authSuccess: false),
        session: VaultSession(),
        vaultDb: vaultDb,
        clock: () => now,
      );
      await notifier.initialize();
      await notifier.createVault('StrongVault#Pass1', 'StrongVault#Pass1');
      await notifier.lockVault();
    });

    tearDown(() async {
      notifier.dispose();
      await vaultDb.close();
    });

    test('lockoutFor: free attempts, then 30s doubling, capped at 1 hour', () {
      expect(VaultAuthNotifier.lockoutFor(4), Duration.zero);
      expect(VaultAuthNotifier.lockoutFor(5), const Duration(seconds: 30));
      expect(VaultAuthNotifier.lockoutFor(6), const Duration(seconds: 60));
      expect(VaultAuthNotifier.lockoutFor(50), const Duration(hours: 1));
    });

    test('After 5 wrong passwords even the correct one is refused until the delay passes', () async {
      for (var i = 0; i < 5; i++) {
        expect(await notifier.unlockWithPassword('WrongVault#Pass1'), isFalse);
      }
      expect(notifier.state.errorMessage, contains('Try again in 30 seconds'));

      expect(await notifier.unlockWithPassword('StrongVault#Pass1'), isFalse);
      expect(notifier.state.status, VaultStatus.locked);

      now = now.add(const Duration(seconds: 31));
      expect(await notifier.unlockWithPassword('StrongVault#Pass1'), isTrue);
      expect(await storage.getFailedAttempts(), 0);
    });

    test('Change-password dialog is subject to the same lockout', () async {
      for (var i = 0; i < 5; i++) {
        await notifier.unlockWithPassword('WrongVault#Pass1');
      }
      final error = await notifier.changeMasterPassword(
        currentPassword: 'StrongVault#Pass1',
        newPassword: 'NewerVault#Pass2',
        confirmPassword: 'NewerVault#Pass2',
      );
      expect(error, contains('Too many failed attempts'));
    });

    test('Unlock uses the KDF parameters stored with the vault', () async {
      final crypto = VaultCryptoService();

      // Recover the real VEK using the credentials createVault stored (default parameters).
      final currentKek = await crypto.deriveMasterKeyAndVerifier(
        password: 'StrongVault#Pass1',
        existingSalt: (await storage.getSalt())!,
      );
      final realVek = await crypto.unwrapVek(
        wrappedVek: (await storage.getWrappedVekKek())!,
        wrappingKey: currentKek.derivedKeyBytes,
      );

      // Re-store the credentials derived with NON-default parameters.
      final custom = await crypto.deriveMasterKeyAndVerifier(
        password: 'StrongVault#Pass1',
        kdfParams: const {'memory': 8192, 'iterations': 1, 'parallelism': 1},
      );
      await storage.saveVaultCredentials(
        salt: custom.saltBytes,
        verifierHash: custom.verifierHashBytes,
        kdfParams: custom.kdfParams,
        wrappedVekKek: await crypto.wrapVek(vek: realVek, wrappingKey: custom.derivedKeyBytes),
      );

      // Default parameters give a different key, so unlocking proves the stored ones were used.
      final withDefaults = await crypto.deriveMasterKeyAndVerifier(
        password: 'StrongVault#Pass1',
        existingSalt: custom.saltBytes,
      );
      expect(withDefaults.verifierHashBytes, isNot(equals(custom.verifierHashBytes)));
      expect(await notifier.unlockWithPassword('StrongVault#Pass1'), isTrue);
    });

    test('Out-of-bounds stored KDF parameters are rejected, not executed', () async {
      expect(
        () => VaultCryptoService().deriveMasterKeyAndVerifier(
          password: 'x',
          kdfParams: {'memory': 4 * 1024 * 1024},
        ),
        throwsArgumentError,
      );
    });

    test('Leaving the app locks by default, except for our own file picker / viewer', () async {
      expect(await notifier.unlockWithPassword('StrongVault#Pass1'), isTrue);
      expect(notifier.state.lockOnBackground, isTrue);

      notifier.allowExternalActivity();
      await notifier.checkAutoLock(isBackgrounding: true);
      expect(notifier.state.status, VaultStatus.unlocked);
      await notifier.checkAutoLock(); // resumed
      expect(notifier.state.status, VaultStatus.unlocked);

      // The grace is one-shot: a normal app switch afterwards locks.
      await notifier.checkAutoLock(isBackgrounding: true);
      expect(notifier.state.status, VaultStatus.locked);
    });

    test('With lock-on-leave off, a short app switch keeps the vault unlocked', () async {
      await notifier.setLockOnBackground(false);
      expect(await notifier.unlockWithPassword('StrongVault#Pass1'), isTrue);

      await notifier.checkAutoLock(isBackgrounding: true);
      expect(notifier.state.status, VaultStatus.unlocked);
      expect(await storage.getLockOnBackground(), isFalse);
    });
  });
}
