import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StoredFileResult {
  final String relativePath;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String fileExtension;

  const StoredFileResult({
    required this.relativePath,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.fileExtension,
  });
}

/// Service managing authenticated file encryption, secure app-private storage,
/// and safe temporary preview handling.
class EncryptedFileService {
  static const List<int> magicHeader = [
    0x4D, 0x59, 0x56, 0x41, 0x55, 0x4C, 0x54, 0x5F, 0x46, 0x5F, 0x56, 0x31 // "MYVAULT_F_V1" (12 bytes)
  ];
  static const int nonceLength = 12; // 96-bit AES-GCM nonce
  static const int tagLength = 16;   // 128-bit MAC tag
  static const int headerSize = 12 + 12 + 16; // 40 bytes

  final AesGcm _aesGcm = AesGcm.with256bits();
  final String? _customStoragePath;

  EncryptedFileService({String? customStoragePath})
      : _customStoragePath = customStoragePath;

  Future<Directory> _getFilesDirectory() async {
    if (_customStoragePath != null) {
      final dir = Directory(_customStoragePath);
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final filesDir = Directory(p.join(appDir.path, 'vault_encrypted_files'));
      if (!await filesDir.exists()) {
        await filesDir.create(recursive: true);
      }
      return filesDir;
    } catch (_) {
      // Fallback for headless unit tests
      final tempDir = Directory.systemTemp.createTempSync('vault_files_test_');
      return tempDir;
    }
  }

  /// Encrypts raw bytes and stores them in the app-private files directory.
  Future<StoredFileResult> encryptAndSave({
    required List<int> fileBytes,
    required String originalFileName,
    required List<int> fileStorageKey,
    String? mimeType,
    String? customRelativePath,
  }) async {
    final secretKey = SecretKey(fileStorageKey);
    final random = Random.secure();
    final nonce = List<int>.generate(nonceLength, (_) => random.nextInt(256));

    final secretBox = await _aesGcm.encrypt(
      fileBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final sanitizedName = p.basename(originalFileName);
    final sanitizedRelative = customRelativePath != null && customRelativePath.trim().isNotEmpty
        ? p.basename(customRelativePath.trim())
        : null;

    final extension = p.extension(sanitizedName).toLowerCase();
    final filesDir = await _getFilesDirectory();

    // Generated names must never collide with an existing file (that would overwrite it).
    String relativePath;
    if (sanitizedRelative != null) {
      relativePath = sanitizedRelative;
    } else {
      do {
        relativePath = '${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(1 << 32)}.enc';
      } while (await File(p.join(filesDir.path, relativePath)).exists());
    }
    final targetFile = File(p.join(filesDir.path, relativePath));

    // Construct authenticated payload: [Magic (12B)] [Nonce (12B)] [Tag (16B)] [Ciphertext]
    final builder = BytesBuilder(copy: false)
      ..add(magicHeader)
      ..add(secretBox.nonce)
      ..add(secretBox.mac.bytes)
      ..add(secretBox.cipherText);

    await targetFile.writeAsBytes(builder.takeBytes(), flush: true);

    return StoredFileResult(
      relativePath: relativePath,
      fileName: sanitizedName,
      fileSize: fileBytes.length,
      mimeType: mimeType ?? _guessMimeType(extension),
      fileExtension: extension,
    );
  }

  /// Authenticates and decrypts an encrypted file from storage. Throws if tampered.
  Future<List<int>> decrypt({
    required String relativePath,
    required List<int> fileStorageKey,
  }) async {
    final filesDir = await _getFilesDirectory();
    final targetFile = File(p.join(filesDir.path, relativePath));

    if (!await targetFile.exists()) {
      throw FileNotFoundException('Encrypted file not found at: $relativePath');
    }

    final rawBytes = await targetFile.readAsBytes();
    if (rawBytes.length < headerSize) {
      throw const FormatException('Encrypted file payload corrupted or truncated.');
    }

    // Verify magic header
    for (var i = 0; i < magicHeader.length; i++) {
      if (rawBytes[i] != magicHeader[i]) {
        throw const FormatException('Invalid file magic header or unsupported version.');
      }
    }

    final nonce = rawBytes.sublist(12, 12 + nonceLength);
    final tag = rawBytes.sublist(12 + nonceLength, headerSize);
    final ciphertext = rawBytes.sublist(headerSize);

    final secretKey = SecretKey(fileStorageKey);
    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(tag),
    );

    return await _aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
  }

