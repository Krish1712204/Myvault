import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:myvault/core/backup/vault_backup_service.dart';
import 'package:myvault/core/database/vault_database.dart';
import 'package:myvault/core/security/device_clock.dart';
import 'package:myvault/core/security/vault_biometric_service.dart';
import 'package:myvault/core/security/vault_crypto_service.dart';
import 'package:myvault/core/security/vault_session.dart';
import 'package:myvault/core/security/vault_storage_service.dart';
import 'package:myvault/core/storage/encrypted_file_service.dart';
import 'package:myvault/features/auth/domain/vault_auth_notifier.dart';
import 'package:myvault/features/auth/domain/vault_auth_state.dart';
import 'package:myvault/features/vault/data/vault_models.dart';
import 'package:myvault/features/vault/data/vault_repository.dart';
import 'package:myvault/features/vault_items/data/vault_item_model.dart';
import 'package:myvault/shared/state/vault_state_provider.dart';
import 'package:myvault/shared/widgets/bold_text.dart';

class _NoBiometrics extends VaultBiometricService {
  @override
  Future<bool> canAuthenticate() async => false;
}

class _FakeDeviceClock extends DeviceClock {
  MonotonicTime value;
  _FakeDeviceClock(this.value);

  @override
  Future<MonotonicTime?> now() async => value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('VCF import parsing', () {
    test('a base64 photo ending in "=" padding does not swallow the next property', () {
      final photo = base64Encode(List<int>.generate(10, (i) => i + 1)); // ends with "=="
      final vcf = 'BEGIN:VCARD\nVERSION:3.0\nFN:Alice\nPHOTO;ENCODING=b;TYPE=JPEG:$photo\n'
          'TEL:+15551234\nEND:VCARD\n';

      final contacts = VaultItemsNotifier.parseVcfContacts(vcf);

      expect(contacts, hasLength(1));
      expect(contacts.single.fullName, 'Alice');
      expect(contacts.single.phoneNumber, '+15551234');
      expect(contacts.single.photoBytes, List<int>.generate(10, (i) => i + 1));
    });

    test('a folded vCard 2.1 photo followed by END:VCARD keeps the next card intact', () {
      final photo = base64Encode(List<int>.generate(60, (i) => i));
      final folded = '${photo.substring(0, 40)}\n  ${photo.substring(40)}';
      final vcf = 'BEGIN:VCARD\r\nVERSION:2.1\r\nFN:Bob\r\nTEL:+1222\r\n'
          'PHOTO;ENCODING=BASE64;JPEG:$folded\r\n\r\nEND:VCARD\r\n'
          'BEGIN:VCARD\r\nVERSION:2.1\r\nFN:Carol\r\nTEL:+1333\r\nEND:VCARD\r\n';

      final contacts = VaultItemsNotifier.parseVcfContacts(vcf);

      expect(contacts.map((c) => c.fullName), ['Bob', 'Carol']);
      expect(contacts.first.photoBytes, List<int>.generate(60, (i) => i));
      expect(contacts.last.phoneNumber, '+1333');
    });

    test('quoted-printable soft line breaks are joined and decoded', () {
      const vcf = 'BEGIN:VCARD\nVERSION:2.1\n'
          'FN;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:=4B=72=69=73=68=6E=61=20=\n'
          '=53=68=65=6C=61=72\nTEL:+9198\nEND:VCARD\n';

      final contacts = VaultItemsNotifier.parseVcfContacts(vcf);

      expect(contacts.single.fullName, 'Krishna Shelar');
    });

    test('ordinary values that contain "=12" are not treated as quoted-printable', () {
      const vcf = 'BEGIN:VCARD\nVERSION:3.0\nFN:Bldg A=12 Office\nTEL:+1\nEND:VCARD\n';

      expect(VaultItemsNotifier.parseVcfContacts(vcf).single.fullName, 'Bldg A=12 Office');
    });

    test('ORG is kept as the company, and a card missing END:VCARD does not swallow the next', () {
      const vcf = 'BEGIN:VCARD\nFN:Dana\nORG:Acme Corp;Sales\nTEL:+1\n'
          'BEGIN:VCARD\nFN:Eve\nTEL:+2\nEND:VCARD\n';

      final contacts = VaultItemsNotifier.parseVcfContacts(vcf);

      expect(contacts.map((c) => c.fullName), ['Dana', 'Eve']);
      expect(contacts.first.company, 'Acme Corp');
    });
  });

