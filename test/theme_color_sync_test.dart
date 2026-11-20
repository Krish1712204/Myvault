import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvault/core/constants/app_colors.dart';
import 'package:myvault/core/theme/theme_color_sync.dart';

/// Reads the static palette the way many app widgets do (no Theme dependency).
class _PaletteProbe extends StatelessWidget {
  const _PaletteProbe();

  @override
  Widget build(BuildContext context) => Text(AppColors.isDark ? 'dark' : 'light');
}

Widget _app(ThemeMode mode) => MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: mode,
      builder: (context, child) => ThemeColorSync(child: child!),
      home: const Scaffold(body: Column(children: [TextField(), _PaletteProbe()])),
    );

void main() {
  testWidgets('a theme switch repaints static-palette widgets and keeps typed text', (tester) async {
    await tester.pumpWidget(_app(ThemeMode.light));
    await tester.enterText(find.byType(TextField), 'unsaved draft');
    expect(find.text('light'), findsOneWidget);

    await tester.pumpWidget(_app(ThemeMode.dark));
    await tester.pumpAndSettle();

    expect(find.text('dark'), findsOneWidget, reason: 'widgets reading AppColors must rebuild');
    expect(find.text('unsaved draft'), findsOneWidget, reason: 'form state must survive the switch');
    AppColors.isDark = false;
  });
}
