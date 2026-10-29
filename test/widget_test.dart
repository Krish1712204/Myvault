import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myvault/main.dart';

void main() {
  testWidgets('MyVault app launches and renders home dashboard with categories', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MyVaultApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title and Hero card
    expect(find.text('MyVault'), findsWidgets);
    expect(find.text('Good Morning.'), findsOneWidget);
    expect(find.text('Your data is safe and secure'), findsOneWidget);

    // Verify Dashboard Categories
    expect(find.text('Passwords'), findsOneWidget);
    expect(find.text('ID Cards'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Contacts'), findsOneWidget);

    // Verify Quick Actions
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Add Item'), findsOneWidget);
  });

  testWidgets('Bottom navigation switches between Search, Categories, and Settings', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MyVaultApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Search tab in bottom bar
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Find anything in your vault'), findsOneWidget);

    // Tap Categories tab in bottom bar
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.text('Categories'), findsWidgets);

    // Tap Settings tab in bottom bar
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Account & Security'), findsOneWidget);
    expect(find.text('Biometric Unlock'), findsOneWidget);
  });
}
