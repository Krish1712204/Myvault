import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/security/clipboard_service.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../data/vault_item_model.dart';

class ContactDetailsScreen extends ConsumerStatefulWidget {
  final String itemId;

  const ContactDetailsScreen({
    super.key,
    required this.itemId,
  });

  @override
  ConsumerState<ContactDetailsScreen> createState() => _ContactDetailsScreenState();
}

class _ContactDetailsScreenState extends ConsumerState<ContactDetailsScreen> {
  Future<void> _makePhoneCall(BuildContext context, String phone) async {
    final cleanNumber = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final uri = Uri(scheme: 'tel', path: cleanNumber);
    try {
      final launched = await launchUrl(uri);
      if (!launched) {
        throw Exception('Could not launch dialer');
      }
    } catch (_) {
      if (context.mounted) {
        ClipboardService.copyPublic(
          context: context,
          text: phone,
          label: 'Phone number',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dialer unavailable. Copied $phone to clipboard.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  Future<void> _sendEmail(BuildContext context, String email) async {
    final uri = Uri(scheme: 'mailto', path: email.trim());
    try {
      final launched = await launchUrl(uri);
      if (!launched) {
        throw Exception('Could not launch email app');
      }
    } catch (_) {
      if (context.mounted) {
        ClipboardService.copyPublic(
          context: context,
          text: email,
          label: 'Email address',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email app unavailable. Copied $email to clipboard.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, VaultItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Contact?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${item.title}" from your encrypted vault? This action cannot be undone.',
          style: const TextStyle(color: AppColors.textPrimaryNavy),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMutedNavy)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(vaultItemsProvider.notifier).removeItem(item.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.title} deleted from vault'),
          backgroundColor: AppColors.textPrimaryNavy,
        ),
      );
      context.pop();
    }
  }

  String _formatTimestamp(int? millis, String fallback) {
    if (millis == null) return fallback;
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

  List<String> _parseTags(String? tags) {
    if (tags == null || tags.trim().isEmpty) return [];
    return tags
        .split(',')
        .map((t) => t.trim().replaceAll('#', ''))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  String _getInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'C';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final allItems = ref.watch(vaultItemsProvider);
    final matches = allItems.where((i) => i.id == widget.itemId).toList();

    if (matches.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
          title: const Text('Contact Details'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline_rounded, size: 48, color: AppColors.textMutedNavy),
              const SizedBox(height: 12),
              const Text('Contact not found', style: TextStyle(color: AppColors.textMutedNavy)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final item = matches.first;
    final primaryPhone = item.phoneNumber ?? (item.details?.startsWith('+') == true ? item.details! : '');
    final secondaryPhone = item.secondaryPhone;
    final primaryEmail = item.email ?? item.username;
    final secondaryEmail = item.secondaryEmail;
    final company = item.company;
    final jobTitle = item.jobTitle;
    final address = item.address;
    final birthday = item.birthday;
    final notes = item.details != null && !item.details!.startsWith('+') ? item.details! : null;
    final tags = _parseTags(item.tags);
    final initials = _getInitials(item.title);

    final workSubtitle = [
      if (jobTitle != null && jobTitle.isNotEmpty) jobTitle,
      if (company != null && company.isNotEmpty) company,
    ].join(' at ');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Contact Details',
          style: TextStyle(
            color: AppColors.textPrimaryNavy,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              item.isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
              color: item.isFavourite ? Colors.amber : AppColors.textMutedNavy,
              size: 24,
            ),
            onPressed: () {
              ref.read(vaultItemsProvider.notifier).toggleFavourite(item.id);
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 22),
            onPressed: () => context.push('/edit-contact/${item.id}'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
            onPressed: () => _confirmDelete(context, item),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Profile Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimaryNavy,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (workSubtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        workSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondaryNavy,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.categoryContactsBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.subcategory ?? 'Personal',
                        style: const TextStyle(
                          color: AppColors.categoryContacts,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Action Buttons (Call, Email, Copy)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (primaryPhone.isNotEmpty) ...[
                          _buildActionButton(
                            icon: Icons.phone_rounded,
                            label: 'Call',
                            onTap: () => _makePhoneCall(context, primaryPhone),
                          ),
                          const SizedBox(width: 16),
                        ],
                        if (primaryEmail != null && primaryEmail.isNotEmpty) ...[
                          _buildActionButton(
                            icon: Icons.email_rounded,
                            label: 'Email',
                            onTap: () => _sendEmail(context, primaryEmail),
                          ),
                          const SizedBox(width: 16),
                        ],
                        _buildActionButton(
                          icon: Icons.copy_rounded,
                          label: 'Copy Info',
                          onTap: () {
                            final info = StringBuffer();
                            info.writeln(item.title);
                            if (primaryPhone.isNotEmpty) info.writeln('Phone: $primaryPhone');
                            if (primaryEmail != null && primaryEmail.isNotEmpty) info.writeln('Email: $primaryEmail');
                            if (company != null && company.isNotEmpty) info.writeln('Company: $company');
                            if (jobTitle != null && jobTitle.isNotEmpty) info.writeln('Job Title: $jobTitle');
                            if (address != null && address.isNotEmpty) info.writeln('Address: $address');
                            ClipboardService.copyPublic(
                              context: context,
                              text: info.toString().trim(),
                              label: 'Contact details',
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Phone Section
              if (primaryPhone.isNotEmpty || (secondaryPhone != null && secondaryPhone.isNotEmpty))
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phone Numbers',
                        style: TextStyle(
                          color: AppColors.textPrimaryNavy,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (primaryPhone.isNotEmpty)
                        _buildContactRow(
                          icon: Icons.phone_android_rounded,
                          label: 'Primary',
                          value: primaryPhone,
                          onAction: () => _makePhoneCall(context, primaryPhone),
                          actionIcon: Icons.phone_forwarded_rounded,
                          onCopy: () => ClipboardService.copyPublic(
                            context: context,
                            text: primaryPhone,
                            label: 'Phone number',
                          ),
                        ),
                      if (secondaryPhone != null && secondaryPhone.isNotEmpty) ...[
                        const Divider(height: 16, color: AppColors.border),
                        _buildContactRow(
                          icon: Icons.phone_rounded,
                          label: 'Secondary',
                          value: secondaryPhone,
                          onAction: () => _makePhoneCall(context, secondaryPhone),
                          actionIcon: Icons.phone_forwarded_rounded,
                          onCopy: () => ClipboardService.copyPublic(
                            context: context,
                            text: secondaryPhone,
                            label: 'Secondary phone',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // Email Section
              if ((primaryEmail != null && primaryEmail.isNotEmpty) ||
                  (secondaryEmail != null && secondaryEmail.isNotEmpty))
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email Addresses',
                        style: TextStyle(
                          color: AppColors.textPrimaryNavy,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (primaryEmail != null && primaryEmail.isNotEmpty)
                        _buildContactRow(
                          icon: Icons.email_outlined,
                          label: 'Primary',
                          value: primaryEmail,
                          onAction: () => _sendEmail(context, primaryEmail),
                          actionIcon: Icons.send_rounded,
                          onCopy: () => ClipboardService.copyPublic(
                            context: context,
                            text: primaryEmail,
                            label: 'Email address',
                          ),
                        ),
                      if (secondaryEmail != null && secondaryEmail.isNotEmpty) ...[
                        const Divider(height: 16, color: AppColors.border),
                        _buildContactRow(
                          icon: Icons.alternate_email_rounded,
                          label: 'Secondary',
                          value: secondaryEmail,
                          onAction: () => _sendEmail(context, secondaryEmail),
                          actionIcon: Icons.send_rounded,
                          onCopy: () => ClipboardService.copyPublic(
                            context: context,
                            text: secondaryEmail,
                            label: 'Secondary email',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // Work & Organization Section
              if ((company != null && company.isNotEmpty) || (jobTitle != null && jobTitle.isNotEmpty))
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Work & Organization',
                        style: TextStyle(
                          color: AppColors.textPrimaryNavy,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (company != null && company.isNotEmpty)
                        _buildInfoRow(
                          icon: Icons.business_rounded,
                          label: 'Company',
                          value: company,
                        ),
                      if (jobTitle != null && jobTitle.isNotEmpty) ...[
                        if (company != null && company.isNotEmpty)
                          const Divider(height: 16, color: AppColors.border),
                        _buildInfoRow(
                          icon: Icons.work_outline_rounded,
                          label: 'Job Title',
                          value: jobTitle,
                        ),
                      ],
                    ],
                  ),
                ),

              // Personal Information (Address & Birthday)
              if ((address != null && address.isNotEmpty) || (birthday != null && birthday.isNotEmpty))
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Personal Info',
                        style: TextStyle(
                          color: AppColors.textPrimaryNavy,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (address != null && address.isNotEmpty)
                        _buildContactRow(
                          icon: Icons.location_on_outlined,
                          label: 'Address',
                          value: address,
                          onCopy: () => ClipboardService.copyPublic(
                            context: context,
                            text: address,
                            label: 'Address',
                          ),
                        ),
                      if (birthday != null && birthday.isNotEmpty) ...[
                        if (address != null && address.isNotEmpty)
                          const Divider(height: 16, color: AppColors.border),
                        _buildInfoRow(
                          icon: Icons.cake_outlined,
                          label: 'Birthday',
                          value: birthday,
                        ),
                      ],
                    ],
                  ),
                ),

              // Notes Section
              if (notes != null && notes.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notes',
                        style: TextStyle(
                          color: AppColors.textPrimaryNavy,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        notes,
                        style: const TextStyle(
                          color: AppColors.textPrimaryNavy,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

              // Tags Section
              if (tags.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tags',
                        style: TextStyle(
                          color: AppColors.textPrimaryNavy,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: tags.map((t) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '#',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  t,
                                  style: const TextStyle(
                                    color: AppColors.textPrimaryNavy,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

              // Metadata Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Information',
                      style: TextStyle(
                        color: AppColors.textPrimaryNavy,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMetaRow(
                      label: 'Created',
                      value: _formatTimestamp(item.createdAt, item.date),
                    ),
                    const Divider(height: 16, color: AppColors.border),
                    _buildMetaRow(
                      label: 'Last Updated',
                      value: _formatTimestamp(item.updatedAt, item.date),
                    ),
                    const Divider(height: 16, color: AppColors.border),
                    _buildMetaRow(
                      label: 'Encryption',
                      value: 'SQLCipher AES-256 (Local App-Private)',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onAction,
    IconData? actionIcon,
    VoidCallback? onCopy,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textMutedNavy),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMutedNavy,
                  fontSize: 11,
                ),
              ),
              SelectableText(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimaryNavy,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (onAction != null && actionIcon != null)
          IconButton(
            icon: Icon(actionIcon, size: 18, color: AppColors.primary),
            onPressed: onAction,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        if (onCopy != null)
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textMutedNavy),
            onPressed: onCopy,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textMutedNavy),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMutedNavy,
                  fontSize: 11,
                ),
              ),
              SelectableText(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimaryNavy,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow({required String label, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMutedNavy,
            fontSize: 13,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textPrimaryNavy,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
