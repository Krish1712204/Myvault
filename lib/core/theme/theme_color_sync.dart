import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Keeps the adaptive [AppColors] palette in step with the resolved theme.
///
/// Many widgets read [AppColors.isDark] directly rather than depending on [Theme], so when
/// the brightness flips every widget below is rebuilt in place. They are rebuilt, not
/// remounted: state such as text typed into a form, scroll positions and open pages
/// survives (e.g. when "System" theme switches to dark at sunset mid-edit).
class ThemeColorSync extends StatefulWidget {
  final Widget child;

  const ThemeColorSync({super.key, required this.child});

  @override
  State<ThemeColorSync> createState() => _ThemeColorSyncState();
}

class _ThemeColorSyncState extends State<ThemeColorSync> {
  bool? _appliedIsDark;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    AppColors.isDark = isDark;
    if (_appliedIsDark != null && _appliedIsDark != isDark) {
      // Allowed during build: every element marked here is a descendant of this one,
      // so all of them are rebuilt in this same frame with the new palette.
      void markDirty(Element element) {
        element.markNeedsBuild();
        element.visitChildren(markDirty);
      }
      (context as Element).visitChildren(markDirty);
    }
    _appliedIsDark = isDark;
    return widget.child;
  }
}
