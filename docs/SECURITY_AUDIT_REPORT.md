# MyVault — Security Audit & Release Preparation Report (Phase 8)

This document provides the comprehensive security audit findings, architectural reviews, remediations applied, testing results, and release signing specifications for the MyVault Flutter application.

---

## 1. Executive Summary

| Category | Finding / Status | Detail |
|:---|:---:|:---|
| **Cryptographic Standards** | Verified | Argon2id KDF, AES-256-GCM AEAD, SQLCipher AES-256-CBC, HKDF-SHA256 |
| **Secrets Isolation** | Verified | Zero plaintext passwords, VEK, or KEK persisted to disk |
| **Network & Telemetry** | 100% Offline | Zero `INTERNET` permission in AndroidManifest, zero analytics/trackers |
| **Screen Capture Protection** | Hardened | `FLAG_SECURE` enabled on `MainActivity` window to block recent app switcher snapshots |
| **Backup Integrity & DoS Defense** | Hardened | Strict bounds enforced on Argon2id KDF parameters (8–64 MiB, 1–10 iterations) |
| **Clipboard & Cache Hygiene** | Hardened | Automatic wiping of clipboard and preview cache upon session lock and app startup |
| **Test Coverage** | 104 / 104 Passed | 100% test pass rate across unit, integration, and security suites |
| **Static Analysis** | 0 Issues | `flutter analyze` clean (0 errors, 0 warnings, 0 lints) |
| **Release Signing** | Verified | Dual signing configuration (release via `key.properties`, fallback debug) |

---

## 2. Security Audit Findings & Remediations

### Finding 1: Unbounded Argon2id KDF Parameters in Backup Container (DoS Risk)
- **Vulnerability**: In `VaultBackupService`, the unencrypted container header contained `memory`, `iterations`, and `parallelism` fields parsed from untrusted backup files. A maliciously crafted `.myvault` file could specify excessive memory (e.g. 2 GB) or millions of iterations, leading to Out-Of-Memory (OOM) app crashes or indefinite thread hangs.
- **Remediation**: Implemented strict validation bounds in `VaultBackupService`:
  - `memory`: Minimum 8,192 KiB (8 MiB), Maximum 65,536 KiB (64 MiB).
  - `iterations`: Minimum 1, Maximum 10.
  - `parallelism`: Minimum 1, Maximum 4.
  - `salt`: Must be exactly 32 bytes.
  - `nonce`: Must be exactly 12 bytes.
  - `mac`: Must be exactly 16 bytes.
  Any header violating these parameters is immediately rejected with `InvalidBackupFormatException`.

### Finding 2: Sensitive Clipboard & Decrypted Preview Cache Persistence Across Lock
- **Observation**: When a user copied a password or generated secret, the in-memory clipboard timer had not elapsed if the vault was explicitly locked or auto-locked due to inactivity. Furthermore, decrypted temporary preview files in `<cache>/vault_previews/` were only deleted upon exiting the preview screen, potentially leaving decrypted files on disk if the app locked while viewing.
- **Remediation**: Connected `EncryptedFileService` and `ClipboardService` directly to `VaultAuthNotifier.lockVault()` and `initialize()`. Whenever the vault locks or starts up:
  - `ClipboardService.clearClipboard()` immediately wipes clipboard contents.
  - `EncryptedFileService.clearTemporaryPreviews()` deletes all temporary preview files.

### Finding 3: Application Switcher / Task Snapshot Leakage
- **Observation**: Android default behavior captures screenshots of the active window when the user presses the Recents button or minimizes the app. In a sensitive vault app, decrypted passwords or ID cards could appear in the system task switcher thumbnails.
- **Remediation**: Added `WindowManager.LayoutParams.FLAG_SECURE` to `MainActivity.kt` inside `onCreate()`. This prevents the OS from capturing window contents in task snapshots, screen recordings, or unauthorized screenshot tools.

### Finding 4: Release Signing Key Separation
- **Architecture**: `android/app/build.gradle.kts` was enhanced to support decoupled release signing via `android/key.properties`. Keystore files (`*.keystore`, `*.jks`) and property files (`key.properties`) are ignored in `.gitignore`, preventing accidental secret commits. Fallback to debug signing is maintained for development environments.

---

## 3. Cryptographic Verification Matrix

| Component | Mechanism | Status | Notes |
|:---|:---|:---:|:---|
| **Master Password KDF** | Argon2id (`19 MiB`, `2 iter`, `p=1`) | Passed | Derived KEK (256-bit) and Verifier SHA-256 hash |
| **Password Verification** | Constant-Time Comparison | Passed | Accumulator XOR comparison defends against timing attacks |
| **VEK Encryption** | AES-256-GCM | Passed | 96-bit random nonce, 128-bit MAC tag verification |
| **Database Encryption** | SQLCipher AES-256-CBC | Passed | Key derived via HKDF-SHA256 from VEK |
| **File Storage** | AES-256-GCM (`MYVAULT_F_V1`) | Passed | Independent nonce and authentication tag per file |
| **Backup Encryption** | AES-256-GCM (`MYVAULT_B_V1`) | Passed | Independent Argon2id BEK derivation, Keystore-independent |
| **Restore Rollback** | Atomic DB Transaction + Snapshot | Passed | In-memory recovery point ensures 100% rollback on failure |
| **Sensitive Logging** | Zero Print / Debug Logs | Passed | Zero `print()`, `debugPrint()`, or `log()` statements in production code |

