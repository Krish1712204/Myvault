import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/vault_database.dart';
import '../../../core/security/clipboard_service.dart';
import '../../../core/security/device_clock.dart';
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
  final EncryptedFileService? _fileService;
  final DateTime Function() _now;
  final DeviceClock? _deviceClock;
  Timer? _inactivityTimer;

  /// Set by [allowExternalActivity]; the next backgrounding within [externalActivityGrant]
  /// is treated as our own file picker / viewer / dialer rather than the user leaving.
  DateTime? _externalActivityRequestedAt;

  /// When the app went to the background for an external activity we launched.
  DateTime? _externalActivityStartedAt;

  /// Wrong-password attempts allowed before delays start.
  static const int freeUnlockAttempts = 5;

  /// How soon after [allowExternalActivity] the app must actually leave the foreground for the
  /// exemption to apply. If the launch fails and nothing opens, the exemption simply expires.
  static const Duration externalActivityGrant = Duration(seconds: 10);

  /// Longest time the vault stays unlocked while the user is in an app we launched, even if
  /// the auto-lock timeout is shorter (or "Immediately").
  static const Duration minExternalActivityLimit = Duration(minutes: 5);

  VaultAuthNotifier({
    required VaultCryptoService cryptoService,
    required VaultStorageService storageService,
    required VaultBiometricService biometricService,
    required VaultSession session,
    required VaultDatabase vaultDb,
    EncryptedFileService? fileService,
    DateTime Function()? clock,
    DeviceClock? deviceClock,
  })  : _now = clock ?? DateTime.now,
        _deviceClock = deviceClock,
        _cryptoService = cryptoService,
        _storageService = storageService,
        _biometricService = biometricService,
        _session = session,
        _vaultDb = vaultDb,
        _fileService = fileService,
        super(const VaultAuthState()) {
    addListener(_syncInactivityTimer, fireImmediately: false);
    initialize();
  }

  /// Initializes auth state from secure storage and platform hardware capabilities
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);

    try {
      await _fileService?.clearTemporaryPreviews();
      await _fileService?.clearPickerCache();
      final hasVault = await _storageService.hasVault();

      // Older versions kept the biometric wrapping key in plain app storage, so anyone able to
      // read that storage could unlock without a fingerprint. Discard it; the user re-enables
      // fingerprint unlock (now Keystore-bound) after their next password unlock.
      if (hasVault && await _storageService.hasLegacyBiometricKey()) {
        await _storageService.clearBiometricKeys();
        await _storageService.setBiometricUpgradePending(true);
      }
      final canBiometrics = await _biometricService.canAuthenticate();
      final biometricEnabled = await _storageService.isBiometricEnabled() &&
          await _storageService.getSealedBiometricVek() != null;
      final offerBiometricSetup = await _storageService.isBiometricUpgradePending();
      final autoLockDuration = await _storageService.getAutoLockDuration();
      final lockOnBackground = await _storageService.getLockOnBackground();

      if (!hasVault) {
        state = state.copyWith(
          status: VaultStatus.uninitialized,
          isBiometricAvailable: canBiometrics,
          isBiometricEnabled: false,
          autoLockDuration: autoLockDuration,
          lockOnBackground: lockOnBackground,
          isLoading: false,
          clearError: true,
        );
      } else {
        // Vault exists: always start locked on launch
        state = state.copyWith(
          status: VaultStatus.locked,
          isBiometricAvailable: canBiometrics,
          isBiometricEnabled: biometricEnabled && canBiometrics,
          offerBiometricSetup: offerBiometricSetup,
          autoLockDuration: autoLockDuration,
          lockOnBackground: lockOnBackground,
          isLoading: false,
          clearError: true,
        );
      }
    } catch (_) {
      // Fail safe to "locked", never "uninitialized": the latter routes to Create Vault,
      // which would overwrite the existing (temporarily unreadable) credentials.
      state = state.copyWith(
        status: VaultStatus.locked,
        isLoading: false,
        errorMessage: 'Secure storage could not be read. Restart the app; '
            'if this continues, restore from a backup.',
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
      // Never replace the credentials of an existing vault.
      if (await _storageService.hasVault()) {
        state = state.copyWith(isLoading: false, errorMessage: 'A vault already exists on this device.');
        return false;
      }
      // Leftovers of a vault whose keys are gone (e.g. secure storage was reset) can never be
      // decrypted again, and an old database file would make opening the new one fail.
      await _vaultDb.deleteDatabaseFile();
      await _fileService?.deleteAllStoredFiles();

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

      // 5. Fingerprint unlock is NOT set up here: it needs a real fingerprint confirmation,
      //    which the UI offers right after creation via setBiometricEnabled(true).
      final canBiometrics = await _biometricService.canAuthenticate();
      await _storageService.clearBiometricKeys();

      // 6. Initialize in-memory ephemeral VEK
      _session.startSession(vek);

      // 7. Open encrypted SQLCipher database using derived database key & seed initial data
      final hexDbKey = await _cryptoService.deriveDatabaseKeyHex(vek);
      await _vaultDb.open(hexDatabaseKey: hexDbKey);

      state = state.copyWith(
        status: VaultStatus.unlocked,
        isBiometricAvailable: canBiometrics,
        isBiometricEnabled: false,
        offerBiometricSetup: canBiometrics,
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
  /// [onVerified] runs after the vault is open but before the app navigates away, so the
  /// UI can play a short success animation.
  Future<bool> unlockWithPassword(String password, {Future<void> Function()? onVerified}) async {
    if (password.isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter your master password.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final lockoutMessage = await _activeLockoutMessage();
      if (lockoutMessage != null) {
        state = state.copyWith(isLoading: false, errorMessage: lockoutMessage);
        return false;
      }

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
        kdfParams: await _storageService.getKdfParams(),
      );

      final isValid = _cryptoService.constantTimeEquals(
        derivedResult.verifierHashBytes,
        storedVerifier,
      );

      if (!isValid) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: await _recordFailedAttempt('Incorrect master password.'),
        );
        return false;
      }
      await _storageService.resetFailedAttempts();

      // Password matches: unwrap VEK using KEK
      final unwrappedVek = await _cryptoService.unwrapVek(
        wrappedVek: wrappedVek,
        wrappingKey: derivedResult.derivedKeyBytes,
      );

      _session.startSession(unwrappedVek);

      // Open encrypted SQLCipher database using key derived from VEK
      final hexDbKey = await _cryptoService.deriveDatabaseKeyHex(unwrappedVek);
      await _vaultDb.open(hexDatabaseKey: hexDbKey);
      await onVerified?.call();

      state = state.copyWith(
        status: VaultStatus.unlocked,
        isLoading: false,
        clearError: true,
      );
      return true;
    } catch (e) {
      // Type only: never log key material or messages that could contain it.
      debugPrint('MyVault: password unlock failed (${e.runtimeType})');
      _session.clear();
      await _vaultDb.close();
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Authentication error occurred. Please try again.',
      );
      return false;
    }
  }

  /// Unlocks with a fingerprint: the Keystore key (usable only after a successful strong-biometric
  /// prompt) unseals the genuine VEK, which then opens the encrypted database.
  Future<bool> unlockWithBiometrics({Future<void> Function()? onVerified}) async {
    if (!state.isBiometricAvailable || !state.isBiometricEnabled) {
      state = state.copyWith(
        errorMessage: 'Fingerprint unlock is not set up. Use your master password.',
      );
      return false;
    }

    try {
      final sealed = await _storageService.getSealedBiometricVek();
      if (sealed == null) {
        await _disableBiometrics();
        state = state.copyWith(
          errorMessage: 'Fingerprint unlock is not set up. Use your master password.',
        );
        return false;
      }

      final vek = await _biometricService.unseal(sealed);

      _session.startSession(vek);
      final hexDbKey = await _cryptoService.deriveDatabaseKeyHex(vek);
      await _vaultDb.open(hexDatabaseKey: hexDbKey);
      await onVerified?.call();

      state = state.copyWith(
        status: VaultStatus.unlocked,
        clearError: true,
      );
      return true;
    } on BiometricKeyException catch (e) {
      switch (e.error) {
        case BiometricKeyError.cancelled:
          return false;
        case BiometricKeyError.keyInvalidated:
          await _disableBiometrics();
          state = state.copyWith(
            errorMessage: 'Fingerprints on this phone changed, so fingerprint unlock was turned off. '
                'Unlock with your master password, then turn it back on in Settings.',
          );
          return false;
        case BiometricKeyError.lockedOut:
          state = state.copyWith(
            errorMessage: 'Too many fingerprint attempts. Use your master password.',
          );
          return false;
        case BiometricKeyError.notAvailable:
        case BiometricKeyError.failed:
          state = state.copyWith(
            errorMessage: 'Fingerprint unlock failed. Use your master password.',
          );
          return false;
      }
    } catch (e) {
      debugPrint('MyVault: fingerprint unlock failed (${e.runtimeType})');
      _session.clear();
      await _vaultDb.close();
      state = state.copyWith(
        errorMessage: 'Fingerprint unlock failed. Use your master password.',
      );
      return false;
    }
  }

  Future<void> _disableBiometrics() async {
    await _storageService.clearBiometricKeys();
    await _biometricService.deleteKey();
    state = state.copyWith(isBiometricEnabled: false);
  }

  /// Locks the vault, closes encrypted database, and zeroizes memory.
  ///
  /// [clearClipboard] is false when locking because the user switched apps: they have most
  /// likely just copied a password to paste it there, and the clipboard's own auto-clear
  /// timer still removes it shortly afterwards.
  Future<void> lockVault({bool clearClipboard = true}) async {
    _session.clear();
    _externalActivityRequestedAt = null;
    _externalActivityStartedAt = null;
    if (clearClipboard) await ClipboardService.clearClipboard();
    await _fileService?.clearTemporaryPreviews();
    await _fileService?.clearPickerCache();
    state = state.copyWith(
      status: VaultStatus.locked,
      clearError: true,
    );
    await _vaultDb.close();
  }

  /// Permanently erases the vault on this device: database, encrypted files, fingerprint key
  /// and all stored settings. This is the only way forward after a forgotten master password,
  /// since the vault cannot be decrypted without it. Afterwards a new vault can be created
  /// and a backup restored into it.
  Future<void> eraseVault() async {
    _session.clear();
    _externalActivityRequestedAt = null;
    _externalActivityStartedAt = null;
    await ClipboardService.clearClipboard();
    await _vaultDb.deleteDatabaseFile();
    await _fileService?.deleteAllStoredFiles();
    await _fileService?.clearTemporaryPreviews();
    await _fileService?.clearPickerCache();
    await _biometricService.deleteKey();
    await _storageService.clearVault();
    state = VaultAuthState(
      status: VaultStatus.uninitialized,
      isBiometricAvailable: state.isBiometricAvailable,
    );
  }

  /// Records user touch or UI interaction to reset inactivity timer
  void recordActivity() {
    if (state.status == VaultStatus.unlocked) {
      _session.updateActivity();
    }
  }

  /// Evaluates auto-lock policy. Call with [isBackgrounding] when the app leaves the
  /// foreground, and without it when the app returns to the foreground.
  Future<void> checkAutoLock({bool isBackgrounding = false}) async {
    if (state.status != VaultStatus.unlocked) return;

    if (isBackgrounding) {
      // Android reports "hidden" and then "paused" for the same move to the background.
      if (_externalActivityStartedAt != null) return;
      // Leaving the app for a file picker / dialer / viewer we launched ourselves
      // must not lock the vault mid-task.
      if (_takeExternalActivityGrant()) {
        _externalActivityStartedAt = _now();
        return;
      }
      if (state.lockOnBackground || state.autoLockDuration == 'Immediately') {
        await lockVault(clearClipboard: false);
      }
      return;
    }

    final startedAt = _externalActivityStartedAt;
    if (startedAt != null) {
      // Back from our own external activity: counts as user activity, unless the user stayed
      // away so long that the vault should have locked anyway.
      _externalActivityStartedAt = null;
      if (_now().difference(startedAt) > _externalActivityLimit) {
        await lockVault();
        return;
      }
      _session.updateActivity();
      return;
    }
    if (_session.isExpired(state.autoLockTimeout)) {
      await lockVault();
    }
  }

  /// Periodic foreground inactivity check (also runs while we are away in an external app).
  Future<void> _onInactivityTick() async {
    if (state.status != VaultStatus.unlocked) return;
    final startedAt = _externalActivityStartedAt;
    if (startedAt != null) {
      if (_now().difference(startedAt) > _externalActivityLimit) await lockVault();
      return;
    }
    if (_session.isExpired(state.autoLockTimeout)) {
      await lockVault();
    }
  }

  Duration get _externalActivityLimit => state.autoLockTimeout > minExternalActivityLimit
      ? state.autoLockTimeout
      : minExternalActivityLimit;

  /// Consumes the exemption granted by [allowExternalActivity], if it is still fresh.
  bool _takeExternalActivityGrant() {
    final requestedAt = _externalActivityRequestedAt;
    _externalActivityRequestedAt = null;
    return requestedAt != null && _now().difference(requestedAt) <= externalActivityGrant;
  }

  /// Call right before launching another app (file picker, dialer, document viewer)
  /// so the resulting backgrounding does not lock the vault. The exemption is one-shot and
  /// expires after [externalActivityGrant], so a launch that fails (nothing opens) cannot
  /// leave the vault exempt from locking.
  void allowExternalActivity() {
    if (state.status == VaultStatus.unlocked) {
      _externalActivityRequestedAt = _now();
    }
  }

  /// Starts/stops the foreground inactivity check as the vault unlocks/locks.
  void _syncInactivityTimer(VaultAuthState s) {
    final shouldRun = s.status == VaultStatus.unlocked && s.autoLockTimeout > Duration.zero;
    if (shouldRun && _inactivityTimer == null) {
      _inactivityTimer = Timer.periodic(const Duration(seconds: 15), (_) => _onInactivityTick());
    } else if (!shouldRun) {
      _inactivityTimer?.cancel();
      _inactivityTimer = null;
    }
  }

  /// Delay imposed after [failures] consecutive wrong passwords:
  /// none for the first [freeUnlockAttempts], then 30s doubling up to 1 hour.
  static Duration lockoutFor(int failures) {
    if (failures < freeUnlockAttempts) return Duration.zero;
    final seconds = 30 * (1 << (failures - freeUnlockAttempts).clamp(0, 7));
    return Duration(seconds: seconds.clamp(30, 3600));
  }

  /// Returns a user-facing message if password entry is currently locked out.
  ///
  /// Within the same boot, the monotonic clock decides, so moving the phone's date or time
  /// forward does not end the delay. After a reboot only the wall clock is available.
  Future<String?> _activeLockoutMessage() async {
    final until = await _storageService.getLockoutUntil();
    if (until == null) return null;
    var remaining = until.difference(_now());
    final monotonicUntil = await _storageService.getLockoutUntilMonotonic();
    final monotonicNow = await _deviceClock?.now();
    if (monotonicUntil != null &&
        monotonicNow != null &&
        monotonicNow.bootCount >= 0 &&
        monotonicNow.bootCount == monotonicUntil.bootCount) {
      remaining = Duration(milliseconds: monotonicUntil.untilElapsedMs - monotonicNow.elapsedMs);
    }
    if (remaining <= Duration.zero) return null;
    return 'Too many failed attempts. Try again in ${_formatWait(remaining)}.';
  }

  /// Records a wrong password and returns [baseMessage] plus any new lockout.
  Future<String> _recordFailedAttempt(String baseMessage) async {
    final failures = await _storageService.getFailedAttempts() + 1;
    final lockout = lockoutFor(failures);
    final monotonicNow = lockout > Duration.zero ? await _deviceClock?.now() : null;
    await _storageService.setFailedAttempts(
      failures,
      lockoutUntil: lockout > Duration.zero ? _now().add(lockout) : null,
      lockoutUntilMonotonic: monotonicNow == null
          ? null
          : (
              untilElapsedMs: monotonicNow.elapsedMs + lockout.inMilliseconds,
              bootCount: monotonicNow.bootCount,
            ),
    );
    if (lockout > Duration.zero) {
      return '$baseMessage Too many failed attempts. Try again in ${_formatWait(lockout)}.';
    }
    final left = freeUnlockAttempts - failures;
    return left <= 2 ? '$baseMessage $left attempt${left == 1 ? '' : 's'} left before a delay.' : baseMessage;
  }

  static String _formatWait(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds} seconds';
    final minutes = (d.inSeconds / 60).ceil();
    return '$minutes minute${minutes == 1 ? '' : 's'}';
  }

  /// Updates the lock-when-leaving-app preference
  Future<void> setLockOnBackground(bool enabled) async {
    await _storageService.setLockOnBackground(enabled);
    state = state.copyWith(lockOnBackground: enabled);
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  /// Turns fingerprint unlock on (asks for a fingerprint to seal the VEK under a new Keystore key)
  /// or off (deletes the key and sealed VEK). Returns the resulting enabled state.
  Future<bool> setBiometricEnabled(bool enabled) async {
    if (!enabled) {
      await _disableBiometrics();
      return false;
    }

    final vek = _session.vek;
    if (vek == null) return false;
    try {
      final sealed = await _biometricService.seal(vek);
      await _storageService.saveSealedBiometricVek(sealed);
      await _storageService.setBiometricUpgradePending(false);
      state = state.copyWith(
        isBiometricEnabled: true,
        offerBiometricSetup: false,
        clearError: true,
      );
      return true;
    } on BiometricKeyException catch (e) {
      if (e.error != BiometricKeyError.cancelled) {
        state = state.copyWith(errorMessage: 'Could not turn on fingerprint unlock.');
      }
      return state.isBiometricEnabled;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Could not turn on fingerprint unlock.');
      return state.isBiometricEnabled;
    }
  }

  /// After a password unlock, returns true once if fingerprint unlock should be offered again
  /// (it was removed by the security upgrade). Clears the flag either way.
  Future<bool> takeBiometricSetupOffer() async {
    if (!state.offerBiometricSetup) return false;
    await _storageService.setBiometricUpgradePending(false);
    state = state.copyWith(offerBiometricSetup: false);
    return state.isBiometricAvailable;
  }

  /// Changes the master password by re-wrapping the existing VEK under a new KEK.
  /// The VEK itself is unchanged, so the database, files and biometric unlock keep working.
  /// Returns null on success, or a user-facing error message.
  Future<String?> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      // Same guessing limits as unlock: this dialog must not be a bypass.
      final lockoutMessage = await _activeLockoutMessage();
      if (lockoutMessage != null) return lockoutMessage;

      final salt = await _storageService.getSalt();
      final verifier = await _storageService.getVerifier();
      final wrappedVek = await _storageService.getWrappedVekKek();
      if (salt == null || verifier == null || wrappedVek == null) {
        return 'Vault credentials missing.';
      }

      final currentKek = await _cryptoService.deriveMasterKeyAndVerifier(
        password: currentPassword,
        existingSalt: salt,
        kdfParams: await _storageService.getKdfParams(),
      );
      if (!_cryptoService.constantTimeEquals(currentKek.verifierHashBytes, verifier)) {
        return await _recordFailedAttempt('Current password is incorrect.');
      }
      await _storageService.resetFailedAttempts();

      final validation = _cryptoService.validatePassword(newPassword, confirmPassword);
      if (!validation.isValid) {
        return validation.errorMessage ?? 'Password criteria not met.';
      }

      final vek = await _cryptoService.unwrapVek(
        wrappedVek: wrappedVek,
        wrappingKey: currentKek.derivedKeyBytes,
      );

      final newKek = await _cryptoService.deriveMasterKeyAndVerifier(password: newPassword);
      final newWrappedVek = await _cryptoService.wrapVek(
        vek: vek,
        wrappingKey: newKek.derivedKeyBytes,
      );

      // Single atomic write: a crash can never leave a new salt next to an old wrapped VEK.
      await _storageService.saveVaultCredentials(
        salt: newKek.saltBytes,
        verifierHash: newKek.verifierHashBytes,
        kdfParams: newKek.kdfParams,
        wrappedVekKek: newWrappedVek,
      );
      return null;
    } catch (_) {
      return 'Could not change master password. Your current password is still active.';
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
    fileService: ref.watch(encryptedFileServiceProvider),
    deviceClock: const DeviceClock(),
  );
});
