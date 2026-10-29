# MyVault — Key Management Architecture (Phase 3 Implemented)

This document specifies the cryptographic key lifecycle, storage mechanisms, and hardware-backed security architecture implemented in MyVault.

---

## 1. Threat Model & Security Principles

1. **Zero-Knowledge Architecture**: The user's Master Password is never transmitted over a network or stored on disk in plaintext or reversible ciphertext.
2. **Device-Bound Protection**: Cryptographic material is bound to the physical hardware using the **Android Keystore system** (StrongBox Keymaster or TEE — Trusted Execution Environment).
3. **No Hardcoded Keys / No Insecure Placeholders**: No static or predictable keys exist anywhere in the codebase.
4. **Separation of Authentication and Encryption**: Biometric authentication confirms identity and releases a hardware-protected Biometric Wrapping Key (`BWK`) that unwraps the **same** Vault Encryption Key (`VEK`), rather than bypassing encryption.
5. **Memory Ephemeral Exposure**: Decrypted keys exist strictly in memory within the active app session and are zeroized upon lock, backgrounding, or timeout.

---

## 2. Key Hierarchy & Architecture

```
+-------------------------------------------------------------+
|                      Master Password                        |
+-------------------------------------------------------------+
                              |
                     Argon2id KDF (Salt: 32 bytes)
                              v
+-------------------------------------------------------------+
|               Key Encryption Key (KEK)                      |
|                       256-bit AES Key                       |
+-------------------------------------------------------------+
                              |
        +---------------------+---------------------+
        |                                           |
        v                                           v
+-----------------------------+           +-----------------------------+
|    Password Verifier Hash   |           |    Wrapped Vault Key        |
|  SHA-256(KEK + VerifierTag) |           |  AES-256-GCM(VEK, by KEK)   |
|     (Stored in Encrypted    |           |    (Stored in Encrypted     |
|      SharedPreferences)     |           |     SharedPreferences)      |
+-----------------------------+           +-----------------------------+
                                                         |
                                                         v
                                          +-----------------------------+
                                          | Vault Encryption Key (VEK)  |
                                          |      256-bit Random Key     |
                                          +-----------------------------+
                                                         |
                                 +-----------------------+-----------------------+
                                 |                                               |
                     HKDF-SHA256 (Database Info)                     HKDF-SHA256 (File Info)
                                 |                                               |
                                 v                                               v
                  +-----------------------------+                 +-----------------------------+
                  |  SQLCipher Database Key     |                 |  File Storage Key           |
                  |     (256-bit AES Key)       |                 |     (256-bit AES Key)       |
                  |  Used for page encryption   |                 | Used for AES-256-GCM files  |
                  +-----------------------------+                 +-----------------------------+
```

### Biometric Path:
```
+-------------------------------------------------------------+
|                  Android BiometricPrompt                    |
|             (Fingerprint / Hardware-Backed Face)            |
+-------------------------------------------------------------+
                              | (User verified)
                              v
+-------------------------------------------------------------+
|               Biometric Wrapping Key (BWK)                  |
|     (Stored in Android Keystore / FlutterSecureStorage)     |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|              Wrapped VEK (Biometric)                        |
|             AES-256-GCM(VEK, key: BWK)                      |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|                  Same Decrypted VEK                         |
|             Loaded into VaultSession in RAM                 |
+-------------------------------------------------------------+
```

---

## 3. Vault Encryption Key (VEK) Lifecycle

### 3.1 Vault Initialization (Creation)
1. User provides master password and confirmation.
2. System validates master password complexity ($\ge 8$ chars, uppercase, lowercase, numbers, symbols, match).
3. 32-byte cryptographically secure random salt generated via `Random.secure()`.
4. KEK is derived via Argon2id (`memory: 19 MiB`, `iterations: 2`, `parallelism: 1`, `hashLength: 32`).
5. Password verifier hash (`SHA-256(KEK || "MyVault_Verifier_Tag_V1")`) is generated.
6. A fresh 256-bit VEK is generated using `Random.secure()`.
7. VEK is encrypted with KEK using AES-256-GCM, producing `wrapped_vek_password` with a 96-bit nonce and a 128-bit MAC tag.
8. If biometrics are enrolled:
   - A 256-bit random Biometric Wrapping Key (`BWK`) is generated and stored in Android Keystore backed storage.
   - VEK is encrypted with BWK using AES-256-GCM, producing `wrapped_vek_biometric`.
9. The salt, verifier hash, KDF metadata, and `wrapped_vek_password` are persisted into `FlutterSecureStorage`.
10. The unencrypted VEK is loaded into `VaultSession` in RAM.
11. SQLCipher database is initialized and opened using `HKDF-SHA256(VEK, 'MyVault_SQLCipher_Database_Key_V1')`.

### 3.2 Vault Unlock via Master Password
1. User enters candidate master password.
2. Stored salt, verifier hash, and `wrapped_vek_password` are retrieved.
3. Candidate KEK is derived via Argon2id.
4. Candidate verifier is compared to stored verifier in constant time.
5. If match:
   - Candidate KEK unwraps `wrapped_vek_password` using AES-256-GCM.
   - If MAC tag authenticates, VEK is extracted and loaded into `VaultSession`.
   - SQLCipher database is opened using the derived database key.
