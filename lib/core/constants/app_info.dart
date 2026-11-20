/// App identity shown in Settings and written into backup headers.
class AppInfo {
  AppInfo._();

  /// Must match `version:` in pubspec.yaml (without the +build suffix).
  /// Enforced by test/app_info_test.dart.
  static const String version = '1.0.2';
}
