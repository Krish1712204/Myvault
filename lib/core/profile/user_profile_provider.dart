import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../features/auth/domain/vault_auth_notifier.dart';
import '../../features/auth/domain/vault_auth_state.dart';
import '../security/vault_storage_service.dart';

class UserProfile {
  /// Empty until the user sets it in Settings; nothing is pre-filled.
  final String name;

  /// The profile photo, stored like every vault attachment: encrypted with the vault's file
  /// key in the vault's files folder. It can only be shown while the vault is unlocked.
  final String? encryptedPhotoPath;

  const UserProfile({this.name = '', this.encryptedPhotoPath});

  bool get hasName => name.trim().isNotEmpty;

  bool get hasPhoto => encryptedPhotoPath != null;

  String get firstName => hasName ? name.trim().split(RegExp(r'\s+')).first : '';

  String get initials => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
}

class UserProfileNotifier extends StateNotifier<UserProfile> {
  static const _prefNameKey = 'user_profile_name';
  static const _prefPhotoKey = 'user_profile_photo_encrypted';

  /// Older builds kept an unencrypted copy of the photo here; it is encrypted and deleted
  /// at the next unlock.
  static const _legacyPhotoPathKey = 'user_profile_photo_path';

  final FlutterSecureStorage _storage;
  final Ref? _ref;

  UserProfileNotifier({FlutterSecureStorage? storage, Ref? ref})
      : _storage = storage ?? vaultSecureStorage,
        _ref = ref,
        super(const UserProfile()) {
    _loadProfile();
    _ref?.listen<VaultAuthState>(vaultAuthStateProvider, (previous, next) {
      if (next.isUnlocked && previous?.isUnlocked != true) _migrateLegacyPhoto();
    });
  }

  Future<void> _loadProfile() async {
    try {
      final name = await _storage.read(key: _prefNameKey) ?? '';
      final photo = await _storage.read(key: _prefPhotoKey);
      state = UserProfile(name: name, encryptedPhotoPath: (photo == null || photo.isEmpty) ? null : photo);
      if (_ref?.read(vaultAuthStateProvider).isUnlocked == true) await _migrateLegacyPhoto();
    } catch (_) {}
  }

  Future<void> setName(String name) async {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    state = UserProfile(name: clean, encryptedPhotoPath: state.encryptedPhotoPath);
    try {
      await _storage.write(key: _prefNameKey, value: clean);
    } catch (_) {}
  }

  /// Encrypts the picked image into the vault (requires the vault to be unlocked).
  Future<void> setPhoto(String sourcePath) async {
    await _savePhotoBytes(await File(sourcePath).readAsBytes(), p.basename(sourcePath));
  }

  Future<void> _savePhotoBytes(List<int> bytes, String fileName) async {
    final ref = _ref;
    if (ref == null) throw StateError('Profile photos need the vault.');
    final vek = ref.read(vaultSessionProvider).vek;
    if (vek == null) throw StateError('Unlock the vault to change the profile photo.');
    final key = await ref.read(vaultCryptoServiceProvider).deriveFileStorageKey(vek);
    vek.fillRange(0, vek.length, 0);
    final fileService = ref.read(encryptedFileServiceProvider);
    final stored = await fileService.encryptAndSave(
      fileBytes: bytes,
      originalFileName: fileName,
      fileStorageKey: key,
    );

    final old = state.encryptedPhotoPath;
    state = UserProfile(name: state.name, encryptedPhotoPath: stored.relativePath);
    try {
      await _storage.write(key: _prefPhotoKey, value: stored.relativePath);
    } catch (_) {}
    if (old != null) await fileService.deleteEncryptedFile(old);
  }

  Future<void> removePhoto() async {
    final old = state.encryptedPhotoPath;
    state = UserProfile(name: state.name);
    try {
      await _storage.delete(key: _prefPhotoKey);
    } catch (_) {}
    if (old != null) await _ref?.read(encryptedFileServiceProvider).deleteEncryptedFile(old);
  }

  /// Moves a photo saved unencrypted by an older build into encrypted storage.
  Future<void> _migrateLegacyPhoto() async {
    try {
      final legacyPath = await _storage.read(key: _legacyPhotoPathKey);
      if (legacyPath == null || legacyPath.isEmpty) return;
      final file = File(legacyPath);
      if (state.encryptedPhotoPath == null && await file.exists()) {
        await _savePhotoBytes(await file.readAsBytes(), p.basename(legacyPath));
      }
      await _storage.delete(key: _legacyPhotoPathKey);
      final dir = p.join((await getApplicationSupportDirectory()).path, 'profile');
      if (await file.exists() && p.isWithin(dir, legacyPath)) await file.delete();
    } catch (_) {}
  }
}

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  return UserProfileNotifier(ref: ref);
});

/// The decrypted profile photo while the vault is unlocked; null when locked or unset.
/// Kept in memory only.
final profilePhotoProvider = FutureProvider<Uint8List?>((ref) async {
  final path = ref.watch(userProfileProvider.select((profile) => profile.encryptedPhotoPath));
  final unlocked = ref.watch(vaultAuthStateProvider.select((auth) => auth.isUnlocked));
  if (path == null || !unlocked) return null;
  final vek = ref.read(vaultSessionProvider).vek;
  if (vek == null) return null;
  try {
    final key = await ref.read(vaultCryptoServiceProvider).deriveFileStorageKey(vek);
    final bytes = await ref.read(encryptedFileServiceProvider).decrypt(relativePath: path, fileStorageKey: key);
    return Uint8List.fromList(bytes);
  } catch (_) {
    return null;
  } finally {
    vek.fillRange(0, vek.length, 0);
  }
});
