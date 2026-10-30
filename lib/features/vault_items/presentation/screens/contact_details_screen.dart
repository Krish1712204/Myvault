import 'dart:typed_data';
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

  Future<void> _sendSms(BuildContext context, String phone) async {
    final cleanNumber = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final uri = Uri(scheme: 'sms', path: cleanNumber);
    try {
      final launched = await launchUrl(uri);
      if (!launched) {
        throw Exception('Could not launch SMS');
      }
    } catch (_) {
      if (context.mounted) {
        ClipboardService.copyPublic(
          context: context,
          text: phone,
          label: 'Phone number',
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
          'Are you sure you want to permanently delete "${item.title}" from your vault? This action cannot be undone.',
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

  String _getInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'C';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean.substring(0, 1).toUpperCase();
  }

  void _showPhotoPreview(Uint8List bytes, String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(name, style: const TextStyle(fontSize: 16)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: InteractiveViewer(
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    final email = item.email ?? item.username;
    final initials = _getInitials(item.title);

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
            tooltip: item.isFavourite ? 'Starred' : 'Mark as Favourite',
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
              // Header Profile Card with Photo Avatar
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
                    _buildAvatar(item, initials),
                    const SizedBox(height: 14),
                    Text(
                      item.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimaryNavy,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Action Buttons (Call, SMS, Email, Copy)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (primaryPhone.isNotEmpty) ...[
                          _buildActionButton(
                            icon: Icons.phone_rounded,
                            label: 'Call',
                            onTap: () => _makePhoneCall(context, primaryPhone),
                          ),
                          const SizedBox(width: 12),
                          _buildActionButton(
                            icon: Icons.message_rounded,
                            label: 'Message',
                            onTap: () => _sendSms(context, primaryPhone),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (email != null && email.isNotEmpty) ...[
                          _buildActionButton(
                            icon: Icons.email_rounded,
                            label: 'Email',
                            onTap: () => _sendEmail(context, email),
                          ),
                          const SizedBox(width: 12),
                        ],
                        _buildActionButton(
                          icon: Icons.copy_rounded,
                          label: 'Copy',
                          onTap: () {
                            final info = StringBuffer();
                            info.writeln(item.title);
                            if (primaryPhone.isNotEmpty) info.writeln('Phone: $primaryPhone');
                            if (email != null && email.isNotEmpty) info.writeln('Email: $email');
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

              // Contact Information Card
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
                      'Contact Information',
                      style: TextStyle(
                        color: AppColors.textPrimaryNavy,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Mobile Number Row
                    if (primaryPhone.isNotEmpty)
                      _buildContactRow(
                        icon: Icons.phone_android_rounded,
                        label: 'Mobile Number',
                        value: primaryPhone,
                        onAction: () => _makePhoneCall(context, primaryPhone),
                        actionIcon: Icons.phone_forwarded_rounded,
                        onCopy: () => ClipboardService.copyPublic(
                          context: context,
                          text: primaryPhone,
                          label: 'Mobile number',
                        ),
                      ),
                    if (primaryPhone.isNotEmpty && email != null && email.isNotEmpty)
                      const Divider(height: 20, color: AppColors.border),
                    // Email Row (if exists)
                    if (email != null && email.isNotEmpty)
                      _buildContactRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: email,
                        onAction: () => _sendEmail(context, email),
                        actionIcon: Icons.send_rounded,
                        onCopy: () => ClipboardService.copyPublic(
                          context: context,
                          text: email,
                          label: 'Email address',
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Edit and Delete Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit Contact', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => context.push('/edit-contact/${item.id}'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _confirmDelete(context, item),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(VaultItem item, String initials) {
    if (item.attachmentPath != null && item.attachmentPath!.isNotEmpty) {
      return FutureBuilder<Uint8List>(
        future: ref.read(vaultItemsProvider.notifier).getDecryptedFileBytes(item.attachmentPath!),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return GestureDetector(
              onTap: () => _showPhotoPreview(snapshot.data!, item.title),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: ClipOval(
                  child: Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    width: 80,
                    height: 80,
                  ),
                ),
              ),
            );
          }
          return CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      );
    }

    return CircleAvatar(
      radius: 40,
      backgroundColor: AppColors.primary,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
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
    required VoidCallback onAction,
    required IconData actionIcon,
    required VoidCallback onCopy,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
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
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
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
        IconButton(
          icon: Icon(actionIcon, size: 20, color: AppColors.primary),
          onPressed: onAction,
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.textMutedNavy),
          onPressed: onCopy,
        ),
      ],
    );
  }
}
