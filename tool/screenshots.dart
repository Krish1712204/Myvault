// Renders every MyVault screen (light and dark) with a realistic sample vault, for design
// review. Uses the app's real fonts and icons.
//
//   flutter test tool/screenshots.dart
//
// Images are written to build/screenshots/<light|dark>/.
//
// This runs as a test, so test-only APIs are fine here.
// ignore_for_file: invalid_use_of_visible_for_testing_member, use_build_context_synchronously
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myvault/core/router/app_router.dart';
import 'package:myvault/features/auth/domain/vault_auth_notifier.dart';
import 'package:myvault/features/auth/domain/vault_auth_state.dart';
import 'package:myvault/features/vault_items/data/vault_item_model.dart';
import 'package:myvault/main.dart';
import 'package:myvault/shared/state/vault_state_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Auth notifier pinned to a given status (no real crypto or storage).
class _FixedAuthNotifier extends VaultAuthNotifier {
  _FixedAuthNotifier(Ref ref, VaultStatus status)
      : super(
          cryptoService: ref.watch(vaultCryptoServiceProvider),
          storageService: ref.watch(vaultStorageServiceProvider),
          biometricService: ref.watch(vaultBiometricServiceProvider),
          session: ref.watch(vaultSessionProvider),
          vaultDb: ref.watch(vaultDatabaseProvider),
        ) {
    // A session key, so the vault does not count as expired and auto-lock mid-run.
    if (status == VaultStatus.unlocked) ref.read(vaultSessionProvider).startSession(List<int>.filled(32, 1));
    state = VaultAuthState(
      status: status,
      isBiometricAvailable: true,
      isBiometricEnabled: status != VaultStatus.uninitialized,
    );
  }

  @override
  Future<void> initialize() async {}
}

/// Items notifier serving a fixed sample vault.
class _SampleItemsNotifier extends VaultItemsNotifier {
  _SampleItemsNotifier(Ref ref) : super(ref.watch(vaultRepositoryProvider), ref);

  @override
  Future<bool> loadItems() async {
    state = sampleVault;
    return true;
  }

  @override
  Future<Uint8List?> getThumbnail(VaultItem item) async => null;
}

final int _now = DateTime(2026, 11, 18, 10, 30).millisecondsSinceEpoch;
int _ago(int hours) => _now - hours * 3600 * 1000;

