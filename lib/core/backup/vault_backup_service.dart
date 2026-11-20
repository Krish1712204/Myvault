import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../features/auth/domain/vault_auth_notifier.dart';
import '../constants/app_info.dart';
import '../database/vault_database.dart';
import '../security/vault_crypto_service.dart';
import '../storage/encrypted_file_service.dart';

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);
  @override
  String toString() => message;
}

class InvalidBackupFormatException extends BackupException {
  const InvalidBackupFormatException(super.message);
}

class UnsupportedBackupVersionException extends BackupException {
  const UnsupportedBackupVersionException(super.message);
}

class InvalidBackupPassphraseException extends BackupException {
  const InvalidBackupPassphraseException(super.message);
}

class BackupCorruptedAttachmentException extends BackupException {
  const BackupCorruptedAttachmentException(super.message);
}

/// Some attachments could not be read, so a backup would silently be missing them.
/// Pass `allowMissingAttachments: true` to create the backup anyway.
class BackupIncompleteException extends BackupException {
  final List<String> missingFiles;
  const BackupIncompleteException(super.message, this.missingFiles);
}

/// The vault is too large to back up (and restore) in one piece on this device.
class BackupTooLargeException extends BackupException {
  const BackupTooLargeException(super.message);
}

class BackupInspectResult {
  final String format;
  final int version;
  final String appVersion;
  final int createdAt;
  final String kdfAlgorithm;
  final int itemCount;
  final int fileCount;
  final int fileSize;

  const BackupInspectResult({
    required this.format,
    required this.version,
    required this.appVersion,
    required this.createdAt,
    required this.kdfAlgorithm,
    required this.itemCount,
    required this.fileCount,
    required this.fileSize,
  });
}

class BackupFileAttachment {
  final String fileName;
  final String relativePath;
  final String mimeType;
  final int size;
  final String sha256;
  final String dataB64;

  const BackupFileAttachment({
    required this.fileName,
    required this.relativePath,
    required this.mimeType,
    required this.size,
    required this.sha256,
    required this.dataB64,
  });

  Map<String, dynamic> toMap() => {
        'file_name': fileName,
        'relative_path': relativePath,
        'mime_type': mimeType,
        'size': size,
        'sha256': sha256,
        'data_b64': dataB64,
      };

  factory BackupFileAttachment.fromMap(Map<String, dynamic> map) => BackupFileAttachment(
        fileName: map['file_name'] as String,
        relativePath: map['relative_path'] as String,
        mimeType: map['mime_type'] as String? ?? 'application/octet-stream',
        size: map['size'] as int,
        sha256: map['sha256'] as String,
        dataB64: map['data_b64'] as String,
      );
}

class BackupPayload {
  final int version;
  final int timestamp;
  final List<Map<String, dynamic>> vaultItems;
  final List<Map<String, dynamic>> passwordEntries;
  final List<Map<String, dynamic>> identityEntries;
  final List<Map<String, dynamic>> documentEntries;
  final List<Map<String, dynamic>> notes;
  final List<Map<String, dynamic>> contacts;
  final List<Map<String, dynamic>> tags;
  final List<Map<String, dynamic>> itemTags;
  final List<BackupFileAttachment> files;

  const BackupPayload({
    required this.version,
    required this.timestamp,
    required this.vaultItems,
    required this.passwordEntries,
    required this.identityEntries,
    required this.documentEntries,
    required this.notes,
    required this.contacts,
    required this.tags,
    required this.itemTags,
    required this.files,
  });

  Map<String, dynamic> toMap() => {
        'version': version,
        'timestamp': timestamp,
        'vault_items': vaultItems,
        'password_entries': passwordEntries,
        'identity_entries': identityEntries,
        'document_entries': documentEntries,
        'notes': notes,
        'contacts': contacts,
        'tags': tags,
        'item_tags': itemTags,
        'files': files.map((f) => f.toMap()).toList(),
      };

