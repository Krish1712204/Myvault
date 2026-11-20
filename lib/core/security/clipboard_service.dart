import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClipboardService {
  static Timer? _clearTimer;
  static bool _hasSensitiveDataCopied = false;
  static const MethodChannel _system = MethodChannel('myvault/system');

  /// Copies [text] flagged as sensitive on Android (see SystemChannel.kt): hidden in the
  /// Android 13+ "copied" preview and kept out of keyboard clipboard history.
  static Future<void> _setSensitiveClip(String text, String label) async {
    if (Platform.isAndroid) {
      try {
        await _system.invokeMethod<void>('copySensitive', {'text': text, 'label': label});
        return;
      } catch (_) {}
    }
    await Clipboard.setData(ClipboardData(text: text));
  }

  static Future<void> _emptyClipboard() async {
    if (Platform.isAndroid) {
      try {
        await _system.invokeMethod<void>('clearClipboard');
        return;
      } catch (_) {}
    }
    await Clipboard.setData(const ClipboardData(text: ''));
  }

  /// Copies sensitive text to the clipboard and schedules automatic clearing
  static Future<void> copySensitive({
    required BuildContext context,
    required String text,
    required String label,
    Duration clearDuration = const Duration(seconds: 30),
  }) async {
    _clearTimer?.cancel();
    _hasSensitiveDataCopied = true;

    try {
      await _setSensitiveClip(text, label);
    } catch (_) {}

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copied (auto-clears in ${clearDuration.inSeconds}s)'),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Clear Now',
            textColor: Colors.amber,
            onPressed: () {
              clearClipboard();
            },
          ),
        ),
      );
    }

    _clearTimer = Timer(clearDuration, () async {
      await clearIfMatches(text);
    });
  }

  /// Copies non-sensitive text (like username or URL) without auto-clear warning
  static Future<void> copyPublic({
    required BuildContext context,
    required String text,
    required String label,
  }) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copied to clipboard'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Clears clipboard if it still holds the sensitive text.
  ///
  /// Android 10+ does not let a background app read the clipboard (the read returns
  /// nothing). The user has usually switched apps to paste the password, so an unreadable
  /// clipboard is cleared too; only clipboard text known to be something else is kept.
  static Future<void> clearIfMatches(String expectedText) async {
    if (!_hasSensitiveDataCopied) return;
    String? current;
    try {
      current = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (_) {
      current = null;
    }
    if (current != null && current.isNotEmpty && current != expectedText) {
      _hasSensitiveDataCopied = false; // the user copied something else since
      return;
    }
    _hasSensitiveDataCopied = false;
    try {
      await _emptyClipboard();
    } catch (_) {}
  }

  /// Immediately wipes the clipboard if sensitive data was previously copied.
  /// Does NOT touch the clipboard if no sensitive data was copied, preventing
  /// the system "Copied" toast from triggering on app launch or lock.
  static Future<void> clearClipboard() async {
    _clearTimer?.cancel();
    _clearTimer = null;
    if (!_hasSensitiveDataCopied) return;
    _hasSensitiveDataCopied = false;
    try {
      await _emptyClipboard();
    } catch (_) {}
  }
}
