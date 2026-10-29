# MyVault — Key Management Architecture (Phase 3 Preparation)

This document specifies the cryptographic key lifecycle, storage mechanisms, and hardware-backed security architecture designed for MyVault's encrypted database and file storage in Phase 3.

---

## 1. Threat Model & Security Principles

1. **Zero-Knowledge Architecture**: The user's Master Password is never transmitted over a network or stored on disk in plaintext or reversible ciphertext.
2. **Device-Bound Protection**: Cryptographic material is bound to the physical hardware using the **Android Keystore system** (StrongBox Keymaster or TEE — Trusted Execution Environment).
3. **No Hardcoded Keys / No Insecure Placeholders**: No static or predictable keys exist anywhere in the codebase.
4. **Separation of Authentication and Encryption**: Biometric authentication confirms identity but does **not** generate cryptographic entropy on its own. Instead, it unlocks a hardware-protected key wrapper.
5. **Memory Ephemeral Exposure**: Decrypted keys exist strictly in memory within the active app session and are zeroized upon lock, backgrounding, or timeout.

---

## 2. Key Hierarchy

The MyVault architecture employs a multi-tiered key hierarchy:

```
+-------------------------------------------------------------+
|                      Master Password                        |
+-------------------------------------------------------------+
                              |
                     Argon2id KDF (Salt: 32 bytes)
                              v
+-------------------------------------------------------------+
|               Master Key (Key Encryption Key - KEK)          |
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
                                 v                                               v
                  +-----------------------------+                 +-----------------------------+
                  |    SQLCipher Database Key   |                 |    Payload Encryptor Key    |
                  |  (Protects vault items DB)  |                 | (Protects files, documents) |
                  +-----------------------------+                 +-----------------------------+
```

### Definitions:
- **Master Password**: User-chosen secret string satisfying strict entropy criteria (>= 8 chars, uppercase, lowercase, numbers, symbols).
- **Salt**: 32-byte cryptographically secure random value generated via `Random.secure()`. Stored alongside verifier.
- **Key Encryption Key (KEK)**: 256-bit key derived via Argon2id (`memory: 19 MiB`, `iterations: 2`, `parallelism: 1`). Never saved to disk.
- **Password Verifier**: `SHA-256(KEK || "MyVault_Verifier_Tag_V1")`. Used to verify password correctness in constant time without storing the master password.
- **Vault Encryption Key (VEK)**: 256-bit cryptographically random symmetric key generated at vault creation. Used as the master data key to encrypt the database and media files.
- **Wrapped VEK (by Password)**: `AES-256-GCM(VEK, key: KEK, iv: Random(12 bytes))`.
- **Wrapped VEK (by Biometrics)**: `AES-256-GCM(VEK, key: AndroidKeystoreKey, iv: Random(12 bytes))`, where `AndroidKeystoreKey` requires biometric authentication (`setUserAuthenticationRequired(true)`).

---

## 3. Vault Encryption Key (VEK) Lifecycle

### 3.1 Vault Initialization (Creation)
1. User provides master password and confirmation.
2. System generates a 32-byte cryptographically secure salt.
3. KEK is derived via Argon2id.
4. Verifier Hash is calculated and stored in `EncryptedSharedPreferences` (backed by Android Keystore).
5. A fresh 256-bit VEK is generated using `Random.secure()`.
6. VEK is encrypted with KEK using AES-256-GCM, producing `wrapped_vek_password` and an authentication tag.
7. If biometrics are enrolled:
   - A biometric-bound AES-256 master key is created in Android Keystore (`KeyGenParameterSpec` with `PURPOSE_ENCRYPT | PURPOSE_DECRYPT`, `setUserAuthenticationRequired(true)`).
   - VEK is encrypted with this hardware key, producing `wrapped_vek_biometric`.
8. The derived VEK is loaded into the in-memory `VaultSession`.
9. The plain VEK and KEK are immediately zeroized from temporary buffers.

### 3.2 Vault Unlock via Master Password
1. User enters candidate master password.
2. Stored salt and verifier are retrieved from secure storage.
3. Argon2id derives candidate KEK.
4. Candidate verifier is hashed and compared to stored verifier in constant time.
5. If match:
   - Candidate KEK decrypts `wrapped_vek_password` with AES-256-GCM.
   - Decrypted VEK is placed into `VaultSession`.
   - `lastActivityTime` is updated.
6. If mismatch:
   - Error returned; no decrypted material retained; session remains locked.

### 3.3 Vault Unlock via Biometrics
1. App requests biometric authentication using Android `BiometricPrompt.CryptoObject` initialized with the Keystore cipher.
2. User provides enrolled biometric (fingerprint/face).
3. Upon hardware verification, the Keystore cipher decrypts `wrapped_vek_biometric`.
4. Decrypted VEK is placed into `VaultSession`.
5. Note: If the user disables biometrics in Settings, `wrapped_vek_biometric` is securely deleted from storage.

### 3.4 Inactivity and Explicit Locking
1. User clicks "Lock Vault Now" OR inactivity timer expires OR app transitions to background (when set to "Immediately").
2. `VaultSession.clear()` is called:
   - VEK buffer in memory is overwritten with zeros (`fillRange(0, length, 0)`).
   - Reference is set to `null`.
   - Any open database connection or cipher context is closed.
3. GoRouter redirect immediately forces navigation to `/unlock`.

---

## 4. Phase 3 Database & Storage Integration

In Phase 3, the decrypted VEK from `VaultSession` will be consumed by:
1. **SQLCipher / sqlite3_flutter_libs**:
   - `PRAGMA key = "x'<VEK_HEX>'";` or `PRAGMA cipher_key`.
   - Ensures transparent full database encryption at page level (AES-256-CBC).
2. **Encrypted Attachment Storage**:
   - Individual documents, PDFs, and photos stored on device filesystem encrypted with AES-256-GCM using unique per-file random IVs and sub-keys derived from VEK via HKDF.

---

## 5. Security Summary Checklist

| Objective | Phase 2 Implementation | Phase 3 Integration |
|:---|:---|:---|
| Master Password Security | Never stored; Argon2id KDF + constant-time verifier | Same derivation |
| Hardware Binding | Android Keystore (`EncryptedSharedPreferences`) | Android Keystore + Biometric CryptoObject |
| Data Key (VEK) | Ephemeral in-memory session with zeroization | Wraps SQLCipher DB & encrypted files |
| Biometric Integrity | Hardware enrollment check (`LocalAuthentication`) | Hardware-bound key release |
| Unauthorized Navigation | GoRouter redirect guards prevent route bypassing | Same guards protecting decryptors |
