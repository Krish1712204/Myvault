import 'dart:io';

import 'package:flutter/services.dart';

import '../backup/google_drive_backup_service.dart';
import '../backup/vault_backup_service.dart';

/// Plain-language text for an error shown to the user.
///
/// The app's own exceptions already carry messages written for people; anything else
/// (database, platform, programming errors) gets a generic sentence instead of raw text
/// such as "Bad state: …" or "DatabaseException(…)".
String userMessage(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
  if (error is BackupException) return error.message;
  if (error is GoogleDriveBackupException) return error.message;
  if (error is StateError && error.message.toLowerCase().contains('locked')) {
    return 'Your vault is locked. Unlock it and try again.';
  }
  if (error is FileSystemException) return 'The file could not be read or saved on this phone.';
  if (error is PlatformException) {
    final message = error.message;
    return message != null && message.isNotEmpty && message.length < 140 ? message : fallback;
  }
  return fallback;
}
