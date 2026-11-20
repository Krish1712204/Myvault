import 'dart:io';
import 'package:flutter/services.dart';

/// A reading of the device's monotonic clock: time since boot, and which boot it was.
/// Unlike the wall clock, it cannot be moved from Settings.
class MonotonicTime {
  final int elapsedMs;

  /// Android's boot counter, or -1 when unknown.
  final int bootCount;

  const MonotonicTime({required this.elapsedMs, required this.bootCount});
}

/// Reads the monotonic clock through SystemChannel.kt. Returns null where it is unavailable
/// (other platforms, tests), so callers fall back to the wall clock.
class DeviceClock {
  static const MethodChannel _channel = MethodChannel('myvault/system');

  const DeviceClock();

  Future<MonotonicTime?> now() async {
    if (!Platform.isAndroid) return null;
    try {
      final map = await _channel.invokeMapMethod<String, Object?>('monotonicClock');
      final elapsed = map?['elapsedMs'];
      final boot = map?['bootCount'];
      if (elapsed is! int || boot is! int) return null;
      return MonotonicTime(elapsedMs: elapsed, bootCount: boot);
    } catch (_) {
      return null;
    }
  }
}
