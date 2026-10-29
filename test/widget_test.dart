import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myvault/main.dart';

void main() {
  testWidgets('MyVault app launches and displays title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyVaultApp(),
      ),
    );

    expect(find.text('MyVault'), findsOneWidget);
    expect(find.text('Personal Digital Vault'), findsOneWidget);
  });
}

