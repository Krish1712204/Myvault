import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/domain/vault_auth_notifier.dart';
import '../../features/auth/domain/vault_auth_state.dart';
import '../../features/vault/data/vault_models.dart';
import '../../features/vault/data/vault_repository.dart';
import '../../core/storage/thumbnail_service.dart';
import '../../core/backup/google_drive_backup_service.dart';
import '../../features/vault_items/data/vault_item_model.dart';
import '../widgets/bold_text.dart';

/// Manages vault items state (supports real SQLCipher storage via repository)
class VaultItemsNotifier extends StateNotifier<List<VaultItem>> {
  final VaultRepository _repository;
  final Ref _ref;

  VaultItemsNotifier(this._repository, this._ref) : super([]) {
    _initListener();
  }

  void _initListener() {
    _ref.listen<VaultAuthState>(vaultAuthStateProvider, (previous, next) {
      if (next.status == VaultStatus.unlocked) {
        loadItems();
        if (previous?.status != VaultStatus.unlocked) {
          // Upload changes that were made just before the vault last locked.
          _ref.read(googleDriveBackupServiceProvider).resumePendingBackup();
        }
      } else if (next.status == VaultStatus.locked || next.status == VaultStatus.uninitialized) {
        _thumbnailCache.clear();
        state = [];
      }
    });

    if (_ref.read(vaultAuthStateProvider).status == VaultStatus.unlocked) {
      loadItems();
    }
  }

  /// Reloads all items from the encrypted database.
  /// On failure the current state is kept as-is; it is never replaced with sample data.
  Future<bool> loadItems() async {
    try {
      final items = await _repository.getAllItems();
      state = items;
      return true;
    } catch (_) {
      return false;
    }
  }

  static final Random _idRandom = Random.secure();