  factory BackupPayload.fromMap(Map<String, dynamic> map) {
    return BackupPayload(
      version: map['version'] as int? ?? 1,
      timestamp: map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      vaultItems: List<Map<String, dynamic>>.from(map['vault_items'] ?? []),
      passwordEntries: List<Map<String, dynamic>>.from(map['password_entries'] ?? []),
      identityEntries: List<Map<String, dynamic>>.from(map['identity_entries'] ?? []),
      documentEntries: List<Map<String, dynamic>>.from(map['document_entries'] ?? []),
      notes: List<Map<String, dynamic>>.from(map['notes'] ?? []),
      contacts: List<Map<String, dynamic>>.from(map['contacts'] ?? []),
      tags: List<Map<String, dynamic>>.from(map['tags'] ?? []),
      itemTags: List<Map<String, dynamic>>.from(map['item_tags'] ?? []),
      files: (map['files'] as List<dynamic>? ?? [])
          .map((f) => BackupFileAttachment.fromMap(Map<String, dynamic>.from(f)))
          .toList(),
    );
  }
}

class RestoreResult {
  final bool success;
  final int itemsRestored;
  final int filesRestored;
  final String message;

  const RestoreResult({
    required this.success,
    required this.itemsRestored,
    required this.filesRestored,
    required this.message,
  });
}

/// Service providing standalone portable encrypted backup and authenticated restoration
class VaultBackupService {
  static const String containerMagic = 'MYVAULT_B_V1'; // 12 bytes

  /// Container layout by version (both remain restorable):
  /// - v1: magic | header length | header (holds the GCM tag) | ciphertext.
  ///       The header (item counts, dates, KDF settings) is not authenticated.
  /// - v2: magic | header length | header | ciphertext | GCM tag (16 bytes).
  ///       The exact header bytes are the GCM associated data, so any change to them
  ///       makes decryption fail.
  static const int currentBackupVersion = 2;
  static const int _tagLength = 16;

  // Strict Argon2id resource bounds to prevent Denial-of-Service / Memory exhaustion attacks
  static const int minArgon2Memory = 8192; // 8 MiB minimum
  static const int maxArgon2Memory = 65536; // 64 MiB maximum safe limit on mobile
  static const int minArgon2Iterations = 1;
  static const int maxArgon2Iterations = 10;
  static const int minArgon2Parallelism = 1;
  static const int maxArgon2Parallelism = 4;

  /// Largest backup container created or restored. Backup and restore hold the whole
  /// container in memory, and every backup made must also be restorable, so both sides
  /// share this limit.
  static const int maxBackupBytes = 512 * 1024 * 1024;

  final VaultDatabase _vaultDb;
  final EncryptedFileService _fileService;
  final VaultCryptoService _cryptoService;

  VaultBackupService({
    required VaultDatabase vaultDb,
    required EncryptedFileService fileService,
    required VaultCryptoService cryptoService,
  })  : _vaultDb = vaultDb,
        _fileService = fileService,
        _cryptoService = cryptoService;

  /// Number of items in the vault.
  Future<int> itemCount() async =>
      Sqflite.firstIntValue(await _vaultDb.database.rawQuery('SELECT COUNT(*) FROM vault_items')) ?? 0;

  static String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';