  group('Note previews', () {
    test('collapse whitespace without touching the letter "s"', () {
      expect(notePreview('classes **discuss**\n\n  less'), 'classes discuss less');
    });

    test('are truncated to 50 characters', () {
      expect(notePreview('x' * 60), '${'x' * 50}…');
    });

    test('previews stored garbled by older builds are recomputed from the content', () async {
      final dir = await Directory.systemTemp.createTemp('myvault_preview_test_');
      final crypto = VaultCryptoService();
      final db = VaultDatabase(customFactory: databaseFactoryFfi);
      await db.open(
        hexDatabaseKey: await crypto.deriveDatabaseKeyHex(crypto.generateVek()),
        customPath: '${dir.path}/vault.db',
      );
      final repo = VaultRepository(vaultDb: db, fileService: EncryptedFileService(customStoragePath: dir.path));

      await repo.insertItem(
        const VaultItem(id: 'note_1', title: 'T', subtitle: 'cla e  di cu', category: VaultCategory.notes),
        noteEntry: const NoteEntry(id: 'entry_note_1', itemId: 'note_1', content: 'classes discuss'),
      );

      expect((await repo.getItemById('note_1'))!.subtitle, 'classes discuss');
      await db.close();
      await dir.delete(recursive: true);
    });
  });

  group('Auto-lock exemption for apps we launch', () {
    late VaultDatabase vaultDb;
    late VaultAuthNotifier notifier;
    late DateTime now;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      vaultDb = VaultDatabase(customFactory: databaseFactoryFfi);
      now = DateTime(2026, 11, 19, 12);
      notifier = VaultAuthNotifier(
        cryptoService: VaultCryptoService(),
        storageService: VaultStorageService(storage: const FlutterSecureStorage()),
        biometricService: _NoBiometrics(),
        session: VaultSession(),
        vaultDb: vaultDb,
        clock: () => now,
      );
      await notifier.initialize();
      expect(await notifier.createVault('StrongVault#Pass1', 'StrongVault#Pass1'), isTrue);
    });

    tearDown(() async {
      notifier.dispose();
      await vaultDb.close();
    });

    test('expires if the launch never leaves the app (e.g. no viewer installed)', () async {
      notifier.allowExternalActivity();
      // Nothing opened; the user keeps using MyVault and only leaves later.
      now = now.add(VaultAuthNotifier.externalActivityGrant + const Duration(seconds: 1));

      await notifier.checkAutoLock(isBackgrounding: true);

      expect(notifier.state.status, VaultStatus.locked);
    });

    test('"hidden" then "paused" for one launch is exempted once', () async {
      notifier.allowExternalActivity();
      await notifier.checkAutoLock(isBackgrounding: true); // hidden
      await notifier.checkAutoLock(isBackgrounding: true); // paused
      expect(notifier.state.status, VaultStatus.unlocked);

      await notifier.checkAutoLock(); // resumed
      expect(notifier.state.status, VaultStatus.unlocked);
    });