  /// A new, unique item id: microsecond timestamp plus 32 random bits, so items saved in
  /// the same instant (double taps, bulk imports) never collide.
  static String _newItemId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_idRandom.nextInt(1 << 32).toRadixString(36)}';

  void _requestAutomaticDriveBackup() {
    _ref.read(googleDriveBackupServiceProvider).requestAutomaticBackup();
  }

  /// Saves (creates or updates) a password item with full relational mapping
  Future<void> savePasswordItem({
    String? id,
    required String title,
    String? websiteUrl,
    String? username,
    required String password,
    String subcategory = 'Website',
    String? notes,
    bool isFavourite = false,
  }) async {
    final isNew = id == null || id.isEmpty;
    final itemId = isNew ? _newItemId('pwd') : id;
    final now = DateTime.now().millisecondsSinceEpoch;

    final item = VaultItem(
      id: itemId,
      title: title,
      subtitle: (username != null && username.isNotEmpty) ? username : subcategory,
      category: VaultCategory.passwords,
      url: websiteUrl,
      username: username,
      password: password,
      details: notes,
      subcategory: subcategory,
      isFavourite: isFavourite,
      createdAt: now,
      updatedAt: now,
    );

    final pwdEntry = PasswordEntry(
      id: 'entry_$itemId',
      itemId: itemId,
      username: username,
      encryptedPassword: password,
      websiteUrl: websiteUrl,
      notes: notes,
    );

    if (isNew) {
      await _repository.insertItem(item, passwordEntry: pwdEntry);
    } else {
      await _repository.updateItem(item, passwordEntry: pwdEntry);
    }

    await loadItems();
    _requestAutomaticDriveBackup();
  }

  /// Saves (creates or updates) an ID Card / Identity item
  Future<void> saveIdentityItem({
    String? id,
    required String title,
    required String documentType,
    String? documentNumber,
    String? fullName,
    String? issuedDate,
    String? expiryDate,
    String? issuingCountry,
    String subcategory = 'Government',
    String? notes,
    String? attachmentPath,
    bool isFavourite = false,
  }) async {
    final isNew = id == null || id.isEmpty;
    final itemId = isNew ? _newItemId('id') : id;
    final now = DateTime.now().millisecondsSinceEpoch;

    final item = VaultItem(
      id: itemId,
      title: title,
      subtitle: subcategory.isNotEmpty ? subcategory : documentType,
      category: VaultCategory.idCards,
      details: notes,
      subcategory: subcategory,
      isFavourite: isFavourite,
      createdAt: now,
      updatedAt: now,
      documentType: documentType,
      documentNumber: documentNumber,
      fullName: fullName,
      issuedDate: issuedDate,
      expiryDate: expiryDate,
      issuingCountry: issuingCountry,
      attachmentPath: attachmentPath,
    );

    final idEntry = IdentityEntry(
      id: 'entry_$itemId',
      itemId: itemId,
      documentType: documentType,
      documentNumber: documentNumber ?? '',
      fullName: fullName,
      issuedDate: issuedDate,
      expiryDate: expiryDate,
      issuingCountry: issuingCountry,
      notes: notes,
      attachmentPath: attachmentPath,
    );

    if (isNew) {
      await _repository.insertItem(item, identityEntry: idEntry);
    } else {
      await _repository.updateItem(item, identityEntry: idEntry);
    }

    await loadItems();
    _requestAutomaticDriveBackup();
  }

  /// Encrypts an attached file or photo for an identity item
  Future<String> encryptAttachment({
    required List<int> fileBytes,
    required String originalFileName,
  }) async {
    final session = _ref.read(vaultSessionProvider);
    final vek = session.vek;
    if (vek == null) {
      throw StateError('Vault is locked. Cannot encrypt attachment.');
    }
    final crypto = _ref.read(vaultCryptoServiceProvider);
    final fileStorageKey = await crypto.deriveFileStorageKey(vek);
    final fileService = _ref.read(encryptedFileServiceProvider);
    final stored = await fileService.encryptAndSave(
      fileBytes: fileBytes,
      originalFileName: originalFileName,
      fileStorageKey: fileStorageKey,
    );
    return stored.relativePath;
  }

  /// Saves (creates or updates) a Document or Photo item, encrypting the file contents
  Future<void> saveDocumentItem({
    String? id,
    required String title,
    required VaultCategory category,
    required String originalFileName,
    required List<int> fileBytes,
    String? notes,
    String? documentDate,
    bool isFavourite = false,
    bool refresh = true,
  }) async {
    final session = _ref.read(vaultSessionProvider);
    final vek = session.vek;
    if (vek == null) {
      throw StateError('Vault is locked. Cannot encrypt document.');
    }

    final isNew = id == null || id.isEmpty;
    final itemId = isNew ? _newItemId('doc') : id;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Encrypt file bytes using derived storage key
    final crypto = _ref.read(vaultCryptoServiceProvider);
    final fileStorageKey = await crypto.deriveFileStorageKey(vek);
    final fileService = _ref.read(encryptedFileServiceProvider);

    final stored = await fileService.encryptAndSave(
      fileBytes: fileBytes,
      originalFileName: originalFileName,
      fileStorageKey: fileStorageKey,
    );

    String? thumbnailPath;
    if (canMakeThumbnail(extension: stored.fileExtension, mimeType: stored.mimeType)) {
      final thumb = await makeFileThumbnail(
        Uint8List.fromList(fileBytes),
        extension: stored.fileExtension,
        mimeType: stored.mimeType,
      );
      if (thumb != null) {
        thumbnailPath = (await fileService.encryptAndSave(
          fileBytes: thumb,
          originalFileName: 'thumb.png',
          fileStorageKey: fileStorageKey,
        ))
            .relativePath;
        _thumbnailCache[itemId] = thumb;
      }
    }

    final sizeStr = stored.fileSize > 1024 * 1024
        ? '${(stored.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(stored.fileSize / 1024).toStringAsFixed(0)} KB';

    final item = VaultItem(
      id: itemId,
      title: title,
      subtitle: '${stored.fileExtension.toUpperCase().replaceAll('.', '')} · $sizeStr',
      category: category,
      details: notes,
      isFavourite: isFavourite,
      createdAt: now,
      updatedAt: now,
      filePath: stored.relativePath,
      fileName: stored.fileName,
      fileSize: stored.fileSize,
      mimeType: stored.mimeType,
      fileExtension: stored.fileExtension,
      thumbnailPath: thumbnailPath,
    );

    final docEntry = DocumentEntry(
      id: 'entry_$itemId',
      itemId: itemId,
      filePath: stored.relativePath,
      fileName: stored.fileName,
      fileSize: stored.fileSize,
      mimeType: stored.mimeType,
      fileExtension: stored.fileExtension,
      notes: notes,
      thumbnailPath: thumbnailPath,
    );

    if (isNew) {
      await _repository.insertItem(item, documentEntry: docEntry);
    } else {
      await _repository.updateItem(item, documentEntry: docEntry);
    }

    if (refresh) {
      await loadItems();
      _requestAutomaticDriveBackup();
    }
  }

  /// Saves several picked files as separate items, one after another.
  /// [onProgress] receives (done, total). Returns how many were saved.
  Future<int> saveDocumentItems({
    required List<({String name, Future<List<int>> Function() read})> files,
    required VaultCategory category,
    bool isFavourite = false,
    void Function(int done, int total)? onProgress,
  }) async {
    var saved = 0;
    try {
      for (final file in files) {
        final dot = file.name.lastIndexOf('.');
        await saveDocumentItem(
          title: dot > 0 ? file.name.substring(0, dot) : file.name,
          category: category,
          originalFileName: file.name,
          // Read one file at a time so a large batch never sits in memory at once.
          fileBytes: await file.read(),
          isFavourite: isFavourite,
          refresh: false,
        );
        saved++;
        onProgress?.call(saved, files.length);
      }
    } finally {
      await loadItems();
      if (saved > 0) _requestAutomaticDriveBackup();
    }
    return saved;
  }

  /// Decrypted thumbnails kept in memory while unlocked; cleared on lock.
  final Map<String, Uint8List> _thumbnailCache = {};
  static const int _thumbnailCacheLimit = 150;
  Future<void> _thumbnailQueue = Future.value();

  /// Grid thumbnail for an image or PDF item. Files saved before thumbnails existed get one
  /// generated (from the full file) on first request; requests run one at a time so a
  /// screen full of old files never decrypts many large files at once.
  Future<Uint8List?> getThumbnail(VaultItem item) {
    final cached = _thumbnailCache[item.id];
    if (cached != null) return Future.value(cached);

    final result = _thumbnailQueue.then((_) => _loadThumbnail(item));
    _thumbnailQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<Uint8List?> _loadThumbnail(VaultItem item) async {
    final cached = _thumbnailCache[item.id];
    if (cached != null) return cached;
    if (item.filePath == null) return null;
    // Only images and PDFs have previews; never decrypt other files just to find that out.
    if (!canMakeThumbnail(extension: item.fileExtension, mimeType: item.mimeType)) return null;

    Uint8List? thumb;
    final thumbPath = item.thumbnailPath;
    if (thumbPath != null && thumbPath.isNotEmpty) {
      try {
        thumb = await getDecryptedFileBytes(thumbPath);
      } catch (_) {
        thumb = null; // missing (e.g. after restore) or unreadable: regenerate below
      }
    }

    if (thumb == null) {
      final session = _ref.read(vaultSessionProvider);
      final vek = session.vek;
      if (vek == null) return null;
      final full = await getDecryptedFileBytes(item.filePath!);
      thumb = await makeFileThumbnail(full, extension: item.fileExtension, mimeType: item.mimeType);
      if (thumb == null) return null;
      final key = await _ref.read(vaultCryptoServiceProvider).deriveFileStorageKey(vek);
      final stored = await _ref.read(encryptedFileServiceProvider).encryptAndSave(
            fileBytes: thumb,
            originalFileName: 'thumb.png',
            fileStorageKey: key,
          );
      final old = item.thumbnailPath;
      await _repository.setThumbnailPath(item.id, stored.relativePath);
      if (old != null && old.isNotEmpty) {
        await _ref.read(encryptedFileServiceProvider).deleteEncryptedFile(old);
      }
    }

    if (_thumbnailCache.length >= _thumbnailCacheLimit) {
      _thumbnailCache.remove(_thumbnailCache.keys.first);
    }
    _thumbnailCache[item.id] = thumb;
    return thumb;
  }

  /// Updates document metadata (e.g. title, category, notes, favourite) without re-encrypting the file
  Future<void> updateDocumentMetadata({
    required String id,
    required String title,
    required VaultCategory category,
    String? notes,
    bool? isFavourite,
  }) async {
    final existing = await _repository.getItemById(id);
    if (existing == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedItem = existing.copyWith(
      title: title,
      category: category,
      details: notes ?? existing.details,
      isFavourite: isFavourite ?? existing.isFavourite,
      updatedAt: now,
    );

    final docEntry = DocumentEntry(
      id: 'entry_$id',
      itemId: id,
      filePath: existing.filePath ?? '',
      fileName: existing.fileName ?? title,
      fileSize: existing.fileSize ?? 0,
      mimeType: existing.mimeType ?? 'application/octet-stream',
      fileExtension: existing.fileExtension ?? '',
      notes: notes ?? existing.details,
      thumbnailPath: existing.thumbnailPath,
    );

    await _repository.updateItem(updatedItem, documentEntry: docEntry);
    await loadItems();
    _requestAutomaticDriveBackup();
  }

  /// Decrypts file contents on demand in memory (zero plaintext file written to disk)
  Future<Uint8List> getDecryptedFileBytes(String relativePath) async {
    final session = _ref.read(vaultSessionProvider);
    final vek = session.vek;
    if (vek == null) {
      throw StateError('Vault is locked. Cannot decrypt file.');
    }
    final crypto = _ref.read(vaultCryptoServiceProvider);
    final fileStorageKey = await crypto.deriveFileStorageKey(vek);
    final fileService = _ref.read(encryptedFileServiceProvider);
    final bytes = await fileService.decrypt(
      relativePath: relativePath,
      fileStorageKey: fileStorageKey,
    );
    return Uint8List.fromList(bytes);
  }

  /// Creates a safe temporary preview file (e.g. for external PDF viewer) with cleanup capability
  Future<File> createTemporaryPreviewFile(String relativePath, String originalFileName) async {
    final session = _ref.read(vaultSessionProvider);
    final vek = session.vek;
    if (vek == null) {
      throw StateError('Vault is locked. Cannot preview file.');
    }
    final crypto = _ref.read(vaultCryptoServiceProvider);
    final fileStorageKey = await crypto.deriveFileStorageKey(vek);
    final fileService = _ref.read(encryptedFileServiceProvider);
    return await fileService.createTemporaryPreviewFile(
      relativePath: relativePath,
      fileName: originalFileName,
      fileStorageKey: fileStorageKey,
    );
  }

  /// Cleans up any leftover temporary preview files
  Future<void> clearTemporaryPreviews() async {
    final fileService = _ref.read(encryptedFileServiceProvider);
    await fileService.clearTemporaryPreviews();
  }

  /// Saves (creates or updates) a Note item
  Future<void> saveNoteItem({
    String? id,
    required String title,
    required String content,
    String? category,
    String? colorTag,
    String? tags,
    bool isFavourite = false,
  }) async {
    final isNew = id == null || id.isEmpty;
    final itemId = isNew ? _newItemId('note') : id;
    final now = DateTime.now().millisecondsSinceEpoch;

    final item = VaultItem(
      id: itemId,
      title: title,
      subtitle: notePreview(content),
      category: VaultCategory.notes,
      details: content,
      subcategory: category ?? 'General',
      isFavourite: isFavourite,
      createdAt: now,
      updatedAt: now,
      colorTag: colorTag,
      tags: tags,
    );

    final noteEntry = NoteEntry(
      id: 'entry_$itemId',
      itemId: itemId,
      content: content,
      colorTag: colorTag,
      tags: tags,
    );

    if (isNew) {
      await _repository.insertItem(item, noteEntry: noteEntry);
    } else {
      await _repository.updateItem(item, noteEntry: noteEntry);
    }

    await loadItems();
    _requestAutomaticDriveBackup();
  }

  /// Saves (creates or updates) a Contact item
  Future<void> saveContactItem({
    String? id,
    required String fullName,
    required String phoneNumber,
    String? email,
    String? company,
    String? jobTitle,
    String? address,
    String? birthday,
    String? notes,
    String? category,
    String? tags,
    String? secondaryPhone,
    String? secondaryEmail,
    String? attachmentPath,
    bool isFavourite = false,
    bool refresh = true,
  }) async {
    final isNew = id == null || id.isEmpty;
    final itemId = isNew ? _newItemId('cnt') : id;
    final now = DateTime.now().millisecondsSinceEpoch;

    final subtitle = [
      if (jobTitle != null && jobTitle.isNotEmpty) jobTitle,
      if (company != null && company.isNotEmpty) company,
      if ((jobTitle == null || jobTitle.isEmpty) && (company == null || company.isEmpty)) phoneNumber,
    ].join(' · ');

    final item = VaultItem(
      id: itemId,
      title: fullName,
      subtitle: subtitle,
      category: VaultCategory.contacts,
      details: notes,
      subcategory: category ?? 'Personal',
      isFavourite: isFavourite,
      createdAt: now,
      updatedAt: now,
      phoneNumber: phoneNumber,
      email: email,
      company: company,
      jobTitle: jobTitle,
      address: address,
      birthday: birthday,
      tags: tags,
      secondaryPhone: secondaryPhone,
      secondaryEmail: secondaryEmail,
      attachmentPath: attachmentPath,
      username: email,
    );

    final contactEntry = ContactEntry(
      id: 'entry_$itemId',
      itemId: itemId,
      phoneNumber: phoneNumber,
      email: email,
      company: company,
      jobTitle: jobTitle,
      address: address,
      birthday: birthday,
      notes: notes,
      tags: tags,
      secondaryPhone: secondaryPhone,
      secondaryEmail: secondaryEmail,
      attachmentPath: attachmentPath,
    );

    if (isNew) {
      await _repository.insertItem(item, contactEntry: contactEntry);
    } else {
      await _repository.updateItem(item, contactEntry: contactEntry);
    }

    if (refresh) {
      await loadItems();
      _requestAutomaticDriveBackup();
    }
  }

  /// Decodes Quoted-Printable encoded strings (vCard 2.1 standard) into UTF-8.
  static String _decodeQuotedPrintable(String input) {
    final cleaned = input.replaceAll(RegExp(r'=+(?:\r\n|\r|\n)'), '');
    final bytes = <int>[];
    int i = 0;
    while (i < cleaned.length) {
      if (cleaned[i] == '=' && i + 2 < cleaned.length) {
        final hex = cleaned.substring(i + 1, i + 3);
        final byteVal = int.tryParse(hex, radix: 16);
        if (byteVal != null) {
          bytes.add(byteVal);
          i += 3;
          continue;
        }
      }
      bytes.add(cleaned.codeUnitAt(i));
      i++;
    }
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }

  /// Decodes and cleans a vCard property value (handles Quoted-Printable, UTF-8, and escapes).
  static String _cleanVcfValue(String rawValue, String keyOrParams) {
    String val = rawValue;
    final upperKey = keyOrParams.toUpperCase();
    // Some exporters omit the ENCODING parameter, so also accept a value that contains a
    // quoted-printable UTF-8 sequence (=C3=A9 ...). A lone "=12" in ordinary text is not one.
    final isQP = _isQuotedPrintableParams(upperKey) || _qpUtf8Sequence.hasMatch(val);

    if (isQP) {
      val = _decodeQuotedPrintable(val);
    }

    val = val
        .replaceAll(r'\,', ',')
        .replaceAll(r'\;', ';')
        .replaceAll(r'\:', ':')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\n', ' ')
        .replaceAll(r'\N', ' ')
        .trim();

    if (val.startsWith('"') && val.endsWith('"') && val.length >= 2) {
      val = val.substring(1, val.length - 1).trim();
    }
    return val;
  }

  /// Parses every contact in a VCF file (vCard 2.1/3.0/4.0), sorted by name ascending.
  /// Pure, so the parser can be tested without a vault.
  static List<ParsedVcfContact> parseVcfContacts(String vcfContent) {
    if (vcfContent.trim().isEmpty) return const [];

    // Normalize line endings and strip BOM, then unfold into logical property lines.
    final normalized = vcfContent.replaceFirst('\uFEFF', '').replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final cardMatches = _splitVcards(_unfoldVcfLines(normalized));

    if (cardMatches.isEmpty) {
      return const [];
    }

    final parsedList = <ParsedVcfContact>[];

    for (final lines in cardMatches) {

      String formattedName = '';
      String structuredName = '';
      String organization = '';
      String nickname = '';
      String phoneNumber = '';
      String? email;
      Uint8List? photoBytes;

      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;

        final colonIndex = line.indexOf(':');
        if (colonIndex == -1) continue;

        var keyPart = line.substring(0, colonIndex).trim();
        final rawVal = line.substring(colonIndex + 1).trim();
        if (rawVal.isEmpty) continue;

        // Strip group prefix (e.g. item1.FN -> FN, item2.TEL -> TEL)
        if (keyPart.contains('.')) {
          final dotIdx = keyPart.indexOf('.');
          keyPart = keyPart.substring(dotIdx + 1).trim();
        }

        final keyUpper = keyPart.toUpperCase();
        final decodedVal = _cleanVcfValue(rawVal, keyPart);

        if (keyUpper == 'FN' || keyUpper.startsWith('FN;') || keyUpper.startsWith('FN:')) {
          if (decodedVal.isNotEmpty) {
            formattedName = decodedVal;
          }
        } else if (keyUpper == 'N' || keyUpper.startsWith('N;') || keyUpper.startsWith('N:')) {
          if (decodedVal.isNotEmpty) {
            structuredName = decodedVal;
          }
        } else if (keyUpper == 'ORG' || keyUpper.startsWith('ORG;') || keyUpper.startsWith('ORG:')) {
          if (organization.isEmpty && decodedVal.isNotEmpty) {
            organization = decodedVal.split(';').first.trim();
          }
        } else if (keyUpper == 'NICKNAME' || keyUpper.startsWith('NICKNAME;')) {
          if (nickname.isEmpty && decodedVal.isNotEmpty) {
            nickname = decodedVal;
          }
        } else if (keyUpper == 'TEL' || keyUpper.startsWith('TEL;') || keyUpper.startsWith('TEL:')) {
          if (phoneNumber.isEmpty && decodedVal.isNotEmpty) {
            phoneNumber = decodedVal;
          }
        } else if (keyUpper == 'EMAIL' || keyUpper.startsWith('EMAIL;') || keyUpper.startsWith('EMAIL:')) {
          if ((email == null || email.isEmpty) && decodedVal.isNotEmpty) {
            email = decodedVal;
          }
        } else if (keyUpper.startsWith('PHOTO')) {
          try {
            var base64Str = rawVal;
            if (base64Str.contains(',')) {
              base64Str = base64Str.split(',').last;
            }
            base64Str = base64Str.replaceAll(RegExp(r'\s+'), '');
            if (base64Str.isNotEmpty) {
              photoBytes = base64Decode(base64Str);
            }
          } catch (_) {}
        }
      }

      // Determine Contact Name with strict priority:
      // 1. FN (Formatted Name is canonical)
      // 2. Structured N (Prefix + First + Middle + Last + Suffix)
      // 3. Nickname
      // 4. Organization
      // 5. Phone Number
      // 6. Email
      String contactName = '';

      if (formattedName.isNotEmpty) {
        contactName = formattedName;
      } else if (structuredName.isNotEmpty) {
        final nParts = structuredName.split(';');
        final lastName = nParts.isNotEmpty ? nParts[0].trim() : '';
        final firstName = nParts.length > 1 ? nParts[1].trim() : '';
        final middleName = nParts.length > 2 ? nParts[2].trim() : '';
        final prefix = nParts.length > 3 ? nParts[3].trim() : '';
        final suffix = nParts.length > 4 ? nParts[4].trim() : '';
        final constructed = [prefix, firstName, middleName, lastName, suffix]
            .where((p) => p.isNotEmpty)
            .join(' ')
            .trim();
        if (constructed.isNotEmpty) {
          contactName = constructed;
        }
      }

      if (contactName.isEmpty && nickname.isNotEmpty) {
        contactName = nickname;
      }
      if (contactName.isEmpty && organization.isNotEmpty) {
        contactName = organization;
      }
      if (contactName.isEmpty && phoneNumber.isNotEmpty) {
        contactName = phoneNumber;
      }
      if (contactName.isEmpty && email != null && email.isNotEmpty) {
        contactName = email;
      }

      // Skip only if record has zero identifiers
      if (contactName.isEmpty && phoneNumber.isEmpty && (email == null || email.isEmpty)) {
        continue;
      }

      parsedList.add(ParsedVcfContact(
        fullName: contactName,
        phoneNumber: phoneNumber,
        email: email,
        company: organization.isEmpty ? null : organization,
        photoBytes: photoBytes,
      ));
    }

    if (parsedList.isEmpty) {
      return const [];
    }

    // Sort in ascending alphabetical order by Contact Name
    parsedList.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

    return parsedList;
  }

  /// Bulk imports contacts from a VCF string, parsing names, phones, emails, organisations and
  /// base64 photos, sorting them in ascending alphabetical order by Contact Name, and saving
  /// them to the vault. Contacts already in the vault (same name and phone) are skipped.
  Future<({int imported, int duplicates})> importContactsFromVcf(String vcfContent) async {
    final session = _ref.read(vaultSessionProvider);
    final vek = session.vek;
    if (vek == null) {
      throw StateError('Vault is locked. Cannot import contacts.');
    }

    final parsedList = parseVcfContacts(vcfContent);
    if (parsedList.isEmpty) return (imported: 0, duplicates: 0);

    // Skip contacts already in the vault (same name and phone), so importing the same file
    // twice does not create duplicates. Also dedupes repeats within the file.
    String identity(String name, String? phone) =>
        '${name.trim().toLowerCase()}|${(phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '')}';
    final known = {
      for (final item in state.where((i) => i.category == VaultCategory.contacts))
        identity(item.title, item.phoneNumber),
    };

    int count = 0;
    int duplicates = 0;
    for (final contact in parsedList) {
      if (!known.add(identity(contact.fullName, contact.phoneNumber))) {
        duplicates++;
        continue;
      }
      String? attachmentPath;
      if (contact.photoBytes != null && contact.photoBytes!.isNotEmpty) {
        try {
          final cleanName = contact.fullName.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
          attachmentPath = await encryptAttachment(
            fileBytes: contact.photoBytes!,
            originalFileName: '${cleanName}_photo.jpg',
          );
        } catch (_) {}
      }

      await saveContactItem(
        fullName: contact.fullName,
        phoneNumber: contact.phoneNumber,
        email: contact.email,
        company: contact.company,
        attachmentPath: attachmentPath,
        refresh: false,
      );
      count++;
    }

    await loadItems();
    if (count > 0) _requestAutomaticDriveBackup();
    return (imported: count, duplicates: duplicates);
  }

  static final RegExp _qpUtf8Sequence = RegExp(r'=[C-Fc-f][0-9A-Fa-f]=[89ABab][0-9A-Fa-f]');

  static bool _isQuotedPrintableParams(String upperParams) =>
      upperParams.contains('QUOTED-PRINTABLE') || upperParams.contains('ENCODING=QP');

  /// Joins folded lines into logical property lines:
  /// - RFC 2425/6350 folding: a line starting with a space or tab continues the previous one.
  /// - vCard 2.1 quoted-printable soft breaks: a QUOTED-PRINTABLE property line ending in "="
  ///   continues on the next line. Only those properties are joined, never e.g. a base64
  ///   photo whose padding happens to end a line with "=".
  static List<String> _unfoldVcfLines(String text) {
    final out = <String>[];
    var qpOpen = false; // the previous logical line is quoted-printable and ended with "="
    for (final raw in text.split('\n')) {
      if (out.isNotEmpty && qpOpen) {
        // Soft break: drop the "=" and keep the next line as-is (a leading space is data).
        final last = out.last;
        out[out.length - 1] = last.substring(0, last.length - 1) + raw;
      } else if (out.isNotEmpty && (raw.startsWith(' ') || raw.startsWith('\t'))) {
        out[out.length - 1] += raw.substring(1);
      } else {
        out.add(raw);
      }
      final line = out.last;
      final colon = line.indexOf(':');
      qpOpen = colon > 0 &&
          line.endsWith('=') &&
          _isQuotedPrintableParams(line.substring(0, colon).toUpperCase());
    }
    return out;
  }

  /// Groups logical lines into cards. A BEGIN:VCARD always starts a new card, so a card
  /// missing its END:VCARD does not swallow the next one.
  static List<List<String>> _splitVcards(List<String> lines) {
    final cards = <List<String>>[];
    List<String>? current;
    for (final line in lines) {
      final upper = line.trim().toUpperCase();
      if (upper == 'BEGIN:VCARD') {
        if (current != null) cards.add(current);
        current = [line];
      } else if (upper == 'END:VCARD') {
        if (current != null) cards.add([...current, line]);
        current = null;
      } else {
        current?.add(line);
      }
    }
    if (current != null) cards.add(current);
    return cards;
  }

  /// Toggles an item's favourite status. Returns false if the database write failed;
  /// state is then reloaded from the database so the UI never shows an unsaved change.
  Future<bool> toggleFavourite(String id) async {
    try {
      await _repository.toggleFavourite(id);
      await loadItems();
      _requestAutomaticDriveBackup();
      return true;
    } catch (_) {
      await loadItems();
      return false;
    }
  }

  /// Deletes an item from the encrypted database. Returns false if the delete failed.
  Future<bool> removeItem(String id) async {
    try {
      await _repository.deleteItem(id);
      await loadItems();
      _requestAutomaticDriveBackup();
      return true;
    } catch (_) {
      await loadItems();
      return false;
    }
  }

  /// Deletes multiple items from the encrypted database in bulk.
  /// Returns false if any delete failed; state reflects what was actually deleted.
  Future<bool> removeItems(Iterable<String> ids) async {
    final idSet = ids.toSet();
    if (idSet.isEmpty) return true;
    try {
      for (final id in idSet) {
        await _repository.deleteItem(id);
      }
      await loadItems();
      _requestAutomaticDriveBackup();
      return true;
    } catch (_) {
      await loadItems();
      return false;
    }
  }
}

