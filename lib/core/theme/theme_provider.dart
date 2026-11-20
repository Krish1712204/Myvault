import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../security/vault_storage_service.dart';

const String _themePrefKey = 'user_theme_mode';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final FlutterSecureStorage _storage;

  ThemeModeNotifier({FlutterSecureStorage? storage})
      : _storage = storage ?? vaultSecureStorage,
        super(ThemeMode.light) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final savedTheme = await _storage.read(key: _themePrefKey);
      if (savedTheme == 'dark') {
        state = ThemeMode.dark;
      } else if (savedTheme == 'system') {
        state = ThemeMode.system;
      } else {
        state = ThemeMode.light;
      }
    } catch (_) {
      state = ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      String val = 'light';
      if (mode == ThemeMode.dark) val = 'dark';
      if (mode == ThemeMode.system) val = 'system';
      await _storage.write(key: _themePrefKey, value: val);
    } catch (_) {}
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