    test('staying away in the launched app too long locks on return', () async {
      notifier.allowExternalActivity();
      await notifier.checkAutoLock(isBackgrounding: true);
      now = now.add(VaultAuthNotifier.minExternalActivityLimit + const Duration(minutes: 1));

      await notifier.checkAutoLock(); // resumed

      expect(notifier.state.status, VaultStatus.locked);
    });
  });

  group('Backups', () {
    late Directory dir;
    late VaultDatabase db;
    late EncryptedFileService files;
    late VaultBackupService backups;
    late Uint8List vek;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('myvault_backup_fix_test_');
      final crypto = VaultCryptoService();
      vek = Uint8List.fromList(crypto.generateVek());
      db = VaultDatabase(customFactory: databaseFactoryFfi);
      await db.open(hexDatabaseKey: await crypto.deriveDatabaseKeyHex(vek), customPath: '${dir.path}/vault.db');
      files = EncryptedFileService(customStoragePath: '${dir.path}/files');
      backups = VaultBackupService(vaultDb: db, fileService: files, cryptoService: crypto);

      final stored = await files.encryptAndSave(
        fileBytes: utf8.encode('scan'),
        originalFileName: 'passport.pdf',
        fileStorageKey: await crypto.deriveFileStorageKey(vek),
      );
      await VaultRepository(vaultDb: db, fileService: files).insertItem(
        const VaultItem(id: 'doc_1', title: 'Passport', subtitle: '', category: VaultCategory.documents),
        documentEntry: DocumentEntry(
          id: 'entry_doc_1',
          itemId: 'doc_1',
          filePath: stored.relativePath,
          fileName: 'passport.pdf',
          fileSize: 4,
          mimeType: 'application/pdf',
          fileExtension: '.pdf',
        ),
      );
      // The attachment goes missing on disk.
      await files.deleteEncryptedFile(stored.relativePath);
    });

    tearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });

    test('refuse to silently leave out unreadable attachments', () async {
      await expectLater(
        backups.createBackupBytes(passphrase: 'Backup#Pass1', vek: vek),
        throwsA(isA<BackupIncompleteException>()
            .having((e) => e.missingFiles, 'missingFiles', ['passport.pdf'])),
      );
    });

    test('can still be created without them when the user agrees', () async {
      final bytes = await backups.createBackupBytes(
        passphrase: 'Backup#Pass1',
        vek: vek,
        allowMissingAttachments: true,
      );
      final payload = await backups.decryptAndValidateBackup(fileBytes: bytes, passphrase: 'Backup#Pass1');
      expect(payload.vaultItems, hasLength(1));
      expect(payload.files, isEmpty);
    });
  });

  group('Low-priority fixes', () {
    late Directory dir;
    late VaultDatabase db;
    late EncryptedFileService files;
    late VaultRepository repo;
    late VaultCryptoService crypto;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('myvault_lowprio_test_');
      crypto = VaultCryptoService();
      db = VaultDatabase(customFactory: databaseFactoryFfi);
      await db.open(
        hexDatabaseKey: await crypto.deriveDatabaseKeyHex(crypto.generateVek()),
        customPath: '${dir.path}/vault.db',
      );
      files = EncryptedFileService(customStoragePath: '${dir.path}/files');
      repo = VaultRepository(vaultDb: db, fileService: files);
    });

    tearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });

    const note = VaultItem(id: 'note_a', title: 'A', subtitle: '', category: VaultCategory.notes);
    const noteEntry = NoteEntry(id: 'entry_note_a', itemId: 'note_a', content: 'original');

    test('favouriting does not change the last-modified time', () async {
      await repo.insertItem(note, noteEntry: noteEntry);
      final before = (await repo.getItemById('note_a'))!.updatedAt;
      await Future<void>.delayed(const Duration(milliseconds: 5));

      await repo.toggleFavourite('note_a');

      final after = (await repo.getItemById('note_a'))!;
      expect(after.isFavourite, isTrue);
      expect(after.updatedAt, before);
    });

    test('inserting a new item never overwrites an existing one with the same id', () async {
      await repo.insertItem(note, noteEntry: noteEntry);

      await expectLater(
        repo.insertItem(note.copyWith(title: 'Other'), noteEntry: noteEntry),
        throwsA(isA<DatabaseException>()),
      );
      expect((await repo.getItemById('note_a'))!.title, 'A');
    });

    test('getAllItems returns every category with its details', () async {
      await repo.insertItem(note, noteEntry: noteEntry);
      await repo.insertItem(
        const VaultItem(id: 'pwd_a', title: 'Mail', subtitle: '', category: VaultCategory.passwords),
        passwordEntry: const PasswordEntry(id: 'entry_pwd_a', itemId: 'pwd_a', encryptedPassword: 'S3cret!'),
      );
      final items = {for (final i in await repo.getAllItems()) i.id: i};
      expect(items['note_a']!.details, 'original');
      expect(items['pwd_a']!.password, 'S3cret!');
    });

    test('.docx files get the Word MIME type', () async {
      final stored = await files.encryptAndSave(
        fileBytes: [1, 2, 3],
        originalFileName: 'report.docx',
        fileStorageKey: List<int>.filled(32, 7),
      );
      expect(stored.mimeType, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
    });

    test('verifyMasterPassword honours the KDF settings stored with the vault', () async {
      const params = {'memory': 8192, 'iterations': 1, 'parallelism': 1};
      final derived = await crypto.deriveMasterKeyAndVerifier(password: 'Pass#word1', kdfParams: params);
      expect(
        await crypto.verifyMasterPassword(
          candidatePassword: 'Pass#word1',
          storedSalt: derived.saltBytes,
          storedVerifierHash: derived.verifierHashBytes,
          kdfParams: params,
        ),
        isTrue,
      );
    });

    test('a backup header that was edited is rejected', () async {
      final vek = Uint8List.fromList(crypto.generateVek());
      final backups = VaultBackupService(vaultDb: db, fileService: files, cryptoService: crypto);
      await repo.insertItem(note, noteEntry: noteEntry);
      final bytes = await backups.createBackupBytes(passphrase: 'Backup#Pass1', vek: vek);

      final text = latin1.decode(bytes);
      final tampered = Uint8List.fromList(latin1.encode(text.replaceFirst('"item_count":1', '"item_count":9')));
      expect(tampered, isNot(equals(bytes)));

      await expectLater(
        backups.decryptAndValidateBackup(fileBytes: tampered, passphrase: 'Backup#Pass1'),
        throwsA(isA<InvalidBackupPassphraseException>()),
      );
      // The untouched file still restores.
      final payload = await backups.decryptAndValidateBackup(fileBytes: bytes, passphrase: 'Backup#Pass1');
      expect(payload.vaultItems, hasLength(1));
    });
  });

  group('Vault lifecycle and lockout', () {
    late VaultDatabase vaultDb;
    late VaultStorageService storage;
    late DateTime now;
    late _FakeDeviceClock deviceClock;
    late VaultAuthNotifier notifier;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      storage = VaultStorageService(storage: const FlutterSecureStorage());
      vaultDb = VaultDatabase(customFactory: databaseFactoryFfi);
      now = DateTime(2026, 11, 19, 12);
      deviceClock = _FakeDeviceClock(const MonotonicTime(elapsedMs: 1000000, bootCount: 7));
      notifier = VaultAuthNotifier(
        cryptoService: VaultCryptoService(),
        storageService: storage,
        biometricService: _NoBiometrics(),
        session: VaultSession(),
        vaultDb: vaultDb,
        clock: () => now,
        deviceClock: deviceClock,
      );
      await notifier.initialize();
      expect(await notifier.createVault('StrongVault#Pass1', 'StrongVault#Pass1'), isTrue);
    });

    tearDown(() async {
      notifier.dispose();
      await vaultDb.close();
    });

    test('createVault refuses to replace an existing vault', () async {
      expect(await notifier.createVault('Another#Pass2', 'Another#Pass2'), isFalse);
      await notifier.lockVault();
      expect(await notifier.unlockWithPassword('StrongVault#Pass1'), isTrue);
    });

    test('erasing the vault (forgot password) allows creating a new one', () async {
      await notifier.lockVault();
      await notifier.eraseVault();

      expect(notifier.state.status, VaultStatus.uninitialized);
      expect(await storage.hasVault(), isFalse);
      expect(await notifier.createVault('Fresh#Vault3', 'Fresh#Vault3'), isTrue);
      expect(notifier.state.status, VaultStatus.unlocked);
    });

    test('moving the phone clock forward does not end the wrong-password delay', () async {
      await notifier.lockVault();
      for (var i = 0; i < VaultAuthNotifier.freeUnlockAttempts; i++) {
        await notifier.unlockWithPassword('Wrong#Pass$i');
      }

      now = now.add(const Duration(hours: 2)); // the user changes the date/time in Settings
      expect(await notifier.unlockWithPassword('StrongVault#Pass1'), isFalse);
      expect(notifier.state.errorMessage, contains('Too many failed attempts'));

      // Real time passes on the monotonic clock: the delay ends.
      deviceClock.value = const MonotonicTime(elapsedMs: 1000000 + 31000, bootCount: 7);
      expect(await notifier.unlockWithPassword('StrongVault#Pass1'), isTrue);
    });
  });
}
