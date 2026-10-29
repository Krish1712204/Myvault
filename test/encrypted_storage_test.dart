import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:myvault/core/database/vault_database.dart';
import 'package:myvault/core/security/vault_crypto_service.dart';
import 'package:myvault/core/storage/encrypted_file_service.dart';
import 'package:myvault/features/vault/data/vault_models.dart';
import 'package:myvault/features/vault/data/vault_repository.dart';
import 'package:myvault/features/vault_items/data/vault_item_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempTestDir;
  late VaultCryptoService crypto;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempTestDir = await Directory.systemTemp.createTemp('myvault_test_');
    crypto = VaultCryptoService();
  });

  tearDown(() async {
    try {
      if (await tempTestDir.exists()) {
        await tempTestDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('1. VEK Lifecycle, KEK Wrapping & Biometric Binding', () {
    test('Generates 256-bit secure random VEK', () {
      final vek1 = crypto.generateVek();
      final vek2 = crypto.generateVek();

      expect(vek1.length, equals(32));
      expect(vek2.length, equals(32));
      expect(vek1, isNot(equals(vek2)));
    });

    test('Wraps and unwraps VEK using AES-256-GCM with KEK', () async {
      final vek = crypto.generateVek();
      final kek = crypto.generateRandomBytes(32);

      final wrapped = await crypto.wrapVek(vek: vek, wrappingKey: kek);
      expect(wrapped['iv'], isNotNull);
      expect(wrapped['ciphertext'], isNotNull);
      expect(wrapped['tag'], isNotNull);

      // Verify ciphertext does not equal plaintext
      final cipherBytes = base64Decode(wrapped['ciphertext']!);
      expect(cipherBytes, isNot(equals(vek)));

      // Unwrap with correct KEK
      final unwrapped = await crypto.unwrapVek(wrappedVek: wrapped, wrappingKey: kek);
      expect(unwrapped, equals(vek));
    });

    test('Unwrapping VEK with wrong key fails closed', () async {
      final vek = crypto.generateVek();
      final kek = crypto.generateRandomBytes(32);
      final wrongKek = crypto.generateRandomBytes(32);

      final wrapped = await crypto.wrapVek(vek: vek, wrappingKey: kek);

      expect(
        () async => await crypto.unwrapVek(wrappedVek: wrapped, wrappingKey: wrongKek),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('Tampered wrapped VEK ciphertext fails closed', () async {
      final vek = crypto.generateVek();
      final kek = crypto.generateRandomBytes(32);

      final wrapped = await crypto.wrapVek(vek: vek, wrappingKey: kek);
      final tamperedBytes = base64Decode(wrapped['ciphertext']!);
      tamperedBytes[0] ^= 0xFF; // Flip bits

      final tamperedWrapped = {
        'iv': wrapped['iv']!,
        'ciphertext': base64Encode(tamperedBytes),
        'tag': wrapped['tag']!,
      };

      expect(
        () async => await crypto.unwrapVek(wrappedVek: tamperedWrapped, wrappingKey: kek),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('Derives distinct, reproducible database and file storage keys via HKDF', () async {
      final vek = crypto.generateVek();

      final dbKey1 = await crypto.deriveDatabaseKey(vek);
      final dbKey2 = await crypto.deriveDatabaseKey(vek);
      final fileKey = await crypto.deriveFileStorageKey(vek);

      expect(dbKey1.length, equals(32));
      expect(fileKey.length, equals(32));

      // Same input produces identical keys
      expect(dbKey1, equals(dbKey2));

      // Domain separation: dbKey must not equal fileKey
      expect(dbKey1, isNot(equals(fileKey)));
    });
  });

  group('2. Encrypted Database Operations & Persistence', () {
    test('Database opens with derived key, records persist across reopen', () async {
      final dbPath = '${tempTestDir.path}/test_vault.db';
      final vek = crypto.generateVek();
      final hexKey = await crypto.deriveDatabaseKeyHex(vek);

      final vaultDb = VaultDatabase(customFactory: databaseFactoryFfi);
      await vaultDb.open(hexDatabaseKey: hexKey, customPath: dbPath);

      final fileService = EncryptedFileService(customStoragePath: '${tempTestDir.path}/files');
      final repo = VaultRepository(vaultDb: vaultDb, fileService: fileService);

      // Insert record
      const testItem = VaultItem(
        id: 'test_1',
        title: 'GitHub Personal',
        subtitle: 'developer@example.com',
        category: VaultCategory.passwords,
        username: 'developer@example.com',
        password: 'SuperSecretPassword#123',
        url: 'https://github.com',
      );

      const pwdEntry = PasswordEntry(
        id: 'pwd_1',
        itemId: 'test_1',
        username: 'developer@example.com',
        encryptedPassword: 'SuperSecretPassword#123',
        websiteUrl: 'https://github.com',
      );

      await repo.insertItem(testItem, passwordEntry: pwdEntry);

      // Verify item exists
      var items = await repo.getAllItems();
      expect(items.length, equals(1));
      expect(items.first.title, equals('GitHub Personal'));

      // Close database (simulating lock or app termination)
      await vaultDb.close();
      expect(vaultDb.isOpen, isFalse);

      // Reopen with the same derived key
      await vaultDb.open(hexDatabaseKey: hexKey, customPath: dbPath);
      items = await repo.getAllItems();
      expect(items.length, equals(1));
      expect(items.first.title, equals('GitHub Personal'));
      expect(items.first.password, equals('SuperSecretPassword#123'));

      await vaultDb.close();
    });

    test('Accessing repository when database is locked throws StateError', () async {
      final vaultDb = VaultDatabase(customFactory: databaseFactoryFfi);
      final fileService = EncryptedFileService(customStoragePath: '${tempTestDir.path}/files');
      final repo = VaultRepository(vaultDb: vaultDb, fileService: fileService);

      expect(() => repo.getAllItems(), throwsStateError);
    });

    test('Foreign key cascade deletes subtype records when item is deleted', () async {
      final dbPath = '${tempTestDir.path}/cascade_test.db';
      final vek = crypto.generateVek();
      final hexKey = await crypto.deriveDatabaseKeyHex(vek);

      final vaultDb = VaultDatabase(customFactory: databaseFactoryFfi);
      await vaultDb.open(hexDatabaseKey: hexKey, customPath: dbPath);
      final fileService = EncryptedFileService(customStoragePath: '${tempTestDir.path}/files');
      final repo = VaultRepository(vaultDb: vaultDb, fileService: fileService);

      const testItem = VaultItem(
        id: 'pwd_item_1',
        title: 'Work Email',
        subtitle: 'work@company.com',
        category: VaultCategory.passwords,
      );

      const pwdEntry = PasswordEntry(
        id: 'entry_1',
        itemId: 'pwd_item_1',
        username: 'work@company.com',
        encryptedPassword: 'WorkPassword#2026',
      );

      await repo.insertItem(testItem, passwordEntry: pwdEntry);

      // Verify insertion
      final retrieved = await repo.getItemById('pwd_item_1');
      expect(retrieved, isNotNull);
      expect(retrieved!.username, equals('work@company.com'));

      // Delete master item
      await repo.deleteItem('pwd_item_1');

      // Verify deleted from master and subtype
      final afterDelete = await repo.getItemById('pwd_item_1');
      expect(afterDelete, isNull);

      final countRows = await vaultDb.database.rawQuery('SELECT COUNT(*) FROM password_entries WHERE item_id = ?', ['pwd_item_1']);
      final rawCount = (countRows.first.values.first as num?)?.toInt() ?? 0;
      expect(rawCount, equals(0));

      await vaultDb.close();
    });
  });

  group('3. Encrypted File Storage', () {
    late EncryptedFileService fileService;
    late List<int> fileKey;

    setUp(() async {
      fileService = EncryptedFileService(customStoragePath: '${tempTestDir.path}/encrypted_files');
      final vek = crypto.generateVek();
      fileKey = await crypto.deriveFileStorageKey(vek);
    });

    test('Encrypted file does not contain original plaintext content', () async {
      const plaintext = 'TOP_SECRET_PASSPORT_DATA_DO_NOT_LEAK_1234567890';
      final fileBytes = utf8.encode(plaintext);

      final result = await fileService.encryptAndSave(
        fileBytes: fileBytes,
        originalFileName: 'passport.pdf',
        fileStorageKey: fileKey,
      );

      final onDiskFile = File('${tempTestDir.path}/encrypted_files/${result.relativePath}');
      expect(await onDiskFile.exists(), isTrue);

      final onDiskBytes = await onDiskFile.readAsBytes();

      // Ensure plaintext does not appear anywhere in ciphertext
      final onDiskString = String.fromCharCodes(onDiskBytes);
      expect(onDiskString, isNot(contains(plaintext)));

      // Decrypt and verify matching plaintext
      final decrypted = await fileService.decrypt(
        relativePath: result.relativePath,
        fileStorageKey: fileKey,
      );

      expect(utf8.decode(decrypted), equals(plaintext));
    });

    test('Tampered encrypted file fails authentication', () async {
      final fileBytes = utf8.encode('CONFIDENTIAL_TAX_DOCUMENT');

      final result = await fileService.encryptAndSave(
        fileBytes: fileBytes,
        originalFileName: 'tax.pdf',
        fileStorageKey: fileKey,
      );

      final onDiskFile = File('${tempTestDir.path}/encrypted_files/${result.relativePath}');
      final onDiskBytes = await onDiskFile.readAsBytes();

      // Corrupt a byte in the ciphertext body
      onDiskBytes[onDiskBytes.length - 1] ^= 0x01;
      await onDiskFile.writeAsBytes(onDiskBytes);

      expect(
        () async => await fileService.decrypt(
          relativePath: result.relativePath,
          fileStorageKey: fileKey,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('Deleting item record cleans up associated encrypted file', () async {
      final dbPath = '${tempTestDir.path}/file_delete_test.db';
      final vek = crypto.generateVek();
      final hexKey = await crypto.deriveDatabaseKeyHex(vek);

      final vaultDb = VaultDatabase(customFactory: databaseFactoryFfi);
      await vaultDb.open(hexDatabaseKey: hexKey, customPath: dbPath);
      final repo = VaultRepository(vaultDb: vaultDb, fileService: fileService);

      final fileResult = await fileService.encryptAndSave(
        fileBytes: utf8.encode('Sample Document Content'),
        originalFileName: 'sample.pdf',
        fileStorageKey: fileKey,
      );

      const docItem = VaultItem(
        id: 'doc_item_1',
        title: 'Sample Document',
        subtitle: 'sample.pdf',
        category: VaultCategory.documents,
      );

      final docEntry = DocumentEntry(
        id: 'd_entry_1',
        itemId: 'doc_item_1',
        filePath: fileResult.relativePath,
        fileName: fileResult.fileName,
        fileSize: fileResult.fileSize,
        mimeType: fileResult.mimeType,
        fileExtension: fileResult.fileExtension,
      );

      await repo.insertItem(docItem, documentEntry: docEntry);

      final storedFile = File('${tempTestDir.path}/encrypted_files/${fileResult.relativePath}');
      expect(await storedFile.exists(), isTrue);

      // Delete item
      await repo.deleteItem('doc_item_1');

      // Verify file is deleted on disk
      expect(await storedFile.exists(), isFalse);

      await vaultDb.close();
    });
  });
}