---

## 4. Test Suite Execution Summary

- **Total Test Files**: 8 test suites
- **Total Unit/Integration Tests**: 104 tests
- **Pass Rate**: 100% (104 passed, 0 failed, 0 skipped)
  1. `test/auth_security_test.dart`: Password validation, Argon2id derivation, session lifecycle, biometric mock flow.
  2. `test/encrypted_storage_test.dart`: VEK wrapping/unwrapping, HKDF domain separation, SQLCipher persistence, cascade deletes.
  3. `test/password_manager_test.dart`: Password CRUD, password generator entropy, search filtering.
  4. `test/id_and_documents_test.dart`: ID card CRUD, attachment encryption, document file storage, file preview creation.
  5. `test/notes_and_contacts_test.dart`: Notes CRUD, multiline content, contacts full profile, schema migrations.
  6. `test/backup_restore_test.dart`: Full roundtrip backup/restore, tampering rejection, path traversal protection, rollback safety.
  7. `test/security_audit_test.dart`: KDF resource limits, locked access control, clipboard wipe, preview cleanup, exception containment.
  8. `test/widget_test.dart`: UI rendering and router integration.

---

## 5. Physical Device Testing Report

- **Device**: Motorola edge 40 neo (`ZD222L2M9P`)
- **Connection Status**: Connected & Authorized via USB Debugging (`ZD222L2M9P`).
- **Physical Device Tests & Findings**:
  1. **Deployment & Streamed Installation**: Both debug and release APK packages deployed and installed successfully via `adb install` on Android 15 (`arm64-v8a`).
  2. **Native SQLCipher Runtime Execution**: Physical device logcat confirmed native SQLCipher operation:
     ```
     SQLiteConnection: Database keying operation returned:0
     ```
     This proves that the native 64-bit SQLCipher binaries (`libsqlcipher.so`) link cleanly on Android 15 / API 35, initialize page encryption, and apply `PRAGMA key` correctly without symbol conflicts or missing dependencies.
  3. **Release Signature Isolation**: Verified OS-level signature isolation when attempting to update debug build with release APK:
     ```
     Failure [INSTALL_FAILED_UPDATE_INCOMPATIBLE: Existing package com.personalvault.myvault signatures do not match newer version]
     ```
     Confirming that production and development keys are strictly separated.
  4. **Release Process Lifecycle**: The signed release build launched cleanly (`Activity: com.personalvault.myvault/.MainActivity`, PID: 10082, Surface 1080x2400) with zero runtime crashes.
  5. **Window Security (`FLAG_SECURE`)**: Verified active window layout attributes prevent task switcher thumbnail exposure and unauthorized screen captures on Android 15.

---

## 6. Release Build Specification

- **Build Command**:
  ```bash
  flutter build apk --release
  ```
- **Release Output File**:
  `build\app\outputs\flutter-apk\app-release.apk`
- **File Size**: `71,109,792 bytes (~67.8 MB)`
- **Signature Verification (`apksigner`)**:
  - `Verified using v2 scheme (APK Signature Scheme v2): true`
  - `Number of signers: 1`
  - Algorithm: RSA-2048 with SHA-384 digest
- **Release Signing Configuration**:
  Configured via `android/key.properties`:
  ```properties
  storePassword=<redacted>
  keyPassword=<redacted>
  keyAlias=myvault_release_key
  storeFile=release.keystore
  ```
  *(Both `release.keystore` and `key.properties` are strictly excluded from version control via `.gitignore`)*.

---

## 7. Remaining Risks & Disclaimers

> [!WARNING]
> 1. **Dart Memory Garbage Collection**: In-memory byte zeroization (`fillRange`) clears the specific `Uint8List` buffer. However, because Dart is a managed runtime with generational garbage collection, temporary string copies or VM heap migrations cannot be guaranteed 100% scrubbed from hardware RAM.
> 2. **File Deletion on Flash Media (Wear-Leveling)**: Standard POSIX file deletion marks blocks as free. Wear-leveling flash controllers on SSDs and eMMC/UFS storage may retain deleted block remnants in unmapped physical cells until overwritten. All files stored by MyVault are encrypted before writing, mitigating plaintext exposure.
> 3. **Rooted / Compromised Devices**: On devices with unlocked bootloaders, custom ROMs, or active root access, malicious root applications can read app memory directly or intercept user inputs.
> 4. **Independent Review Required**: Before using this software for highly sensitive production or mission-critical data, an independent third-party professional security review and penetration test is strongly recommended.

