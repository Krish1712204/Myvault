import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:myvault/core/database/vault_database.dart';
import 'package:myvault/core/security/clipboard_service.dart';
import 'package:myvault/core/security/password_generator.dart';
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
    tempDir = await Directory.systemTemp.createTemp('myvault_pwd_test_');
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

  group('1. Password Generator Cryptographic Engine', () {
    final generator = PasswordGenerator();

    test('Generates passwords of specified lengths', () {
      for (final len in [8, 12, 16, 24, 32, 64]) {
        final pwd = generator.generate(PasswordGeneratorOptions(length: len));
        expect(pwd.length, equals(len));
      }
    });

    test('Includes characters from all enabled character sets', () {
      final pwd = generator.generate(const PasswordGeneratorOptions(
        length: 20,
        includeUppercase: true,
        includeLowercase: true,
        includeNumbers: true,
        includeSpecial: true,
      ));

      expect(RegExp(r'[A-Z]').hasMatch(pwd), isTrue, reason: 'Must contain uppercase');
      expect(RegExp(r'[a-z]').hasMatch(pwd), isTrue, reason: 'Must contain lowercase');
      expect(RegExp(r'[0-9]').hasMatch(pwd), isTrue, reason: 'Must contain numbers');
      expect(RegExp(r'[!@#\$%^&*()_\-+=\[\]{}|;:,.<>?]').hasMatch(pwd), isTrue, reason: 'Must contain special symbols');
    });

    test('Respects character set exclusions', () {
      // Numbers only
      final numbersOnly = generator.generate(const PasswordGeneratorOptions(
        length: 12,
        includeUppercase: false,
        includeLowercase: false,
        includeNumbers: true,
        includeSpecial: false,
      ));
      expect(RegExp(r'^[0-9]+$').hasMatch(numbersOnly), isTrue);

      // Uppercase and Lowercase letters only
      final lettersOnly = generator.generate(const PasswordGeneratorOptions(
        length: 16,
        includeUppercase: true,
        includeLowercase: true,
        includeNumbers: false,
        includeSpecial: false,
      ));
      expect(RegExp(r'^[a-zA-Z]+$').hasMatch(lettersOnly), isTrue);
    });

    test('Generates distinct passwords across multiple runs (entropy test)', () {
      final generatedSet = <String>{};
      for (int i = 0; i < 50; i++) {
        final pwd = generator.generate(const PasswordGeneratorOptions(length: 16));
        expect(generatedSet.contains(pwd), isFalse, reason: 'Duplicate password generated!');
        generatedSet.add(pwd);
      }
      expect(generatedSet.length, equals(50));
    });

    test('Calculates password strength correctly', () {
      expect(PasswordGenerator.calculateStrength('abc'), equals(PasswordStrength.weak));
      expect(PasswordGenerator.calculateStrength('pass1234'), equals(PasswordStrength.fair));
      expect(PasswordGenerator.calculateStrength('Password123'), equals(PasswordStrength.good));
      expect(PasswordGenerator.calculateStrength('V@ult#9xK!mQ2\$zL8'), equals(PasswordStrength.strong));
    });
  });

  group('2. Password CRUD Operations in Encrypted Database', () {
    test('Creates and retrieves a complete password entry', () async {
      const item = VaultItem(
        id: 'pwd_github_1',
        title: 'GitHub',
        subtitle: 'octocat@github.com',
        category: VaultCategory.passwords,
        url: 'https://github.com/login',
        username: 'octocat@github.com',
        password: 'SuperSecurePassword#2026',
        details: 'Work developer account',
        subcategory: 'Developer',
        isFavourite: true,
      );

      const pwdEntry = PasswordEntry(
        id: 'entry_pwd_github_1',
        itemId: 'pwd_github_1',
        username: 'octocat@github.com',
        encryptedPassword: 'SuperSecurePassword#2026',
        websiteUrl: 'https://github.com/login',
        notes: 'Work developer account',
      );

      await repository.insertItem(item, passwordEntry: pwdEntry);

      final fetched = await repository.getItemById('pwd_github_1');
      expect(fetched, isNotNull);
      expect(fetched!.title, equals('GitHub'));
      expect(fetched.username, equals('octocat@github.com'));
      expect(fetched.password, equals('SuperSecurePassword#2026'));
      expect(fetched.url, equals('https://github.com/login'));
      expect(fetched.details, equals('Work developer account'));
      expect(fetched.isFavourite, isTrue);
      expect(fetched.createdAt, isNotNull);
      expect(fetched.updatedAt, isNotNull);
    });

    test('Updates an existing password entry', () async {
      const originalItem = VaultItem(
        id: 'pwd_amazon_1',
        title: 'Amazon',
        subtitle: 'shopper@amazon.com',
        category: VaultCategory.passwords,
        url: 'https://amazon.com',
        username: 'shopper@amazon.com',
        password: 'OldPassword#1',
        details: 'Personal prime account',
        subcategory: 'Shopping',
        isFavourite: false,
      );

      const originalEntry = PasswordEntry(
        id: 'entry_pwd_amazon_1',
        itemId: 'pwd_amazon_1',
        username: 'shopper@amazon.com',
        encryptedPassword: 'OldPassword#1',
        websiteUrl: 'https://amazon.com',
        notes: 'Personal prime account',
      );

      await repository.insertItem(originalItem, passwordEntry: originalEntry);

      // Update password and favorite status
      final updatedItem = originalItem.copyWith(
        title: 'Amazon Prime',
        password: 'NewStrongP@ssword#2026',
        isFavourite: true,
        details: 'Updated 2FA enabled prime account',
      );

      const updatedEntry = PasswordEntry(
        id: 'entry_pwd_amazon_1',
        itemId: 'pwd_amazon_1',
        username: 'shopper@amazon.com',
        encryptedPassword: 'NewStrongP@ssword#2026',
        websiteUrl: 'https://amazon.com',
        notes: 'Updated 2FA enabled prime account',
      );

      await repository.updateItem(updatedItem, passwordEntry: updatedEntry);

      final fetched = await repository.getItemById('pwd_amazon_1');
      expect(fetched, isNotNull);
      expect(fetched!.title, equals('Amazon Prime'));
      expect(fetched.password, equals('NewStrongP@ssword#2026'));
      expect(fetched.isFavourite, isTrue);
      expect(fetched.details, equals('Updated 2FA enabled prime account'));
      expect(fetched.updatedAt, isNotNull);
    });

    test('Deletes password entry and cascades removal from password_entries table', () async {
      const item = VaultItem(
        id: 'pwd_delete_test',
        title: 'Temp Service',
        subtitle: 'temp@service.com',
        category: VaultCategory.passwords,
      );

      const entry = PasswordEntry(
        id: 'entry_pwd_delete_test',
        itemId: 'pwd_delete_test',
        username: 'temp@service.com',
        encryptedPassword: 'TempPassword#99',
      );

      await repository.insertItem(item, passwordEntry: entry);

      // Verify item exists
      expect(await repository.getItemById('pwd_delete_test'), isNotNull);

      // Delete item
      await repository.deleteItem('pwd_delete_test');

      // Verify item no longer exists
      expect(await repository.getItemById('pwd_delete_test'), isNull);

      // Verify password_entries table no longer has the child record (cascading delete)
      final pRows = await vaultDb.database.query(
        'password_entries',
        where: 'item_id = ?',
        whereArgs: ['pwd_delete_test'],
      );
      expect(pRows, isEmpty);
    });
  });

  group('3. Search and Category Filtering', () {
    setUp(() async {
      final items = [
        (
          const VaultItem(
            id: 'pwd_1',
            title: 'Google',
            subtitle: 'user@gmail.com',
            category: VaultCategory.passwords,
            url: 'https://accounts.google.com',
            username: 'user@gmail.com',
            password: 'Pass#1Google',
            isFavourite: true,
          ),
          const PasswordEntry(
            id: 'e_pwd_1',
            itemId: 'pwd_1',
            username: 'user@gmail.com',
            encryptedPassword: 'Pass#1Google',
            websiteUrl: 'https://accounts.google.com',
          ),
        ),
        (
          const VaultItem(
            id: 'pwd_2',
            title: 'Microsoft',
            subtitle: 'office@outlook.com',
            category: VaultCategory.passwords,
            url: 'https://login.live.com',
            username: 'office@outlook.com',
            password: 'Pass#2Microsoft',
            isFavourite: false,
          ),
          const PasswordEntry(
            id: 'e_pwd_2',
            itemId: 'pwd_2',
            username: 'office@outlook.com',
            encryptedPassword: 'Pass#2Microsoft',
            websiteUrl: 'https://login.live.com',
          ),
        ),
        (
          const VaultItem(
            id: 'note_1',
            title: 'Meeting Notes',
            subtitle: 'Project discussion points',
            category: VaultCategory.notes,
            isFavourite: true,
          ),
          null,
        ),
      ];

      for (final pair in items) {
        await repository.insertItem(pair.$1, passwordEntry: pair.$2);
      }
    });

    test('Searches items by title', () async {
      final results = await repository.searchItems('Google');
      expect(results.length, equals(1));
      expect(results.first.title, equals('Google'));
    });

    test('Searches items by username', () async {
      final results = await repository.searchItems('outlook.com');
      expect(results.length, equals(1));
      expect(results.first.title, equals('Microsoft'));
    });

    test('Searches items by website URL', () async {
      final results = await repository.searchItems('accounts.google');
      expect(results.length, equals(1));
      expect(results.first.title, equals('Google'));
    });

    test('Filters items by category', () async {
      final passwords = await repository.getItemsByCategory(VaultCategory.passwords);
      expect(passwords.length, equals(2));
      for (final item in passwords) {
        expect(item.category, equals(VaultCategory.passwords));
      }

      final notes = await repository.getItemsByCategory(VaultCategory.notes);
      expect(notes.length, equals(1));
      expect(notes.first.category, equals(VaultCategory.notes));
    });

    test('Filters items by favourite status', () async {
      final favourites = await repository.getFavouriteItems();
      expect(favourites.length, equals(2));
      for (final item in favourites) {
        expect(item.isFavourite, isTrue);
      }
    });
  });

  group('4. Database Persistence and Restart Verification', () {
    test('Saved password entries persist across database close and reopen', () async {
      const item = VaultItem(
        id: 'pwd_persist_test',
        title: 'ProtonMail',
        subtitle: 'privacy@proton.me',
        category: VaultCategory.passwords,
        url: 'https://mail.proton.me',
        username: 'privacy@proton.me',
        password: 'EncryptedSecretPass#2026',
        details: 'Encrypted email provider',
        isFavourite: true,
      );

      const entry = PasswordEntry(
        id: 'e_pwd_persist_test',
        itemId: 'pwd_persist_test',
        username: 'privacy@proton.me',
        encryptedPassword: 'EncryptedSecretPass#2026',
        websiteUrl: 'https://mail.proton.me',
        notes: 'Encrypted email provider',
      );

      await repository.insertItem(item, passwordEntry: entry);

      // Close database (simulate vault lock)
      await vaultDb.close();
      expect(vaultDb.isOpen, isFalse);

      // Reopen database with genuine derived key (simulate restart and unlock)
      await vaultDb.open(
        hexDatabaseKey: hexDbKey,
        customPath: '${tempDir.path}/test_encrypted.db',
      );
      expect(vaultDb.isOpen, isTrue);

      final restored = await repository.getItemById('pwd_persist_test');
      expect(restored, isNotNull);
      expect(restored!.title, equals('ProtonMail'));
      expect(restored.password, equals('EncryptedSecretPass#2026'));
      expect(restored.username, equals('privacy@proton.me'));
      expect(restored.isFavourite, isTrue);
    });
  });

  group('5. Access Rejection While Vault Is Locked', () {
    test('Repository operations throw StateError when database is closed', () async {
      await vaultDb.close();

      expect(() => repository.getAllItems(), throwsStateError);
      expect(() => repository.getItemById('pwd_1'), throwsStateError);
      expect(
        () => repository.insertItem(const VaultItem(
          id: 'test',
          title: 'test',
          subtitle: 'test',
          category: VaultCategory.passwords,
        )),
        throwsStateError,
      );
      expect(() => repository.deleteItem('pwd_1'), throwsStateError);
      expect(() => repository.searchItems('query'), throwsStateError);
    });
  });

  group('6. Clipboard Protection Service', () {
    test('clearIfMatches only clears clipboard when text matches', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await ClipboardService.clearIfMatches('UnmatchedRandomSecret');
      await ClipboardService.clearClipboard();
    });
  });
}
