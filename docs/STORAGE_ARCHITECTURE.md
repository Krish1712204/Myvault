# MyVault — Storage Architecture (Phase 3)

This document specifies the encrypted local database and file storage implementation for MyVault.

---

## 1. Overview & Security Invariants

MyVault uses a **zero-knowledge, local-first storage architecture**:
1. **Device-Private Isolation**: All database files and encrypted attachments reside solely in internal app-private storage (`/data/user/0/com.personalvault.myvault/app_flutter/`).
2. **Transparent Page-Level Encryption**: All structured relational data is encrypted with **SQLCipher** (AES-256 in CBC mode with HMAC-SHA512 per-page authentication).
3. **Authenticated File Storage**: All documents, PDFs, photos, and media attachments are stored as encrypted blobs using **AES-256-GCM** with a unique 96-bit nonce per file and a 128-bit authentication tag.
4. **Key Hierarchy & Domain Separation**:
   - The Root Data Key is the 256-bit **Vault Encryption Key (VEK)** generated via `Random.secure()`.
   - The Database Key is derived from VEK via `HKDF-SHA256(info: 'MyVault_SQLCipher_Database_Key_V1')`.
   - The File Storage Key is derived from VEK via `HKDF-SHA256(info: 'MyVault_File_Storage_AES256GCM_V1')`.
   - Both subkeys are ephemeral and zeroized upon locking the vault.
5. **No Cloud Exposure or Android Auto-Backup**:
   `android:allowBackup="false"` is set in `AndroidManifest.xml` to prevent Google Drive Auto Backup from capturing device-bound keys or partial encrypted databases.

---

## 2. SQLCipher Database Schema

Database path: `<app_private_storage>/vault_secure/myvault_encrypted.db`

### Tables and Constraints
1. **`vault_items`** (Master Index):
   - `id` (TEXT, PK): Unique record identifier (UUID / prefixed key).
   - `category` (TEXT): One of `'passwords'`, `'idCards'`, `'documents'`, `'photos'`, `'notes'`, `'contacts'`.
   - `title` (TEXT): Display title.
   - `subtitle` (TEXT): Secondary display metadata.
   - `is_favourite` (INTEGER): `1` if starred, `0` otherwise.
   - `created_at` (INTEGER): Milliseconds since epoch.
   - `updated_at` (INTEGER): Milliseconds since epoch.

2. **`password_entries`** (Credentials):
   - `id` (TEXT, PK)
   - `item_id` (TEXT, UNIQUE, FK -> `vault_items(id)` ON DELETE CASCADE)
   - `username` (TEXT)
   - `encrypted_password` (TEXT)
   - `website_url` (TEXT)
   - `notes` (TEXT)

3. **`identity_entries`** (Government & Personal IDs):
   - `id` (TEXT, PK)
   - `item_id` (TEXT, UNIQUE, FK -> `vault_items(id)` ON DELETE CASCADE)
   - `document_type` (TEXT)
   - `document_number` (TEXT)
   - `full_name` (TEXT)
   - `issued_date` (TEXT)
   - `expiry_date` (TEXT)
   - `issuing_country` (TEXT)
   - `notes` (TEXT)

4. **`document_entries`** (File Attachments):
   - `id` (TEXT, PK)
   - `item_id` (TEXT, UNIQUE, FK -> `vault_items(id)` ON DELETE CASCADE)
   - `file_path` (TEXT): Relative path to encrypted file inside `vault_encrypted_files/`.
   - `file_name` (TEXT): Original file name.
   - `file_size` (INTEGER): Size in bytes.
   - `mime_type` (TEXT)
   - `file_extension` (TEXT)
   - `notes` (TEXT)

5. **`notes`** (Secure Notes):
   - `id` (TEXT, PK)
   - `item_id` (TEXT, UNIQUE, FK -> `vault_items(id)` ON DELETE CASCADE)
   - `content` (TEXT)
   - `color_tag` (TEXT)

6. **`contacts`** (Secure Contacts):
   - `id` (TEXT, PK)
   - `item_id` (TEXT, UNIQUE, FK -> `vault_items(id)` ON DELETE CASCADE)
   - `phone_number` (TEXT)
   - `email` (TEXT)
   - `company` (TEXT)
   - `address` (TEXT)

7. **`tags`** & **`item_tags`** (Categorization & Labeling):
   - Many-to-many relationship supporting cross-category tagging.

Foreign key enforcement (`PRAGMA foreign_keys = ON;`) is executed on every database connection.

---

## 3. Encrypted File Storage Architecture

File storage directory: `<app_private_storage>/vault_encrypted_files/`

### Format Specification: `MYVAULT_F_V1`
Every encrypted file is stored with an authenticated header followed by AES-256-GCM ciphertext:

