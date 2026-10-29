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

## 4. Phase 7 Portable Encrypted Backup Roadmap

In Phase 7, backup and restore will be implemented as follows:
1. **Archive Generation**:
   The active `myvault_encrypted.db` file and all files in `vault_encrypted_files/` are bundled into a tar/zip container.
2. **Backup Encryption Key (BEK)**:
   A dedicated BEK is derived from a user-specified backup password or 24-word recovery seed using Argon2id with independent salt.
3. **Encrypted Container**:
   The container is encrypted with AES-256-GCM and formatted with metadata headers indicating timestamp, item counts, and schema version.
4. **Portability**:
   The exported file (`myvault_backup_<date>.myvault`) can be saved to user-selected destinations (USB, local storage, or shared safely) without exposing the master password or device-bound keystore credentials.