  /// Creates a single, portable, authenticated encrypted backup file (.myvault).
  ///
  /// Throws [BackupIncompleteException] if any attachment cannot be read, unless
  /// [allowMissingAttachments] is true, and [BackupTooLargeException] if the result would
  /// exceed [maxBackupBytes].
  Future<Uint8List> createBackupBytes({
    required String passphrase,
    required Uint8List vek,
    void Function(double progress, String status)? onProgress,
    bool allowMissingAttachments = false,
  }) async {
    if (passphrase.trim().length < 8) {
      throw const BackupException('Backup passphrase must be at least 8 characters long.');
    }
    if (vek.isEmpty) {
      throw const BackupException('Vault is locked. Cannot export backup.');
    }

    onProgress?.call(0.1, 'Extracting database records...');
    final db = _vaultDb.database;

    final vaultItems = await db.query('vault_items');
    final passwordEntries = await db.query('password_entries');
    final identityEntries = await db.query('identity_entries');
    final documentEntries = await db.query('document_entries');
    final notes = await db.query('notes');
    final contacts = await db.query('contacts');
    final tags = await db.query('tags');
    final itemTags = await db.query('item_tags');

    // Refuse before decrypting anything if the result could not be restored later.
    // Attachments are base64-encoded in the payload (4/3 of their size).
    var estimatedBytes = await _vaultDb.fileSizeBytes();
    final estimatedPaths = <String>{};
    for (final (rows, column) in [
      (documentEntries, 'file_path'),
      (identityEntries, 'attachment_path'),
      (contacts, 'attachment_path'),
    ]) {
      for (final row in rows) {
        final path = row[column] as String?;
        if (path == null || path.isEmpty || !estimatedPaths.add(path)) continue;
        estimatedBytes += (await _fileService.encryptedFileSize(path)) * 4 ~/ 3;
      }
    }
    if (estimatedBytes > maxBackupBytes) {
      throw BackupTooLargeException(
        'Your vault (about ${_mb(estimatedBytes)}) is larger than the ${_mb(maxBackupBytes)} '
        'backup limit. Remove some large documents or photos, then try again.',
      );
    }

    onProgress?.call(0.3, 'Reading and decrypting file attachments...');
    final fileStorageKey = await _cryptoService.deriveFileStorageKey(vek);
    final filesList = <BackupFileAttachment>[];
    final missingFiles = <String>[];
    final sha256Algo = Sha256();

    final collectedPaths = <String>{};

    Future<void> collect(String? path, String fileName, String mimeType) async {
      if (path == null || path.isEmpty || !collectedPaths.add(path)) return;
      try {
        final decryptedBytes = await _fileService.decrypt(
          relativePath: path,
          fileStorageKey: fileStorageKey,
        );
        final hash = await sha256Algo.hash(decryptedBytes);
        final hashHex = hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

        filesList.add(BackupFileAttachment(
          fileName: p.basename(fileName),
          relativePath: p.basename(path),
          mimeType: mimeType,
          size: decryptedBytes.length,
          sha256: hashHex,
          dataB64: base64Encode(decryptedBytes),
        ));
      } catch (_) {
        missingFiles.add(p.basename(fileName));
      }
    }

    // Document files, ID card scans, and contact photos
    for (final doc in documentEntries) {
      await collect(
        doc['file_path'] as String?,
        (doc['file_name'] as String?) ?? 'file',
        (doc['mime_type'] as String?) ?? 'application/octet-stream',
      );
    }
    for (final idn in identityEntries) {
      final path = idn['attachment_path'] as String?;
      await collect(path, path ?? 'file', 'application/octet-stream');
    }
    for (final contact in contacts) {
      final path = contact['attachment_path'] as String?;
      await collect(path, path ?? 'photo', 'image/jpeg');
    }

    if (missingFiles.isNotEmpty && !allowMissingAttachments) {
      final shown = missingFiles.take(5).join(', ');
      final more = missingFiles.length > 5 ? ' and ${missingFiles.length - 5} more' : '';
      throw BackupIncompleteException(
        '${missingFiles.length} attachment${missingFiles.length == 1 ? '' : 's'} could not be read '
        'and would be missing from the backup: $shown$more.',
        missingFiles,
      );
    }

    onProgress?.call(0.6, 'Constructing backup payload...');
    // Encoded straight to UTF-8 bytes: no intermediate String copy of the whole vault.
    Uint8List? payloadBytes = _encodeJsonUtf8(BackupPayload(
      version: currentBackupVersion,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      vaultItems: vaultItems,
      passwordEntries: passwordEntries,
      identityEntries: identityEntries,
      documentEntries: documentEntries,
      notes: notes,
      contacts: contacts,
      tags: tags,
      itemTags: itemTags,
      files: filesList,
    ).toMap());
    final fileCount = filesList.length;
    filesList.clear(); // drop the base64 copies before encrypting

    onProgress?.call(0.75, 'Deriving backup key with Argon2id...');
    final salt = _cryptoService.generateSalt(32);
    final nonce = _cryptoService.generateRandomBytes(12);

    final bek = await _cryptoService.deriveBackupKey(
      passphrase: passphrase,
      salt: salt,
      memory: VaultCryptoService.argon2Memory,
      iterations: VaultCryptoService.argon2Iterations,
      parallelism: VaultCryptoService.argon2Parallelism,
    );

    final headerMap = {
      'format': 'MYVAULT_BACKUP',
      'version': currentBackupVersion,
      'app_version': AppInfo.version,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'kdf': 'Argon2id',
      'kdf_params': {
        'memory': VaultCryptoService.argon2Memory,
        'iterations': VaultCryptoService.argon2Iterations,
        'parallelism': VaultCryptoService.argon2Parallelism,
        'key_length': 32,
        'salt': base64Encode(salt),
      },
      'cipher': 'AES-256-GCM',
      'nonce': base64Encode(nonce),
      'item_count': vaultItems.length,
      'file_count': fileCount,
    };
    final headerBytes = utf8.encode(jsonEncode(headerMap));

    onProgress?.call(0.85, 'Encrypting backup with AES-256-GCM...');
    final secretBox = await _cryptoService.encryptBackupPayload(
      plaintext: payloadBytes,
      backupKey: bek,
      nonce: nonce,
      aad: headerBytes, // authenticates the header
    );
    payloadBytes = null; // only the ciphertext is needed from here on

    onProgress?.call(0.95, 'Packaging portable container...');
    final headerLengthBytes = Uint8List(4)..buffer.asByteData().setUint32(0, headerBytes.length, Endian.big);

    final container = BytesBuilder(copy: false)
      ..add(utf8.encode(containerMagic)) // 12 bytes
      ..add(headerLengthBytes)          // 4 bytes
      ..add(headerBytes)                // N bytes
      ..add(secretBox.cipherText)       // M bytes
      ..add(secretBox.mac.bytes);       // 16 bytes (v2)

    final bytes = container.takeBytes();
    if (bytes.length > maxBackupBytes) {
      throw BackupTooLargeException(
        'Your vault (${_mb(bytes.length)}) is larger than the ${_mb(maxBackupBytes)} backup limit. '
        'Remove some large documents or photos, then try again.',
      );
    }
    onProgress?.call(1.0, 'Backup created successfully');
    return bytes;
  }

