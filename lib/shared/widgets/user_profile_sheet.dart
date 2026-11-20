import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/profile/user_profile_provider.dart';
import '../../features/auth/domain/vault_auth_notifier.dart';
import '../state/vault_state_provider.dart';
import 'gradient_button.dart';

/// Edit profile: photo and display name, plus a few true facts about this vault.
class UserProfileSheet extends ConsumerStatefulWidget {
  const UserProfileSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
            // Above the bottom navigation bar, not inside the current tab.
      useRootNavigator: true,
context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const UserProfileSheet(),
    );
  }

  @override
  ConsumerState<UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends ConsumerState<UserProfileSheet> {
  late final TextEditingController _name = TextEditingController(text: ref.read(userProfileProvider).name);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      ref.read(vaultAuthStateProvider.notifier).allowExternalActivity();
      final result = await FilePicker.pickFiles(type: FileType.image);
      final path = result.isNotEmpty ? result.first.path : null;
      if (path == null) return;
      await ref.read(userProfileProvider.notifier).setPhoto(path);
      FilePicker.clearTemporaryFiles().ignore(); // drop the picker's cache copy
      if (mounted) _toast('Profile photo updated');
    } catch (e) {
      if (mounted) _toast('Could not update photo: $e', error: true);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(userProfileProvider.notifier).setName(_name.text);
    if (!mounted) return;
    Navigator.pop(context);
    _toast('Profile saved');
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final photo = ref.watch(profilePhotoProvider).valueOrNull;
    final auth = ref.watch(vaultAuthStateProvider);
    final itemCount = ref.watch(vaultItemsProvider).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimaryNavy;
    final fingerprintOn = auth.isBiometricAvailable && auth.isBiometricEnabled;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.sheetSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 22),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: AppColors.avatarRingGradient,
                      ),
                    ),
                    child: ClipOval(
                      child: Container(
                        color: isDark ? AppColors.darkSurface : AppColors.primaryLight,
                        child: photo != null
                            ? Image.memory(photo, fit: BoxFit.cover, gaplessPlayback: true)
                            : Center(
                                child: profile.initials.isEmpty
                                    ? const Icon(Icons.person_rounded, size: 48, color: AppColors.primary)
                                    : Text(
                                        profile.initials,
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 34,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: _RoundAction(
                      icon: Icons.photo_camera_rounded,
                      color: AppColors.primary,
                      tooltip: 'Change photo',
                      onTap: _pickPhoto,
                    ),
                  ),
                  if (profile.hasPhoto)
                    Positioned(
                      left: -2,
                      bottom: -2,
                      child: _RoundAction(
                        icon: Icons.delete_outline_rounded,
                        color: AppColors.error,
                        tooltip: 'Remove photo',
                        onTap: () => ref.read(userProfileProvider.notifier).removePhoto(),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  hintText: 'Shown in greetings',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.subtleFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _Fact(
                      icon: Icons.inventory_2_rounded,
                      label: 'Items in your vault',
                      value: '$itemCount',
                      color: AppColors.primary,
                      textPrimary: textPrimary,
                    ),
                    const Divider(height: 20),
                    _Fact(
                      icon: Icons.fingerprint_rounded,
                      label: 'Fingerprint unlock',
                      value: fingerprintOn ? 'On' : 'Off',
                      color: fingerprintOn ? AppColors.success : AppColors.textMutedNavy,
                      textPrimary: textPrimary,
                    ),
                    const Divider(height: 20),
                    _Fact(
                      icon: Icons.cloud_off_rounded,
                      label: 'Stored',
                      value: 'Only on this phone',
                      color: AppColors.success,
                      textPrimary: textPrimary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GradientButton(label: 'Save Profile', icon: Icons.check_rounded, loading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color textPrimary;

  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
        ),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12.5)),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundAction({required this.icon, required this.color, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 3)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(9), child: Icon(icon, color: Colors.white, size: 18)),
        ),
      ),
    );
  }
}
