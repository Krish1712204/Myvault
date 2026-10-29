import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/security/clipboard_service.dart';
import '../../../../core/security/password_generator.dart';

class PasswordGeneratorSheet extends StatefulWidget {
  final ValueChanged<String>? onPasswordSelected;

  const PasswordGeneratorSheet({
    super.key,
    this.onPasswordSelected,
  });

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PasswordGeneratorSheet(),
    );
  }

  @override
  State<PasswordGeneratorSheet> createState() => _PasswordGeneratorSheetState();
}

class _PasswordGeneratorSheetState extends State<PasswordGeneratorSheet> {
  final _generator = PasswordGenerator();
  var _options = const PasswordGeneratorOptions();
  String _currentPassword = '';

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  void _regenerate() {
    setState(() {
      _currentPassword = _generator.generate(_options);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strength = PasswordGenerator.calculateStrength(_currentPassword);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.md,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Password Generator',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryNavy,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textMutedNavy),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Password display box
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(6),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _currentPassword,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: AppColors.textPrimaryNavy,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                      tooltip: 'Regenerate',
                      onPressed: _regenerate,
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                      tooltip: 'Copy',
                      onPressed: () {
                        ClipboardService.copySensitive(
                          context: context,
                          text: _currentPassword,
                          label: 'Password',
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Strength bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: strength.score,
                          minHeight: 5,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(strength.color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      strength.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: strength.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Length slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Password Length',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryNavy,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_options.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _options.length.toDouble(),
            min: 8,
            max: 32,
            divisions: 24,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.border,
            onChanged: (val) {
              setState(() {
                _options = _options.copyWith(length: val.toInt());
                _regenerate();
              });
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          // Character sets switches
          _buildToggleOption(
            title: 'Uppercase letters (A-Z)',
            value: _options.includeUppercase,
            onChanged: (v) {
              setState(() {
                _options = _options.copyWith(includeUppercase: v);
                _regenerate();
              });
            },
          ),
          _buildToggleOption(
            title: 'Lowercase letters (a-z)',
            value: _options.includeLowercase,
            onChanged: (v) {
              setState(() {
                _options = _options.copyWith(includeLowercase: v);
                _regenerate();
              });
            },
          ),
          _buildToggleOption(
            title: 'Numbers (0-9)',
            value: _options.includeNumbers,
            onChanged: (v) {
              setState(() {
                _options = _options.copyWith(includeNumbers: v);
                _regenerate();
              });
            },
          ),
          _buildToggleOption(
            title: 'Special symbols (!@#\$%^&*)',
            value: _options.includeSpecial,
            onChanged: (v) {
              setState(() {
                _options = _options.copyWith(includeSpecial: v);
                _regenerate();
              });
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          // Use password button
          ElevatedButton(
            onPressed: () {
              if (widget.onPasswordSelected != null) {
                widget.onPasswordSelected!(_currentPassword);
              }
              Navigator.of(context).pop(_currentPassword);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'Use Password',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimaryNavy,
              fontWeight: FontWeight.w500,
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
