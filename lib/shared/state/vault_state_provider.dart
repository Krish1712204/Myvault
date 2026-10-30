import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/domain/vault_auth_notifier.dart';
import '../../features/auth/domain/vault_auth_state.dart';
import '../../features/vault/data/vault_models.dart';
import '../../features/vault/data/vault_repository.dart';
import '../../features/vault_items/data/mock_vault_data.dart';
import '../../features/vault_items/data/vault_item_model.dart';

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
      } else if (next.status == VaultStatus.locked || next.status == VaultStatus.uninitialized) {
        state = [];
      }
    });

    if (_ref.read(vaultAuthStateProvider).status == VaultStatus.unlocked) {
      loadItems();
    }
  }

  /// Reloads all items from the encrypted database
  Future<void> loadItems() async {
    try {
      final items = await _repository.getAllItems();
      state = items;
    } catch (_) {
      if (state.isEmpty) {
        state = MockVaultData.items;
      }
    }
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
    final itemId = isNew ? 'pwd_${DateTime.now().millisecondsSinceEpoch}' : id;
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
    final itemId = isNew ? 'id_${DateTime.now().millisecondsSinceEpoch}' : id;
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
  }) async {
    final session = _ref.read(vaultSessionProvider);
    final vek = session.vek;
    if (vek == null) {
      throw StateError('Vault is locked. Cannot encrypt document.');
    }

    final isNew = id == null || id.isEmpty;
    final itemId = isNew ? 'doc_${DateTime.now().millisecondsSinceEpoch}' : id;
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
    );

    if (isNew) {
      await _repository.insertItem(item, documentEntry: docEntry);
    } else {
      await _repository.updateItem(item, documentEntry: docEntry);
    }

    await loadItems();
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
    );

    await _repository.updateItem(updatedItem, documentEntry: docEntry);
    await loadItems();
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
    final itemId = isNew ? 'note_${DateTime.now().millisecondsSinceEpoch}' : id;
    final now = DateTime.now().millisecondsSinceEpoch;

    final item = VaultItem(
      id: itemId,
      title: title,
      subtitle: content.length > 50 ? '${content.substring(0, 50)}...' : content,
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
  }) async {
    final isNew = id == null || id.isEmpty;
    final itemId = isNew ? 'cnt_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}' : id;
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

    await loadItems();
  }

  /// Bulk imports contacts from a VCF string, parsing names, phones, emails, and base64 photos,
  /// sorting them in ascending alphabetical order by Contact Name, and saving to vault.
  Future<int> importContactsFromVcf(String vcfContent) async {
    final session = _ref.read(vaultSessionProvider);
    final vek = session.vek;
    if (vek == null) {
      throw StateError('Vault is locked. Cannot import contacts.');
    }

    // Unfold multiline fields (RFC 2425/2426/6350)
    final unfolded = vcfContent.replaceAll(RegExp(r'\r?\n[ \t]'), '');
    final cardRegex = RegExp(r'BEGIN:VCARD[\s\S]*?END:VCARD', caseSensitive: false);
    final matches = cardRegex.allMatches(unfolded);

    if (matches.isEmpty) {
      return 0;
    }

    final parsedList = <_ParsedVcfContact>[];

    for (final match in matches) {
      final cardText = match.group(0)!;
      final lines = cardText.split(RegExp(r'\r?\n'));

      String fullName = '';
      String phoneNumber = '';
      String? email;
      Uint8List? photoBytes;

      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;

        final colonIndex = line.indexOf(':');
        if (colonIndex == -1) continue;

        final key = line.substring(0, colonIndex).toUpperCase();
        final value = line.substring(colonIndex + 1).trim();

        if (key == 'FN' || key.startsWith('FN;')) {
          if (fullName.isEmpty) fullName = value;
        } else if ((key == 'N' || key.startsWith('N;')) && fullName.isEmpty) {
          final parts = value.split(';').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
          if (parts.length >= 2) {
            fullName = '${parts[1]} ${parts[0]}';
          } else if (parts.isNotEmpty) {
            fullName = parts[0];
          }
        } else if (key == 'TEL' || key.startsWith('TEL;')) {
          if (phoneNumber.isEmpty) {
            phoneNumber = value;
          }
        } else if (key == 'EMAIL' || key.startsWith('EMAIL;')) {
          if (email == null || email.isEmpty) {
            email = value;
          }
        } else if (key.startsWith('PHOTO')) {
          try {
            var base64Str = value;
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

      if (fullName.isEmpty) {
        if (phoneNumber.isNotEmpty) {
          fullName = phoneNumber;
        } else {
          continue;
        }
      }

      parsedList.add(_ParsedVcfContact(
        fullName: fullName,
        phoneNumber: phoneNumber,
        email: email,
        photoBytes: photoBytes,
      ));
    }

    if (parsedList.isEmpty) {
      return 0;
    }

    // Sort in ascending alphabetical order by Contact Name
    parsedList.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

    int count = 0;
    for (final contact in parsedList) {
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
        attachmentPath: attachmentPath,
      );
      count++;
    }

    await loadItems();
    return count;
  }

  /// Adds a generic vault item
  Future<void> addItem(VaultItem item) async {
    try {
      await _repository.insertItem(item);
      await loadItems();
    } catch (_) {
      state = [item, ...state];
    }
  }

  /// Toggles an item's favourite status
  Future<void> toggleFavourite(String id) async {
    try {
      await _repository.toggleFavourite(id);
      await loadItems();
    } catch (_) {
      state = state.map((item) {
        if (item.id == id) {
          return item.copyWith(isFavourite: !item.isFavourite);
        }
        return item;
      }).toList();
    }
  }

  /// Deletes an item from the encrypted database
  Future<void> removeItem(String id) async {
    try {
      await _repository.deleteItem(id);
      await loadItems();
    } catch (_) {
      state = state.where((item) => item.id != id).toList();
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
      : super(['google', 'passport', 'bank', 'insurance', 'office id']);

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

class _ParsedVcfContact {
  final String fullName;
  final String phoneNumber;
  final String? email;
  final Uint8List? photoBytes;

  const _ParsedVcfContact({
    required this.fullName,
    required this.phoneNumber,
    this.email,
    this.photoBytes,
  });
}
