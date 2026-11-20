import 'dart:typed_data';

/// In-memory ephemeral session manager that protects decrypted keys and session state.
/// Holds sensitive Vault Encryption Key (VEK) bytes ONLY while the vault is unlocked
/// and zeroizes them immediately upon locking.
class VaultSession {
  Uint8List? _ephemeralVek;
  DateTime? _lastActivityTime;

  bool get isActive => _ephemeralVek != null;
  DateTime? get lastActivityTime => _lastActivityTime;

  /// Ephemeral copy of decrypted Vault Encryption Key (VEK) bytes
  Uint8List? get vek => _ephemeralVek != null
      ? Uint8List.fromList(_ephemeralVek!)
      : null;

  /// Starts an active session with the decrypted VEK
  void startSession(List<int> vekBytes) {
    // Zero out any existing key first
    clear();
    _ephemeralVek = Uint8List.fromList(vekBytes);
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
    if (_ephemeralVek != null) {
      _ephemeralVek!.fillRange(0, _ephemeralVek!.length, 0);
      _ephemeralVek = null;
    }
    _lastActivityTime = null;
  }
}