final vaultItemsProvider =
    StateNotifierProvider<VaultItemsNotifier, List<VaultItem>>((ref) {
  return VaultItemsNotifier(ref.watch(vaultRepositoryProvider), ref);
});

/// Returns items filtered by category
final itemsByCategoryProvider =
    Provider.family<List<VaultItem>, VaultCategory>((ref, category) {
  final items = ref.watch(vaultItemsProvider);
  return items.where((item) => item.category == category).toList();
});

/// Returns items marked as favourite
final favouriteItemsProvider = Provider<List<VaultItem>>((ref) {
  final items = ref.watch(vaultItemsProvider);
  return items.where((item) => item.isFavourite).toList();
});

/// Count for specific categories displayed on dashboard
final categoryCountsProvider = Provider<Map<VaultCategory, int>>((ref) {
  final items = ref.watch(vaultItemsProvider);
  final map = <VaultCategory, int>{
    for (final c in VaultCategory.values) c: 0,
  };
  for (final item in items) {
    map[item.category] = (map[item.category] ?? 0) + 1;
  }
  return map;
});

/// Recent searches list
class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier()
      : super(const []);

  void addSearch(String query) {
    if (query.trim().isEmpty) return;
    state = [query.trim(), ...state.where((q) => q != query.trim())];
  }

  void clearAll() {
    state = [];
  }
}

final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>((ref) {
  return RecentSearchesNotifier();
});

/// One contact read from a VCF file.
class ParsedVcfContact {
  final String fullName;
  final String phoneNumber;
  final String? email;
  final String? company;
  final Uint8List? photoBytes;

  const ParsedVcfContact({
    required this.fullName,
    required this.phoneNumber,
    this.email,
    this.company,
    this.photoBytes,
  });
}
