import 'dart:typed_data';

/// In-memory ephemeral session manager that protects decrypted keys and session state.
/// Holds sensitive master key bytes ONLY while the vault is unlocked and zeroizes them on lock.
class VaultSession {
  Uint8List? _ephemeralMasterKey;
  DateTime? _lastActivityTime;

  bool get isActive => _ephemeralMasterKey != null;
  DateTime? get lastActivityTime => _lastActivityTime;

  /// Ephemeral copy of derived master key bytes
  Uint8List? get masterKey => _ephemeralMasterKey != null
      ? Uint8List.fromList(_ephemeralMasterKey!)
      : null;

  /// Starts an active session with the derived master key
  void startSession(List<int> masterKeyBytes) {
    // Zero out any existing key first
    clear();
    _ephemeralMasterKey = Uint8List.fromList(masterKeyBytes);
    _lastActivityTime = DateTime.now();
  }

  /// Refreshes user activity timestamp
  void updateActivity() {
    if (isActive) {
      _lastActivityTime = DateTime.now();
    }
  }

  /// Checks if the session has exceeded the specified inactivity timeout
  bool isExpired(Duration timeout) {
    if (!isActive || _lastActivityTime == null) return true;
    final elapsed = DateTime.now().difference(_lastActivityTime!);
    return elapsed >= timeout;
  }

  /// Explicitly terminates session and cryptographically overwrites (zeroizes) key bytes in memory
  void clear() {
    if (_ephemeralMasterKey != null) {
      _ephemeralMasterKey!.fillRange(0, _ephemeralMasterKey!.length, 0);
      _ephemeralMasterKey = null;
    }
    _lastActivityTime = null;
  }
}
