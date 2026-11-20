import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../../features/auth/domain/vault_auth_notifier.dart';
import '../security/vault_session.dart';
import '../security/vault_storage_service.dart';
import 'vault_backup_service.dart';

/// Configuration is supplied at build time, never committed to source control.
const String _googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
const String _googleServerClientId =
    String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
const String _driveBackupName = 'myvault_automatic_backup_v1.myvault';
const List<String> _driveScopes = [drive.DriveApi.driveFileScope];
const String _visibleDriveLocation = 'my_drive_v1';

class GoogleDriveBackupException implements Exception {
  final String message;
  const GoogleDriveBackupException(this.message);

  @override
  String toString() => message;
}

/// A manual backup was requested while Drive still holds a backup this device has not
/// restored. Uploading would replace it, so the user must confirm first.
class GoogleDriveRestorePendingException extends GoogleDriveBackupException {
  const GoogleDriveRestorePendingException()
      : super('Google Drive already has a MyVault backup that this device has not restored. '
            'Backing up now replaces it with this vault.');
}

class GoogleDriveBackupStatus {
  final bool enabled;
  final String? accountEmail;
  final DateTime? lastBackupAt;

  /// Drive holds a backup this device has neither restored nor chosen to replace;
  /// automatic backups are paused until one of those happens.
  final bool restorePending;

  /// Why the last automatic backup did not complete, if it failed.
  final String? lastError;

  const GoogleDriveBackupStatus({
    required this.enabled,
    this.accountEmail,
    this.lastBackupAt,
    this.restorePending = false,
    this.lastError,
  });
}

class GoogleDriveBackupResult {
  final int bytesUploaded;
  final DateTime completedAt;

  const GoogleDriveBackupResult({
    required this.bytesUploaded,
    required this.completedAt,
  });
}

/// Describes the current local-encryption or Drive-upload phase for the UI.
class GoogleDriveBackupProgress {
  final double? fraction;
  final String message;

  const GoogleDriveBackupProgress({this.fraction, required this.message});
}

/// Uploads only the existing encrypted `.myvault` container to the user's
/// visible My Drive. Google never receives vault plaintext, the VEK, or the
/// master password.
class GoogleDriveBackupService {
  final VaultBackupService _backupService;
  final VaultStorageService _storage;
  final VaultSession _session;
  final GoogleSignIn _signIn;

  GoogleSignInAccount? _account;
  Timer? _automaticBackupTimer;
  Future<void> _uploadQueue = Future<void>.value();
  final ValueNotifier<GoogleDriveBackupProgress?> progress = ValueNotifier(null);

  GoogleDriveBackupService({
    required VaultBackupService backupService,
    required VaultStorageService storage,
    required VaultSession session,
    GoogleSignIn? signIn,
  })  : _backupService = backupService,
        _storage = storage,
        _session = session,
        _signIn = signIn ??
            GoogleSignIn(
              scopes: _driveScopes,
              clientId: _googleClientId.isEmpty ? null : _googleClientId,
              serverClientId: _googleServerClientId.isEmpty
                  ? null
                  : _googleServerClientId,
            );

  Future<GoogleDriveBackupStatus> status() async {
    return GoogleDriveBackupStatus(
      enabled: await _storage.isGoogleDriveBackupEnabled(),
      accountEmail: await _storage.getGoogleDriveAccountEmail(),
      lastBackupAt: await _storage.getLastBackupAt(),
      restorePending: await _storage.isGoogleDriveRestorePending(),
      lastError: await _storage.getGoogleDriveLastError(),
    );
  }

