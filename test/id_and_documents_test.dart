import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'vault_test_helpers.dart';
import 'package:myvault/core/database/vault_database.dart';
import 'package:myvault/core/security/vault_crypto_service.dart';
import 'package:myvault/core/storage/encrypted_file_service.dart';
import 'package:myvault/features/vault/data/vault_models.dart';
import 'package:myvault/features/vault/data/vault_repository.dart';
import 'package:myvault/features/vault_items/data/vault_item_model.dart';

void main() {
  late Directory tempDir;
  late VaultCryptoService cryptoService;
  late VaultDatabase vaultDb;
  late EncryptedFileService fileService;
  late VaultRepository repository;
  late Uint8List testVek;
  late String hexDbKey;
  late List<int> fileStorageKey;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('myvault_phase5_test_');
    cryptoService = VaultCryptoService();
    testVek = Uint8List.fromList(cryptoService.generateVek());
    hexDbKey = await cryptoService.deriveDatabaseKeyHex(testVek);
    fileStorageKey = await cryptoService.deriveFileStorageKey(testVek);

    vaultDb = VaultDatabase(
      customFactory: databaseFactoryFfi,
    );

    fileService = EncryptedFileService(
      customStoragePath: tempDir.path,
    );

    repository = VaultRepository(
      vaultDb: vaultDb,
      fileService: fileService,
    );

    await vaultDb.open(
      hexDatabaseKey: hexDbKey,
      customPath: '${tempDir.path}/test_encrypted.db',
    );
  });

  tearDown(() async {
    if (vaultDb.isOpen) {
      await vaultDb.close();
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Phase 5 — ID Vault Management & Sensitive Protection', () {
    test('Creates and retrieves Aadhaar Card with full relational details', () async {
      const itemId = 'id_aadhaar_001';
      const item = VaultItem(
        id: itemId,
        title: 'Aadhaar Card',
        subtitle: 'Government ID',
        category: VaultCategory.idCards,
        subcategory: 'Government',
        isFavourite: true,
      );

      const identity = IdentityEntry(
        id: 'idn_$itemId',
        itemId: itemId,
        documentType: 'Aadhaar Card',
        documentNumber: '5482 9182 3019',
        fullName: 'Prathamesh Shelar',
        issuedDate: '15 Jan 2018',
        expiryDate: 'Does not expire',
        issuingCountry: 'India',
        notes: 'Primary national identity document',
      );

      await repository.insertItem(item, identityEntry: identity);

      final fetched = await repository.getItemById(itemId);
      expect(fetched, isNotNull);
      expect(fetched!.title, equals('Aadhaar Card'));
      expect(fetched.category, equals(VaultCategory.idCards));
      expect(fetched.documentType, equals('Aadhaar Card'));
      expect(fetched.documentNumber, equals('5482 9182 3019'));
      expect(fetched.fullName, equals('Prathamesh Shelar'));
      expect(fetched.issuedDate, equals('15 Jan 2018'));
      expect(fetched.expiryDate, equals('Does not expire'));
      expect(fetched.issuingCountry, equals('India'));
      expect(fetched.details, equals('Primary national identity document'));
      expect(fetched.isFavourite, isTrue);
    });

    test('Supports all required ID card types: PAN, Passport, DL, Voter ID, Custom ID', () async {
      final idTypes = [
        {'type': 'PAN Card', 'num': 'ABCDE1234F', 'sub': 'Government'},
        {'type': 'Passport', 'num': 'Z1234567', 'sub': 'Personal'},
        {'type': 'Driving License', 'num': 'MH12 20180012345', 'sub': 'Personal'},
        {'type': 'Voter ID', 'num': 'EPIC987654', 'sub': 'Government'},
        {'type': 'Custom ID', 'num': 'CORP-9921', 'sub': 'Work'},
      ];

      for (var i = 0; i < idTypes.length; i++) {
        final entry = idTypes[i];
        final itemId = 'id_multi_$i';

        await repository.insertItem(
          VaultItem(
            id: itemId,
            title: entry['type']!,
            subtitle: entry['sub']!,
            category: VaultCategory.idCards,
            subcategory: entry['sub'],
          ),
          identityEntry: IdentityEntry(
            id: 'idn_$itemId',
            itemId: itemId,
            documentType: entry['type']!,
            documentNumber: entry['num']!,
            fullName: 'Holder $i',
            issuingCountry: 'India',
          ),
        );

        final retrieved = await repository.getItemById(itemId);
        expect(retrieved, isNotNull);
        expect(retrieved!.documentType, equals(entry['type']));
        expect(retrieved.documentNumber, equals(entry['num']));
      }

      final allIds = await itemsInCategory(repository, VaultCategory.idCards);
      expect(allIds.length, equals(5));
    });

    test('Searches ID cards by document number, holder name, and title', () async {
      await repository.insertItem(
        const VaultItem(
          id: 'id_search_1',
          title: 'Indian Passport',
          subtitle: 'Personal',
          category: VaultCategory.idCards,
        ),
        identityEntry: const IdentityEntry(
          id: 'idn_search_1',
          itemId: 'id_search_1',
          documentType: 'Passport',
          documentNumber: 'K8822910',
          fullName: 'Aarav Sharma',
        ),
      );

      // Search by partial title
      final byTitle = await searchVault(repository, 'Passport');
      expect(byTitle.any((i) => i.id == 'id_search_1'), isTrue);

      // Search by document number
      final byNumber = await searchVault(repository, '8822910');
      expect(byNumber.any((i) => i.id == 'id_search_1'), isTrue);

      // Search by holder name
      final byHolder = await searchVault(repository, 'Aarav');
      expect(byHolder.any((i) => i.id == 'id_search_1'), isTrue);

      // Search for non-existent query
      final emptyResult = await searchVault(repository, 'NonExistentTermXYZ');
      expect(emptyResult, isEmpty);
    });

    test('Updates existing ID card without duplicating or corrupting fields', () async {
      const itemId = 'id_update_test';
      await repository.insertItem(
        const VaultItem(
          id: itemId,
          title: 'Driving Licence',
          subtitle: 'Personal',
          category: VaultCategory.idCards,
        ),
        identityEntry: const IdentityEntry(
          id: 'idn_upd',
          itemId: itemId,
          documentType: 'Driving License',
          documentNumber: 'DL12345',
          fullName: 'Original Name',
          expiryDate: '2025-01-01',
        ),
      );

      // Update
      await repository.updateItem(
        const VaultItem(
          id: itemId,
          title: 'Driving Licence (Renewed)',
          subtitle: 'Personal',
          category: VaultCategory.idCards,
          isFavourite: true,
        ),
        identityEntry: const IdentityEntry(
          id: 'idn_upd',
          itemId: itemId,
          documentType: 'Driving License',
          documentNumber: 'DL12345',
          fullName: 'Updated Name',
          expiryDate: '2035-01-01',
        ),
      );

      final updated = await repository.getItemById(itemId);
      expect(updated, isNotNull);
      expect(updated!.title, equals('Driving Licence (Renewed)'));
      expect(updated.fullName, equals('Updated Name'));
      expect(updated.expiryDate, equals('2035-01-01'));
      expect(updated.isFavourite, isTrue);
    });

    test('Deleting ID card cascades to removing identity details and attachment', () async {
      // 1. Create encrypted attachment
      final rawPhotoBytes = utf8.encode('FAKE_ID_PHOTO_IMAGE_DATA');
      final storedAttachment = await fileService.encryptAndSave(
        fileBytes: rawPhotoBytes,
        originalFileName: 'aadhaar_front.jpg',
        fileStorageKey: fileStorageKey,
      );

      final attachmentFile = File('${tempDir.path}/${storedAttachment.relativePath}');
      expect(await attachmentFile.exists(), isTrue);

      // 2. Insert item with attachment_path
      const itemId = 'id_delete_cascade';
      await repository.insertItem(
        const VaultItem(
          id: itemId,
          title: 'Aadhaar with Attachment',
          subtitle: 'Government',
          category: VaultCategory.idCards,
        ),
        identityEntry: IdentityEntry(
          id: 'idn_del_cas',
          itemId: itemId,
          documentType: 'Aadhaar Card',
          documentNumber: '1111 2222 3333',
          attachmentPath: storedAttachment.relativePath,
        ),
      );

      // 3. Delete item
      await repository.deleteItem(itemId);

      // 4. Verify item and attached file are gone
      final item = await repository.getItemById(itemId);
      expect(item, isNull);
      expect(await attachmentFile.exists(), isFalse);
    });
  });

  group('Phase 5 — Encrypted Documents & Photos Management', () {
    test('Encrypts document file with AES-256-GCM and persists in app-private storage', () async {
      final originalContent = utf8.encode('CONFIDENTIAL_TAX_RETURN_REPORT_2026');
      final storedResult = await fileService.encryptAndSave(
        fileBytes: originalContent,
        originalFileName: 'TaxReturn2026.pdf',
        fileStorageKey: fileStorageKey,
      );

      expect(storedResult.fileName, equals('TaxReturn2026.pdf'));
      expect(storedResult.mimeType, equals('application/pdf'));
      expect(storedResult.fileExtension, equals('.pdf'));
      expect(storedResult.fileSize, equals(originalContent.length));
      expect(storedResult.relativePath.endsWith('.enc'), isTrue);

      // Verify file exists on disk and is encrypted (does not contain plaintext)
      final diskFile = File('${tempDir.path}/${storedResult.relativePath}');
      expect(await diskFile.exists(), isTrue);

      final encryptedBytes = await diskFile.readAsBytes();
      // Should not contain plaintext string anywhere
      expect(utf8.decode(encryptedBytes, allowMalformed: true).contains('CONFIDENTIAL_TAX_RETURN'), isFalse);

      // Verify magic header
      expect(encryptedBytes.sublist(0, 12), equals(EncryptedFileService.magicHeader));
    });

    test('Decrypts encrypted file on-demand matching original content exactly', () async {
      final sampleImageBytes = List<int>.generate(2048, (i) => (i * 7) % 256);
      final storedResult = await fileService.encryptAndSave(
        fileBytes: sampleImageBytes,
        originalFileName: 'FamilyVacation.jpg',
        fileStorageKey: fileStorageKey,
      );

      final decryptedBytes = await fileService.decrypt(
        relativePath: storedResult.relativePath,
        fileStorageKey: fileStorageKey,
      );

      expect(decryptedBytes, equals(sampleImageBytes));
    });

    test('Tampering with ciphertext causes authenticated decryption failure', () async {
      final sampleBytes = utf8.encode('CRITICAL_CONTRACT_DATA');
      final storedResult = await fileService.encryptAndSave(
        fileBytes: sampleBytes,
        originalFileName: 'contract.pdf',
        fileStorageKey: fileStorageKey,
      );

      final diskFile = File('${tempDir.path}/${storedResult.relativePath}');
      final rawEncrypted = await diskFile.readAsBytes();

      // Tamper with ciphertext bytes (flip a bit near the end)
      final tampered = Uint8List.fromList(rawEncrypted);
      tampered[tampered.length - 2] ^= 0x01;
      await diskFile.writeAsBytes(tampered, flush: true);

      expect(
        () async => await fileService.decrypt(
          relativePath: storedResult.relativePath,
          fileStorageKey: fileStorageKey,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('Decrypting with incorrect file storage key fails closed', () async {
      final sampleBytes = utf8.encode('SENSITIVE_MEMO');
      final storedResult = await fileService.encryptAndSave(
        fileBytes: sampleBytes,
        originalFileName: 'memo.txt',
        fileStorageKey: fileStorageKey,
      );

      final wrongKey = cryptoService.generateRandomBytes(32);
      expect(
        () async => await fileService.decrypt(
          relativePath: storedResult.relativePath,
          fileStorageKey: wrongKey,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('Saves Document and Photo items in SQLCipher database with full metadata', () async {
      const docItemId = 'doc_test_101';
      final pdfContent = utf8.encode('RESUME_CONTENT');
      final storedDoc = await fileService.encryptAndSave(
        fileBytes: pdfContent,
        originalFileName: 'Resume.pdf',
        fileStorageKey: fileStorageKey,
      );

      await repository.insertItem(
        const VaultItem(
          id: docItemId,
          title: 'My Resume',
          subtitle: 'PDF · 14 B',
          category: VaultCategory.documents,
          details: 'Updated software resume',
          isFavourite: true,
        ),
        documentEntry: DocumentEntry(
          id: 'doc_entry_$docItemId',
          itemId: docItemId,
          filePath: storedDoc.relativePath,
          fileName: storedDoc.fileName,
          fileSize: storedDoc.fileSize,
          mimeType: storedDoc.mimeType,
          fileExtension: storedDoc.fileExtension,
          notes: 'Updated software resume',
        ),
      );

      final fetchedDoc = await repository.getItemById(docItemId);
      expect(fetchedDoc, isNotNull);
      expect(fetchedDoc!.title, equals('My Resume'));
      expect(fetchedDoc.category, equals(VaultCategory.documents));
      expect(fetchedDoc.fileName, equals('Resume.pdf'));
      expect(fetchedDoc.mimeType, equals('application/pdf'));
      expect(fetchedDoc.fileExtension, equals('.pdf'));
      expect(fetchedDoc.fileSize, equals(pdfContent.length));
      expect(fetchedDoc.filePath, equals(storedDoc.relativePath));
      expect(fetchedDoc.isFavourite, isTrue);
    });

    test('Updates document metadata without re-encrypting underlying file', () async {
      const docItemId = 'doc_meta_test';
      final rawBytes = utf8.encode('ORIGINAL_DATA');
      final stored = await fileService.encryptAndSave(
        fileBytes: rawBytes,
        originalFileName: 'DocOriginal.pdf',
        fileStorageKey: fileStorageKey,
      );

      await repository.insertItem(
        const VaultItem(
          id: docItemId,
          title: 'Initial Title',
          subtitle: 'PDF',
          category: VaultCategory.documents,
        ),
        documentEntry: DocumentEntry(
          id: 'entry_$docItemId',
          itemId: docItemId,
          filePath: stored.relativePath,
          fileName: stored.fileName,
          fileSize: stored.fileSize,
          mimeType: stored.mimeType,
          fileExtension: stored.fileExtension,
        ),
      );

      // Update title, category, and notes
      await repository.updateItem(
        const VaultItem(
          id: docItemId,
          title: 'Renamed Document',
          subtitle: 'PDF',
          category: VaultCategory.documents,
          details: 'Newly added notes',
          isFavourite: true,
        ),
        documentEntry: DocumentEntry(
          id: 'entry_$docItemId',
          itemId: docItemId,
          filePath: stored.relativePath,
          fileName: stored.fileName,
          fileSize: stored.fileSize,
          mimeType: stored.mimeType,
          fileExtension: stored.fileExtension,
          notes: 'Newly added notes',
        ),
      );

      final updated = await repository.getItemById(docItemId);
      expect(updated, isNotNull);
      expect(updated!.title, equals('Renamed Document'));
      expect(updated.details, equals('Newly added notes'));
      expect(updated.isFavourite, isTrue);
      // Verify underlying encrypted file path remains valid and decrypts properly
      expect(updated.filePath, equals(stored.relativePath));
      final decrypted = await fileService.decrypt(
        relativePath: updated.filePath!,
        fileStorageKey: fileStorageKey,
      );
      expect(decrypted, equals(rawBytes));
    });

    test('Deleting document removes database record and cascades to file removal', () async {
      final fileData = utf8.encode('TEMPORARY_DELETE_ME');
      final stored = await fileService.encryptAndSave(
        fileBytes: fileData,
        originalFileName: 'DeleteMe.png',
        fileStorageKey: fileStorageKey,
      );

      final diskFile = File('${tempDir.path}/${stored.relativePath}');
      expect(await diskFile.exists(), isTrue);

      const itemId = 'doc_to_delete';
      await repository.insertItem(
        const VaultItem(
          id: itemId,
          title: 'To Delete',
          subtitle: 'PNG',
          category: VaultCategory.photos,
        ),
        documentEntry: DocumentEntry(
          id: 'entry_$itemId',
          itemId: itemId,
          filePath: stored.relativePath,
          fileName: stored.fileName,
          fileSize: stored.fileSize,
          mimeType: stored.mimeType,
          fileExtension: stored.fileExtension,
        ),
      );

      // Verify item exists
      expect(await repository.getItemById(itemId), isNotNull);

      // Delete item
      await repository.deleteItem(itemId);

      // Item should be gone from db
      expect(await repository.getItemById(itemId), isNull);
      // Encrypted file on disk should be deleted
      expect(await diskFile.exists(), isFalse);
    });

    test('Creates and cleans up temporary preview file safely', () async {
      final docData = utf8.encode('PDF_DOCUMENT_BINARY_SIMULATION');
      final stored = await fileService.encryptAndSave(
        fileBytes: docData,
        originalFileName: 'SampleStatement.pdf',
        fileStorageKey: fileStorageKey,
      );

      // Create preview file
      final previewFile = await fileService.createTemporaryPreviewFile(
        relativePath: stored.relativePath,
        fileName: 'preview_SampleStatement.pdf',
        fileStorageKey: fileStorageKey,
      );

      expect(await previewFile.exists(), isTrue);
      final readBytes = await previewFile.readAsBytes();
      expect(readBytes, equals(docData));

      // Clean up preview files
      await fileService.clearTemporaryPreviews();
      expect(await previewFile.exists(), isFalse);
    });
  });
}
