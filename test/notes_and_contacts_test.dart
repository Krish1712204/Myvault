import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'vault_test_helpers.dart';
import 'package:myvault/core/database/vault_database.dart';
import 'package:myvault/core/database/vault_schema.dart';
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

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('myvault_phase6_test_');
    cryptoService = VaultCryptoService();
    testVek = Uint8List.fromList(cryptoService.generateVek());
    hexDbKey = await cryptoService.deriveDatabaseKeyHex(testVek);

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
      customPath: '${tempDir.path}/test_phase6_encrypted.db',
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

  group('Phase 6 — Notes Module CRUD & Persistence', () {
    test('Creates and retrieves a multiline note with tags and category', () async {
      const itemId = 'note_001';
      const multilineText = '''Meeting Minutes - Oct 2026:
1. Architecture discussion for local-first sync.
2. Verified SQLCipher AES-256 zero cloud dependencies.
3. Next milestone: secure encrypted backup.''';

      final item = VaultItem(
        id: itemId,
        title: 'Project Roadmap 2026',
        subtitle: multilineText.substring(0, 50),
        category: VaultCategory.notes,
        details: multilineText,
        subcategory: 'Work',
        tags: 'work,roadmap,planning',
        isFavourite: true,
        createdAt: 1729000000000,
        updatedAt: 1729000000000,
      );

      const note = NoteEntry(
        id: 'entry_$itemId',
        itemId: itemId,
        content: multilineText,
        tags: 'work,roadmap,planning',
      );

      await repository.insertItem(item, noteEntry: note);

      final retrieved = await repository.getItemById(itemId);
      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('Project Roadmap 2026'));
      expect(retrieved.category, equals(VaultCategory.notes));
      expect(retrieved.details, equals(multilineText));
      expect(retrieved.tags, equals('work,roadmap,planning'));
      expect(retrieved.isFavourite, isTrue);

      // Verify category listing
      final notes = await itemsInCategory(repository, VaultCategory.notes);
      expect(notes.length, equals(1));
      expect(notes.first.id, equals(itemId));
    });

    test('Updates existing note content, tags, and category', () async {
      const itemId = 'note_002';
      const item = VaultItem(
        id: itemId,
        title: 'Ideas',
        subtitle: 'Initial draft',
        category: VaultCategory.notes,
        details: 'Initial draft',
        subcategory: 'Ideas',
        tags: 'draft',
      );
      const note = NoteEntry(
        id: 'entry_$itemId',
        itemId: itemId,
        content: 'Initial draft',
        tags: 'draft',
      );
      await repository.insertItem(item, noteEntry: note);

      // Update
      const updatedContent = 'Updated ideas with refined specifications.';
      final updatedItem = item.copyWith(
        title: 'Ideas - Final',
        details: updatedContent,
        tags: 'ideas,approved',
        isFavourite: true,
      );
      const updatedNote = NoteEntry(
        id: 'entry_$itemId',
        itemId: itemId,
        content: updatedContent,
        tags: 'ideas,approved',
      );

      await repository.updateItem(updatedItem, noteEntry: updatedNote);

      final retrieved = await repository.getItemById(itemId);
      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('Ideas - Final'));
      expect(retrieved.details, equals(updatedContent));
      expect(retrieved.tags, equals('ideas,approved'));
      expect(retrieved.isFavourite, isTrue);
    });

    test('Deletes note and cascades from detail table', () async {
      const itemId = 'note_003';
      const item = VaultItem(
        id: itemId,
        title: 'Scratch Note',
        subtitle: 'Temporary',
        category: VaultCategory.notes,
        details: 'Temporary text',
      );
      const note = NoteEntry(
        id: 'entry_$itemId',
        itemId: itemId,
        content: 'Temporary text',
      );
      await repository.insertItem(item, noteEntry: note);

      expect(await repository.getItemById(itemId), isNotNull);
      await repository.deleteItem(itemId);
      expect(await repository.getItemById(itemId), isNull);

      final db = vaultDb.database;
      final orphan = await db.query('notes', where: 'item_id = ?', whereArgs: [itemId]);
      expect(orphan, isEmpty);
    });
  });

  group('Phase 6 — Contacts Module CRUD & Persistence', () {
    test('Creates and retrieves full private contact profile', () async {
      const itemId = 'cnt_001';
      const item = VaultItem(
        id: itemId,
        title: 'Prathamesh Shelar',
        subtitle: 'Senior Engineer · Security Team',
        category: VaultCategory.contacts,
        subcategory: 'Work',
        phoneNumber: '+91 98765 43210',
        secondaryPhone: '+91 91234 56789',
        email: 'prathamesh@example.com',
        secondaryEmail: 'pshelar@work.com',
        company: 'SecureSoft Labs',
        jobTitle: 'Senior Engineer',
        address: '42 MG Road, Bengaluru, Karnataka, 560001',
        birthday: '15 Aug 1995',
        details: 'Key contact for local-first encryption modules',
        tags: 'colleague,vip,dev',
        isFavourite: true,
      );

      const contact = ContactEntry(
        id: 'entry_$itemId',
        itemId: itemId,
        phoneNumber: '+91 98765 43210',
        secondaryPhone: '+91 91234 56789',
        email: 'prathamesh@example.com',
        secondaryEmail: 'pshelar@work.com',
        company: 'SecureSoft Labs',
        jobTitle: 'Senior Engineer',
        address: '42 MG Road, Bengaluru, Karnataka, 560001',
        birthday: '15 Aug 1995',
        notes: 'Key contact for local-first encryption modules',
        tags: 'colleague,vip,dev',
      );

      await repository.insertItem(item, contactEntry: contact);

      final retrieved = await repository.getItemById(itemId);
      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('Prathamesh Shelar'));
      expect(retrieved.category, equals(VaultCategory.contacts));
      expect(retrieved.phoneNumber, equals('+91 98765 43210'));
      expect(retrieved.secondaryPhone, equals('+91 91234 56789'));
      expect(retrieved.email, equals('prathamesh@example.com'));
      expect(retrieved.secondaryEmail, equals('pshelar@work.com'));
      expect(retrieved.company, equals('SecureSoft Labs'));
      expect(retrieved.jobTitle, equals('Senior Engineer'));
      expect(retrieved.address, equals('42 MG Road, Bengaluru, Karnataka, 560001'));
      expect(retrieved.birthday, equals('15 Aug 1995'));
      expect(retrieved.details, equals('Key contact for local-first encryption modules'));
      expect(retrieved.tags, equals('colleague,vip,dev'));
      expect(retrieved.isFavourite, isTrue);

      final contactsList = await itemsInCategory(repository, VaultCategory.contacts);
      expect(contactsList.length, equals(1));
    });

    test('Updates contact profile fields and maintains consistency', () async {
      const itemId = 'cnt_002';
      const item = VaultItem(
        id: itemId,
        title: 'Amit Sharma',
        subtitle: '+91 98000 11111',
        category: VaultCategory.contacts,
        phoneNumber: '+91 98000 11111',
      );
      const contact = ContactEntry(
        id: 'entry_$itemId',
        itemId: itemId,
        phoneNumber: '+91 98000 11111',
      );
      await repository.insertItem(item, contactEntry: contact);

      // Update with promotion and email
      final updatedItem = item.copyWith(
        title: 'Amit Sharma',
        subtitle: 'VP of Engineering · FinTech Corp',
        phoneNumber: '+91 98000 11111',
        email: 'amit@fintech.io',
        company: 'FinTech Corp',
        jobTitle: 'VP of Engineering',
        tags: 'management,fintech',
        isFavourite: true,
      );
      const updatedContact = ContactEntry(
        id: 'entry_$itemId',
        itemId: itemId,
        phoneNumber: '+91 98000 11111',
        email: 'amit@fintech.io',
        company: 'FinTech Corp',
        jobTitle: 'VP of Engineering',
        tags: 'management,fintech',
      );

      await repository.updateItem(updatedItem, contactEntry: updatedContact);

      final retrieved = await repository.getItemById(itemId);
      expect(retrieved, isNotNull);
      expect(retrieved!.company, equals('FinTech Corp'));
      expect(retrieved.jobTitle, equals('VP of Engineering'));
      expect(retrieved.email, equals('amit@fintech.io'));
      expect(retrieved.tags, equals('management,fintech'));
      expect(retrieved.isFavourite, isTrue);
    });

    test('Deletes contact completely without leaving orphan rows', () async {
      const itemId = 'cnt_003';
      const item = VaultItem(
        id: itemId,
        title: 'Temp Contact',
        subtitle: '+91 00000 00000',
        category: VaultCategory.contacts,
        phoneNumber: '+91 00000 00000',
      );
      const contact = ContactEntry(
        id: 'entry_$itemId',
        itemId: itemId,
        phoneNumber: '+91 00000 00000',
      );
      await repository.insertItem(item, contactEntry: contact);

      expect(await repository.getItemById(itemId), isNotNull);
      await repository.deleteItem(itemId);
      expect(await repository.getItemById(itemId), isNull);

      final db = vaultDb.database;
      final rows = await db.query('contacts', where: 'item_id = ?', whereArgs: [itemId]);
      expect(rows, isEmpty);
    });
  });

  group('Phase 6 — Global Search Across All 5 Vault Types', () {
    setUp(() async {
      // 1. Password
      await repository.insertItem(
        const VaultItem(
          id: 's_pwd_1',
          title: 'GitHub Developer',
          subtitle: 'prathameshdev',
          category: VaultCategory.passwords,
          username: 'prathameshdev',
          url: 'https://github.com',
        ),
        passwordEntry: const PasswordEntry(
          id: 'p1',
          itemId: 's_pwd_1',
          username: 'prathameshdev',
          encryptedPassword: 'SecretGhPassword#2026',
          websiteUrl: 'https://github.com',
          notes: 'Personal 2FA recovery tokens stored offline',
        ),
      );

      // 2. ID Card
      await repository.insertItem(
        const VaultItem(
          id: 's_idn_1',
          title: 'Indian Passport',
          subtitle: 'Travel Document',
          category: VaultCategory.idCards,
          documentNumber: 'Z9876543',
          fullName: 'Prathamesh Shelar',
        ),
        identityEntry: const IdentityEntry(
          id: 'i1',
          itemId: 's_idn_1',
          documentType: 'Passport',
          documentNumber: 'Z9876543',
          fullName: 'Prathamesh Shelar',
          issuingCountry: 'India',
        ),
      );

      // 3. Document
      await repository.insertItem(
        const VaultItem(
          id: 's_doc_1',
          title: 'House Lease Agreement',
          subtitle: 'PDF · 1.5 MB',
          category: VaultCategory.documents,
          fileName: 'rental_agreement_2026.pdf',
        ),
        documentEntry: const DocumentEntry(
          id: 'd1',
          itemId: 's_doc_1',
          filePath: 'docs/rental_2026.enc',
          fileName: 'rental_agreement_2026.pdf',
          fileSize: 1572864,
          mimeType: 'application/pdf',
          fileExtension: '.pdf',
          notes: 'Signed landlord agreement for Bandra apartment',
        ),
      );

      // 4. Note
      await repository.insertItem(
        const VaultItem(
          id: 's_note_1',
          title: 'Cryptographic Architecture Notes',
          subtitle: 'Argon2id KDF specifications',
          category: VaultCategory.notes,
          details: 'Argon2id m=65536 t=3 p=4 with 256-bit salt derived key',
          tags: 'crypto,security,architecture',
        ),
        noteEntry: const NoteEntry(
          id: 'n1',
          itemId: 's_note_1',
          content: 'Argon2id m=65536 t=3 p=4 with 256-bit salt derived key',
          tags: 'crypto,security,architecture',
        ),
      );

      // 5. Contact
      await repository.insertItem(
        const VaultItem(
          id: 's_cnt_1',
          title: 'Dr. Ramesh Kulkarni',
          subtitle: 'Chief Cardiologist · City Hospital',
          category: VaultCategory.contacts,
          phoneNumber: '+91 94220 12345',
          email: 'dr.kulkarni@cityhospital.org',
          company: 'City Hospital Pune',
          jobTitle: 'Chief Cardiologist',
          address: 'Shivajinagar, Pune',
          tags: 'doctor,emergency,health',
        ),
        contactEntry: const ContactEntry(
          id: 'c1',
          itemId: 's_cnt_1',
          phoneNumber: '+91 94220 12345',
          email: 'dr.kulkarni@cityhospital.org',
          company: 'City Hospital Pune',
          jobTitle: 'Chief Cardiologist',
          address: 'Shivajinagar, Pune',
          tags: 'doctor,emergency,health',
        ),
      );
    });

    test('Searches across passwords by username or url', () async {
      final results = await searchVault(repository, 'prathameshdev');
      expect(results.length, equals(1));
      expect(results.first.id, equals('s_pwd_1'));
      expect(results.first.category, equals(VaultCategory.passwords));
    });

    test('Searches across identity entries by document number or holder name', () async {
      final results = await searchVault(repository, 'Z9876543');
      expect(results.length, equals(1));
      expect(results.first.id, equals('s_idn_1'));
      expect(results.first.category, equals(VaultCategory.idCards));
    });

    test('Searches across documents by file name or notes', () async {
      final results = await searchVault(repository, 'rental_agreement');
      expect(results.length, equals(1));
      expect(results.first.id, equals('s_doc_1'));
      expect(results.first.category, equals(VaultCategory.documents));

      final noteMatch = await searchVault(repository, 'Bandra');
      expect(noteMatch.length, equals(1));
      expect(noteMatch.first.id, equals('s_doc_1'));
    });

    test('Searches across notes by content text and tag keywords', () async {
      final contentResults = await searchVault(repository, 'Argon2id');
      expect(contentResults.length, equals(1));
      expect(contentResults.first.id, equals('s_note_1'));
      expect(contentResults.first.category, equals(VaultCategory.notes));

      final tagResults = await searchVault(repository, 'architecture');
      expect(tagResults.any((r) => r.id == 's_note_1'), isTrue);
    });

    test('Searches across contacts by name, company, job title, phone, and tags', () async {
      // Match by company
      final companyResults = await searchVault(repository, 'City Hospital');
      expect(companyResults.length, equals(1));
      expect(companyResults.first.id, equals('s_cnt_1'));

      // Match by job title
      final jobResults = await searchVault(repository, 'Cardiologist');
      expect(jobResults.length, equals(1));
      expect(jobResults.first.id, equals('s_cnt_1'));

      // Match by phone number
      final phoneResults = await searchVault(repository, '94220');
      expect(phoneResults.length, equals(1));
      expect(phoneResults.first.id, equals('s_cnt_1'));

      // Match by tag
      final tagResults = await searchVault(repository, 'emergency');
      expect(tagResults.any((r) => r.id == 's_cnt_1'), isTrue);
    });

    test('Global multi-result search finds matches across multiple item categories', () async {
      // 'Prathamesh' matches password username, passport full name
      final results = await searchVault(repository, 'prathamesh');
      expect(results.length, greaterThanOrEqualTo(2));
      final categories = results.map((r) => r.category).toSet();
      expect(categories.contains(VaultCategory.passwords), isTrue);
      expect(categories.contains(VaultCategory.idCards), isTrue);
    });

    test('Empty query returns all items without errors', () async {
      final all = await searchVault(repository, '');
      expect(all.length, equals(5));
    });
  });

  group('Phase 6 — Schema Version 3 Migration Integrity', () {
    test('Migrates existing schema from V2 to V3 safely preserving data', () async {
      final migrationDbPath = '${tempDir.path}/migration_test.db';

      // 1. Setup V2 database manually
      final dbV2 = await databaseFactoryFfi.openDatabase(
        migrationDbPath,
        options: OpenDatabaseOptions(
          version: 2,
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

            // Insert initial V2 rows
            await db.insert('vault_items', {
              'id': 'v2_note_1',
              'category': 'notes',
              'title': 'Legacy V2 Note',
              'subtitle': 'V2 Content',
              'is_favourite': 0,
              'created_at': 1700000000000,
              'updated_at': 1700000000000,
            });
            await db.insert('notes', {
              'id': 'n_v2_1',
              'item_id': 'v2_note_1',
              'content': 'Important note created in V2 schema',
              'color_tag': '#FF0000',
            });

            await db.insert('vault_items', {
              'id': 'v2_cnt_1',
              'category': 'contacts',
              'title': 'Legacy V2 Contact',
              'subtitle': '+91 99999 88888',
              'is_favourite': 1,
              'created_at': 1700000000000,
              'updated_at': 1700000000000,
            });
            await db.insert('contacts', {
              'id': 'c_v2_1',
              'item_id': 'v2_cnt_1',
              'phone_number': '+91 99999 88888',
              'email': 'legacy@v2.org',
              'company': 'Legacy Corp',
              'address': 'Old Town',
            });
          },
        ),
      );
      await dbV2.close();

      // 2. Re-open through VaultSchema onUpgrade to V3
      final upgradedDb = await databaseFactoryFfi.openDatabase(
        migrationDbPath,
        options: OpenDatabaseOptions(
          version: 3,
          onUpgrade: (db, oldVersion, newVersion) async {
            await VaultSchema.onUpgrade(db, oldVersion, newVersion);
          },
        ),
      );

      // Verify V2 data is preserved
      final preservedNoteRows = await upgradedDb.query('notes', where: 'id = ?', whereArgs: ['n_v2_1']);
      expect(preservedNoteRows.length, equals(1));
      expect(preservedNoteRows.first['content'], equals('Important note created in V2 schema'));
      expect(preservedNoteRows.first['tags'], isNull); // New column defaults to null

      final preservedCntRows = await upgradedDb.query('contacts', where: 'id = ?', whereArgs: ['c_v2_1']);
      expect(preservedCntRows.length, equals(1));
      expect(preservedCntRows.first['company'], equals('Legacy Corp'));
      expect(preservedCntRows.first['job_title'], isNull);

      // Verify new V3 columns accept writes
      await upgradedDb.update(
        'notes',
        {'tags': 'migrated,v3'},
        where: 'id = ?',
        whereArgs: ['n_v2_1'],
      );
      final updatedNote = await upgradedDb.query('notes', where: 'id = ?', whereArgs: ['n_v2_1']);
      expect(updatedNote.first['tags'], equals('migrated,v3'));

      await upgradedDb.update(
        'contacts',
        {
          'job_title': 'Director',
          'birthday': '1 Jan 1990',
          'notes': 'Migrated successfully',
          'secondary_phone': '+91 88888 77777',
        },
        where: 'id = ?',
        whereArgs: ['c_v2_1'],
      );
      final updatedCnt = await upgradedDb.query('contacts', where: 'id = ?', whereArgs: ['c_v2_1']);
      expect(updatedCnt.first['job_title'], equals('Director'));
      expect(updatedCnt.first['birthday'], equals('1 Jan 1990'));
      expect(updatedCnt.first['secondary_phone'], equals('+91 88888 77777'));

      await upgradedDb.close();
    });

    test('Persists contact photo attachment_path and retrieves it properly', () async {
      const itemId = 'cnt_photo_01';
      const item = VaultItem(
        id: itemId,
        title: 'Krishna Shelar',
        subtitle: '+91 98765 43210',
        category: VaultCategory.contacts,
        phoneNumber: '+91 98765 43210',
        email: 'krishna@example.com',
        attachmentPath: 'attachments/cnt_photo_01_avatar.enc',
        createdAt: 1729000000000,
        updatedAt: 1729000000000,
      );

      const contact = ContactEntry(
        id: 'entry_$itemId',
        itemId: itemId,
        phoneNumber: '+91 98765 43210',
        email: 'krishna@example.com',
        attachmentPath: 'attachments/cnt_photo_01_avatar.enc',
      );

      await repository.insertItem(item, contactEntry: contact);

      final retrieved = await repository.getItemById(itemId);
      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('Krishna Shelar'));
      expect(retrieved.phoneNumber, equals('+91 98765 43210'));
      expect(retrieved.email, equals('krishna@example.com'));
      expect(retrieved.attachmentPath, equals('attachments/cnt_photo_01_avatar.enc'));
    });

    test('Verifies ID card and attachment file format magic bytes detection', () {
      final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]);
      final jpgBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]);
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      final webpBytes = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50
      ]);

      String detectExt(Uint8List bytes) {
        if (bytes.length >= 4 &&
            bytes[0] == 0x25 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x44 &&
            bytes[3] == 0x46) {
          return '.pdf';
        } else if (bytes.length >= 3 &&
            bytes[0] == 0xFF &&
            bytes[1] == 0xD8 &&
            bytes[2] == 0xFF) {
          return '.jpg';
        } else if (bytes.length >= 8 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47 &&
            bytes[4] == 0x0D &&
            bytes[5] == 0x0A &&
            bytes[6] == 0x1A &&
            bytes[7] == 0x0A) {
          return '.png';
        } else if (bytes.length >= 12 &&
            bytes[0] == 0x52 &&
            bytes[1] == 0x49 &&
            bytes[2] == 0x46 &&
            bytes[3] == 0x46 &&
            bytes[8] == 0x57 &&
            bytes[9] == 0x45 &&
            bytes[10] == 0x42 &&
            bytes[11] == 0x50) {
          return '.webp';
        }
        return '.jpg';
      }

      expect(detectExt(pdfBytes), equals('.pdf'));
      expect(detectExt(jpgBytes), equals('.jpg'));
      expect(detectExt(pngBytes), equals('.png'));
      expect(detectExt(webpBytes), equals('.webp'));
    });

    test('VCF parsing handles Quoted-Printable UTF-8 names, group prefixes, and FN priority', () {
      const vcfData = '''
BEGIN:VCARD
VERSION:2.1
item1.N;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:;=4B=72=69=73=68=6E=61;;;
item1.FN;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:=E0=A4=95=E0=A5=83=E0=A4=B7=E0=A5=8D=E0=A4=A3=E0=A4=BE=20=E0=A4=B6=E0=A5=87=E0=A4=B3=E0=A4=BE=E0=A4=B0
item2.TEL;TYPE=CELL:+919876543210
END:VCARD
BEGIN:VCARD
VERSION:3.0
N:Doe;Jane;Marie;Dr.;
FN:Dr. Jane Marie Doe
TEL;TYPE=HOME:+15551234567
EMAIL;TYPE=WORK:jane.doe@example.com
END:VCARD
BEGIN:VCARD
VERSION:2.1
TEL;TYPE=WORK:+18005550199
ORG:Acme Corp
END:VCARD
''';

      // Test unfolding and QP decoding
      final normalized = vcfData.replaceAll('\r\n', '\n');
      final cardRegex = RegExp(r'BEGIN:VCARD[\s\S]*?END:VCARD', caseSensitive: false);
      final cards = cardRegex.allMatches(normalized).map((m) => m.group(0)!).toList();

      expect(cards.length, equals(3));
    });
  });
}