  /// Must be called by a user action because it can display Google consent UI.
  ///
  /// If Drive already holds a MyVault backup (e.g. when setting up a replacement device),
  /// the passphrase must open it, and automatic backups stay paused until the user restores
  /// it or explicitly replaces it. This way, connecting can never overwrite a good backup.
  Future<GoogleDriveBackupStatus> connect({
    required String recoveryPassphrase,
  }) async {
    if (recoveryPassphrase.trim().length < 8) {
      throw const GoogleDriveBackupException(
        'Choose a backup recovery passphrase with at least 8 characters.',
      );
    }

    final account = await _accountFor(interactive: true);

    var existingBackup = false;
    try {
      progress.value = const GoogleDriveBackupProgress(message: 'Checking Google Drive for a backup…');
      final bytes = await _downloadLatest(requireExisting: false);
      if (bytes != null) {
        existingBackup = true;
        progress.value = const GoogleDriveBackupProgress(message: 'Checking the passphrase…');
        await _backupService.decryptAndValidateBackup(fileBytes: bytes, passphrase: recoveryPassphrase);
      }
    } on InvalidBackupPassphraseException {
      await _storage.clearGoogleDriveBackupConfiguration();
      throw const GoogleDriveBackupException(
        'This Google Drive already has a MyVault backup, and this passphrase does not open it. '
        'Enter the passphrase you used when that backup was made.',
      );
    } on BackupException {
      // An existing backup that is damaged or from a newer app version: connect, but keep
      // automatic uploads paused so replacing it is still the user's explicit choice.
    } catch (_) {
      await _storage.clearGoogleDriveBackupConfiguration();
      rethrow;
    } finally {
      progress.value = null;
    }

    await _storage.saveGoogleDriveBackupConfiguration(
      passphrase: recoveryPassphrase,
      accountEmail: account.email,
    );
    await _storage.setGoogleDriveRestorePending(existingBackup);
    await _storage.setGoogleDriveLastError(null);
    if (!existingBackup) requestAutomaticBackup();
    return status();
  }

  /// Queues a backup after a vault write. The short delay coalesces rapid edits,
  /// such as an imported contact list, into one encrypted upload. The change is also
  /// recorded persistently, so if the vault locks before the upload runs, it is uploaded
  /// after the next unlock instead of being lost.
  void requestAutomaticBackup() {
    unawaited(_markChanged());
    _scheduleAutomaticBackup();
  }

  void _scheduleAutomaticBackup() {
    _automaticBackupTimer?.cancel();
    _automaticBackupTimer = Timer(const Duration(seconds: 5), () {
      unawaited(syncIfEnabled());
    });
  }

  Future<void> _markChanged() async {
    try {
      await _storage.setGoogleDriveChangedAt(DateTime.now());
    } catch (_) {}
  }

  /// Call after the vault unlocks: uploads changes that did not reach Drive before it locked.
  Future<void> resumePendingBackup() async {
    try {
      if (!await _storage.isGoogleDriveBackupEnabled()) return;
      if (await _storage.getGoogleDriveChangedAt() == null) return;
      _scheduleAutomaticBackup();
    } catch (_) {}
  }

  /// Automatic backup. Never fails a local vault edit; problems are recorded in
  /// [GoogleDriveBackupStatus.lastError] for Settings to show.
  Future<void> syncIfEnabled() async {
    try {
      if (!await _storage.isGoogleDriveBackupEnabled()) return;
      // Never overwrite a Drive backup this device has not restored or chosen to replace.
      if (await _storage.isGoogleDriveRestorePending()) return;
      if (!_session.isActive) return; // locked: retried after the next unlock
      // Never replace a backup with an empty vault automatically (e.g. a fresh install);
      // "Back Up Now" can still do that deliberately.
      if (await _backupService.itemCount() == 0) return;
      await syncNow();
    } catch (e) {
      try {
        await _storage.setGoogleDriveLastError(e.toString());
      } catch (_) {}
    }
  }

  /// Builds an encrypted backup locally and replaces the previous Drive copy.
  /// Throws [GoogleDriveRestorePendingException] if Drive holds a backup this device has
  /// not restored, unless [replaceDriveBackup] confirms replacing it.
  Future<GoogleDriveBackupResult> syncNow({bool replaceDriveBackup = false}) {
    final operation = _uploadQueue.then((_) => _syncNow(replaceDriveBackup: replaceDriveBackup));
    _uploadQueue = operation.then<void>((_) {}, onError: (_, __) {});
    return operation;
  }