final List<VaultItem> sampleVault = [
  VaultItem(id: 'pwd_1', title: 'Gmail', subtitle: 'aarav.demo@example.com', category: VaultCategory.passwords, subcategory: 'Email', username: 'aarav.demo@example.com', password: 'Tr0ub4dor&3-Horse!', url: 'https://mail.google.com', isFavourite: true, createdAt: _ago(300), updatedAt: _ago(2), date: '6 Nov 2026, 6:30 PM'),
  VaultItem(id: 'pwd_2', title: 'HDFC NetBanking', subtitle: 'aarav.m', category: VaultCategory.passwords, subcategory: 'Finance', username: 'aarav.m', password: 'bank123', url: 'https://netbanking.hdfcbank.com', createdAt: _ago(500), updatedAt: _ago(30)),
  VaultItem(id: 'pwd_3', title: 'Instagram', subtitle: '@aarav.demo', category: VaultCategory.passwords, subcategory: 'Social', username: '@aarav.demo', password: 'bank123', url: 'https://instagram.com', createdAt: _ago(700), updatedAt: _ago(70)),
  VaultItem(id: 'pwd_4', title: 'GitHub', subtitle: 'aarav-demo', category: VaultCategory.passwords, subcategory: 'Work', username: 'aarav-demo', password: 'x9#Lq!vR2m@Wz7&kP4', url: 'https://github.com', createdAt: _ago(900), updatedAt: _ago(100)),
  VaultItem(id: 'id_1', title: 'Aadhaar Card', subtitle: 'Government', category: VaultCategory.idCards, subcategory: 'Government', documentType: 'Aadhaar Card', documentNumber: '1234 5678 9012', fullName: 'Aarav Mehta', isFavourite: true, createdAt: _ago(1000), updatedAt: _ago(5)),
  VaultItem(id: 'id_2', title: 'PAN Card', subtitle: 'Government', category: VaultCategory.idCards, subcategory: 'Government', documentType: 'PAN Card', documentNumber: 'ABCDE1234F', fullName: 'Aarav Mehta', createdAt: _ago(1100), updatedAt: _ago(150)),
  VaultItem(id: 'id_3', title: 'Debit Card', subtitle: 'Government', category: VaultCategory.idCards, subcategory: 'Government', documentType: 'Debit Card', documentNumber: '4111 1111 1111 1111', fullName: 'AARAV MEHTA', createdAt: _ago(1200), updatedAt: _ago(200)),
  VaultItem(id: 'doc_1', title: 'Rental Agreement 2026', subtitle: 'PDF · 1.2 MB', category: VaultCategory.documents, fileName: 'rental_agreement_2026.pdf', fileExtension: '.pdf', mimeType: 'application/pdf', fileSize: 1258291, size: '1.2 MB', filePath: 'a.enc', createdAt: _ago(40), updatedAt: _ago(8)),
  VaultItem(id: 'doc_2', title: 'Offer Letter', subtitle: 'PDF · 640 KB', category: VaultCategory.documents, fileName: 'offer_letter.pdf', fileExtension: '.pdf', mimeType: 'application/pdf', fileSize: 655360, size: '640 KB', filePath: 'b.enc', createdAt: _ago(400), updatedAt: _ago(250)),
  VaultItem(id: 'doc_3', title: 'Insurance Policy', subtitle: 'DOCX · 220 KB', category: VaultCategory.documents, fileName: 'policy.docx', fileExtension: '.docx', mimeType: 'application/msword', fileSize: 225280, size: '220 KB', filePath: 'c.enc', createdAt: _ago(600), updatedAt: _ago(300)),
  VaultItem(id: 'photo_a', title: 'Passport photo', subtitle: 'JPG · 2.1 MB', category: VaultCategory.photos, fileName: 'passport.jpg', fileExtension: '.jpg', mimeType: 'image/jpeg', fileSize: 2202009, size: '2.1 MB', filePath: 'd.enc', createdAt: _ago(60), updatedAt: _ago(12)),
  VaultItem(id: 'photo_b', title: 'Car RC', subtitle: 'JPG · 1.4 MB', category: VaultCategory.photos, fileName: 'rc.jpg', fileExtension: '.jpg', mimeType: 'image/jpeg', fileSize: 1468006, size: '1.4 MB', filePath: 'e.enc', createdAt: _ago(80), updatedAt: _ago(90)),
  VaultItem(id: 'note_1', title: 'Wi-Fi & router', subtitle: 'Home network: MyHome_5G, password in **bold**', category: VaultCategory.notes, subcategory: 'Personal', details: 'Home network: MyHome_5G\nPassword: **sunflower-river-42**\nRouter admin: 192.168.1.1', createdAt: _ago(20), updatedAt: _ago(3)),
  VaultItem(id: 'note_2', title: 'Recovery codes', subtitle: 'GitHub: 8f2k-1m9q, 3x7p-0zr2, 6h4n-2wq8', category: VaultCategory.notes, subcategory: 'Recovery Codes', details: 'GitHub: 8f2k-1m9q, 3x7p-0zr2, 6h4n-2wq8', isFavourite: true, createdAt: _ago(800), updatedAt: _ago(400)),
  VaultItem(id: 'cnt_1', title: 'Dr. Meera Kulkarni', subtitle: '+91 98765 43210', category: VaultCategory.contacts, subcategory: 'Emergency', phoneNumber: '+91 98765 43210', email: 'dr.meera@example.com', createdAt: _ago(100), updatedAt: _ago(15)),
  VaultItem(id: 'cnt_2', title: 'Riya Mehta', subtitle: '+91 91234 56789', category: VaultCategory.contacts, subcategory: 'Family', phoneNumber: '+91 91234 56789', createdAt: _ago(110), updatedAt: _ago(160)),
];

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(File(f).readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await loader.load();
  }

  const jakarta = 'assets/fonts/PlusJakartaSans';
  await load('PlusJakartaSans', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) '$jakarta-$w.ttf',
  ]);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? 'C:/src/flutter';
  final fonts = '$flutterRoot/bin/cache/artifacts/material_fonts';
  await load('MaterialIcons', ['$fonts/materialicons-regular.otf']);
  // The app asks for the platform 'monospace' font (card numbers); stand in a system one.
  const mono = 'C:/Windows/Fonts/consola.ttf';
  if (File(mono).existsSync()) await load('monospace', [mono, 'C:/Windows/Fonts/consolab.ttf']);
  await load('Roboto', ['$fonts/roboto-regular.ttf', '$fonts/roboto-medium.ttf', '$fonts/roboto-bold.ttf']);
}

