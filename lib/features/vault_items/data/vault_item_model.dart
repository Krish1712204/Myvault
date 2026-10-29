enum VaultCategory {
  passwords,
  idCards,
  documents,
  photos,
  notes,
  contacts;

  String get displayName {
    switch (this) {
      case VaultCategory.passwords:
        return 'Passwords';
      case VaultCategory.idCards:
        return 'ID Cards';
      case VaultCategory.documents:
        return 'Documents';
      case VaultCategory.photos:
        return 'Photos';
      case VaultCategory.notes:
        return 'Notes';
      case VaultCategory.contacts:
        return 'Contacts';
    }
  }

  String get keyName {
    switch (this) {
      case VaultCategory.passwords:
        return 'passwords';
      case VaultCategory.idCards:
        return 'id_cards';
      case VaultCategory.documents:
        return 'documents';
      case VaultCategory.photos:
        return 'photos';
      case VaultCategory.notes:
        return 'notes';
      case VaultCategory.contacts:
        return 'contacts';
    }
  }

  static VaultCategory fromKey(String key) {
    return VaultCategory.values.firstWhere(
      (c) => c.keyName == key,
      orElse: () => VaultCategory.passwords,
    );
  }
}

class VaultItem {
  final String id;
  final String title;
  final String subtitle;
  final VaultCategory category;
  final String? url;
  final String? username;
  final String? password;
  final String? details;
  final String? subcategory;
  final bool isFavourite;
  final String date;
  final String? size;
  final int? createdAt;
  final int? updatedAt;

  const VaultItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    this.url,
    this.username,
    this.password,
    this.details,
    this.subcategory,
    this.isFavourite = false,
    this.date = '12 Oct 2025',
    this.size,
    this.createdAt,
    this.updatedAt,
  });

  VaultItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    VaultCategory? category,
    String? url,
    String? username,
    String? password,
    String? details,
    String? subcategory,
    bool? isFavourite,
    String? date,
    String? size,
    int? createdAt,
    int? updatedAt,
  }) {
    return VaultItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      category: category ?? this.category,
      url: url ?? this.url,
      username: username ?? this.username,
      password: password ?? this.password,
      details: details ?? this.details,
      subcategory: subcategory ?? this.subcategory,
      isFavourite: isFavourite ?? this.isFavourite,
      date: date ?? this.date,
      size: size ?? this.size,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

