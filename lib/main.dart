import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/vault/presentation/screens/vault_home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MyVaultApp(),
    ),
  );
}

class MyVaultApp extends StatelessWidget {
  const MyVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyVault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const VaultHomeScreen(),
    );
  }
}