  Future<Directory> _getPreviewDirectory() async {
    if (_customStoragePath != null) {
      final dir = Directory(p.join(_customStoragePath, 'vault_previews'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory(p.join(tempDir.path, 'vault_previews'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (_) {
      final dir = Directory(p.join(Directory.systemTemp.path, 'vault_previews'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
  }

  /// Creates a temporary decrypted file for viewer/preview with best-effort cleanup
  Future<File> createTemporaryPreviewFile({
    required String relativePath,
    required String fileName,
    required List<int> fileStorageKey,
  }) async {
    final decryptedBytes = await decrypt(
      relativePath: relativePath,
      fileStorageKey: fileStorageKey,
    );

    final previewDir = await _getPreviewDirectory();
    final tempFile = File(p.join(previewDir.path, fileName));
    await tempFile.writeAsBytes(decryptedBytes, flush: true);
    return tempFile;
  }

  /// Cleans up temporary preview files
  Future<void> clearTemporaryPreviews() async {
    try {
      final previewDir = await _getPreviewDirectory();
      if (await previewDir.exists()) {
        await previewDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  /// Size in bytes of one stored encrypted file, or 0 if it does not exist.
  Future<int> encryptedFileSize(String relativePath) async {
    try {
      final file = File(p.join((await _getFilesDirectory()).path, relativePath));
      return await file.exists() ? await file.length() : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Deletes the unencrypted copies the system file picker leaves in the app cache
  /// (ID scans, contact photos, VCF files, backups). Run on launch and on lock.
  Future<void> clearPickerCache() async {
    if (_customStoragePath != null) return; // unit tests: no platform plugin
    try {
      await FilePicker.clearTemporaryFiles();
    } catch (_) {}
  }

  /// Total bytes of encrypted attachments on disk
  Future<int> storedFilesBytes() async => _directoryBytes(await _getFilesDirectory());

  /// Total bytes of decrypted temporary previews currently on disk
  Future<int> previewBytes() async => _directoryBytes(await _getPreviewDirectory());

  static Future<int> _directoryBytes(Directory dir) async {
    var total = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) total += await entity.length();
      }
    } catch (_) {}
    return total;
  }

  /// Permanently deletes every stored encrypted file. Used when a vault is created or
  /// erased: files encrypted under a key that no longer exists can never be read again.
  Future<void> deleteAllStoredFiles() async {
    try {
      final dir = await _getFilesDirectory();
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) await entity.delete();
      }
    } catch (_) {}
  }

  /// Permanently deletes an encrypted file from storage
  Future<void> deleteEncryptedFile(String relativePath) async {
    try {
      final filesDir = await _getFilesDirectory();
      final targetFile = File(p.join(filesDir.path, relativePath));
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
    } catch (_) {}
  }

  /// MIME type by extension, so "Open" hands the file to an app that can show it.
  static const Map<String, String> _mimeTypes = {
    '.pdf': 'application/pdf',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.webp': 'image/webp',
    '.gif': 'image/gif',
    '.bmp': 'image/bmp',
    '.heic': 'image/heic',
    '.heif': 'image/heif',
    '.txt': 'text/plain',
    '.csv': 'text/csv',
    '.json': 'application/json',
    '.xml': 'application/xml',
    '.html': 'text/html',
    '.rtf': 'application/rtf',
    '.zip': 'application/zip',
    '.doc': 'application/msword',
    '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    '.xls': 'application/vnd.ms-excel',
    '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    '.ppt': 'application/vnd.ms-powerpoint',
    '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    '.odt': 'application/vnd.oasis.opendocument.text',
    '.ods': 'application/vnd.oasis.opendocument.spreadsheet',
    '.mp3': 'audio/mpeg',
    '.m4a': 'audio/mp4',
    '.mp4': 'video/mp4',
    '.mov': 'video/quicktime',
    '.vcf': 'text/vcard',
  };

  String _guessMimeType(String ext) => _mimeTypes[ext] ?? 'application/octet-stream';
}

class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);
  @override
  String toString() => 'FileNotFoundException: $message';
}