  Future<GoogleDriveBackupResult> _syncNow({required bool replaceDriveBackup}) async {
    final passphrase = await _storage.getGoogleDriveBackupPassphrase();
    if (passphrase == null || passphrase.isEmpty) {
      throw const GoogleDriveBackupException(
          'Google Drive backup is not configured.');
    }
    if (!replaceDriveBackup && await _storage.isGoogleDriveRestorePending()) {
      throw const GoogleDriveRestorePendingException();
    }
    final vek = _session.vek;
    if (vek == null) {
      throw const GoogleDriveBackupException(
          'Unlock the vault before creating a backup.');
    }

    // Changes made after this point are not in this backup and must stay marked as pending.
    final snapshotAt = DateTime.now();
    try {
      progress.value = const GoogleDriveBackupProgress(
          fraction: 0, message: 'Preparing encrypted backup…');
      final bytes = await _backupService.createBackupBytes(
        passphrase: passphrase,
        vek: vek,
        onProgress: (fraction, message) {
          progress.value = GoogleDriveBackupProgress(
              fraction: fraction, message: message);
        },
      );
      progress.value = const GoogleDriveBackupProgress(
          fraction: null, message: 'Uploading encrypted backup to Drive…');
      final client = await _authorizedClient(interactive: false);
      try {
        final api = drive.DriveApi(client);
        final saved = await _upload(api, bytes);
        if (saved.id == null || saved.id!.isEmpty) {
          throw const GoogleDriveBackupException(
              'Google Drive did not return a backup identifier.');
        }
        await _storage.setGoogleDriveBackupFileId(saved.id!);
        final now = DateTime.now();
        await _storage.setLastBackupAt(now);
        await _storage.setGoogleDriveRestorePending(false);
        await _storage.setGoogleDriveLastError(null);
        await _clearChangedIfBefore(snapshotAt);
        return GoogleDriveBackupResult(
            bytesUploaded: bytes.length, completedAt: now);
      } finally {
        client.close();
      }
    } finally {
      progress.value = null;
      vek.fillRange(0, vek.length, 0);
    }
  }

  Future<void> _clearChangedIfBefore(DateTime snapshotAt) async {
    final changedAt = await _storage.getGoogleDriveChangedAt();
    if (changedAt != null && !changedAt.isAfter(snapshotAt)) {
      await _storage.setGoogleDriveChangedAt(null);
    }
  }

  /// Downloads, authenticates, and restores the latest encrypted Drive copy.
  /// On a replacement device, first create and unlock an empty vault, connect
  /// the same Google account with the remembered recovery passphrase, then run
  /// this restore. Restored files are re-encrypted for the new vault key.
  Future<RestoreResult> restoreLatest({required bool replaceExisting}) async {
    final passphrase = await _storage.getGoogleDriveBackupPassphrase();
    final vek = _session.vek;
    if (passphrase == null || passphrase.isEmpty) {
      throw const GoogleDriveBackupException(
          'Enter the recovery passphrase to connect Google Drive.');
    }
    if (vek == null) {
      throw const GoogleDriveBackupException(
          'Unlock the vault before restoring a backup.');
    }

    try {
      final bytes = (await _downloadLatest(requireExisting: true))!;
      final payload = await _backupService.decryptAndValidateBackup(
        fileBytes: bytes,
        passphrase: passphrase,
      );
      // Don't let a queued automatic upload of the pre-restore vault run afterwards.
      _automaticBackupTimer?.cancel();
      final result = await _backupService.restoreBackupPayload(
        payload: payload,
        currentVek: vek,
        replaceExisting: replaceExisting,
      );
      // The vault now matches Drive.
      await _storage.setGoogleDriveRestorePending(false);
      await _storage.setGoogleDriveChangedAt(null);
      await _storage.setGoogleDriveLastError(null);
      return result;
    } finally {
      vek.fillRange(0, vek.length, 0);
    }
  }

  Future<drive.File> _upload(drive.DriveApi api, Uint8List bytes) async {
    // Never upload a backup that restore would refuse to download.
    if (bytes.length > VaultBackupService.maxBackupBytes) {
      throw const BackupTooLargeException('This backup is larger than the restore limit.');
    }
    final media = drive.Media(Stream<List<int>>.value(bytes), bytes.length);
    final fileId = await _existingBackupId(api);

    final metadata = drive.File()
      ..name = _driveBackupName
      ..mimeType = 'application/octet-stream'
      ..appProperties = {'format': 'MYVAULT_B_V1', 'kind': 'automatic-backup'};

    if (fileId == null || fileId.isEmpty) {
      final created = await api.files.create(metadata, uploadMedia: media);
      await _storage.setGoogleDriveBackupLocation(_visibleDriveLocation);
      return created;
    }
    final updated =
        await api.files.update(metadata, fileId, uploadMedia: media);
    await _storage.setGoogleDriveBackupLocation(_visibleDriveLocation);
    return updated;
  }

