enum VaultStatus {
  initial,
  uninitialized,
  locked,
  unlocked,
}

class VaultAuthState {
  final VaultStatus status;
  final bool isBiometricAvailable;
  final bool isBiometricEnabled;
  final String autoLockDuration;
  final bool lockOnBackground;

  /// Offer to turn on fingerprint unlock once the vault is open: after creating a vault, or after
  /// the upgrade to Keystore-bound keys removed the old (insecure) fingerprint setup.
  final bool offerBiometricSetup;
  final String? errorMessage;
  final bool isLoading;

  const VaultAuthState({
    this.status = VaultStatus.initial,
    this.isBiometricAvailable = false,
    this.isBiometricEnabled = false,
    this.autoLockDuration = '5 minutes',
    this.lockOnBackground = true,
    this.offerBiometricSetup = false,
    this.errorMessage,
    this.isLoading = false,
  });

  bool get isVaultCreated =>
      status != VaultStatus.uninitialized && status != VaultStatus.initial;

  bool get isUnlocked => status == VaultStatus.unlocked;

  Duration get autoLockTimeout {
    switch (autoLockDuration) {
      case 'Immediately':
        return Duration.zero;
      case '1 minute':
        return const Duration(minutes: 1);
      case '5 minutes':
        return const Duration(minutes: 5);
      case '15 minutes':
        return const Duration(minutes: 15);
      case '30 minutes':
        return const Duration(minutes: 30);
      default:
        return const Duration(minutes: 5);
    }
  }

  VaultAuthState copyWith({
    VaultStatus? status,
    bool? isBiometricAvailable,
    bool? isBiometricEnabled,
    String? autoLockDuration,
    bool? lockOnBackground,
    bool? offerBiometricSetup,
    String? errorMessage,
    bool clearError = false,
    bool? isLoading,
  }) {
    return VaultAuthState(
      status: status ?? this.status,
      isBiometricAvailable: isBiometricAvailable ?? this.isBiometricAvailable,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      autoLockDuration: autoLockDuration ?? this.autoLockDuration,
      lockOnBackground: lockOnBackground ?? this.lockOnBackground,
      offerBiometricSetup: offerBiometricSetup ?? this.offerBiometricSetup,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

