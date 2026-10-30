import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/vault_database.dart';
import '../../../core/security/clipboard_service.dart';
import '../../../core/security/vault_biometric_service.dart';
import '../../../core/security/vault_crypto_service.dart';
import '../../../core/security/vault_session.dart';
import '../../../core/security/vault_storage_service.dart';
import '../../../core/storage/encrypted_file_service.dart';
import '../../vault/data/vault_repository.dart';
import 'vault_auth_state.dart';

final vaultCryptoServiceProvider = Provider<VaultCryptoService>((ref) {
  return VaultCryptoService();
});

final vaultStorageServiceProvider = Provider<VaultStorageService>((ref) {
  return VaultStorageService();
});

final vaultBiometricServiceProvider = Provider<VaultBiometricService>((ref) {
  return VaultBiometricService();
});

final vaultSessionProvider = Provider<VaultSession>((ref) {
  return VaultSession();
});

final vaultDatabaseProvider = Provider<VaultDatabase>((ref) {
  return VaultDatabase();
});

final encryptedFileServiceProvider = Provider<EncryptedFileService>((ref) {
  return EncryptedFileService();
});

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  return VaultRepository(
    vaultDb: ref.watch(vaultDatabaseProvider),
    fileService: ref.watch(encryptedFileServiceProvider),
  );
});

class VaultAuthNotifier extends StateNotifier<VaultAuthState> {
  final VaultCryptoService _cryptoService;
  final VaultStorageService _storageService;
  final VaultBiometricService _biometricService;
  final VaultSession _session;
  final VaultDatabase _vaultDb;
  final VaultRepository _repository;
  final EncryptedFileService? _fileService;

  VaultAuthNotifier({
    required VaultCryptoService cryptoService,
    required VaultStorageService storageService,
    required VaultBiometricService biometricService,
    required VaultSession session,
    required VaultDatabase vaultDb,
    required VaultRepository repository,
    EncryptedFileService? fileService,
  })  : _cryptoService = cryptoService,
        _storageService = storageService,
        _biometricService = biometricService,
        _session = session,
        _vaultDb = vaultDb,
        _repository = repository,
        _fileService = fileService,
        super(const VaultAuthState()) {
    initialize();
  }