  static Uint8List _encodeJsonUtf8(Object value) {
    final bytes = JsonUtf8Encoder().convert(value);
    return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  }

  /// Inspects a backup file and returns its unencrypted header metadata without needing the passphrase
  Future<BackupInspectResult> inspectBackupFile(List<int> fileBytes) async {
    if (fileBytes.length < 16) {
      throw const InvalidBackupFormatException('Backup file is truncated or invalid.');
    }

    final magic = utf8.decode(fileBytes.sublist(0, 12), allowMalformed: true);
    if (magic != containerMagic) {
      throw const InvalidBackupFormatException('Invalid file signature. Not a valid MyVault backup file.');
    }

    final headerLen = ByteData.sublistView(Uint8List.fromList(fileBytes.sublist(12, 16))).getUint32(0, Endian.big);
    if (fileBytes.length < 16 + headerLen) {
      throw const InvalidBackupFormatException('Backup header is corrupted or incomplete.');
    }

    final headerJsonStr = utf8.decode(fileBytes.sublist(16, 16 + headerLen), allowMalformed: true);
    final header = jsonDecode(headerJsonStr) as Map<String, dynamic>;

    if (header['format'] != 'MYVAULT_BACKUP') {
      throw const InvalidBackupFormatException('Unrecognized backup format in header.');
    }

    final version = header['version'] as int? ?? 1;
    if (version > currentBackupVersion) {
      throw UnsupportedBackupVersionException('Backup version $version is not supported by this version of MyVault.');
    }

    return BackupInspectResult(
      format: header['format'] as String,
      version: version,
      appVersion: (header['app_version'] as String?) ?? '1.0.0',
      createdAt: header['created_at'] as int? ?? 0,
      kdfAlgorithm: (header['kdf'] as String?) ?? 'Argon2id',
      itemCount: header['item_count'] as int? ?? 0,
      fileCount: header['file_count'] as int? ?? 0,
      fileSize: fileBytes.length,
    );
  }

