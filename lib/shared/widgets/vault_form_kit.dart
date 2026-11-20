import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/ui/motion.dart';
import '../../features/vault_items/data/vault_item_model.dart';
import '../navigation/item_routes.dart';
import 'gradient_button.dart';
import 'pressable_scale.dart';

/// Shared look for every add/edit form: a category-coloured header, sections that slide in,
/// and a sticky save button in the category's colours.
class VaultFormScaffold extends StatefulWidget {
  final VaultCategory category;
  final String title;
  final String subtitle;
  final bool isFavourite;
  final ValueChanged<bool>? onFavouriteChanged;
  final bool saving;
  final VoidCallback? onSave;
  final String saveLabel;
  final List<Widget> children;

  const VaultFormScaffold({
    super.key,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.saving,
    required this.onSave,
    required this.saveLabel,
    required this.children,
    this.isFavourite = false,
    this.onFavouriteChanged,
  });

  @override
  State<VaultFormScaffold> createState() => _VaultFormScaffoldState();
}

class _VaultFormScaffoldState extends State<VaultFormScaffold> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    motionEnabled(context) ? _entrance.forward() : _entrance.value = 1;
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Widget _reveal(int index, Widget child) {
    final start = math.min(index * 0.1, 0.5);
    final curve = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, math.min(start + 0.5, 1), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      child: child,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(offset: Offset(0, 24 * (1 - curve.value)), child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(widget.category);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(child: _Header(widget: widget, style: style)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                sliver: SliverList.separated(
                  itemCount: widget.children.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, i) => _reveal(i + 1, widget.children[i]),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
          decoration: BoxDecoration(
            color: AppColors.sheetSurface,
            border: Border(top: BorderSide(color: isDark ? AppColors.darkSurface : AppColors.border)),
          ),
          child: GradientButton(
            label: widget.saveLabel,
            icon: Icons.check_rounded,
            loading: widget.saving,
            colors: style.gradient,
            onPressed: widget.onSave,
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VaultFormScaffold widget;
  final CategoryStyle style;

  const _Header({required this.widget, required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: style.gradient),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              bottom: -40,
              child: Transform.rotate(
                angle: -0.25,
                child: Icon(style.icon, size: 170, color: Colors.white.withAlpha(28)),
              ),
            ),
            Positioned(
              left: -60,
              top: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Colors.white.withAlpha(40), Colors.white.withAlpha(0)]),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _GlassIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          tooltip: 'Back',
                          onTap: () => context.pop(),
                        ),
                        const Spacer(),
                        if (widget.onFavouriteChanged != null)
                          _GlassIconButton(
                            icon: widget.isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
                            tooltip: widget.isFavourite ? 'Remove from favourites' : 'Add to favourites',
                            iconColor: widget.isFavourite ? const Color(0xFFFDE047) : Colors.white,
                            onTap: () => widget.onFavouriteChanged!(!widget.isFavourite),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(45),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withAlpha(70)),
                          ),
                          child: Icon(style.icon, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.subtitle,
                                style: TextStyle(color: Colors.white.withAlpha(215), fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color iconColor;

  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(40),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(60)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: Icon(icon, key: ValueKey(icon), color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }
}

/// White rounded card grouping related fields under a small heading.
class FormSectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;

  const FormSectionCard({super.key, required this.title, required this.children, this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.formCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.formCardBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(isDark ? 30 : 8), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.textMutedNavy),
                const SizedBox(width: 6),
              ],
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: AppColors.textMutedNavy,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._spaced(children),
        ],
      ),
    );
  }

  static List<Widget> _spaced(List<Widget> children) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) out.add(const SizedBox(height: 14));
      out.add(children[i]);
    }
    return out;
  }
}

/// Label above a field, with an optional required marker and a trailing widget.
class FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  final Widget? trailing;

  const FieldLabel(this.text, {super.key, this.required = false, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7, left: 2),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              color: AppColors.textSecondaryNavy,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (required)
            const Padding(
              padding: EdgeInsets.only(left: 3),
              child: Text('*', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w800)),
            ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

/// Label + field in one widget.
class LabeledField extends StatelessWidget {
  final String label;
  final bool required;
  final Widget? trailing;
  final Widget child;

  const LabeledField({super.key, required this.label, required this.child, this.required = false, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [FieldLabel(label, required: required, trailing: trailing), child],
    );
  }
}

/// Single-choice pills that animate between selected and unselected.
class ChipSelector<T> extends StatelessWidget {
  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final String Function(T) labelOf;
  final IconData Function(T)? iconOf;
  final Color color;

  const ChipSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.labelOf,
    this.iconOf,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          PressableScale(
            pressedScale: 0.94,
            onTap: () => onSelected(option),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: option == selected ? color : (AppColors.chipFill),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: option == selected ? color : (AppColors.border),
                ),
                boxShadow: option == selected
                    ? [BoxShadow(color: color.withAlpha(70), blurRadius: 12, offset: const Offset(0, 4))]
                    : const [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (iconOf != null) ...[
                    Icon(
                      iconOf!(option),
                      size: 16,
                      color: option == selected ? Colors.white : AppColors.textMutedNavy,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    labelOf(option),
                    style: TextStyle(
                      color: option == selected
                          ? Colors.white
                          : (AppColors.textSecondaryNavy),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Dashed drop-zone for picking a file, or a compact tile for the chosen file.
class UploadZone extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPick;

  /// When set, the chosen file is shown instead of the empty drop-zone.
  final String? fileName;
  final String? fileDetail;
  final Widget? preview;
  final VoidCallback? onRemove;

  const UploadZone({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPick,
    this.fileName,
    this.fileDetail,
    this.preview,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimaryNavy;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: fileName == null
          ? PressableScale(
              key: const ValueKey('empty'),
              onTap: onPick,
              child: CustomPaint(
                painter: _DashedBorderPainter(color: color.withAlpha(140)),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
                  decoration: BoxDecoration(
                    color: color.withAlpha(isDark ? 22 : 12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withAlpha(isDark ? 50 : 28),
                        ),
                        child: Icon(icon, color: color, size: 28),
                      ),
                      const SizedBox(height: 12),
                      Text(title, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Container(
              key: const ValueKey('file'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(isDark ? 26 : 14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withAlpha(70)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.square(
                      dimension: 54,
                      child: preview ??
                          Container(
                            color: color.withAlpha(isDark ? 50 : 28),
                            child: Icon(icon, color: color, size: 26),
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        if (fileDetail != null) ...[
                          const SizedBox(height: 2),
                          Text(fileDetail!, style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12)),
                        ],
                        const SizedBox(height: 2),
                        const Row(
                          children: [
                            Icon(Icons.lock_rounded, size: 12, color: AppColors.success),
                            SizedBox(width: 4),
                            Text(
                              'Encrypted on save',
                              style: TextStyle(color: AppColors.success, fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Replace',
                    onPressed: onPick,
                    icon: Icon(Icons.swap_horiz_rounded, color: color),
                  ),
                  if (onRemove != null)
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    ),
                ],
              ),
            ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;

  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(1), const Radius.circular(18)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 7), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => oldDelegate.color != color;
}