  /// Initializes auth state from secure storage and platform hardware capabilities
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);

    try {
      await _fileService?.clearTemporaryPreviews();
      final hasVault = await _storageService.hasVault();
      final canBiometrics = await _biometricService.canAuthenticate();
      final biometricEnabled = await _storageService.isBiometricEnabled();
      final autoLockDuration = await _storageService.getAutoLockDuration();

      if (!hasVault) {
        state = state.copyWith(
          status: VaultStatus.uninitialized,
          isBiometricAvailable: canBiometrics,
          isBiometricEnabled: false,
          autoLockDuration: autoLockDuration,
          isLoading: false,
          clearError: true,
        );
      } else {
        // Vault exists: always start locked on launch
        state = state.copyWith(
          status: VaultStatus.locked,
          isBiometricAvailable: canBiometrics,
          isBiometricEnabled: biometricEnabled && canBiometrics,
          autoLockDuration: autoLockDuration,
          isLoading: false,
          clearError: true,
        );
      }
    } catch (_) {
      state = state.copyWith(
        status: VaultStatus.uninitialized,
        isLoading: false,
        errorMessage: 'Unable to initialize secure storage.',
      );
    }
  }

  /// Creates a new vault with VEK generation, KEK wrapping, secure storage, and database setup
  Future<bool> createVault(String password, String confirmPassword) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final validation = _cryptoService.validatePassword(password, confirmPassword);
    if (!validation.isValid) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: validation.errorMessage ?? 'Password does not meet security criteria.',
      );
      return false;
    }

    try {
      // 1. Derive KEK (Key Encryption Key) and Verifier Hash from password using Argon2id
      final derivedResult = await _cryptoService.deriveMasterKeyAndVerifier(password: password);

      // 2. Generate a fresh, cryptographically secure 256-bit Vault Encryption Key (VEK)
      final vek = _cryptoService.generateVek();

      // 3. Wrap VEK using AES-256-GCM with KEK
      final wrappedVekPassword = await _cryptoService.wrapVek(
        vek: vek,
        wrappingKey: derivedResult.derivedKeyBytes,
      );

      // 4. Persist salt, verifier hash, KDF parameters, and wrapped VEK
      await _storageService.saveVaultCredentials(
        salt: derivedResult.saltBytes,
        verifierHash: derivedResult.verifierHashBytes,
        kdfParams: derivedResult.kdfParams,
        wrappedVekKek: wrappedVekPassword,
      );

      // 5. If device supports biometrics, generate Biometric Wrapping Key and wrap VEK
      final canBiometrics = await _biometricService.canAuthenticate();
      if (canBiometrics) {
        final bwk = _cryptoService.generateRandomBytes(32);
        final wrappedVekBiometric = await _cryptoService.wrapVek(
          vek: vek,
          wrappingKey: bwk,
        );
        await _storageService.saveBiometricVek(
          biometricWrappingKey: bwk,
          wrappedVekBiometric: wrappedVekBiometric,
        );
      }

      // 6. Initialize in-memory ephemeral VEK
      _session.startSession(vek);

      // 7. Open encrypted SQLCipher database using derived database key & seed initial data
      final hexDbKey = await _cryptoService.deriveDatabaseKeyHex(vek);
      await _vaultDb.open(hexDatabaseKey: hexDbKey);
      await _repository.seedInitialDataIfEmpty();

      state = state.copyWith(
        status: VaultStatus.unlocked,
        isBiometricAvailable: canBiometrics,
        isBiometricEnabled: canBiometrics,
        isLoading: false,
        clearError: true,
      );
      return true;
    } catch (_) {
      _session.clear();
      await _vaultDb.close();
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to create vault securely. Please try again.',
      );
      return false;
    }
  }

  /// Authenticates using master password, unwraps VEK, and opens encrypted database
  Future<bool> unlockWithPassword(String password) async {
    if (password.isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter your master password.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final storedSalt = await _storageService.getSalt();
      final storedVerifier = await _storageService.getVerifier();
      final wrappedVek = await _storageService.getWrappedVekKek();

      if (storedSalt == null || storedVerifier == null || wrappedVek == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Vault credentials not found. Please recreate your vault.',
        );
        return false;
      }

      final derivedResult = await _cryptoService.deriveMasterKeyAndVerifier(
        password: password,
        existingSalt: storedSalt,
      );

      final isValid = _cryptoService.constantTimeEquals(
        derivedResult.verifierHashBytes,
        storedVerifier,
      );

      if (!isValid) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Incorrect master password. Please try again.',
        );
        return false;
      }

      // Password matches: unwrap VEK using KEK
      final unwrappedVek = await _cryptoService.unwrapVek(
        wrappedVek: wrappedVek,
        wrappingKey: derivedResult.derivedKeyBytes,
      );

      _session.startSession(unwrappedVek);

      // Open encrypted SQLCipher database using key derived from VEK
      final hexDbKey = await _cryptoService.deriveDatabaseKeyHex(unwrappedVek);
      await _vaultDb.open(hexDatabaseKey: hexDbKey);
      await _repository.seedInitialDataIfEmpty();

      state = state.copyWith(
        status: VaultStatus.unlocked,
        isLoading: false,
        clearError: true,
      );
      return true;
    } catch (_) {
      _session.clear();
      await _vaultDb.close();
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Authentication error occurred. Please try again.',
      );
      return false;
    }
  }

  /// Authenticates using Android Biometrics, unwraps genuine VEK, and opens encrypted database
  Future<bool> unlockWithBiometrics() async {
    if (!state.isBiometricAvailable || !state.isBiometricEnabled) {
      state = state.copyWith(
        errorMessage: 'Biometric unlock is not enabled or not available on this device.',
      );
      return false;
    }

    try {
      final authenticated = await _biometricService.authenticate();
      if (!authenticated) return false;

      final bwk = await _storageService.getBiometricWrappingKey();
      final wrappedVek = await _storageService.getWrappedVekBiometric();

      if (bwk == null || wrappedVek == null) {
        state = state.copyWith(
          errorMessage: 'Biometric credentials not found. Please enter master password.',
        );
        return false;
      }

      // Unwrap the SAME genuine VEK using the hardware-protected biometric wrapping key
      final unwrappedVek = await _cryptoService.unwrapVek(
        wrappedVek: wrappedVek,
        wrappingKey: bwk,
      );

      _session.startSession(unwrappedVek);

      // Open encrypted SQLCipher database
      final hexDbKey = await _cryptoService.deriveDatabaseKeyHex(unwrappedVek);
      await _vaultDb.open(hexDatabaseKey: hexDbKey);
      await _repository.seedInitialDataIfEmpty();

      state = state.copyWith(
        status: VaultStatus.unlocked,
        clearError: true,
      );
      return true;
    } catch (_) {
      _session.clear();
      await _vaultDb.close();
      state = state.copyWith(
        errorMessage: 'Biometric unlock failed. Please use master password.',
      );
      return false;
    }
  }

  /// Locks the vault, closes encrypted database, and zeroizes memory
  Future<void> lockVault() async {
    _session.clear();
    await ClipboardService.clearClipboard();
    await _fileService?.clearTemporaryPreviews();
    state = state.copyWith(
      status: VaultStatus.locked,
      clearError: true,
    );
    await _vaultDb.close();
  }

  /// Records user touch or UI interaction to reset inactivity timer
  void recordActivity() {
    if (state.status == VaultStatus.unlocked) {
      _session.updateActivity();
    }
  }

  /// Evaluates auto-lock policy (e.g. backgrounding or inactivity timeout)
  Future<void> checkAutoLock({bool isBackgrounding = false}) async {
    if (state.status != VaultStatus.unlocked) return;

    if (isBackgrounding) {
      if (state.autoLockDuration == 'Immediately') {
        await lockVault();
      }
    } else {
      if (_session.isExpired(state.autoLockTimeout)) {
        await lockVault();
      }
    }
  }

  /// Updates biometric setting and manages biometric wrapping key
  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      final vek = _session.vek;
      if (vek != null) {
        final bwk = _cryptoService.generateRandomBytes(32);
        final wrappedVek = await _cryptoService.wrapVek(vek: vek, wrappingKey: bwk);
        await _storageService.saveBiometricVek(
          biometricWrappingKey: bwk,
          wrappedVekBiometric: wrappedVek,
        );
      }
      state = state.copyWith(isBiometricEnabled: true);
    } else {
      await _storageService.clearBiometricKeys();
      state = state.copyWith(isBiometricEnabled: false);
    }
  }

  /// Updates auto-lock duration preference
  Future<void> setAutoLockDuration(String duration) async {
    await _storageService.setAutoLockDuration(duration);
    state = state.copyWith(autoLockDuration: duration);
  }

  /// Clears error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final vaultAuthStateProvider =
    StateNotifierProvider<VaultAuthNotifier, VaultAuthState>((ref) {
  return VaultAuthNotifier(
    cryptoService: ref.watch(vaultCryptoServiceProvider),
    storageService: ref.watch(vaultStorageServiceProvider),
    biometricService: ref.watch(vaultBiometricServiceProvider),
    session: ref.watch(vaultSessionProvider),
    vaultDb: ref.watch(vaultDatabaseProvider),
    repository: ref.watch(vaultRepositoryProvider),
    fileService: ref.watch(encryptedFileServiceProvider),
  );
});
