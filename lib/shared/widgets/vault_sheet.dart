import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'vault_form_kit.dart';

/// Shared building blocks for sheets and dialogs: one frame, one banner style, one
/// passphrase field and one confirm dialog, so every flow looks and behaves the same.

/// Opens a bottom sheet above the bottom navigation bar, sized to its content.
Future<T?> showVaultSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    backgroundColor: AppColors.sheetSurface,
    builder: builder,
  );
}

/// Tinted square behind an icon, as used in Settings and sheet headers.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;

  const IconTile(this.icon, {super.key, this.color, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.primaryOnSurface;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withAlpha(AppColors.isDark ? 46 : 22),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, color: tint, size: size * 0.56),
    );
  }
}

/// Sheet body: grab handle, icon + title header, then [children]. Scrolls when the content
/// is taller than the screen and lifts above the keyboard.
class VaultSheet extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const VaultSheet({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.subtitle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.handle, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  IconTile(icon, color: iconColor, size: 44),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: AppColors.textPrimaryNavy,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: TextStyle(color: AppColors.textMutedNavy, fontSize: 13, height: 1.35)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

enum NoticeTone { info, success, warning, error }

/// A short tinted message with an icon: tips, warnings and inline errors.
class NoticeBanner extends StatelessWidget {
  final NoticeTone tone;
  final String message;
  final String? title;
  final IconData? icon;

  const NoticeBanner({super.key, required this.tone, required this.message, this.title, this.icon});

  const NoticeBanner.error(this.message, {super.key})
      : tone = NoticeTone.error,
        title = null,
        icon = null;

  Color get _color => switch (tone) {
        NoticeTone.info => AppColors.primaryOnSurface,
        NoticeTone.success => AppColors.success,
        NoticeTone.warning => AppColors.warning,
        NoticeTone.error => AppColors.error,
      };

  IconData get _icon =>
      icon ??
      switch (tone) {
        NoticeTone.info => Icons.info_outline_rounded,
        NoticeTone.success => Icons.check_circle_outline_rounded,
        NoticeTone.warning => Icons.warning_amber_rounded,
        NoticeTone.error => Icons.error_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
      decoration: BoxDecoration(
        color: color.withAlpha(AppColors.isDark ? 36 : 20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(AppColors.isDark ? 70 : 50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(color: AppColors.textPrimaryNavy, fontSize: 13.5, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  message,
                  style: TextStyle(color: AppColors.textSecondaryNavy, fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Label and value on one line, for summaries such as a backup's contents.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.textMutedNavy, fontSize: 13)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: AppColors.textPrimaryNavy, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded inset panel grouping [InfoRow]s or other quiet content.
class InfoPanel extends StatelessWidget {
  final List<Widget> children;

  const InfoPanel({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.subtleFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// Labelled, obscured passphrase field with a show/hide toggle.
class PassphraseField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool enabled;
  final bool autofocus;
  final IconData icon;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const PassphraseField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.enabled = true,
    this.autofocus = false,
    this.icon = Icons.key_rounded,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  @override
  State<PassphraseField> createState() => _PassphraseFieldState();
}

class _PassphraseFieldState extends State<PassphraseField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: widget.label,
      child: TextField(
        controller: widget.controller,
        obscureText: _obscure,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: Icon(widget.icon),
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Show passphrase' : 'Hide passphrase',
            icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
    );
  }
}

/// Full-width primary button that shows a spinner and [busyLabel] while [busy].
class BusyButton extends StatelessWidget {
  final String label;
  final String? busyLabel;
  final IconData? icon;
  final bool busy;
  final VoidCallback? onPressed;
  final Color? color;

  const BusyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.busyLabel,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final style = color == null
        ? null
        : ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white);
    final Widget leading = busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
          )
        : Icon(icon ?? Icons.arrow_forward_rounded, size: 20);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: style,
        onPressed: busy ? null : onPressed,
        icon: leading,
        label: Text(busy ? (busyLabel ?? label) : label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Confirmation dialog. Returns true only when the user confirms.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: icon == null
          ? null
          : Center(child: IconTile(icon, color: destructive ? AppColors.error : null, size: 48)),
      title: Text(title, textAlign: icon == null ? null : TextAlign.center),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          style: destructive
              ? ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white)
              : null,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Single-button dialog for a result: success, failure or information.
Future<void> showResultDialog(
  BuildContext context, {
  required String title,
  required String message,
  NoticeTone tone = NoticeTone.info,
  String buttonLabel = 'OK',
}) {
  final (IconData icon, Color color) = switch (tone) {
    NoticeTone.success => (Icons.check_circle_rounded, AppColors.success),
    NoticeTone.error => (Icons.error_outline_rounded, AppColors.error),
    NoticeTone.warning => (Icons.warning_amber_rounded, AppColors.warning),
    NoticeTone.info => (Icons.info_outline_rounded, AppColors.primaryOnSurface),
  };
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Center(child: IconTile(icon, color: color, size: 48)),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(buttonLabel),
          ),
        ),
      ],
    ),
  );
}
