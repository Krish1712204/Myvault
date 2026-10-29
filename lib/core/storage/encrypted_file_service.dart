import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
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
  }) async {
    final secretKey = SecretKey(fileStorageKey);
    final random = Random.secure();
    final nonce = List<int>.generate(nonceLength, (_) => random.nextInt(256));

    final secretBox = await _aesGcm.encrypt(
      fileBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final fileId = '${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(1000000)}';
    final extension = p.extension(originalFileName).toLowerCase();
    final relativePath = '$fileId.enc';

    final filesDir = await _getFilesDirectory();
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
      fileName: originalFileName,
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

  String _guessMimeType(String ext) {
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.txt':
        return 'text/plain';
      case '.doc':
      case '.docx':
        return 'application/msword';
      default:
        return 'application/octet-stream';
    }
  }
}

class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);
  @override
  String toString() => 'FileNotFoundException: $message';
}