| Offset | Length | Field | Description |
|:---|:---|:---|:---|
| `0x00` | 12 bytes | `Magic Bytes` | ASCII: `MYVAULT_F_V1` (File format identifier & version 1) |
| `0x0C` | 12 bytes | `Nonce` | Cryptographically random 96-bit AES-GCM IV |
| `0x18` | 16 bytes | `MAC Tag` | 128-bit authentication tag validating ciphertext integrity |
| `0x28` | $N$ bytes | `Ciphertext` | AES-256-GCM encrypted payload |

### Integrity Verification & Tamper Resistance
Before returning any plaintext or rendering a preview:
1. Header is validated for `MYVAULT_F_V1`.
2. Nonce and MAC tag are extracted.
3. AES-256-GCM authentication is computed over ciphertext. If a single bit is modified, `decrypt()` throws `MacValidationException`.
4. Plaintext is written only to an ephemeral temporary cache (`<cache>/vault_previews/`) when previewing, and deleted upon completion.

---

## 4. Portable Encrypted Backup & Restore Specification (Phase 7 Implemented)

MyVault Phase 7 implements a single-file portable container format (`.myvault`) with authenticated header metadata, AEAD payload encryption, and transactional rollback recovery.

### 4.1 Container Binary Layout: `MYVAULT_B_V1`

```
+--------------------------------------------------------------------------------------------------+
| Magic Bytes (12B) | Header Len (4B) | Unencrypted JSON Header (NB) | AES-256-GCM Ciphertext (MB) |
|   "MYVAULT_B_V1"  |  Big-Endian U32 |   Format metadata, Salt, MAC |   Encrypted JSON Payload    |
+--------------------------------------------------------------------------------------------------+
```

| Offset | Length | Field | Description |
|:---|:---|:---|:---|
| `0x00` | 12 bytes | `Magic Bytes` | ASCII: `MYVAULT_B_V1` (Portable backup container format identifier) |
| `0x0C` | 4 bytes | `Header Length` | 32-bit big-endian unsigned integer specifying header JSON length $N$ |
| `0x10` | $N$ bytes | `Header JSON` | UTF-8 JSON containing format version, Argon2id parameters, salt, nonce, and MAC |
| `0x10 + N` | $M$ bytes | `Ciphertext` | AES-256-GCM encrypted payload containing database records and file attachments |

### 4.2 Header Metadata Specification
The unencrypted header allows safe inspection of the backup file before requiring the user's passphrase:
```json
{
  "format": "MYVAULT_BACKUP",
  "version": 1,
  "app_version": "1.0.0",
  "created_at": 1729000000000,
  "kdf": "Argon2id",
  "kdf_params": {
    "memory": 19456,
    "iterations": 2,
    "parallelism": 1,
    "key_length": 32,
    "salt": "<Base64 32-byte salt>"
  },
  "cipher": "AES-256-GCM",
  "nonce": "<Base64 12-byte IV>",
  "mac": "<Base64 16-byte GCM authentication tag>",
  "item_count": 42,
  "file_count": 5
}
```

### 4.3 Encrypted Payload Structure
The decrypted payload contains all relational database tables and re-encoded attachment binaries with SHA-256 checksums:
```json
{
  "version": 1,
  "timestamp": 1729000000000,
  "vault_items": [...],
  "password_entries": [...],
  "identity_entries": [...],
  "document_entries": [...],
  "notes": [...],
  "contacts": [...],
  "tags": [...],
  "item_tags": [...],
  "files": [
    {
      "file_name": "aadhaar.pdf",
      "relative_path": "aadhaar.pdf",
      "mime_type": "application/pdf",
      "size": 1048576,
      "sha256": "3a7b...",
      "data_b64": "<Base64 encrypted attachment data>"
    }
  ]
}
```

### 4.4 Atomic Restoration & Rollback Recovery Point
1. **Pre-Restoration Validation**:
   - Signature check verifies `MYVAULT_B_V1` magic bytes.
   - Version check ensures compatibility (`version <= 1`).
   - AEAD MAC tag authentication ensures payload has not been modified or corrupted.
   - Path-traversal checks sanitize all file paths via `p.basename()`, rejecting relative components (`..`) or absolute paths.
   - SHA-256 verification confirms each decrypted file attachment matches its checksum.
2. **Confirmation Enforcement**:
   - If the vault currently contains items and the user has not confirmed replacement (`replaceExisting: true`), restoration is aborted.
3. **Atomic Rollback Architecture**:
   - An in-memory recovery snapshot of all existing table rows is captured.
   - Database operations execute inside a single transaction (`db.transaction()`).
   - Restored file attachments are re-encrypted with the target device's active VEK/File Storage Key.
   - If an error occurs at any point (e.g. disk full, corrupted attachment), all newly written files are deleted from storage and original database rows are restored from the in-memory recovery snapshot.


