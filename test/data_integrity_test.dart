import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:myvault/core/backup/vault_backup_service.dart';
import 'package:myvault/core/database/vault_database.dart';
import 'package:myvault/core/database/vault_schema.dart';
import 'package:myvault/core/security/vault_crypto_service.dart';
import 'package:myvault/core/storage/encrypted_file_service.dart';
import 'package:myvault/features/vault/data/vault_models.dart';
import 'package:myvault/features/vault/data/vault_repository.dart';
import 'package:myvault/features/vault_items/data/vault_item_model.dart';

void main() {
  late Directory tempDir;
  late VaultDatabase vaultDb;
  late VaultRepository repository;
  late String hexDbKey;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('myvault_integrity_test_');
    final crypto = VaultCryptoService();
    hexDbKey = await crypto.deriveDatabaseKeyHex(crypto.generateVek());
    dbPath = '${tempDir.path}/integrity.db';
    vaultDb = VaultDatabase(customFactory: databaseFactoryFfi);
    repository = VaultRepository(
      vaultDb: vaultDb,
      fileService: EncryptedFileService(customStoragePath: tempDir.path),
    );
  });

  tearDown(() async {
    if (vaultDb.isOpen) await vaultDb.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('Subcategory persistence', () {
    test('A fresh vault contains no sample items', () async {
      await vaultDb.open(hexDatabaseKey: hexDbKey, customPath: dbPath);
      expect(await repository.getAllItems(), isEmpty);
    });

    test('Subcategory survives insert, update, and reload', () async {
      await vaultDb.open(hexDatabaseKey: hexDbKey, customPath: dbPath);

      const itemId = 'cnt_001';
      const item = VaultItem(
        id: itemId,
        title: 'Asha Rao',
        subtitle: '+91 90000 00000',
        category: VaultCategory.contacts,
        subcategory: 'Work',
      );
      const contact = ContactEntry(
        id: 'entry_$itemId',
        itemId: itemId,
        phoneNumber: '+91 90000 00000',
      );

      await repository.insertItem(item, contactEntry: contact);
      expect((await repository.getItemById(itemId))!.subcategory, equals('Work'));

      await repository.updateItem(
        item.copyWith(subcategory: 'Family'),
        contactEntry: contact,
      );
      expect((await repository.getItemById(itemId))!.subcategory, equals('Family'));

      // Reopen the database to prove the value is persisted, not cached.
      await vaultDb.close();
      await vaultDb.open(hexDatabaseKey: hexDbKey, customPath: dbPath);
      final all = await repository.getAllItems();
      expect(all.single.subcategory, equals('Family'));
    });

    test('Upgrading a v4 database adds subcategory and keeps existing rows', () async {
      // Build a minimal v4 database: vault_items without the subcategory column.
      final v4 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: (db, _) async {
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
            await db.insert('vault_items', {
              'id': 'note_legacy',
              'category': VaultCategory.notes.keyName,
              'title': 'Legacy note',
              'subtitle': '',
              'is_favourite': 0,
              'created_at': 1,
              'updated_at': 1,
            });
          },
        ),
      );
      await v4.close();

      await vaultDb.open(hexDatabaseKey: hexDbKey, customPath: dbPath);
      final db = vaultDb.database;

      expect(await db.getVersion(), equals(VaultSchema.currentVersion));
      final columns = await db.rawQuery('PRAGMA table_info(vault_items)');
      expect(columns.map((c) => c['name']), contains('subcategory'));

      final rows = await db.query('vault_items');
      expect(rows.single['title'], equals('Legacy note'));
      expect(rows.single['subcategory'], isNull);
    });
  });

  group('Legacy sample-data cleanup (v6)', () {
    test('Removes untouched sample items, keeps edited samples and real items', () async {
      final v5 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 5,
          onConfigure: VaultSchema.onConfigure,
          onCreate: VaultSchema.onCreate,
        ),
      );
      Future<void> addPassword(String itemId, String entryId, String title) async {
        await v5.insert('vault_items', {
          'id': itemId,
          'category': 'passwords',
          'title': title,
          'subtitle': '',
          'is_favourite': 0,
          'created_at': 1,
          'updated_at': 1,
        });
        await v5.insert('password_entries', {'id': entryId, 'item_id': itemId, 'encrypted_password': 'x'});
      }

      await addPassword('pwd_1', 'pwd_pwd_1', 'Google'); // untouched sample
      await addPassword('pwd_2', 'entry_pwd_2', 'Microsoft'); // sample the user edited
      await addPassword('pwd_1729000000000', 'entry_pwd_1729000000000', 'My bank'); // real item
      await v5.close();

      await vaultDb.open(hexDatabaseKey: hexDbKey, customPath: dbPath);
      final ids = (await vaultDb.database.query('vault_items')).map((r) => r['id']).toSet();

      expect(ids, {'pwd_2', 'pwd_1729000000000'});
      expect(await vaultDb.database.query('password_entries', where: "item_id = 'pwd_1'"), isEmpty);
    });
  });

  group('Attachment file lifecycle', () {
    late EncryptedFileService fileService;
    late List<int> fileKey;
    late VaultBackupService backupService;
    late Uint8List vek;

    setUp(() async {
      final crypto = VaultCryptoService();
      vek = Uint8List.fromList(crypto.generateVek());
      hexDbKey = await crypto.deriveDatabaseKeyHex(vek);
      fileKey = await crypto.deriveFileStorageKey(vek);
      fileService = EncryptedFileService(customStoragePath: '${tempDir.path}/files');
      repository = VaultRepository(vaultDb: vaultDb, fileService: fileService);
      backupService = VaultBackupService(
        vaultDb: vaultDb,
        fileService: fileService,
        cryptoService: crypto,
      );
      await vaultDb.open(hexDatabaseKey: hexDbKey, customPath: dbPath);
    });

    Future<String> storeFile(String content) async {
      final stored = await fileService.encryptAndSave(
        fileBytes: utf8.encode(content),
        originalFileName: 'photo.jpg',
        fileStorageKey: fileKey,
      );
      return stored.relativePath;
    }

    bool fileExists(String relativePath) =>
        File('${tempDir.path}/files/$relativePath').existsSync();

    Future<void> insertContact(String id, String? photoPath) => repository.insertItem(
          VaultItem(id: id, title: 'Contact $id', subtitle: '', category: VaultCategory.contacts),
          contactEntry: ContactEntry(
            id: 'entry_$id',
            itemId: id,
            phoneNumber: '123',
            attachmentPath: photoPath,
          ),
        );

    test('Deleting a photo also deletes its encrypted thumbnail', () async {
      final photo = await storeFile('full image');
      final thumb = await storeFile('thumbnail');
      await repository.insertItem(
        const VaultItem(id: 'doc_1', title: 'Trip', subtitle: '', category: VaultCategory.photos),
        documentEntry: DocumentEntry(
          id: 'entry_doc_1',
          itemId: 'doc_1',
          filePath: photo,
          fileName: 'trip.jpg',
          fileSize: 10,
          mimeType: 'image/jpeg',
          fileExtension: '.jpg',
          thumbnailPath: thumb,
        ),
      );
      expect((await repository.getItemById('doc_1'))!.thumbnailPath, thumb);

      await repository.deleteItem('doc_1');
      expect(fileExists(photo), isFalse);
      expect(fileExists(thumb), isFalse);
    });

    test('Deleting a contact deletes its encrypted photo', () async {
      final photo = await storeFile('photo bytes');
      await insertContact('cnt_1', photo);

      await repository.deleteItem('cnt_1');

      expect(await repository.getItemById('cnt_1'), isNull);
      expect(fileExists(photo), isFalse);
    });

    test('Replacing a contact photo deletes the old file; keeping it does not', () async {
      final oldPhoto = await storeFile('old');
      await insertContact('cnt_1', oldPhoto);
      final item = (await repository.getItemById('cnt_1'))!;

      // Unchanged photo is kept.
      await repository.updateItem(
        item,
        contactEntry: ContactEntry(id: 'entry_cnt_1', itemId: 'cnt_1', phoneNumber: '456', attachmentPath: oldPhoto),
      );
      expect(fileExists(oldPhoto), isTrue);

      // New photo replaces the old one.
      final newPhoto = await storeFile('new');
      await repository.updateItem(
        item,
        contactEntry: ContactEntry(id: 'entry_cnt_1', itemId: 'cnt_1', phoneNumber: '456', attachmentPath: newPhoto),
      );
      expect(fileExists(oldPhoto), isFalse);
      expect(fileExists(newPhoto), isTrue);
    });

    test('Backup includes contact photos and restore re-links them', () async {
      final photo = await storeFile('contact photo bytes');
      await insertContact('cnt_1', photo);

      final backup = await backupService.createBackupBytes(passphrase: 'Backup#Pass1', vek: vek);
      final payload = await backupService.decryptAndValidateBackup(
        fileBytes: backup,
        passphrase: 'Backup#Pass1',
      );
      expect(payload.files.length, equals(1));

      await backupService.restoreBackupPayload(payload: payload, currentVek: vek, replaceExisting: true);

      final restored = (await repository.getItemById('cnt_1'))!;
      expect(restored.attachmentPath, isNotNull);
      final bytes = await fileService.decrypt(relativePath: restored.attachmentPath!, fileStorageKey: fileKey);
      expect(utf8.decode(bytes), equals('contact photo bytes'));
      // The pre-restore file is replaced by a freshly written copy and cleaned up.
      expect(restored.attachmentPath, isNot(equals(photo)));
      expect(fileExists(photo), isFalse);
    });

    test('A failed restore never deletes or overwrites live files', () async {
      final photo = await storeFile('original live photo');
      await insertContact('cnt_1', photo);

      // Backup carries a file with the SAME name as the live one, plus a row that
      // violates NOT NULL (title) so the database transaction fails.
      final payload = BackupPayload(
        version: 1,
        timestamp: 0,
        vaultItems: [
          {'id': 'bad', 'category': 'contacts', 'created_at': 1, 'updated_at': 1, 'is_favourite': 0},
        ],
        passwordEntries: const [],
        identityEntries: const [],
        documentEntries: const [],
        notes: const [],
        contacts: const [],
        tags: const [],
        itemTags: const [],
        files: [
          BackupFileAttachment(
            fileName: 'photo.jpg',
            relativePath: photo,
            mimeType: 'image/jpeg',
            size: 5,
            sha256: '',
            dataB64: base64Encode(utf8.encode('evil')),
          ),
        ],
      );

      await expectLater(
        () => backupService.restoreBackupPayload(payload: payload, currentVek: vek, replaceExisting: true),
        throwsA(isA<BackupException>()),
      );

      final item = (await repository.getItemById('cnt_1'))!;
      expect(item.attachmentPath, equals(photo));
      final bytes = await fileService.decrypt(relativePath: photo, fileStorageKey: fileKey);
      expect(utf8.decode(bytes), equals('original live photo'));
      // Only the live file remains; the staged copy was removed.
      expect(Directory('${tempDir.path}/files').listSync().whereType<File>().length, equals(1));
    });
  });
}
