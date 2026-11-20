import '../../features/vault_items/data/vault_item_model.dart';

extension VaultItemDisplay on VaultItem {
  /// The secondary line shown under an item's title in lists and search results.
  /// Sensitive numbers are masked to their last four characters.
  String get displaySubtitle {
    switch (category) {
      case VaultCategory.idCards:
        // The type only adds information when it differs from the title (usually it is the
        // title, e.g. "PAN Card"); the masked number is what tells cards apart.
        final type = (documentType != null && documentType!.isNotEmpty && documentType != title)
            ? documentType!
            : null;
        final number = documentNumber?.replaceAll(RegExp(r'\s'), '') ?? '';
        if (number.isEmpty) return type ?? (subtitle.isNotEmpty ? subtitle : category.displayName);
        final last4 = number.length <= 4 ? number : number.substring(number.length - 4);
        return type == null ? '•••• $last4' : '$type · •••• $last4';
      case VaultCategory.passwords:
        if (username != null && username!.isNotEmpty) return username!;
        return url ?? subtitle;
      case VaultCategory.contacts:
        final parts = [
          if (jobTitle != null && jobTitle!.isNotEmpty) jobTitle!,
          if (company != null && company!.isNotEmpty) company!,
        ];
        if (parts.isEmpty && phoneNumber != null && phoneNumber!.isNotEmpty) parts.add(phoneNumber!);
        return parts.isNotEmpty ? parts.join(' · ') : subtitle;
      default:
        return subtitle;
    }
  }
}
