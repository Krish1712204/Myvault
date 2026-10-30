import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClipboardService {
  static Timer? _clearTimer;
  static bool _hasSensitiveDataCopied = false;

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
      await Clipboard.setData(ClipboardData(text: text));
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

  /// Clears clipboard if it still holds the sensitive text
  static Future<void> clearIfMatches(String expectedText) async {
    if (!_hasSensitiveDataCopied) return;
    try {
      final currentData = await Clipboard.getData(Clipboard.kTextPlain);
      if (currentData?.text == expectedText) {
        _hasSensitiveDataCopied = false;
        await Clipboard.setData(const ClipboardData(text: ''));
      }
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
      await Clipboard.setData(const ClipboardData(text: ''));
    } catch (_) {}
  }
}
