import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/vault_auth_notifier.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MyVaultApp(),
    ),
  );
}

class MyVaultApp extends ConsumerStatefulWidget {
  const MyVaultApp({super.key});

  @override
  ConsumerState<MyVaultApp> createState() => _MyVaultAppState();
}

class _MyVaultAppState extends ConsumerState<MyVaultApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final authNotifier = ref.read(vaultAuthStateProvider.notifier);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App moving to background: check if immediate auto-lock applies
      authNotifier.checkAutoLock(isBackgrounding: true);
    } else if (state == AppLifecycleState.resumed) {
      // App returning to foreground: check if inactivity timeout expired
      authNotifier.checkAutoLock(isBackgrounding: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        ref.read(vaultAuthStateProvider.notifier).recordActivity();
      },
      child: MaterialApp.router(
        title: 'MyVault',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    );
  }
}