  /// Authenticates, decrypts, and validates the entire backup file using the user-provided passphrase
  Future<BackupPayload> decryptAndValidateBackup({
    required List<int> fileBytes,
    required String passphrase,
    void Function(double progress, String status)? onProgress,
  }) async {
    onProgress?.call(0.1, 'Inspecting backup container...');
    if (fileBytes.length < 16) {
      throw const InvalidBackupFormatException('Backup file is truncated or invalid.');
    }

    final magic = utf8.decode(fileBytes.sublist(0, 12), allowMalformed: true);
    if (magic != containerMagic) {
      throw const InvalidBackupFormatException('Invalid file signature. Not a valid MyVault backup file.');
    }

    final headerLen = ByteData.sublistView(Uint8List.fromList(fileBytes.sublist(12, 16))).getUint32(0, Endian.big);
    if (fileBytes.length < 16 + headerLen) {
      throw const InvalidBackupFormatException('Backup header is corrupted or incomplete.');
    }

    final headerJsonStr = utf8.decode(fileBytes.sublist(16, 16 + headerLen));
    final header = jsonDecode(headerJsonStr) as Map<String, dynamic>;

    if (header['format'] != 'MYVAULT_BACKUP') {
      throw const InvalidBackupFormatException('Unrecognized backup format in header.');
    }

    final version = header['version'] as int? ?? 1;
    if (version > currentBackupVersion) {
      throw UnsupportedBackupVersionException('Backup version $version is not supported by this version of MyVault.');
    }

    final kdfParams = header['kdf_params'] as Map<String, dynamic>?;
    if (kdfParams == null) {
      throw const InvalidBackupFormatException('Missing KDF parameters in backup header.');
    }
    final saltStr = kdfParams['salt'] as String?;
    if (saltStr == null) {
      throw const InvalidBackupFormatException('Missing salt in backup header.');
    }
    final salt = base64Decode(saltStr);
    if (salt.length != 32) {
      throw const InvalidBackupFormatException('Invalid salt length in backup header (must be 32 bytes).');
    }

    final memory = kdfParams['memory'] as int? ?? VaultCryptoService.argon2Memory;
    if (memory < minArgon2Memory || memory > maxArgon2Memory) {
      throw InvalidBackupFormatException(
          'Argon2id memory parameter ($memory KiB) exceeds safety limits ($minArgon2Memory-$maxArgon2Memory KiB).');
    }

    final iterations = kdfParams['iterations'] as int? ?? VaultCryptoService.argon2Iterations;
    if (iterations < minArgon2Iterations || iterations > maxArgon2Iterations) {
      throw InvalidBackupFormatException(
          'Argon2id iterations parameter ($iterations) exceeds safety limits ($minArgon2Iterations-$maxArgon2Iterations).');
    }

    final parallelism = kdfParams['parallelism'] as int? ?? VaultCryptoService.argon2Parallelism;
    if (parallelism < minArgon2Parallelism || parallelism > maxArgon2Parallelism) {
      throw InvalidBackupFormatException(
          'Argon2id parallelism parameter ($parallelism) exceeds safety limits ($minArgon2Parallelism-$maxArgon2Parallelism).');
    }

    final nonceStr = header['nonce'] as String?;
    final bodyStart = 16 + headerLen;
    final List<int> mac;
    final List<int> ciphertext;
    final List<int> aad;
    if (version >= 2) {
      if (fileBytes.length < bodyStart + _tagLength) {
        throw const InvalidBackupFormatException('Backup file is truncated or invalid.');
      }
      mac = fileBytes.sublist(fileBytes.length - _tagLength);
      ciphertext = fileBytes.sublist(bodyStart, fileBytes.length - _tagLength);
      aad = fileBytes.sublist(16, bodyStart);
    } else {
      final macStr = header['mac'] as String?;
      if (macStr == null) {
        throw const InvalidBackupFormatException('Missing cryptographic nonce or MAC in backup header.');
      }
      mac = base64Decode(macStr);
      ciphertext = fileBytes.sublist(bodyStart);
      aad = const [];
    }
    if (nonceStr == null) {
      throw const InvalidBackupFormatException('Missing cryptographic nonce or MAC in backup header.');
    }

    final nonce = base64Decode(nonceStr);

    if (nonce.length != 12) {
      throw const InvalidBackupFormatException('Invalid AES-GCM nonce length in backup header (must be 12 bytes).');
    }
    if (mac.length != 16) {
      throw const InvalidBackupFormatException('Invalid AES-GCM MAC tag length in backup header (must be 16 bytes).');
    }

    onProgress?.call(0.3, 'Deriving backup key with Argon2id...');
    final bek = await _cryptoService.deriveBackupKey(
      passphrase: passphrase,
      salt: salt,
      memory: memory,
      iterations: iterations,
      parallelism: parallelism,
    );

    onProgress?.call(0.6, 'Decrypting and verifying authentication tag (AES-256-GCM)...');
    List<int> plaintextBytes;
    try {
      plaintextBytes = await _cryptoService.decryptBackupPayload(
        ciphertext: ciphertext,
        nonce: nonce,
        mac: mac,
        backupKey: bek,
        aad: aad,
      );
    } catch (_) {
      throw const InvalidBackupPassphraseException('Incorrect backup passphrase or corrupted backup file.');
    }

    onProgress?.call(0.8, 'Validating records and attachment checksums...');
    // Fused decoder: parses the UTF-8 bytes directly, without a String copy of the whole vault.
    final payloadMap = utf8.decoder.fuse(json.decoder).convert(plaintextBytes) as Map<String, dynamic>;
    final payload = BackupPayload.fromMap(payloadMap);

    // Validate path safety and file integrity
    final sha256Algo = Sha256();
    for (final file in payload.files) {
      final sanitizedName = p.basename(file.fileName);
      if (sanitizedName.isEmpty || sanitizedName == '.' || sanitizedName == '..') {
        throw const InvalidBackupFormatException('Unsafe attachment filename detected in backup.');
      }
      if (file.relativePath.contains('..') ||
          file.relativePath.startsWith('/') ||
          file.relativePath.startsWith('\\')) {
        throw const InvalidBackupFormatException('Path traversal attempt detected in backup attachment.');
      }

      final fileBytesDecoded = base64Decode(file.dataB64);
      final hash = await sha256Algo.hash(fileBytesDecoded);
      final hashHex = hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      if (hashHex.toLowerCase() != file.sha256.toLowerCase()) {
        throw BackupCorruptedAttachmentException('Checksum verification failed for attachment: ${file.fileName}');
      }
    }

    onProgress?.call(1.0, 'Backup verified successfully');
    return payload;
  }

