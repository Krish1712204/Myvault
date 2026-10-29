import 'package:sqflite_sqlcipher/sqflite.dart';

/// Database schema definitions, migrations, and table creation logic for SQLCipher
class VaultSchema {
  static const int currentVersion = 1;
  static const String dbFileName = 'myvault_encrypted.db';

  static Future<void> onConfigure(Database db) async {
    // Enforce foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  static Future<void> onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      // 1. Vault items master table
      await txn.execute('''
        CREATE TABLE vault_items (
          id TEXT PRIMARY KEY,
          category TEXT NOT NULL,
          title TEXT NOT NULL,
          subtitle TEXT,
          is_favourite INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');

      // 2. Passwords entry table
      await txn.execute('''
        CREATE TABLE password_entries (
          id TEXT PRIMARY KEY,
          item_id TEXT NOT NULL UNIQUE,
          username TEXT,
          encrypted_password TEXT NOT NULL,
          website_url TEXT,
          notes TEXT,
          FOREIGN KEY (item_id) REFERENCES vault_items (id) ON DELETE CASCADE
        );
      ''');

      // 3. ID Cards / Identity entries table
      await txn.execute('''
        CREATE TABLE identity_entries (
          id TEXT PRIMARY KEY,
          item_id TEXT NOT NULL UNIQUE,
          document_type TEXT NOT NULL,
          document_number TEXT NOT NULL,
          full_name TEXT,
          issued_date TEXT,
          expiry_date TEXT,
          issuing_country TEXT,
          notes TEXT,
          FOREIGN KEY (item_id) REFERENCES vault_items (id) ON DELETE CASCADE
        );
      ''');

      // 4. Documents & Photos file entries table
      await txn.execute('''
        CREATE TABLE document_entries (
          id TEXT PRIMARY KEY,
          item_id TEXT NOT NULL UNIQUE,
          file_path TEXT NOT NULL,
          file_name TEXT NOT NULL,
          file_size INTEGER NOT NULL,
          mime_type TEXT NOT NULL,
          file_extension TEXT NOT NULL,
          notes TEXT,
          FOREIGN KEY (item_id) REFERENCES vault_items (id) ON DELETE CASCADE
        );
      ''');

      // 5. Secure Notes table
      await txn.execute('''
        CREATE TABLE notes (
          id TEXT PRIMARY KEY,
          item_id TEXT NOT NULL UNIQUE,
          content TEXT NOT NULL,
          color_tag TEXT,
          FOREIGN KEY (item_id) REFERENCES vault_items (id) ON DELETE CASCADE
        );
      ''');

      // 6. Secure Contacts table
      await txn.execute('''
        CREATE TABLE contacts (
          id TEXT PRIMARY KEY,
          item_id TEXT NOT NULL UNIQUE,
          phone_number TEXT NOT NULL,
          email TEXT,
          company TEXT,
          address TEXT,
          FOREIGN KEY (item_id) REFERENCES vault_items (id) ON DELETE CASCADE
        );
      ''');

      // 7. Tags table
      await txn.execute('''
        CREATE TABLE tags (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          color TEXT
        );
      ''');

      // 8. Item-Tag associations
      await txn.execute('''
        CREATE TABLE item_tags (
          item_id TEXT NOT NULL,
          tag_id TEXT NOT NULL,
          PRIMARY KEY (item_id, tag_id),
          FOREIGN KEY (item_id) REFERENCES vault_items (id) ON DELETE CASCADE,
          FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
        );
      ''');

      // Indexes for fast lookup
      await txn.execute('CREATE INDEX idx_vault_items_category ON vault_items(category);');
      await txn.execute('CREATE INDEX idx_vault_items_favourite ON vault_items(is_favourite);');
      await txn.execute('CREATE INDEX idx_vault_items_updated ON vault_items(updated_at DESC);');
      await txn.execute('CREATE INDEX idx_password_entries_item ON password_entries(item_id);');
      await txn.execute('CREATE INDEX idx_identity_entries_item ON identity_entries(item_id);');
      await txn.execute('CREATE INDEX idx_document_entries_item ON document_entries(item_id);');
      await txn.execute('CREATE INDEX idx_notes_item ON notes(item_id);');
      await txn.execute('CREATE INDEX idx_contacts_item ON contacts(item_id);');
    });
  }

  static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration hooks for future schema versions
    if (oldVersion < 2) {
      // Future V2 migration logic
    }
  }
}

