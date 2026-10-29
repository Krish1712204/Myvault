# MyVault

MyVault is a personal digital vault Android application built with Flutter, designed with a local-first security architecture.

---

## Architecture & Directory Structure

```
Myvault/
├── .vscode/               # VS Code debugging & extension configuration
├── lib/
│   ├── core/              # Core application configurations, themes, constants
│   │   ├── constants/     # App colors (navy text, white surfaces, blue actions) & spacing tokens
│   │   └── theme/         # Material 3 ThemeData with rounded cards
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

An automated check on this Windows workstation revealed the following status:

| Component | Status | Details |
| :--- | :--- | :--- |
| **Git** | Verified Available | `git version 2.55.0.windows.3` |
| **Flutter SDK** | Not Installed | Missing from `PATH` |
| **Dart SDK** | Not Installed | Included with Flutter SDK |
| **Java JDK** | Not Installed | `java` binary not found |
| **Android SDK / Studio** | Not Installed | `adb` binary not found |
| **Connected Android Devices** | Not Detected | Requires Android SDK Platform-Tools (`adb`) |

---

## Windows Installation Guide

Follow these verified steps to install the missing development toolchain on Windows:

### 1. Install Java Development Kit (JDK 17 LTS)
Flutter for Android requires OpenJDK 17.

1. Download **Eclipse Temurin OpenJDK 17 (LTS)** installer:
   - Official URL: [https://adoptium.net/temurin/releases/?version=17](https://adoptium.net/temurin/releases/?version=17)
   - Or install via winget (in an elevated PowerShell terminal):
     ```powershell
     winget install EclipseAdoptium.Temurin.17.JDK
     ```
2. Verify `JAVA_HOME` environment variable points to the JDK directory (e.g., `C:\Program Files\Eclipse Adoptium\jdk-17.x.x-hotspot`).
3. Add `%JAVA_HOME%\bin` to your system `PATH`.

### 2. Install Android Studio & Android SDK
1. Download **Android Studio Ladybug or later**:
   - URL: [https://developer.android.com/studio](https://developer.android.com/studio)
   - Or install via winget:
     ```powershell
     winget install Google.AndroidStudio
     ```
2. Open Android Studio, navigate through the Setup Wizard, and install:
   - Android SDK (API 34 or 35)
   - Android SDK Platform-Tools (contains `adb.exe`)
   - Android SDK Command-line Tools (`Tools > SDK Manager > SDK Tools > Android SDK Command-line Tools (latest)`)
3. Set user environment variables:
   - `ANDROID_HOME`: `%LOCALAPPDATA%\Android\Sdk`
   - Add to `PATH`:
     - `%LOCALAPPDATA%\Android\Sdk\platform-tools`
     - `%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\bin`

### 3. Install Flutter SDK
1. Download the latest stable Flutter Windows bundle:
   - URL: [https://docs.flutter.dev/get-started/install/windows/mobile](https://docs.flutter.dev/get-started/install/windows/mobile)
   - Or clone via Git into `C:\src\flutter`:
     ```powershell
     git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter
     ```
2. Add `C:\src\flutter\bin` to your User `PATH` environment variable.
3. Restart your terminal or IDE so the updated `PATH` takes effect.

### 4. Enable USB Debugging on Physical Android Phone
1. On your Android phone, go to **Settings > About Phone**.
2. Tap **Build Number** 7 times to enable Developer Options.
3. Go to **Settings > System > Developer Options**.
4. Enable **USB Debugging**.
5. Connect your phone via USB cable to this PC.
6. Accept the "Allow USB debugging?" prompt on your phone (check "Always allow from this computer").

---

## Project Verification Commands

Once the above dependencies are installed:

### Step 1: Run Flutter Doctor
Run to verify all dependencies and accept Android licenses:
```powershell
flutter doctor -v
flutter doctor --android-licenses
```

### Step 2: Generate Android Platform Bindings (Application ID `com.personalvault.myvault`)
Generate the native Android wrapper around this workspace:
```powershell
flutter create . --org com.personalvault --project-name myvault
```

### Step 3: Fetch Packages & Run Tests
```powershell
flutter pub get
flutter analyze
flutter test
```

### Step 4: Verify Device & Run on Physical Android Phone
```powershell
flutter devices
flutter run
```

---

## Security Guidelines for Future Phases
- **Local-first**: Data remains strictly on-device in SQLCipher encrypted storage.
- **Keys**: Cryptographic keys must be protected using Android Keystore.
- **Never commit secrets**: Keystores (`*.jks`, `*.keystore`), `key.properties`, and test credentials are intentionally excluded by `.gitignore`.
