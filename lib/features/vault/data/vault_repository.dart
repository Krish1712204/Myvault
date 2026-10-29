import 'dart:math';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../core/database/vault_database.dart';
import '../../../core/storage/encrypted_file_service.dart';
import '../../vault_items/data/mock_vault_data.dart';
import '../../vault_items/data/vault_item_model.dart';
import 'vault_models.dart';

class VaultRepository {
  final VaultDatabase _vaultDb;
  final EncryptedFileService _fileService;

  VaultRepository({
    required VaultDatabase vaultDb,
    required EncryptedFileService fileService,
  })  : _vaultDb = vaultDb,
        _fileService = fileService;

  Database get _db => _vaultDb.database;

  /// Fetches all vault items sorted by updated timestamp
  Future<List<VaultItem>> getAllItems() async {
    final rows = await _db.query('vault_items', orderBy: 'updated_at DESC');
    return Future.wait(rows.map((row) => _mapRowToVaultItem(row)));
  }

  /// Fetches items for a specific category
  Future<List<VaultItem>> getItemsByCategory(VaultCategory category) async {
    final rows = await _db.query(
      'vault_items',
      where: 'category = ?',
      whereArgs: [category.keyName],
      orderBy: 'updated_at DESC',
    );
    return Future.wait(rows.map((row) => _mapRowToVaultItem(row)));
  }

  /// Fetches items marked as favourite
  Future<List<VaultItem>> getFavouriteItems() async {
    final rows = await _db.query(
      'vault_items',
      where: 'is_favourite = 1',
      orderBy: 'updated_at DESC',
    );
    return Future.wait(rows.map((row) => _mapRowToVaultItem(row)));
  }

  /// Counts items by category
  Future<Map<VaultCategory, int>> getCategoryCounts() async {
    final counts = <VaultCategory, int>{
      for (final c in VaultCategory.values) c: 0,
    };

    final rows = await _db.rawQuery('''
      SELECT category, COUNT(*) as count 
      FROM vault_items 
      GROUP BY category
    ''');

    for (final row in rows) {
      final catKey = row['category'] as String?;
      final count = (row['count'] as num?)?.toInt() ?? 0;
      if (catKey != null) {
        counts[VaultCategory.fromKey(catKey)] = count;
      }
    }

    return counts;
  }