  /// Restores a validated backup payload into the database with atomic rollback safety.
  ///
  /// Order matters: attachments are first re-encrypted under NEW unique file names, so live
  /// files are never overwritten. Rows are then swapped in a single transaction (rolled back
  /// automatically by SQLite on failure). Old files are deleted only after the commit.
  Future<RestoreResult> restoreBackupPayload({
    required BackupPayload payload,
    required Uint8List currentVek,
    required bool replaceExisting,
    void Function(double progress, String status)? onProgress,
  }) async {
    if (currentVek.isEmpty) {
      throw const BackupException('Vault is locked. Cannot restore backup.');
    }

    final db = _vaultDb.database;

    // Check existing count if not replacing
    final currentItemCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM vault_items')) ?? 0;
    if (currentItemCount > 0 && !replaceExisting) {
      throw const BackupException('Vault already contains items. Explicit confirmation is required to replace data.');
    }

    final oldPaths = await _allAttachmentPaths(db);
    final newlyCreatedFiles = <String>[];
    final currentFileStorageKey = await _cryptoService.deriveFileStorageKey(currentVek);

    try {
      onProgress?.call(0.2, 'Re-encrypting file attachments...');
      // Backup relative path -> freshly written relative path
      final pathMap = <String, String>{};
      for (final file in payload.files) {
        final backupPath = p.basename(file.relativePath);
        if (pathMap.containsKey(backupPath)) continue;
        final stored = await _fileService.encryptAndSave(
          fileBytes: base64Decode(file.dataB64),
          originalFileName: p.basename(file.fileName),
          fileStorageKey: currentFileStorageKey,
        );
        newlyCreatedFiles.add(stored.relativePath);
        pathMap[backupPath] = stored.relativePath;
      }

      List<Map<String, dynamic>> remapped(List<Map<String, dynamic>> rows, String column) {
        return rows.map((row) {
          final copy = Map<String, dynamic>.from(row);
          final path = copy[column];
          if (path is String && path.isNotEmpty) {
            copy[column] = pathMap[p.basename(path)] ?? path;
          }
          return copy;
        }).toList();
      }

      // Thumbnails are not backed up; they are regenerated on first view.
      final documentEntries = remapped(payload.documentEntries, 'file_path');
      for (final row in documentEntries) {
        row['thumbnail_path'] = null;
      }
      final identityEntries = remapped(payload.identityEntries, 'attachment_path');
      final contacts = remapped(payload.contacts, 'attachment_path');

      onProgress?.call(0.6, 'Updating database records in transaction...');
      await db.transaction((txn) async {
        // Clear old records
        await txn.delete('item_tags');
        await txn.delete('tags');
        await txn.delete('contacts');
        await txn.delete('notes');
        await txn.delete('document_entries');
        await txn.delete('identity_entries');
        await txn.delete('password_entries');
        await txn.delete('vault_items');

        Future<void> insertAll(String table, List<Map<String, dynamic>> rows) async {
          for (final row in rows) {
            await txn.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        await insertAll('vault_items', payload.vaultItems);
        await insertAll('password_entries', payload.passwordEntries);
        await insertAll('identity_entries', identityEntries);
        await insertAll('document_entries', documentEntries);
        await insertAll('notes', payload.notes);
        await insertAll('contacts', contacts);
        await insertAll('tags', payload.tags);
        await insertAll('item_tags', payload.itemTags);
      });
    } catch (e) {
      // Nothing committed: the transaction rolled itself back (or was never started).
      // Only the files written above need removing; they have new names, so live files are untouched.
      for (final f in newlyCreatedFiles) {
        await _fileService.deleteEncryptedFile(f);
      }
      debugPrint('MyVault: restore rolled back (${e.runtimeType})');
      throw const BackupException('The backup could not be restored. Your vault was not changed.');
    }

    onProgress?.call(0.9, 'Removing replaced files...');
    final activePaths = await _allAttachmentPaths(db);
    for (final oldPath in oldPaths.difference(activePaths)) {
      await _fileService.deleteEncryptedFile(oldPath);
    }

    onProgress?.call(1.0, 'Restoration complete');
    return RestoreResult(
      success: true,
      itemsRestored: payload.vaultItems.length,
      filesRestored: newlyCreatedFiles.length,
      message: 'Successfully restored ${payload.vaultItems.length} items and ${newlyCreatedFiles.length} attachments.',
    );
  }

  /// Every encrypted file referenced anywhere in the vault database
  Future<Set<String>> _allAttachmentPaths(Database db) async {
    final paths = <String>{};
    for (final (table, column) in const [
      ('document_entries', 'file_path'),
      ('document_entries', 'thumbnail_path'),
      ('identity_entries', 'attachment_path'),
      ('contacts', 'attachment_path'),
    ]) {
      for (final row in await db.query(table, columns: [column])) {
        final path = row[column] as String?;
        if (path != null && path.isNotEmpty) paths.add(path);
      }
    }
    return paths;
  }
}

final vaultBackupServiceProvider = Provider<VaultBackupService>((ref) {
  return VaultBackupService(
    vaultDb: ref.watch(vaultDatabaseProvider),
    fileService: ref.watch(encryptedFileServiceProvider),
    cryptoService: ref.watch(vaultCryptoServiceProvider),
  );
});
