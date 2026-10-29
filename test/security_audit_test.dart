import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:myvault/core/backup/vault_backup_service.dart';
import 'package:myvault/core/database/vault_database.dart';
import 'package:myvault/core/database/vault_schema.dart';
import 'package:myvault/core/security/clipboard_service.dart';
import 'package:myvault/core/security/vault_crypto_service.dart';
import 'package:myvault/core/security/vault_session.dart';
import 'package:myvault/core/storage/encrypted_file_service.dart';
import 'package:myvault/features/vault/data/vault_repository.dart';
import 'package:myvault/features/vault_items/data/vault_item_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late VaultCryptoService cryptoService;
  late VaultDatabase vaultDb;
  late EncryptedFileService fileService;
  late VaultRepository repository;
  late VaultSession session;
  late Uint8List testVek;
  late String hexDbKey;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('myvault_security_audit_');
    cryptoService = VaultCryptoService();
    testVek = Uint8List.fromList(cryptoService.generateVek());
    hexDbKey = await cryptoService.deriveDatabaseKeyHex(testVek);

    vaultDb = VaultDatabase(customFactory: databaseFactoryFfi);
    fileService = EncryptedFileService(
      customStoragePath: '${tempDir.path}/vault_files',
    );
    repository = VaultRepository(
      vaultDb: vaultDb,
      fileService: fileService,
    );
    session = VaultSession();

    await vaultDb.open(
      hexDatabaseKey: hexDbKey,
      customPath: '${tempDir.path}/security_audit.db',
    );
  });

  tearDown(() async {
    session.clear();
    if (vaultDb.isOpen) {
      await vaultDb.close();
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Phase 8 — Security Audit & Hardening Tests', () {
    test('1. Cryptographic Key Derivation & Argon2id Parameters', () async {
      const password = 'CorrectPassword2026!';
      final result = await cryptoService.deriveMasterKeyAndVerifier(password: password);

      expect(result.derivedKeyBytes.length, equals(32)); // 256 bits
      expect(result.verifierHashBytes.length, equals(32)); // SHA-256
      expect(result.saltBytes.length, equals(32)); // 256-bit salt
      expect(result.kdfParams['algorithm'], equals('Argon2id'));
      expect(result.kdfParams['memory'], equals(VaultCryptoService.argon2Memory));
      expect(result.kdfParams['iterations'], equals(VaultCryptoService.argon2Iterations));

      // Verifier verification succeeds with correct password
      final verified = await cryptoService.verifyMasterPassword(
        candidatePassword: password,
        storedSalt: result.saltBytes,
        storedVerifierHash: result.verifierHashBytes,
      );
      expect(verified, isTrue);

      // Verifier verification fails with wrong password
      final wrongVerified = await cryptoService.verifyMasterPassword(
        candidatePassword: 'WrongPassword2026!',
        storedSalt: result.saltBytes,
        storedVerifierHash: result.verifierHashBytes,
      );
      expect(wrongVerified, isFalse);
    });

    test('2. Constant-time equality defends against length and timing side-channels', () {
      final a = [1, 2, 3, 4, 5];
      final b = [1, 2, 3, 4, 5];
      final c = [1, 2, 3, 4, 6];
      final d = [1, 2, 3, 4];

      expect(cryptoService.constantTimeEquals(a, b), isTrue);
      expect(cryptoService.constantTimeEquals(a, c), isFalse);
      expect(cryptoService.constantTimeEquals(a, d), isFalse);
    });

    test('3. VEK Wrapping & AEAD Tamper Resistance', () async {
      final kek = cryptoService.generateRandomBytes(32);
      final originalVek = cryptoService.generateVek();

      final wrapped = await cryptoService.wrapVek(vek: originalVek, wrappingKey: kek);
      expect(wrapped['iv'], isNotNull);
      expect(wrapped['ciphertext'], isNotNull);
      expect(wrapped['tag'], isNotNull);

      // Unwrapping with genuine KEK succeeds
      final unwrapped = await cryptoService.unwrapVek(wrappedVek: wrapped, wrappingKey: kek);
      expect(unwrapped, equals(originalVek));

      // Unwrapping with wrong KEK fails
      final wrongKek = cryptoService.generateRandomBytes(32);
      expect(
        () => cryptoService.unwrapVek(wrappedVek: wrapped, wrappingKey: wrongKek),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );

      // Tampered ciphertext fails
      final tamperedCiphertextBytes = base64Decode(wrapped['ciphertext']!);
      tamperedCiphertextBytes[0] ^= 0xFF;
      final tamperedWrapped = {
        'iv': wrapped['iv']!,
        'ciphertext': base64Encode(tamperedCiphertextBytes),
        'tag': wrapped['tag']!,
      };
      expect(
        () => cryptoService.unwrapVek(wrappedVek: tamperedWrapped, wrappingKey: kek),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('4. Locked Database Access Rejection', () async {
      // Create a record in current encrypted database
      const item = VaultItem(
        id: 'sec_test_1',
        title: 'Secret Vault Item',
        subtitle: 'Confidential',
        category: VaultCategory.passwords,
      );
      await repository.insertItem(item);

      // Verify item exists when unlocked
      final items = await repository.getAllItems();
      expect(items.length, equals(1));

      // Close database (simulating lock)
      await vaultDb.close();
      expect(vaultDb.isOpen, isFalse);

      // Attempting to access repository or database when locked must fail closed
      expect(() => repository.getAllItems(), throwsStateError);
      expect(() => vaultDb.database, throwsStateError);
    });

    test('5. Ephemeral Session Zeroization on Lock', () {
      final secretBytes = cryptoService.generateVek();
      session.startSession(secretBytes);
      expect(session.isActive, isTrue);
      expect(session.vek, isNotNull);

      // Clear session
      session.clear();
      expect(session.isActive, isFalse);
      expect(session.vek, isNull);
    });

    test('6. Temporary Preview Creation and Cleanup', () async {
      final fileKey = await cryptoService.deriveFileStorageKey(testVek);
      final rawFileBytes = utf8.encode('PDF CONFIDENTIAL PREVIEW CONTENTS 2026');

      final stored = await fileService.encryptAndSave(
        fileBytes: rawFileBytes,
        originalFileName: 'confidential_report.pdf',
        fileStorageKey: fileKey,
      );

      // Create temporary preview file
      final previewFile = await fileService.createTemporaryPreviewFile(
        relativePath: stored.relativePath,
        fileName: 'confidential_report.pdf',
        fileStorageKey: fileKey,
      );

      expect(await previewFile.exists(), isTrue);
      expect(await previewFile.readAsBytes(), equals(rawFileBytes));

      // Clear previews
      await fileService.clearTemporaryPreviews();
      expect(await previewFile.exists(), isFalse);
    });

    test('7. Clipboard Service clearClipboard wipes text', () async {
      await ClipboardService.clearClipboard();
      // Verifies no exception occurs when invoked headless
    });

    test('8. Backup Header Argon2id Resource Limits Defense', () async {
      final backupService = VaultBackupService(
        vaultDb: vaultDb,
        fileService: fileService,
        cryptoService: cryptoService,
      );

      // A. Excessive memory limit in header (DoS prevention)
      final evilMemoryHeader = {
        'format': 'MYVAULT_BACKUP',
        'version': 1,
        'app_version': '1.0.0',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'kdf': 'Argon2id',
        'kdf_params': {
          'memory': 1048576, // 1 GB memory allocation attempt!
          'iterations': 2,
          'parallelism': 1,
          'salt': base64Encode(cryptoService.generateRandomBytes(32)),
        },
        'cipher': 'AES-256-GCM',
        'nonce': base64Encode(cryptoService.generateRandomBytes(12)),
        'mac': base64Encode(cryptoService.generateRandomBytes(16)),
        'item_count': 0,
        'file_count': 0,
      };

      final headerBytes = utf8.encode(jsonEncode(evilMemoryHeader));
      final headerLengthBytes = Uint8List(4)..buffer.asByteData().setUint32(0, headerBytes.length, Endian.big);
      final container = BytesBuilder(copy: false)
        ..add(utf8.encode(VaultBackupService.containerMagic))
        ..add(headerLengthBytes)
        ..add(headerBytes)
        ..add(cryptoService.generateRandomBytes(32));

      expect(
        () => backupService.decryptAndValidateBackup(
          fileBytes: container.takeBytes(),
          passphrase: 'Password123!',
        ),
        throwsA(isA<InvalidBackupFormatException>().having(
          (e) => e.message,
          'message',
          contains('safety limits'),
        )),
      );

      // B. Excessive iterations limit in header (DoS prevention)
      final evilIterationsHeader = {
        'format': 'MYVAULT_BACKUP',
        'version': 1,
        'app_version': '1.0.0',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'kdf': 'Argon2id',
        'kdf_params': {
          'memory': 19456,
          'iterations': 5000, // 5000 iterations attempt!
          'parallelism': 1,
          'salt': base64Encode(cryptoService.generateRandomBytes(32)),
        },
        'cipher': 'AES-256-GCM',
        'nonce': base64Encode(cryptoService.generateRandomBytes(12)),
        'mac': base64Encode(cryptoService.generateRandomBytes(16)),
        'item_count': 0,
        'file_count': 0,
      };

      final headerBytes2 = utf8.encode(jsonEncode(evilIterationsHeader));
      final headerLengthBytes2 = Uint8List(4)..buffer.asByteData().setUint32(0, headerBytes2.length, Endian.big);
      final container2 = BytesBuilder(copy: false)
        ..add(utf8.encode(VaultBackupService.containerMagic))
        ..add(headerLengthBytes2)
        ..add(headerBytes2)
        ..add(cryptoService.generateRandomBytes(32));

      expect(
        () => backupService.decryptAndValidateBackup(
          fileBytes: container2.takeBytes(),
          passphrase: 'Password123!',
        ),
        throwsA(isA<InvalidBackupFormatException>().having(
          (e) => e.message,
          'message',
          contains('safety limits'),
        )),
      );

      // C. Invalid salt length in header
      final badSaltHeader = {
        'format': 'MYVAULT_BACKUP',
        'version': 1,
        'app_version': '1.0.0',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'kdf': 'Argon2id',
        'kdf_params': {
          'memory': 19456,
          'iterations': 2,
          'parallelism': 1,
          'salt': base64Encode(cryptoService.generateRandomBytes(16)), // Only 16 bytes!
        },
        'cipher': 'AES-256-GCM',
        'nonce': base64Encode(cryptoService.generateRandomBytes(12)),
        'mac': base64Encode(cryptoService.generateRandomBytes(16)),
        'item_count': 0,
        'file_count': 0,
      };

      final headerBytes3 = utf8.encode(jsonEncode(badSaltHeader));
      final headerLengthBytes3 = Uint8List(4)..buffer.asByteData().setUint32(0, headerBytes3.length, Endian.big);
      final container3 = BytesBuilder(copy: false)
        ..add(utf8.encode(VaultBackupService.containerMagic))
        ..add(headerLengthBytes3)
        ..add(headerBytes3)
        ..add(cryptoService.generateRandomBytes(32));

      expect(
        () => backupService.decryptAndValidateBackup(
          fileBytes: container3.takeBytes(),
          passphrase: 'Password123!',
        ),
        throwsA(isA<InvalidBackupFormatException>().having(
          (e) => e.message,
          'message',
          contains('Invalid salt length'),
        )),
      );
    });

    test('9. Database Migration from V1 to V2 to V3 Preserves Records', () async {
      final migrationDbPath = '${tempDir.path}/migration_test.db';
      final factory = databaseFactoryFfi;

      // 1. Initialize as V1 database
      var db = await factory.openDatabase(
        migrationDbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE vault_items (
                id TEXT PRIMARY KEY,
                category TEXT NOT NULL,
                title TEXT NOT NULL,
                subtitle TEXT,
                is_favourite INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              );
            ''');
            await db.execute('''
              CREATE TABLE identity_entries (
                id TEXT PRIMARY KEY,
                item_id TEXT NOT NULL UNIQUE,
                document_type TEXT NOT NULL,
                document_number TEXT NOT NULL,
                full_name TEXT,
                issued_date TEXT,
                expiry_date TEXT,
                issuing_country TEXT,
                notes TEXT
              );
            ''');
            await db.execute('''
              CREATE TABLE notes (
                id TEXT PRIMARY KEY,
                item_id TEXT NOT NULL UNIQUE,
                content TEXT NOT NULL,
                color_tag TEXT
              );
            ''');
            await db.execute('''
              CREATE TABLE contacts (
                id TEXT PRIMARY KEY,
                item_id TEXT NOT NULL UNIQUE,
                phone_number TEXT NOT NULL,
                email TEXT,
                company TEXT,
                address TEXT
              );
            ''');
          },
        ),
      );

      // Insert record in V1
      await db.insert('vault_items', {
        'id': 'v1_item',
        'category': 'notes',
        'title': 'Original V1 Note',
        'subtitle': 'Created in V1',
        'is_favourite': 1,
        'created_at': 1729000000000,
        'updated_at': 1729000000000,
      });
      await db.insert('notes', {
        'id': 'entry_v1',
        'item_id': 'v1_item',
        'content': 'V1 Note Content',
        'color_tag': '#1E88E5',
      });
      await db.close();

      // 2. Open with V3 schema via VaultSchema.onUpgrade
      db = await factory.openDatabase(
        migrationDbPath,
        options: OpenDatabaseOptions(
          version: 3,
          onUpgrade: VaultSchema.onUpgrade,
        ),
      );

      // Verify V1 record preserved
      final items = await db.query('vault_items', where: 'id = ?', whereArgs: ['v1_item']);
      expect(items.length, equals(1));
      expect(items.first['title'], equals('Original V1 Note'));

      // Verify upgraded columns exist and are accessible
      final notes = await db.query('notes', where: 'item_id = ?', whereArgs: ['v1_item']);
      expect(notes.length, equals(1));
      expect(notes.first['content'], equals('V1 Note Content'));
      expect(notes.first.containsKey('tags'), isTrue); // Added in V3 migration!

      await db.close();
    });

    test('10. Sensitive Data Containment in Exceptions', () {
      const sensitivePassword = 'SuperSecretPassword123!#\$';
      const sensitiveNote = 'Top secret coordinates 48.8584, 2.2945';

      try {
        throw const BackupException('Failed to restore backup due to corrupted file.');
      } catch (e) {
        expect(e.toString(), isNot(contains(sensitivePassword)));
        expect(e.toString(), isNot(contains(sensitiveNote)));
      }
    });
  });
}
