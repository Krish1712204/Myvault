import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:myvault/core/backup/vault_backup_service.dart';
import 'package:myvault/core/database/vault_database.dart';
import 'package:myvault/core/security/vault_crypto_service.dart';
import 'package:myvault/core/storage/encrypted_file_service.dart';
import 'package:myvault/features/vault/data/vault_models.dart';
import 'package:myvault/features/vault/data/vault_repository.dart';
import 'package:myvault/features/vault_items/data/vault_item_model.dart';

void main() {
  late Directory tempDir;
  late VaultCryptoService cryptoService;
  late VaultDatabase sourceDb;
  late EncryptedFileService sourceFileService;
  late VaultRepository sourceRepo;
  late VaultBackupService sourceBackupService;
  late Uint8List sourceVek;
  late String sourceHexDbKey;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('myvault_phase7_test_');
    cryptoService = VaultCryptoService();
    sourceVek = Uint8List.fromList(cryptoService.generateVek());
    sourceHexDbKey = await cryptoService.deriveDatabaseKeyHex(sourceVek);

    sourceDb = VaultDatabase(customFactory: databaseFactoryFfi);
    sourceFileService = EncryptedFileService(
      customStoragePath: '${tempDir.path}/source_files',
    );
    sourceRepo = VaultRepository(
      vaultDb: sourceDb,
      fileService: sourceFileService,
    );
    sourceBackupService = VaultBackupService(
      vaultDb: sourceDb,
      fileService: sourceFileService,
      cryptoService: cryptoService,
    );

    await sourceDb.open(
      hexDatabaseKey: sourceHexDbKey,
      customPath: '${tempDir.path}/source_vault.db',
    );
  });

  tearDown(() async {
    if (sourceDb.isOpen) {
      await sourceDb.close();
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Phase 7 — Encrypted Backup & Restore Tests', () {
    test('1. Passphrase length validation', () async {
      expect(
        () => sourceBackupService.createBackupBytes(
          passphrase: 'short',
          vek: sourceVek,
        ),
        throwsA(isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('at least 8 characters'),
        )),
      );
    });

    test('2. Locked vault rejects backup and restore operations', () async {
      expect(
        () => sourceBackupService.createBackupBytes(
          passphrase: 'StrongPassphrase123!',
          vek: Uint8List(0),
        ),
        throwsA(isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('Vault is locked'),
        )),
      );

      const dummyPayload = BackupPayload(
        version: 1,
        timestamp: 123456789,
        vaultItems: [],
        passwordEntries: [],
        identityEntries: [],
        documentEntries: [],
        notes: [],
        contacts: [],
        tags: [],
        itemTags: [],
        files: [],
      );

      expect(
        () => sourceBackupService.restoreBackupPayload(
          payload: dummyPayload,
          currentVek: Uint8List(0),
          replaceExisting: true,
        ),
        throwsA(isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('Vault is locked'),
        )),
      );
    });

    test('3. Full roundtrip backup, header inspection, and restore across all categories', () async {
      final sourceFileStorageKey = await cryptoService.deriveFileStorageKey(sourceVek);

      // A. Populate Password Item
      const pwItem = VaultItem(
        id: 'pw_001',
        title: 'Google Account',
        subtitle: 'alice@example.com',
        category: VaultCategory.passwords,
        details: 'Personal main Google login',
        subcategory: 'Email',
        tags: 'google,primary',
        isFavourite: true,
        createdAt: 1729000000000,
        updatedAt: 1729000000000,
      );
      const pwEntry = PasswordEntry(
        id: 'entry_pw_001',
        itemId: 'pw_001',
        username: 'alice@example.com',
        encryptedPassword: 'SuperSecretPassword99!',
        websiteUrl: 'https://accounts.google.com',
      );
      await sourceRepo.insertItem(pwItem, passwordEntry: pwEntry);

      // B. Populate ID Card Item with an attached file
      final idRawBytes = utf8.encode('PDF DUMMY ID SCAN: AADHAAR CARD 1234 5678 9012');
      final idStoredFile = await sourceFileService.encryptAndSave(
        fileBytes: idRawBytes,
        originalFileName: 'aadhaar_card.pdf',
        fileStorageKey: sourceFileStorageKey,
      );

      const idItem = VaultItem(
        id: 'id_001',
        title: 'Aadhaar Card',
        subtitle: '1234 **** 9012',
        category: VaultCategory.idCards,
        details: 'National Identity Card',
        subcategory: 'Government',
        tags: 'government,id',
        isFavourite: true,
        createdAt: 1729000000000,
        updatedAt: 1729000000000,
      );
      final idEntry = IdentityEntry(
        id: 'entry_id_001',
        itemId: 'id_001',
        documentType: 'Aadhaar Card',
        documentNumber: '1234 5678 9012',
        fullName: 'Alice Johnson',
        attachmentPath: idStoredFile.relativePath,
      );
      await sourceRepo.insertItem(idItem, identityEntry: idEntry);

      // C. Populate Document Item with an attached file
      final docRawBytes = utf8.encode('CONFIDENTIAL FINANCIAL REPORT 2026 Q3');
      final docStoredFile = await sourceFileService.encryptAndSave(
        fileBytes: docRawBytes,
        originalFileName: 'financial_report_q3.pdf',
        fileStorageKey: sourceFileStorageKey,
      );

      const docItem = VaultItem(
        id: 'doc_001',
        title: 'Financial Report Q3',
        subtitle: 'PDF Document',
        category: VaultCategory.documents,
        details: 'Quarterly financial report',
        subcategory: 'Finance',
        tags: 'finance,confidential',
        isFavourite: false,
        createdAt: 1729000000000,
        updatedAt: 1729000000000,
      );
      final docEntry = DocumentEntry(
        id: 'entry_doc_001',
        itemId: 'doc_001',
        filePath: docStoredFile.relativePath,
        fileName: 'financial_report_q3.pdf',
        fileSize: docRawBytes.length,
        mimeType: 'application/pdf',
        fileExtension: 'pdf',
      );
      await sourceRepo.insertItem(docItem, documentEntry: docEntry);

      // D. Populate Note Item
      const noteItem = VaultItem(
        id: 'note_001',
        title: 'Meeting Notes Oct 2026',
        subtitle: 'Discussion points on offline crypto',
        category: VaultCategory.notes,
        details: 'Discussion on Argon2id KDF and AES-256-GCM AEAD container.',
        subcategory: 'Work',
        tags: 'work,crypto',
        isFavourite: true,
        createdAt: 1729000000000,
        updatedAt: 1729000000000,
      );
      const noteEntry = NoteEntry(
        id: 'entry_note_001',
        itemId: 'note_001',
        content: 'Discussion on Argon2id KDF and AES-256-GCM AEAD container.',
        tags: 'work,crypto',
      );
      await sourceRepo.insertItem(noteItem, noteEntry: noteEntry);

      // E. Populate Contact Item
      const contactItem = VaultItem(
        id: 'contact_001',
        title: 'Dr. Robert Smith',
        subtitle: '+1-555-0199',
        category: VaultCategory.contacts,
        details: 'Family Physician',
        subcategory: 'Medical',
        tags: 'doctor,emergency',
        isFavourite: false,
        createdAt: 1729000000000,
        updatedAt: 1729000000000,
      );
      const contactEntry = ContactEntry(
        id: 'entry_contact_001',
        itemId: 'contact_001',
        phoneNumber: '+1-555-0199',
        email: 'rsmith@clinic.example',
        notes: 'Available Mon-Thu',
      );
      await sourceRepo.insertItem(contactItem, contactEntry: contactEntry);

      // Verify source database item count
      final sourceItems = await sourceRepo.getAllItems();
      expect(sourceItems.length, equals(5));

      // 1. Create Encrypted Backup Bytes
      const backupPassphrase = 'MyBackupSuperSecretPassword2026!';
      final backupBytes = await sourceBackupService.createBackupBytes(
        passphrase: backupPassphrase,
        vek: sourceVek,
      );
      expect(backupBytes.length, greaterThan(100));

      // 2. Inspect Header without decrypting payload
      final inspection = await sourceBackupService.inspectBackupFile(backupBytes);
      expect(inspection.format, equals('MYVAULT_BACKUP'));
      expect(inspection.version, equals(2));
      expect(inspection.kdfAlgorithm, equals('Argon2id'));
      expect(inspection.itemCount, equals(5));
      expect(inspection.fileCount, equals(2)); // id attachment + doc attachment
      expect(inspection.fileSize, equals(backupBytes.length));

      // 3. Set up Target (Restored) Vault on a different database & file directory
      final targetVek = Uint8List.fromList(cryptoService.generateVek());
      final targetHexDbKey = await cryptoService.deriveDatabaseKeyHex(targetVek);

      final targetDb = VaultDatabase(customFactory: databaseFactoryFfi);
      final targetFileService = EncryptedFileService(
        customStoragePath: '${tempDir.path}/target_files',
      );
      final targetRepo = VaultRepository(
        vaultDb: targetDb,
        fileService: targetFileService,
      );
      final targetBackupService = VaultBackupService(
        vaultDb: targetDb,
        fileService: targetFileService,
        cryptoService: cryptoService,
      );

      await targetDb.open(
        hexDatabaseKey: targetHexDbKey,
        customPath: '${tempDir.path}/target_vault.db',
      );

      // 4. Authenticate, Decrypt and Validate Payload
      final decryptedPayload = await targetBackupService.decryptAndValidateBackup(
        fileBytes: backupBytes,
        passphrase: backupPassphrase,
      );
      expect(decryptedPayload.version, equals(2));
      expect(decryptedPayload.vaultItems.length, equals(5));
      expect(decryptedPayload.files.length, equals(2));

      // 5. Restore Payload into target database
      final restoreResult = await targetBackupService.restoreBackupPayload(
        payload: decryptedPayload,
        currentVek: targetVek,
        replaceExisting: true,
      );
      expect(restoreResult.success, isTrue);
      expect(restoreResult.itemsRestored, equals(5));
      expect(restoreResult.filesRestored, equals(2));

      // 6. Verify restored database records in target
      final targetItems = await targetRepo.getAllItems();
      expect(targetItems.length, equals(5));

      // Verify Password Record
      final restoredPw = await targetRepo.getItemById('pw_001');
      expect(restoredPw, isNotNull);
      expect(restoredPw!.title, equals('Google Account'));
      final targetDbInstance = targetDb.database;
      final pwRows = await targetDbInstance.query('password_entries', where: 'item_id = ?', whereArgs: ['pw_001']);
      expect(pwRows.length, equals(1));
      expect(pwRows.first['username'], equals('alice@example.com'));
      expect(pwRows.first['encrypted_password'], equals('SuperSecretPassword99!'));

      // Verify Note Record
      final restoredNote = await targetRepo.getItemById('note_001');
      expect(restoredNote, isNotNull);
      expect(restoredNote!.title, equals('Meeting Notes Oct 2026'));
      final noteRows = await targetDbInstance.query('notes', where: 'item_id = ?', whereArgs: ['note_001']);
      expect(noteRows.length, equals(1));
      expect(noteRows.first['content'], contains('Argon2id KDF'));

      // Verify Contact Record
      final restoredContact = await targetRepo.getItemById('contact_001');
      expect(restoredContact, isNotNull);
      expect(restoredContact!.title, equals('Dr. Robert Smith'));
      final contactRows = await targetDbInstance.query('contacts', where: 'item_id = ?', whereArgs: ['contact_001']);
      expect(contactRows.length, equals(1));
      expect(contactRows.first['phone_number'], equals('+1-555-0199'));

      // Verify ID Card Record & File Attachment Decryption with Target VEK
      final restoredId = await targetRepo.getItemById('id_001');
      expect(restoredId, isNotNull);
      final idRows = await targetDbInstance.query('identity_entries', where: 'item_id = ?', whereArgs: ['id_001']);
      expect(idRows.length, equals(1));
      final restoredIdAttachmentPath = idRows.first['attachment_path'] as String;
      final targetFileKey = await cryptoService.deriveFileStorageKey(targetVek);
      final decryptedIdBytes = await targetFileService.decrypt(
        relativePath: restoredIdAttachmentPath,
        fileStorageKey: targetFileKey,
      );
      expect(utf8.decode(decryptedIdBytes), equals('PDF DUMMY ID SCAN: AADHAAR CARD 1234 5678 9012'));

      // Verify Document Record & File Attachment Decryption with Target VEK
      final restoredDoc = await targetRepo.getItemById('doc_001');
      expect(restoredDoc, isNotNull);
      final docRows = await targetDbInstance.query('document_entries', where: 'item_id = ?', whereArgs: ['doc_001']);
      expect(docRows.length, equals(1));
      final restoredDocPath = docRows.first['file_path'] as String;
      final decryptedDocBytes = await targetFileService.decrypt(
        relativePath: restoredDocPath,
        fileStorageKey: targetFileKey,
      );
      expect(utf8.decode(decryptedDocBytes), equals('CONFIDENTIAL FINANCIAL REPORT 2026 Q3'));

      await targetDb.close();
    });

    test('4. Rejects incorrect passphrase during restore', () async {
      const pwItem = VaultItem(
        id: 'pw_002',
        title: 'Test',
        subtitle: 'Account',
        category: VaultCategory.passwords,
      );
      await sourceRepo.insertItem(pwItem);

      final backupBytes = await sourceBackupService.createBackupBytes(
        passphrase: 'CorrectPassword123!',
        vek: sourceVek,
      );

      expect(
        () => sourceBackupService.decryptAndValidateBackup(
          fileBytes: backupBytes,
          passphrase: 'WrongPassword456!',
        ),
        throwsA(isA<InvalidBackupPassphraseException>()),
      );
    });

    test('5. Rejects corrupted or tampered ciphertext (AEAD MAC verification)', () async {
      const pwItem = VaultItem(
        id: 'pw_003',
        title: 'Test Tampering',
        subtitle: 'Account',
        category: VaultCategory.passwords,
      );
      await sourceRepo.insertItem(pwItem);

      final backupBytes = await sourceBackupService.createBackupBytes(
        passphrase: 'CorrectPassword123!',
        vek: sourceVek,
      );

      final tamperedBytes = Uint8List.fromList(backupBytes);
      // Flip bits in the ciphertext portion (at the end)
      tamperedBytes[tamperedBytes.length - 1] ^= 0xFF;

      expect(
        () => sourceBackupService.decryptAndValidateBackup(
          fileBytes: tamperedBytes,
          passphrase: 'CorrectPassword123!',
        ),
        throwsA(isA<InvalidBackupPassphraseException>()),
      );
    });

    test('6. Rejects corrupted file format or invalid magic bytes', () async {
      final invalidBytes = utf8.encode('INVALID_MAGIC_HEADER_BYTES_ETC');

      expect(
        () => sourceBackupService.inspectBackupFile(invalidBytes),
        throwsA(isA<InvalidBackupFormatException>()),
      );

      expect(
        () => sourceBackupService.decryptAndValidateBackup(
          fileBytes: invalidBytes,
          passphrase: 'SomePassphrase123!',
        ),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    });

    test('7. Rejects unsupported backup version', () async {
      // Create backup container with version 999 in the header
      final headerMap = {
        'format': 'MYVAULT_BACKUP',
        'version': 999,
        'app_version': '9.0.0',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'kdf': 'Argon2id',
        'kdf_params': {
          'salt': base64Encode(List.filled(32, 0)),
        },
        'nonce': base64Encode(List.filled(12, 0)),
        'mac': base64Encode(List.filled(16, 0)),
        'item_count': 0,
        'file_count': 0,
      };

      final headerBytes = utf8.encode(jsonEncode(headerMap));
      final headerLengthBytes = Uint8List(4)..buffer.asByteData().setUint32(0, headerBytes.length, Endian.big);

      final container = BytesBuilder(copy: false)
        ..add(utf8.encode(VaultBackupService.containerMagic))
        ..add(headerLengthBytes)
        ..add(headerBytes)
        ..add(List.filled(32, 0)); // Dummy ciphertext

      final bytes = container.takeBytes();

      expect(
        () => sourceBackupService.inspectBackupFile(bytes),
        throwsA(isA<UnsupportedBackupVersionException>()),
      );

      expect(
        () => sourceBackupService.decryptAndValidateBackup(
          fileBytes: bytes,
          passphrase: 'SomePassphrase123!',
        ),
        throwsA(isA<UnsupportedBackupVersionException>()),
      );
    });

    test('8. Prevents path traversal attempts in backup attachments', () async {
      final testBytes = utf8.encode('evil file payload');
      final sha256Hash = (await Sha256().hash(testBytes)).bytes;
      final sha256Hex = sha256Hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      final evilPayload = BackupPayload(
        version: 1,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        vaultItems: [],
        passwordEntries: [],
        identityEntries: [],
        documentEntries: [],
        notes: [],
        contacts: [],
        tags: [],
        itemTags: [],
        files: [
          BackupFileAttachment(
            fileName: 'evil.txt',
            relativePath: '../../etc/passwd',
            mimeType: 'text/plain',
            size: testBytes.length,
            sha256: sha256Hex,
            dataB64: base64Encode(testBytes),
          ),
        ],
      );

      // Encrypt evil payload
      final payloadJsonStr = jsonEncode(evilPayload.toMap());
      final payloadBytes = utf8.encode(payloadJsonStr);
      final salt = cryptoService.generateSalt(32);
      final nonce = cryptoService.generateRandomBytes(12);
      const passphrase = 'BackupPassphrase123!';
      final bek = await cryptoService.deriveBackupKey(passphrase: passphrase, salt: salt);
      final box = await cryptoService.encryptBackupPayload(plaintext: payloadBytes, backupKey: bek, nonce: nonce);

      final headerMap = {
        'format': 'MYVAULT_BACKUP',
        'version': 1,
        'app_version': '1.0.0',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'kdf': 'Argon2id',
        'kdf_params': {
          'salt': base64Encode(salt),
        },
        'nonce': base64Encode(nonce),
        'mac': base64Encode(box.mac.bytes),
        'item_count': 0,
        'file_count': 1,
      };
      final headerBytes = utf8.encode(jsonEncode(headerMap));
      final headerLengthBytes = Uint8List(4)..buffer.asByteData().setUint32(0, headerBytes.length, Endian.big);

      final container = BytesBuilder(copy: false)
        ..add(utf8.encode(VaultBackupService.containerMagic))
        ..add(headerLengthBytes)
        ..add(headerBytes)
        ..add(box.cipherText);

      expect(
        () => sourceBackupService.decryptAndValidateBackup(
          fileBytes: container.takeBytes(),
          passphrase: passphrase,
        ),
        throwsA(isA<InvalidBackupFormatException>().having(
          (e) => e.message,
          'message',
          contains('Path traversal attempt detected'),
        )),
      );
    });

    test('9. Rejects restoring into non-empty vault without explicit confirmation', () async {
      // Populate source vault
      const item = VaultItem(id: 'existing_001', title: 'Existing Item', subtitle: 'Note', category: VaultCategory.notes);
      await sourceRepo.insertItem(item);

      const dummyPayload = BackupPayload(
        version: 1,
        timestamp: 123456789,
        vaultItems: [
          {'id': 'restored_001', 'title': 'Restored Item', 'subtitle': 'Restored', 'category': 'notes'}
        ],
        passwordEntries: [],
        identityEntries: [],
        documentEntries: [],
        notes: [],
        contacts: [],
        tags: [],
        itemTags: [],
        files: [],
      );

      expect(
        () => sourceBackupService.restoreBackupPayload(
          payload: dummyPayload,
          currentVek: sourceVek,
          replaceExisting: false, // Explicit false
        ),
        throwsA(isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('Explicit confirmation is required to replace data'),
        )),
      );
    });

    test('10. Atomic rollback restores original database and files if restore encounters error', () async {
      // 1. Setup existing state in vault
      const existingItem = VaultItem(
        id: 'orig_item_1',
        title: 'Original Existing Item',
        subtitle: 'Account',
        category: VaultCategory.passwords,
      );
      const existingPw = PasswordEntry(
        id: 'orig_pw_1',
        itemId: 'orig_item_1',
        username: 'orig_user',
        encryptedPassword: 'orig_password_123',
      );
      await sourceRepo.insertItem(existingItem, passwordEntry: existingPw);

      // Verify item exists
      var items = await sourceRepo.getAllItems();
      expect(items.length, equals(1));
      expect(items.first.title, equals('Original Existing Item'));

      // 2. Prepare payload with an invalid base64 attachment to trigger an exception during attachment restore
      final corruptPayload = BackupPayload(
        version: 1,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        vaultItems: [
          {
            'id': 'new_item_99',
            'title': 'New Incomplete Item',
            'subtitle': 'Corrupt test',
            'category': 'documents',
            'created_at': 1729000000000,
            'updated_at': 1729000000000,
            'is_favourite': 0,
          }
        ],
        passwordEntries: [],
        identityEntries: [],
        documentEntries: [],
        notes: [],
        contacts: [],
        tags: [],
        itemTags: [],
        files: [
          const BackupFileAttachment(
            fileName: 'corrupt.bin',
            relativePath: 'corrupt.bin',
            mimeType: 'application/octet-stream',
            size: 10,
            sha256: 'deadbeef',
            dataB64: '!!!NOT_VALID_BASE64_BYTES!!!',
          ),
        ],
      );

      // 3. Attempt restore and verify it throws BackupException
      await expectLater(
        () => sourceBackupService.restoreBackupPayload(
          payload: corruptPayload,
          currentVek: sourceVek,
          replaceExisting: true,
        ),
        throwsA(isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('Your vault was not changed'),
        )),
      );

      // 4. Assert rollback: original items and passwords must remain completely intact!
      items = await sourceRepo.getAllItems();
      expect(items.length, equals(1));
      expect(items.first.id, equals('orig_item_1'));
      expect(items.first.title, equals('Original Existing Item'));

      final pw = await sourceDb.database.query('password_entries');
      expect(pw.length, equals(1));
      expect(pw.first['encrypted_password'], equals('orig_password_123'));
    });
  });
}
