import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  @override
  Future<bool> authenticate({String reason = ''}) async => authSuccess;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      expect(session.masterKey, isNull);
    });

    test('startSession activates session and holds master key', () {
      final key = List<int>.generate(32, (i) => i + 1);
      session.startSession(key);

      expect(session.isActive, isTrue);
      expect(session.masterKey, equals(key));
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
      expect(session.masterKey, isNull);
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

    test('saveVaultCredentials stores salt, verifier and kdf metadata but NEVER password', () async {
      final salt = [10, 20, 30, 40];
      final verifier = [50, 60, 70, 80];
      final kdfParams = {'algorithm': 'Argon2id', 'memory': 19456};

      await storage.saveVaultCredentials(
        salt: salt,
        verifierHash: verifier,
        kdfParams: kdfParams,
      );

      expect(await storage.hasVault(), isTrue);
      expect(await storage.getSalt(), equals(salt));
      expect(await storage.getVerifier(), equals(verifier));

      final retrievedKdf = await storage.getKdfParams();
      expect(retrievedKdf?['algorithm'], equals('Argon2id'));

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
    late VaultAuthNotifier notifier;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      crypto = VaultCryptoService();
      storage = VaultStorageService(storage: const FlutterSecureStorage());
      biometric = MockBiometricService(isSupported: true, authSuccess: true);
      session = VaultSession();

      notifier = VaultAuthNotifier(
        cryptoService: crypto,
        storageService: storage,
        biometricService: biometric,
        session: session,
      );
      await notifier.initialize();
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
    });

    test('lockVault explicitly locks and wipes session', () async {
      await notifier.createVault('StrongVault#Pass1', 'StrongVault#Pass1');
      expect(notifier.state.status, equals(VaultStatus.unlocked));

      notifier.lockVault();

      expect(notifier.state.status, equals(VaultStatus.locked));
      expect(notifier.state.isUnlocked, isFalse);
      expect(session.isActive, isFalse);
    });

    test('unlockWithPassword succeeds with correct password', () async {
      await notifier.createVault('StrongVault#Pass1', 'StrongVault#Pass1');
      notifier.lockVault();
      expect(notifier.state.status, equals(VaultStatus.locked));

      final success = await notifier.unlockWithPassword('StrongVault#Pass1');
      expect(success, isTrue);
      expect(notifier.state.status, equals(VaultStatus.unlocked));
      expect(session.isActive, isTrue);
    });

    test('unlockWithPassword fails with wrong password and leaves vault locked', () async {
      await notifier.createVault('StrongVault#Pass1', 'StrongVault#Pass1');
      notifier.lockVault();

      final success = await notifier.unlockWithPassword('WrongVault#Pass9');
      expect(success, isFalse);
      expect(notifier.state.status, equals(VaultStatus.locked));
      expect(notifier.state.errorMessage, contains('Incorrect master password'));
      expect(session.isActive, isFalse);
    });

    test('checkAutoLock locks vault when set to Immediately on backgrounding', () async {
      await notifier.createVault('StrongVault#Pass1', 'StrongVault#Pass1');
      await notifier.setAutoLockDuration('Immediately');

      notifier.checkAutoLock(isBackgrounding: true);

      expect(notifier.state.status, equals(VaultStatus.locked));
    });

    test('Biometric unlock unlocks vault when enabled', () async {
      await notifier.createVault('StrongVault#Pass1', 'StrongVault#Pass1');
      notifier.lockVault();

      final success = await notifier.unlockWithBiometrics();
      expect(success, isTrue);
      expect(notifier.state.status, equals(VaultStatus.unlocked));
    });
  });
}