  /// The latest Drive backup, or null if there is none and [requireExisting] is false.
  Future<Uint8List?> _downloadLatest({required bool requireExisting}) async {
    final client = await _authorizedClient(interactive: false);
    try {
      final api = drive.DriveApi(client);
      final fileId = await _existingBackupId(api);
      if (fileId == null || fileId.isEmpty) {
        if (!requireExisting) return null;
        throw const GoogleDriveBackupException(
            'No MyVault backup was found in this Google Drive account.');
      }
      final response = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );
      if (response is! drive.Media) {
        throw const GoogleDriveBackupException(
            'Google Drive returned invalid backup content.');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > VaultBackupService.maxBackupBytes) {
          throw const GoogleDriveBackupException(
              'Drive backup is larger than the 512 MB safety limit.');
        }
        bytes.add(chunk);
      }
      return bytes.takeBytes();
    } finally {
      client.close();
    }
  }

  Future<String?> _existingBackupId(drive.DriveApi api) async {
    // Older builds used Drive's hidden app-data area. Do not overwrite that
    // file: create a new, visible My Drive backup instead.
    final isVisibleBackup =
        await _storage.getGoogleDriveBackupLocation() == _visibleDriveLocation;
    var fileId = isVisibleBackup
        ? await _storage.getGoogleDriveBackupFileId()
        : null;
    if (fileId != null && fileId.isNotEmpty) return fileId;

    final existing = await api.files.list(
      spaces: 'drive',
      q: "name = '$_driveBackupName' and trashed = false",
      pageSize: 1,
    );
    final files = existing.files;
    fileId = files != null && files.isNotEmpty ? files.first.id : null;
    if (fileId != null && fileId.isNotEmpty) {
      await _storage.setGoogleDriveBackupFileId(fileId);
      await _storage.setGoogleDriveBackupLocation(_visibleDriveLocation);
    }
    return fileId;
  }

  /// Removes the local auto-backup configuration and revokes Drive access.
  Future<void> disconnect() async {
    _automaticBackupTimer?.cancel();
    await _storage.clearGoogleDriveBackupConfiguration();
    try {
      await _signIn.disconnect();
    } catch (_) {
      // Local configuration is still removed even if Google cannot be reached.
    }
    _account = null;
  }

  Future<GoogleSignInAccount> _accountFor({required bool interactive}) async {
    var account = _account;
    if (account == null) {
      account = interactive
          ? await _signIn.signIn()
          : await _signIn.signInSilently();
      if (account == null) {
        throw const GoogleDriveBackupException(
          'Google Drive needs to be connected again from Settings.',
        );
      }
      _account = account;
    }

    if (interactive) {
      final granted = await _signIn.requestScopes(_driveScopes);
      if (!granted) {
        throw const GoogleDriveBackupException(
            'Google Drive permission was not granted.');
      }
    }
    return account;
  }

  Future<http.Client> _authorizedClient({required bool interactive}) async {
    final account = await _accountFor(interactive: interactive);
    final headers = await account.authHeaders;
    return _GoogleAuthorizationClient(account, initialHeaders: headers);
  }

  void dispose() {
    _automaticBackupTimer?.cancel();
    progress.dispose();
  }
}

class _GoogleAuthorizationClient extends http.BaseClient {
  final GoogleSignInAccount _account;
  final http.Client _inner = http.Client();
  Map<String, String> _headers;

  _GoogleAuthorizationClient(
    this._account,
    {required Map<String, String> initialHeaders,
  }) : _headers = initialHeaders;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _headers = await _account.authHeaders;
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

final googleDriveBackupServiceProvider =
    Provider<GoogleDriveBackupService>((ref) {
  final service = GoogleDriveBackupService(
    backupService: ref.watch(vaultBackupServiceProvider),
    storage: ref.watch(vaultStorageServiceProvider),
    session: ref.watch(vaultSessionProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