final _boundaryKey = GlobalKey();

Future<void> _shot(WidgetTester tester, String dir, String name) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  final boundary = _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('build/screenshots/$dir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
  });
}

Future<ProviderContainer> _boot(
  WidgetTester tester, {
  required VaultStatus status,
  required bool dark,
  Map<String, String> storage = const {},
}) async {
  FlutterSecureStorage.setMockInitialValues({
    'user_profile_name': 'Aarav Mehta',
    if (dark) 'user_theme_mode': 'dark',
    'myvault_last_backup_at': '${_ago(24 * 40)}',
    ...storage,
  });
  tester.view.physicalSize = const Size(412 * 1.5, 915 * 1.5);
  tester.view.devicePixelRatio = 1.5;
  final container = ProviderContainer(overrides: [
    vaultAuthStateProvider.overrideWith((ref) => _FixedAuthNotifier(ref, status)),
    vaultItemsProvider.overrideWith((ref) => _SampleItemsNotifier(ref)),
  ]);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: RepaintBoundary(key: _boundaryKey, child: const MyVaultApp()),
  ));
  await tester.pump(const Duration(milliseconds: 500));
  return container;
}

Future<void> _tapIfPresent(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) return;
  await tester.tap(finder.first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 400));
}

/// Dismisses an open bottom sheet by tapping its barrier.
Future<void> _closeSheets(WidgetTester tester) async {
  await tester.tapAt(const Offset(200, 40));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await _loadFonts();
  });

  for (final dark in [false, true]) {
    final dir = dark ? 'dark' : 'light';

    testWidgets('$dir: onboarding and unlock', (tester) async {
      await _boot(tester, status: VaultStatus.uninitialized, dark: dark);
      await _shot(tester, dir, '01_welcome');
      final router = rootNavigatorKey.currentContext!;
      GoRouter.of(router).go('/create-vault');
      await _shot(tester, dir, '02_create_vault');
    });

    testWidgets('$dir: unlock', (tester) async {
      await _boot(tester, status: VaultStatus.locked, dark: dark);
      GoRouter.of(rootNavigatorKey.currentContext!).go('/unlock');
      await tester.pump(const Duration(milliseconds: 300));
      await _shot(tester, dir, '03_unlock_password_sheet');
    });

    testWidgets('$dir: main screens', (tester) async {
      final container = await _boot(tester, status: VaultStatus.unlocked, dark: dark);
      final go = GoRouter.of(rootNavigatorKey.currentContext!);
      await _shot(tester, dir, '10_dashboard');
      await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -700));
      await _shot(tester, dir, '11_dashboard_scrolled');

      // The centre + button of the bottom bar (the only 30px add icon).
      await _tapIfPresent(tester, find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.add_rounded && w.size == 30));
      await _shot(tester, dir, '12_add_to_vault_sheet');
      await _closeSheets(tester);

      go.go('/search');
      await _shot(tester, dir, '20_search');
      go.go('/categories');
      await _shot(tester, dir, '21_categories');
      go.go('/settings');
      await _shot(tester, dir, '30_settings');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await _shot(tester, dir, '31_settings_scrolled');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await _shot(tester, dir, '32_settings_bottom');
      go.go('/settings');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pump(const Duration(milliseconds: 300));
      await _tapIfPresent(tester, find.textContaining('Google Drive'));
      await _shot(tester, dir, '33_drive_sheet');
      await tester.pumpWidget(const SizedBox());
      container.dispose(); // stops the vault's inactivity timer
    });

    testWidgets('$dir: backup sheets', (tester) async {
      Future<void> openDriveSheet() async {
        GoRouter.of(rootNavigatorKey.currentContext!).go('/settings');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 300));
        await _tapIfPresent(tester, find.text('Google Drive Backup'));
      }

      const connected = {
        'myvault_google_drive_backup_enabled': 'true',
        'myvault_google_drive_account_email': 'sample.user@gmail.com',
      };
      var container = await _boot(tester, status: VaultStatus.unlocked, dark: dark, storage: {
        ...connected,
        'myvault_last_backup_at': '${_ago(2)}',
      });
      await openDriveSheet();
      await _shot(tester, dir, '34_drive_connected');
      await _tapIfPresent(tester, find.text('Restore from Drive'));
      await _shot(tester, dir, '35_drive_restore_confirm');
      await tester.pumpWidget(const SizedBox());
      container.dispose();

      container = await _boot(tester, status: VaultStatus.unlocked, dark: dark, storage: {
        ...connected,
        'myvault_google_drive_restore_pending': 'true',
      });
      await openDriveSheet();
      await _shot(tester, dir, '36_drive_paused');
      await tester.pumpWidget(const SizedBox());
      container.dispose();

      container = await _boot(tester, status: VaultStatus.unlocked, dark: dark);
      GoRouter.of(rootNavigatorKey.currentContext!).go('/backup-restore');
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await _tapIfPresent(tester, find.text('Create Backup'));
      await _shot(tester, dir, '71_create_backup_sheet');
      await _tapIfPresent(tester, find.text('Create Backup File'));
      await _shot(tester, dir, '72_create_backup_error');
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    testWidgets('$dir: detail and edit screens', (tester) async {
      final container = await _boot(tester, status: VaultStatus.unlocked, dark: dark);
      final go = GoRouter.of(rootNavigatorKey.currentContext!);
      const routes = {
        '40_category_passwords': '/category/passwords',
        '41_category_idcards': '/category/id_cards',
        '42_category_documents': '/category/documents',
        '43_category_photos': '/category/photos',
        '44_category_notes': '/category/notes',
        '45_category_contacts': '/category/contacts',
        '50_password_details': '/password-details/pwd_1',
        '51_id_details': '/id-details/id_1',
        '52_card_details': '/id-details/id_3',
        '53_document_details': '/document-details/doc_1',
        '54_note_details': '/note-details/note_1',
        '55_contact_details': '/contact-details/cnt_1',
        '60_add_password': '/add-item',
        '61_add_id': '/add-id',
        '62_add_document': '/add-document',
        '63_add_note': '/add-note',
        '64_add_contact': '/add-contact',
        '65_edit_password': '/edit-password/pwd_1',
        '70_backup_restore': '/backup-restore',
      };
      for (final MapEntry(key: name, value: route) in routes.entries) {
        go.go(route);
        await _shot(tester, dir, name);
      }
      await tester.pumpWidget(const SizedBox());
      container.dispose(); // stops the vault's inactivity timer
    });
  }
}
