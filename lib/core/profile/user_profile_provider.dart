import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserProfile {
  final String name;
  final String role;
  final String? photoPath;

  const UserProfile({
    this.name = 'Krishna Shelar',
    this.role = 'Primary Vault Owner',
    this.photoPath,
  });

  UserProfile copyWith({
    String? name,
    String? role,
    String? photoPath,
  }) {
    return UserProfile(
      name: name ?? this.name,
      role: role ?? this.role,
      photoPath: photoPath ?? this.photoPath,
    );
  }
}

class UserProfileNotifier extends StateNotifier<UserProfile> {
  static const _prefPhotoKey = 'user_profile_photo_path';
  final FlutterSecureStorage _storage;

  UserProfileNotifier({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(),
        super(const UserProfile()) {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final path = await _storage.read(key: _prefPhotoKey);
      if (path != null && path.isNotEmpty) {
        state = state.copyWith(photoPath: path);
      }
    } catch (_) {}
  }

  Future<void> setPhoto(String path) async {
    state = state.copyWith(photoPath: path);
    try {
      await _storage.write(key: _prefPhotoKey, value: path);
    } catch (_) {}
  }

  Future<void> removePhoto() async {
    state = UserProfile(name: state.name, role: state.role, photoPath: null);
    try {
      await _storage.delete(key: _prefPhotoKey);
    } catch (_) {}
  }
}

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  return UserProfileNotifier();
});
