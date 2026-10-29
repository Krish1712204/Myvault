import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/vault_biometric_service.dart';
import '../../../core/security/vault_crypto_service.dart';
import '../../../core/security/vault_session.dart';
import '../../../core/security/vault_storage_service.dart';
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

class VaultAuthNotifier extends StateNotifier<VaultAuthState> {
  final VaultCryptoService _cryptoService;
  final VaultStorageService _storageService;
  final VaultBiometricService _biometricService;
  final VaultSession _session;

  VaultAuthNotifier({
    required VaultCryptoService cryptoService,
    required VaultStorageService storageService,
    required VaultBiometricService biometricService,
    required VaultSession session,
  })  : _cryptoService = cryptoService,
        _storageService = storageService,
        _biometricService = biometricService,
        _session = session,
        super(const VaultAuthState()) {
    initialize();
  }

  /// Initializes auth state from secure storage and platform hardware capabilities
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);

    try {
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

  /// Creates a new vault with master password derivation and secure storage
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
      // Derive key and verifier using Argon2id
      final derivedResult = await _cryptoService.deriveMasterKeyAndVerifier(password: password);

      // Persist only salt, verifier hash, and KDF metadata (NEVER plaintext password)
      await _storageService.saveVaultCredentials(
        salt: derivedResult.saltBytes,
        verifierHash: derivedResult.verifierHashBytes,
        kdfParams: derivedResult.kdfParams,
      );

      final canBiometrics = await _biometricService.canAuthenticate();
      if (canBiometrics) {
        await _storageService.setBiometricEnabled(true);
      }

      // Initialize in-memory ephemeral master key
      _session.startSession(derivedResult.derivedKeyBytes);

      state = state.copyWith(
        status: VaultStatus.unlocked,
        isBiometricAvailable: canBiometrics,
        isBiometricEnabled: canBiometrics,
        isLoading: false,
        clearError: true,
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to create vault securely. Please try again.',
      );
      return false;
    }
  }

  /// Authenticates using master password and constant-time verifier matching
  Future<bool> unlockWithPassword(String password) async {
    if (password.isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter your master password.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final storedSalt = await _storageService.getSalt();
      final storedVerifier = await _storageService.getVerifier();

      if (storedSalt == null || storedVerifier == null) {
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

      if (isValid) {
        _session.startSession(derivedResult.derivedKeyBytes);
        state = state.copyWith(
          status: VaultStatus.unlocked,
          isLoading: false,
          clearError: true,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Incorrect master password. Please try again.',
        );
        return false;
      }
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Authentication error occurred. Please try again.',
      );
      return false;
    }
  }

  /// Authenticates using Android Biometrics (Fingerprint/Face)
  Future<bool> unlockWithBiometrics() async {
    if (!state.isBiometricAvailable || !state.isBiometricEnabled) {
      state = state.copyWith(
        errorMessage: 'Biometric unlock is not enabled or not available on this device.',
      );
      return false;
    }

    try {
      final authenticated = await _biometricService.authenticate();
      if (authenticated) {
        // Ephemeral session placeholder for biometric unlock
        // In Phase 3, this retrieves the wrapped VEK from Android Keystore.
        _session.startSession(List<int>.filled(32, 0xAA));
        state = state.copyWith(
          status: VaultStatus.unlocked,
          clearError: true,
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Locks the vault and zeros ephemeral sensitive material
  void lockVault() {
    _session.clear();
    state = state.copyWith(
      status: VaultStatus.locked,
      clearError: true,
    );
  }

  /// Records user touch or UI interaction to reset inactivity timer
  void recordActivity() {
    if (state.status == VaultStatus.unlocked) {
      _session.updateActivity();
    }
  }

  /// Evaluates auto-lock policy (e.g. backgrounding or inactivity timeout)
  void checkAutoLock({bool isBackgrounding = false}) {
    if (state.status != VaultStatus.unlocked) return;

    if (isBackgrounding) {
      if (state.autoLockDuration == 'Immediately') {
        lockVault();
      }
    } else {
      if (_session.isExpired(state.autoLockTimeout)) {
        lockVault();
      }
    }
  }

  /// Updates biometric setting
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storageService.setBiometricEnabled(enabled);
    state = state.copyWith(isBiometricEnabled: enabled);
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
  );
});
