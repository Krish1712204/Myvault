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

  // Identity / ID Card specific fields
  final String? documentType;
  final String? documentNumber;
  final String? fullName;
  final String? issuedDate;
  final String? expiryDate;
  final String? issuingCountry;
  final String? attachmentPath;

  // Document & Photo specific fields
  final String? filePath;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final String? fileExtension;
  final String? thumbnailPath;

  // Notes & Contacts specific fields (Phase 6)
  final String? colorTag;
  final String? tags;
  final String? phoneNumber;
  final String? email;
  final String? company;
  final String? jobTitle;
  final String? address;
  final String? birthday;
  final String? secondaryPhone;
  final String? secondaryEmail;

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
    this.documentType,
    this.documentNumber,
    this.fullName,
    this.issuedDate,
    this.expiryDate,
    this.issuingCountry,
    this.attachmentPath,
    this.filePath,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.fileExtension,
    this.thumbnailPath,
    this.colorTag,
    this.tags,
    this.phoneNumber,
    this.email,
    this.company,
    this.jobTitle,
    this.address,
    this.birthday,
    this.secondaryPhone,
    this.secondaryEmail,
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
    String? documentType,
    String? documentNumber,
    String? fullName,
    String? issuedDate,
    String? expiryDate,
    String? issuingCountry,
    String? attachmentPath,
    String? filePath,
    String? fileName,
    int? fileSize,
    String? mimeType,
    String? fileExtension,
    String? thumbnailPath,
    String? colorTag,
    String? tags,
    String? phoneNumber,
    String? email,
    String? company,
    String? jobTitle,
    String? address,
    String? birthday,
    String? secondaryPhone,
    String? secondaryEmail,
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
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      fullName: fullName ?? this.fullName,
      issuedDate: issuedDate ?? this.issuedDate,
      expiryDate: expiryDate ?? this.expiryDate,
      issuingCountry: issuingCountry ?? this.issuingCountry,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      fileExtension: fileExtension ?? this.fileExtension,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      colorTag: colorTag ?? this.colorTag,
      tags: tags ?? this.tags,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      company: company ?? this.company,
      jobTitle: jobTitle ?? this.jobTitle,
      address: address ?? this.address,
      birthday: birthday ?? this.birthday,
      secondaryPhone: secondaryPhone ?? this.secondaryPhone,
      secondaryEmail: secondaryEmail ?? this.secondaryEmail,
    );
  }
}