  /// Fetches a single vault item with its full detail record
  Future<VaultItem?> getItemById(String id) async {
    final rows = await _db.query(
      'vault_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return await _mapRowToVaultItem(rows.first);
  }

  /// Inserts a new vault item with its subtype entry inside a transaction
  Future<void> insertItem(
    VaultItem item, {
    PasswordEntry? passwordEntry,
    IdentityEntry? identityEntry,
    DocumentEntry? documentEntry,
    NoteEntry? noteEntry,
    ContactEntry? contactEntry,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      await txn.insert(
        'vault_items',
        {
          'id': item.id,
          'category': item.category.keyName,
          'title': item.title,
          'subtitle': item.subtitle,
          'is_favourite': item.isFavourite ? 1 : 0,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (passwordEntry != null) {
        await txn.insert('password_entries', passwordEntry.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      } else if (identityEntry != null) {
        await txn.insert('identity_entries', identityEntry.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      } else if (documentEntry != null) {
        await txn.insert('document_entries', documentEntry.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      } else if (noteEntry != null) {
        await txn.insert('notes', noteEntry.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      } else if (contactEntry != null) {
        await txn.insert('contacts', contactEntry.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Updates an existing vault item with its subtype entry inside a transaction
  Future<void> updateItem(
    VaultItem item, {
    PasswordEntry? passwordEntry,
    IdentityEntry? identityEntry,
    DocumentEntry? documentEntry,
    NoteEntry? noteEntry,
    ContactEntry? contactEntry,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      await txn.update(
        'vault_items',
        {
          'category': item.category.keyName,
          'title': item.title,
          'subtitle': item.subtitle,
          'is_favourite': item.isFavourite ? 1 : 0,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [item.id],
      );

      if (passwordEntry != null) {
        await txn.insert(
          'password_entries',
          passwordEntry.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else if (identityEntry != null) {
        await txn.insert(
          'identity_entries',
          identityEntry.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else if (documentEntry != null) {
        await txn.insert(
          'document_entries',
          documentEntry.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else if (noteEntry != null) {
        await txn.insert(
          'notes',
          noteEntry.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else if (contactEntry != null) {
        await txn.insert(
          'contacts',
          contactEntry.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Toggles an item's favourite status
  Future<void> toggleFavourite(String id) async {
    final rows = await _db.query('vault_items', columns: ['is_favourite'], where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final current = (rows.first['is_favourite'] as int? ?? 0) == 1;
    await _db.update(
      'vault_items',
      {
        'is_favourite': current ? 0 : 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes an item and cleans up associated encrypted files
  Future<void> deleteItem(String id) async {
    // Check if there is an associated document file
    final docRows = await _db.query('document_entries', columns: ['file_path'], where: 'item_id = ?', whereArgs: [id]);
    for (final row in docRows) {
      final filePath = row['file_path'] as String?;
      if (filePath != null && filePath.isNotEmpty) {
        await _fileService.deleteEncryptedFile(filePath);
      }
    }

    // Delete from vault_items (cascades to all detail tables)
    await _db.delete('vault_items', where: 'id = ?', whereArgs: [id]);
  }

  /// Searches items by query across titles, subtitles, usernames, and website URLs
  Future<List<VaultItem>> searchItems(String query) async {
    if (query.trim().isEmpty) return getAllItems();
    final cleanQuery = '%${query.trim().toLowerCase()}%';

    final rows = await _db.rawQuery('''
      SELECT DISTINCT v.* FROM vault_items v
      LEFT JOIN password_entries p ON v.id = p.item_id
      WHERE LOWER(v.title) LIKE ? 
         OR LOWER(v.subtitle) LIKE ? 
         OR LOWER(COALESCE(p.username, '')) LIKE ? 
         OR LOWER(COALESCE(p.website_url, '')) LIKE ?
      ORDER BY v.updated_at DESC
    ''', [cleanQuery, cleanQuery, cleanQuery, cleanQuery]);

    return Future.wait(rows.map((row) => _mapRowToVaultItem(row)));
  }

  /// Maps database row and joined subtype details to VaultItem
  Future<VaultItem> _mapRowToVaultItem(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    final categoryKey = row['category'] as String;
    final category = VaultCategory.fromKey(categoryKey);
    final title = row['title'] as String;
    final subtitle = (row['subtitle'] as String?) ?? '';
    final isFavourite = (row['is_favourite'] as int? ?? 0) == 1;
    final createdAt = row['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    final updatedAt = row['updated_at'] as int? ?? createdAt;
    final dateStr = _formatTimestamp(createdAt);

    String? username;
    String? password;
    String? url;
    String? details;
    String? size;

    if (category == VaultCategory.passwords) {
      final pRows = await _db.query('password_entries', where: 'item_id = ?', whereArgs: [id], limit: 1);
      if (pRows.isNotEmpty) {
        username = pRows.first['username'] as String?;
        password = pRows.first['encrypted_password'] as String?;
        url = pRows.first['website_url'] as String?;
        details = pRows.first['notes'] as String?;
      }
    } else if (category == VaultCategory.idCards) {
      final iRows = await _db.query('identity_entries', where: 'item_id = ?', whereArgs: [id], limit: 1);
      if (iRows.isNotEmpty) {
        details = iRows.first['document_number'] as String?;
      }
    } else if (category == VaultCategory.documents || category == VaultCategory.photos) {
      final dRows = await _db.query('document_entries', where: 'item_id = ?', whereArgs: [id], limit: 1);
      if (dRows.isNotEmpty) {
        final bytes = (dRows.first['file_size'] as int?) ?? 0;
        size = bytes > 1024 * 1024
            ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
            : '${(bytes / 1024).toStringAsFixed(0)} KB';
        details = dRows.first['file_name'] as String?;
      }
    } else if (category == VaultCategory.notes) {
      final nRows = await _db.query('notes', where: 'item_id = ?', whereArgs: [id], limit: 1);
      if (nRows.isNotEmpty) {
        details = nRows.first['content'] as String?;
      }
    } else if (category == VaultCategory.contacts) {
      final cRows = await _db.query('contacts', where: 'item_id = ?', whereArgs: [id], limit: 1);
      if (cRows.isNotEmpty) {
        details = cRows.first['phone_number'] as String?;
        username = cRows.first['email'] as String?;
      }
    }

    return VaultItem(
      id: id,
      title: title,
      subtitle: subtitle,
      category: category,
      username: username,
      password: password,
      url: url,
      details: details,
      isFavourite: isFavourite,
      date: dateStr,
      size: size,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static String _formatTimestamp(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[dt.month - 1];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} $month ${dt.year}, $hour:$minute $ampm';
  }

  /// Seeds initial mock data on first vault creation so existing UI is populated
  Future<void> seedInitialDataIfEmpty() async {
    final count = Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM vault_items')) ?? 0;
    if (count > 0) return;

    final random = Random();
    for (final item in MockVaultData.items) {
      PasswordEntry? pwd;
      IdentityEntry? idn;
      DocumentEntry? doc;
      NoteEntry? note;
      ContactEntry? contact;

      if (item.category == VaultCategory.passwords) {
        pwd = PasswordEntry(
          id: 'pwd_${item.id}',
          itemId: item.id,
          username: item.username,
          encryptedPassword: item.password ?? 'SampleP@ss#2026',
          websiteUrl: item.url,
          notes: item.details,
        );
      } else if (item.category == VaultCategory.idCards) {
        idn = IdentityEntry(
          id: 'idn_${item.id}',
          itemId: item.id,
          documentType: item.title,
          documentNumber: 'XXXX-XXXX-XXXX',
          fullName: 'Prathamesh Shelar',
          notes: item.details,
        );
      } else if (item.category == VaultCategory.documents || item.category == VaultCategory.photos) {
        doc = DocumentEntry(
          id: 'doc_${item.id}',
          itemId: item.id,
          filePath: 'seed_${item.id}.enc',
          fileName: item.title,
          fileSize: (random.nextInt(3000) + 500) * 1024,
          mimeType: item.category == VaultCategory.photos ? 'image/jpeg' : 'application/pdf',
          fileExtension: item.category == VaultCategory.photos ? '.jpg' : '.pdf',
          notes: item.details,
        );
      } else if (item.category == VaultCategory.notes) {
        note = NoteEntry(
          id: 'note_${item.id}',
          itemId: item.id,
          content: item.details ?? 'Personal project notes',
        );
      } else if (item.category == VaultCategory.contacts) {
        contact = ContactEntry(
          id: 'cnt_${item.id}',
          itemId: item.id,
          phoneNumber: '+91 98765 43210',
          email: item.username,
        );
      }

      await insertItem(
        item,
        passwordEntry: pwd,
        identityEntry: idn,
        documentEntry: doc,
        noteEntry: note,
        contactEntry: contact,
      );
    }
  }
}

