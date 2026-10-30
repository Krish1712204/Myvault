class PasswordEntry {
  final String id;
  final String itemId;
  final String? username;
  final String encryptedPassword;
  final String? websiteUrl;
  final String? notes;

  const PasswordEntry({
    required this.id,
    required this.itemId,
    this.username,
    required this.encryptedPassword,
    this.websiteUrl,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'item_id': itemId,
        'username': username,
        'encrypted_password': encryptedPassword,
        'website_url': websiteUrl,
        'notes': notes,
      };

  factory PasswordEntry.fromMap(Map<String, dynamic> map) => PasswordEntry(
        id: map['id'] as String,
        itemId: map['item_id'] as String,
        username: map['username'] as String?,
        encryptedPassword: map['encrypted_password'] as String,
        websiteUrl: map['website_url'] as String?,
        notes: map['notes'] as String?,
      );
}

class IdentityEntry {
  final String id;
  final String itemId;
  final String documentType;
  final String documentNumber;
  final String? fullName;
  final String? issuedDate;
  final String? expiryDate;
  final String? issuingCountry;
  final String? notes;
  final String? attachmentPath;

  const IdentityEntry({
    required this.id,
    required this.itemId,
    required this.documentType,
    required this.documentNumber,
    this.fullName,
    this.issuedDate,
    this.expiryDate,
    this.issuingCountry,
    this.notes,
    this.attachmentPath,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'item_id': itemId,
        'document_type': documentType,
        'document_number': documentNumber,
        'full_name': fullName,
        'issued_date': issuedDate,
        'expiry_date': expiryDate,
        'issuing_country': issuingCountry,
        'notes': notes,
        'attachment_path': attachmentPath,
      };

  factory IdentityEntry.fromMap(Map<String, dynamic> map) => IdentityEntry(
        id: map['id'] as String,
        itemId: map['item_id'] as String,
        documentType: map['document_type'] as String,
        documentNumber: map['document_number'] as String,
        fullName: map['full_name'] as String?,
        issuedDate: map['issued_date'] as String?,
        expiryDate: map['expiry_date'] as String?,
        issuingCountry: map['issuing_country'] as String?,
        notes: map['notes'] as String?,
        attachmentPath: map['attachment_path'] as String?,
      );
}

class DocumentEntry {
  final String id;
  final String itemId;
  final String filePath;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String fileExtension;
  final String? notes;

  const DocumentEntry({
    required this.id,
    required this.itemId,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.fileExtension,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'item_id': itemId,
        'file_path': filePath,
        'file_name': fileName,
        'file_size': fileSize,
        'mime_type': mimeType,
        'file_extension': fileExtension,
        'notes': notes,
      };

  factory DocumentEntry.fromMap(Map<String, dynamic> map) => DocumentEntry(
        id: map['id'] as String,
        itemId: map['item_id'] as String,
        filePath: map['file_path'] as String,
        fileName: map['file_name'] as String,
        fileSize: map['file_size'] as int,
        mimeType: map['mime_type'] as String,
        fileExtension: map['file_extension'] as String,
        notes: map['notes'] as String?,
      );
}

class NoteEntry {
  final String id;
  final String itemId;
  final String content;
  final String? colorTag;
  final String? tags;

  const NoteEntry({
    required this.id,
    required this.itemId,
    required this.content,
    this.colorTag,
    this.tags,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'item_id': itemId,
        'content': content,
        'color_tag': colorTag,
        'tags': tags,
      };

  factory NoteEntry.fromMap(Map<String, dynamic> map) => NoteEntry(
        id: map['id'] as String,
        itemId: map['item_id'] as String,
        content: map['content'] as String,
        colorTag: map['color_tag'] as String?,
        tags: map['tags'] as String?,
      );
}

class ContactEntry {
  final String id;
  final String itemId;
  final String phoneNumber;
  final String? email;
  final String? company;
  final String? jobTitle;
  final String? address;
  final String? birthday;
  final String? notes;
  final String? tags;
  final String? secondaryPhone;
  final String? secondaryEmail;
  final String? attachmentPath;

  const ContactEntry({
    required this.id,
    required this.itemId,
    required this.phoneNumber,
    this.email,
    this.company,
    this.jobTitle,
    this.address,
    this.birthday,
    this.notes,
    this.tags,
    this.secondaryPhone,
    this.secondaryEmail,
    this.attachmentPath,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'item_id': itemId,
        'phone_number': phoneNumber,
        'email': email,
        'company': company,
        'job_title': jobTitle,
        'address': address,
        'birthday': birthday,
        'notes': notes,
        'tags': tags,
        'secondary_phone': secondaryPhone,
        'secondary_email': secondaryEmail,
        'attachment_path': attachmentPath,
      };

  factory ContactEntry.fromMap(Map<String, dynamic> map) => ContactEntry(
        id: map['id'] as String,
        itemId: map['item_id'] as String,
        phoneNumber: map['phone_number'] as String,
        email: map['email'] as String?,
        company: map['company'] as String?,
        jobTitle: map['job_title'] as String?,
        address: map['address'] as String?,
        birthday: map['birthday'] as String?,
        notes: map['notes'] as String?,
        tags: map['tags'] as String?,
        secondaryPhone: map['secondary_phone'] as String?,
        secondaryEmail: map['secondary_email'] as String?,
        attachmentPath: map['attachment_path'] as String?,
      );
}
