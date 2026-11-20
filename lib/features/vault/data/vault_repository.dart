import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../core/database/vault_database.dart';
import '../../../core/storage/encrypted_file_service.dart';
import '../../../shared/widgets/bold_text.dart';
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

  /// Detail tables, keyed by the categories whose rows they hold.
  static const Map<String, List<VaultCategory>> _detailTables = {
    'password_entries': [VaultCategory.passwords],
    'identity_entries': [VaultCategory.idCards],
    'document_entries': [VaultCategory.documents, VaultCategory.photos],
    'notes': [VaultCategory.notes],
    'contacts': [VaultCategory.contacts],
  };

  /// Fetches all vault items sorted by updated timestamp.
  /// Runs one query per table (six in total), however many items the vault holds.
  Future<List<VaultItem>> getAllItems() async {
    final rows = await _db.query('vault_items', orderBy: 'updated_at DESC');
    final details = <String, Map<String, Map<String, Object?>>>{};
    for (final table in _detailTables.keys) {
      details[table] = {
        for (final row in await _db.query(table)) row['item_id'] as String: row,
      };
    }
    return [for (final row in rows) _mapRowToVaultItem(row, _detailRowFor(row, details))];
  }

  static Map<String, Object?>? _detailRowFor(
    Map<String, Object?> itemRow,
    Map<String, Map<String, Map<String, Object?>>> details,
  ) {
    final category = VaultCategory.fromKey(itemRow['category'] as String);
    for (final entry in _detailTables.entries) {
      if (entry.value.contains(category)) return details[entry.key]![itemRow['id'] as String];
    }
    return null;
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
    final row = rows.first;
    final category = VaultCategory.fromKey(row['category'] as String);
    Map<String, Object?>? detail;
    for (final entry in _detailTables.entries) {
      if (!entry.value.contains(category)) continue;
      final found = await _db.query(entry.key, where: 'item_id = ?', whereArgs: [id], limit: 1);
      detail = found.isEmpty ? null : found.first;
    }
    return _mapRowToVaultItem(row, detail);
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
          'subcategory': item.subcategory,
          'is_favourite': item.isFavourite ? 1 : 0,
          'created_at': now,
          'updated_at': now,
        },
        // Fail rather than overwrite: an id collision must never replace someone's item.
        conflictAlgorithm: ConflictAlgorithm.abort,
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
    final oldPaths = await _attachmentPaths(item.id);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      await txn.update(
        'vault_items',
        {
          'category': item.category.keyName,
          'title': item.title,
          'subtitle': item.subtitle,
          'subcategory': item.subcategory,
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

    // Remove files that the update replaced (new document file, ID scan or contact photo).
    final newPaths = await _attachmentPaths(item.id);
    await _deleteFiles(oldPaths.difference(newPaths));
  }

  /// Records a generated thumbnail without touching the item's updated time.
  Future<void> setThumbnailPath(String itemId, String path) async {
    await _db.update('document_entries', {'thumbnail_path': path}, where: 'item_id = ?', whereArgs: [itemId]);
  }

  /// Toggles an item's favourite status
  Future<void> toggleFavourite(String id) async {
    final rows = await _db.query('vault_items', columns: ['is_favourite'], where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final current = (rows.first['is_favourite'] as int? ?? 0) == 1;
    // Favouriting is not an edit, so updated_at is left alone: it must not reorder
    // "Recent" items or change the item's "last modified" time.
    await _db.update(
      'vault_items',
      {'is_favourite': current ? 0 : 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes an item and cleans up associated encrypted files
  Future<void> deleteItem(String id) async {
    final paths = await _attachmentPaths(id);

    // Delete the row first (cascades to all detail tables). Files are removed only
    // after that succeeds, so a failed delete never leaves an item with missing files.
    await _db.delete('vault_items', where: 'id = ?', whereArgs: [id]);
    await _deleteFiles(paths);
  }

  /// Every encrypted file referenced by an item: document file, ID scan, contact photo.
  Future<Set<String>> _attachmentPaths(String itemId) async {
    final paths = <String>{};
    Future<void> collect(String table, String column) async {
      final rows = await _db.query(table, columns: [column], where: 'item_id = ?', whereArgs: [itemId]);
      for (final row in rows) {
        final path = row[column] as String?;
        if (path != null && path.isNotEmpty) paths.add(path);
      }
    }

    await collect('document_entries', 'file_path');
    await collect('document_entries', 'thumbnail_path');
    await collect('identity_entries', 'attachment_path');
    await collect('contacts', 'attachment_path');
    return paths;
  }

  Future<void> _deleteFiles(Iterable<String> paths) async {
    for (final path in paths) {
      await _fileService.deleteEncryptedFile(path);
    }
  }

  /// Maps a vault_items row and its detail-table row (if any) to a VaultItem.
  VaultItem _mapRowToVaultItem(Map<String, Object?> row, Map<String, Object?>? detail) {
    final id = row['id'] as String;
    final categoryKey = row['category'] as String;
    final category = VaultCategory.fromKey(categoryKey);
    final title = row['title'] as String;
    var subtitle = (row['subtitle'] as String?) ?? '';
    final subcategory = row['subcategory'] as String?;
    final isFavourite = (row['is_favourite'] as int? ?? 0) == 1;
    final createdAt = row['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    final updatedAt = row['updated_at'] as int? ?? createdAt;
    final dateStr = _formatTimestamp(createdAt);

    String? username;
    String? password;
    String? url;
    String? details;
    String? size;

    // Identity specific
    String? documentType;
    String? documentNumber;
    String? fullName;
    String? issuedDate;
    String? expiryDate;
    String? issuingCountry;
    String? attachmentPath;

    // Document & Photo specific
    String? filePath;
    String? fileName;
    int? fileSize;
    String? mimeType;
    String? fileExtension;
    String? thumbnailPath;

    // Notes specific
    String? colorTag;
    String? tags;

    // Contacts specific
    String? phoneNumber;
    String? email;
    String? company;
    String? jobTitle;
    String? address;
    String? birthday;
    String? secondaryPhone;
    String? secondaryEmail;

    if (category == VaultCategory.passwords) {
      final pRows = [if (detail != null) detail];
      if (pRows.isNotEmpty) {
        username = pRows.first['username'] as String?;
        password = pRows.first['encrypted_password'] as String?;
        url = pRows.first['website_url'] as String?;
        details = pRows.first['notes'] as String?;
      }
    } else if (category == VaultCategory.idCards) {
      final iRows = [if (detail != null) detail];
      if (iRows.isNotEmpty) {
        final iRow = iRows.first;
        documentType = iRow['document_type'] as String?;
        documentNumber = iRow['document_number'] as String?;
        fullName = iRow['full_name'] as String?;
        issuedDate = iRow['issued_date'] as String?;
        expiryDate = iRow['expiry_date'] as String?;
        issuingCountry = iRow['issuing_country'] as String?;
        details = iRow['notes'] as String?;
        attachmentPath = iRow['attachment_path'] as String?;
      }
    } else if (category == VaultCategory.documents || category == VaultCategory.photos) {
      final dRows = [if (detail != null) detail];
      if (dRows.isNotEmpty) {
        final dRow = dRows.first;
        filePath = dRow['file_path'] as String?;
        fileName = dRow['file_name'] as String?;
        fileSize = dRow['file_size'] as int?;
        mimeType = dRow['mime_type'] as String?;
        fileExtension = dRow['file_extension'] as String?;
        thumbnailPath = dRow['thumbnail_path'] as String?;
        details = dRow['notes'] as String?;
        final bytes = fileSize ?? 0;
        size = bytes > 1024 * 1024
            ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
            : '${(bytes / 1024).toStringAsFixed(0)} KB';
      }
    } else if (category == VaultCategory.notes) {
      final nRows = [if (detail != null) detail];
      if (nRows.isNotEmpty) {
        final nRow = nRows.first;
        details = nRow['content'] as String?;
        // Always derived from the content: older builds stored garbled previews.
        if (details != null) subtitle = notePreview(details);
        colorTag = nRow['color_tag'] as String?;
        tags = nRow['tags'] as String?;
      }
    } else if (category == VaultCategory.contacts) {
      final cRows = [if (detail != null) detail];
      if (cRows.isNotEmpty) {
        final cRow = cRows.first;
        phoneNumber = cRow['phone_number'] as String?;
        email = cRow['email'] as String?;
        company = cRow['company'] as String?;
        jobTitle = cRow['job_title'] as String?;
        address = cRow['address'] as String?;
        birthday = cRow['birthday'] as String?;
        details = cRow['notes'] as String?;
        tags = cRow['tags'] as String?;
        secondaryPhone = cRow['secondary_phone'] as String?;
        secondaryEmail = cRow['secondary_email'] as String?;
        attachmentPath = cRow['attachment_path'] as String?;
        username = email;
      }
    }

    return VaultItem(
      id: id,
      title: title,
      subtitle: subtitle,
      category: category,
      subcategory: subcategory,
      username: username,
      password: password,
      url: url,
      details: details,
      isFavourite: isFavourite,
      date: dateStr,
      size: size,
      createdAt: createdAt,
      updatedAt: updatedAt,
      documentType: documentType,
      documentNumber: documentNumber,
      fullName: fullName,
      issuedDate: issuedDate,
      expiryDate: expiryDate,
      issuingCountry: issuingCountry,
      attachmentPath: attachmentPath,
      filePath: filePath,
      fileName: fileName,
      fileSize: fileSize,
      mimeType: mimeType,
      fileExtension: fileExtension,
      thumbnailPath: thumbnailPath,
      colorTag: colorTag,
      tags: tags,
      phoneNumber: phoneNumber,
      email: email,
      company: company,
      jobTitle: jobTitle,
      address: address,
      birthday: birthday,
      secondaryPhone: secondaryPhone,
      secondaryEmail: secondaryEmail,
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
}
