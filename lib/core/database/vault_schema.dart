import 'package:sqflite_sqlcipher/sqflite.dart';

/// Database schema definitions, migrations, and table creation logic for SQLCipher
class VaultSchema {
  static const int currentVersion = 7;
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
          subcategory TEXT,
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
          attachment_path TEXT,
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
          thumbnail_path TEXT,
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
          tags TEXT,
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
          job_title TEXT,
          address TEXT,
          birthday TEXT,
          notes TEXT,
          tags TEXT,
          secondary_phone TEXT,
          secondary_email TEXT,
          attachment_path TEXT,
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
    // Migration hooks for schema versions
    if (oldVersion < 2) {
      // V2: Add optional attachment_path to identity_entries
      await _addColumn(db, 'identity_entries', 'attachment_path');
    }
    if (oldVersion < 3) {
      // V3: Extend notes with tags and contacts with full profile fields
      await _addColumn(db, 'notes', 'tags');
      await _addColumn(db, 'contacts', 'job_title');
      await _addColumn(db, 'contacts', 'birthday');
      await _addColumn(db, 'contacts', 'notes');
      await _addColumn(db, 'contacts', 'tags');
      await _addColumn(db, 'contacts', 'secondary_phone');
      await _addColumn(db, 'contacts', 'secondary_email');
    }
    if (oldVersion < 4) {
      // V4: Add attachment_path (photo) to contacts
      await _addColumn(db, 'contacts', 'attachment_path');
    }
    if (oldVersion < 5) {
      // V5: Persist item subcategory (password type, ID type, note/contact category)
      await _addColumn(db, 'vault_items', 'subcategory');
    }
    if (oldVersion < 6) {
      // V6: Remove the sample items that early builds seeded into every vault.
      await removeLegacySampleItems(db);
    }
    if (oldVersion < 7) {
      // V7: Encrypted thumbnails for the photo grid
      await _addColumn(db, 'document_entries', 'thumbnail_path');
    }
  }

  /// Adds a TEXT column only if its table exists and lacks it, so a migration can never fail
  /// on a database that already has the column (or predates the table).
  static Future<void> _addColumn(DatabaseExecutor db, String table, String column) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    if (info.isEmpty) return;
    if (info.any((c) => c['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column TEXT;');
  }

  /// Ids of the sample items early builds inserted on unlock. Real items never use these:
  /// their ids embed a 13-digit timestamp.
  static const Set<String> legacySampleIds = {
    'pwd_1', 'pwd_2', 'pwd_3', 'pwd_4', 'pwd_5', 'pwd_6',
    'id_1', 'id_2', 'id_3', 'id_4', 'id_5', 'id_6',
    'doc_1', 'doc_2', 'doc_3', 'doc_4', 'doc_5', 'doc_6',
    'photo_1', 'photo_2', 'photo_3', 'photo_4',
    'note_1', 'note_2', 'note_3', 'note_4', 'note_5', 'note_6',
    'contact_1', 'contact_2', 'contact_3', 'contact_4', 'contact_5', 'contact_6',
  };

  /// Deletes untouched sample items. If the user ever edited one, saving rewrote its detail row
  /// with the id `entry_<itemId>`; such items are kept as the user's own data.
  static Future<int> removeLegacySampleItems(DatabaseExecutor db) async {
    var removed = 0;
    final existing = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
        .map((r) => r['name'] as String)
        .toSet();
    final detailTables = const ['password_entries', 'identity_entries', 'document_entries', 'notes', 'contacts']
        .where(existing.contains)
        .toList();
    for (final id in legacySampleIds) {
      var edited = false;
      for (final table in detailTables) {
        final rows = await db.query(table, columns: ['id'], where: 'item_id = ? AND id = ?', whereArgs: [id, 'entry_$id']);
        if (rows.isNotEmpty) {
          edited = true;
          break;
        }
      }
      if (!edited) removed += await db.delete('vault_items', where: 'id = ?', whereArgs: [id]);
    }
    return removed;
  }
}

