# MyVault

MyVault is a personal digital vault Android application built with Flutter, designed with a local-first security architecture.

---

## Architecture & Directory Structure

```
Myvault/
├── .vscode/               # VS Code debugging & extension configuration
├── android/               # Native Android project wrapper (Application ID: com.personalvault.myvault)
├── lib/
│   ├── core/              # Core application configurations, themes, constants
│   │   ├── constants/     # App colors (navy text, white surfaces, blue actions) & spacing tokens
│   │   └── theme/         # Material 3 ThemeData with rounded cards (16px)
│   ├── features/          # Feature-first modular business logic & UI
│   │   └── vault/         # Vault domain, screens, and components
│   ├── shared/            # Shared cross-cutting UI widgets and utilities
│   │   └── widgets/       # Reusable components (e.g. AppCard)
│   └── main.dart          # Application entry point with ProviderScope
├── test/                  # Unit and widget test suite
├── .gitignore             # Excludes build outputs, signing keys, keystores, and test data
├── pubspec.yaml           # Flutter dependencies (Riverpod, Material 3, GoRouter)
└── README.md              # Setup and verification documentation
```

---

## Environment Status & Verification

| Component | Status | Details |
| :--- | :--- | :--- |
| **Git** | Verified Available | `git version 2.55.0.windows.3` |
| **Flutter SDK** | Verified Available | `Flutter 3.47.8 • channel stable` (`C:\src\flutter`) |
| **Dart SDK** | Verified Available | `Dart 3.13.7` |
| **Android Studio** | Installed | Located at `C:\Program Files\Android\Android Studio` |
| **Java JDK (bundled JBR)**| Available | OpenJDK 25 (bundled with Android Studio) |
| **Android SDK / adb** | Pending First Studio Launch | Needs Android Studio First-Run Setup Wizard to download SDK |
| **Connected Android Device**| Pending ADB & USB connection| Ready once Android SDK Platform-Tools are present |

---

## Final Steps to Run on Physical Android Phone

### Step 1: Open Android Studio Once to Download Android SDK
1. Open **Android Studio** from your Windows Start Menu.
2. Complete the setup wizard (choose **Standard** setup).
3. This downloads the Android SDK, Android SDK Platform-Tools (which includes `adb.exe`), and build tools to `%LOCALAPPDATA%\Android\Sdk`.
4. Run `flutter doctor --android-licenses` in terminal and accept the licenses by typing `y`.

### Step 2: Connect Your Android Phone
1. On your phone: **Settings > About Phone > Tap 'Build Number' 7 times**.
2. Go to **Settings > System > Developer Options > Enable USB Debugging**.
3. Plug the phone into your PC via USB and accept the authorization prompt on the phone screen.

### Step 3: Run the Application
In your terminal or VS Code:
```powershell
flutter devices
flutter run
```

---

## Verification & Testing Commands

To run static analysis and tests:
```powershell
flutter pub get
flutter analyze
flutter test
```

---

## Security Guidelines for Future Phases
- **Local-first**: Data remains strictly on-device in SQLCipher encrypted storage.
- **Keys**: Cryptographic keys must be protected using Android Keystore.
- **Never commit secrets**: Keystores (`*.jks`, `*.keystore`), `key.properties`, and test credentials are intentionally excluded by `.gitignore`.