6. If mismatch or tampered:
   - Rejection occurs immediately; session remains locked.

### 3.3 Vault Unlock via Biometrics
1. User passes hardware biometric challenge via `LocalAuthentication`.
2. App retrieves `BWK` and `wrapped_vek_biometric` from secure storage.
3. AES-256-GCM unwraps the **same** VEK using `BWK`.
4. VEK is loaded into `VaultSession` and SQLCipher database is opened.
5. Note: When user disables biometrics in Settings, `BWK` and `wrapped_vek_biometric` are permanently deleted from secure storage.

### 3.4 Inactivity and Explicit Locking
1. Lock triggered by user action, inactivity timeout, or immediate app backgrounding.
2. `VaultDatabase.close()` closes and locks the SQLCipher database.
3. `VaultSession.clear()` zeroizes the VEK byte buffer with zeros (`fillRange(0, length, 0)`).
4. GoRouter redirect forces navigation to `/unlock`.

---

## 4. Security Summary Checklist

| Security Requirement | Status | Verification |
|:---|:---:|:---|
| Secure random VEK generation | Verified | 256-bit entropy via `Random.secure()` |
| Password derives KEK | Verified | Argon2id mobile calibration |
| VEK authenticated encryption | Verified | AES-256-GCM with 96-bit nonce & 128-bit tag |
| Password verifier independent attack resistance | Verified | One-way SHA-256 preimage resistance |
| Biometric releases genuine VEK | Verified | Unwraps same VEK with hardware-protected BWK |
| Tamper resistance & fail-closed behavior | Verified | `MacValidationException` triggers zeroization |
| Database full encryption | Verified | SQLCipher AES-256-CBC page encryption |
| File storage authenticated encryption | Verified | Unique nonce per file, `MYVAULT_F_V1` header |
| Zeroization on lock | Verified | RAM buffers overwritten with zeros |
| Portable backup encryption key | Verified | Independent Argon2id BEK derivation |
| Hardware Keystore independence | Verified | Backups restored on new devices without Keystore dependence |
| Atomic rollback safety on restore | Verified | In-memory transaction snapshot rollback on failure |

---

## 5. Encrypted Backup & Restore Key Architecture (Phase 7)

MyVault implements a portable, authenticated backup and restore mechanism that enables full cross-device migration without depending on Android Keystore hardware-bound keys:

```
+-------------------------------------------------------------+
|                   Backup Passphrase                         |
|            (User-entered at export & import)                |
+-------------------------------------------------------------+
                               |
              Argon2id KDF (Random Salt: 32 bytes)
              Parameters: Memory 19 MiB, Iterations 2
                               v
+-------------------------------------------------------------+
|             Backup Encryption Key (BEK)                     |
|                   256-bit AES Key                           |
+-------------------------------------------------------------+
                               |
                               +-------------------------------------+
                               |                                     |
                               v                                     v
+-----------------------------------------------+   +-----------------------------------------------+
|      Backup Export (AES-256-GCM)              |   |       Backup Import (AEAD Decrypt)            |
| - Plaintext JSON payload (records + files)    |   | - Authenticates 128-bit GCM MAC tag           |
| - Encrypted using BEK + 96-bit random nonce   |   | - Decrypts payload only if MAC is valid       |
| - Zero master keys or Keystore keys exported  |   | - Re-encrypts attachments with target VEK     |
+-----------------------------------------------+   +-----------------------------------------------+
```

### 5.1 Backup Key Principles & Invariants:
1. **Keystore Independence**: The Backup Encryption Key (`BEK`) is derived purely from the user's chosen backup passphrase and a secure random 32-byte salt using Argon2id. It has **no dependency** on the Android Keystore, StrongBox, or TEE. This ensures backups can be restored on another device or after a factory reset.
2. **Strict Cryptographic Domain Separation**:
   - Master Password, KEK, plaintext VEK, Database Key, and Biometric Wrapping Key (`BWK`) are **NEVER** included in backup files.
   - The backup passphrase is completely decoupled from the master password (can be identical or different at user discretion).
3. **AEAD Authenticated Encryption**: The entire backup payload (JSON structure containing records, tags, and decrypted attachment blobs with SHA-256 integrity hashes) is encrypted with AES-256-GCM. Any byte-level modification or incorrect passphrase fails authentication immediately.
4. **Target Device Re-Encryption**: During restoration, file attachments are re-encrypted using the target device's active VEK and local `FileStorageKey`. Restored database records are written directly into the target device's SQLCipher database within an atomic transaction.
5. **Atomic Rollback Point**: Before writing any restored records, an in-memory recovery snapshot is recorded. If any error occurs during restoration or attachment processing, all newly created files are deleted and previous database rows are atomically re-inserted.
6. **Memory Hygiene**: Ephemeral BEK instances and in-memory decrypted buffers are released and zeroized promptly upon completion.

