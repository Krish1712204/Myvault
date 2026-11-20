import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_color_sync.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/domain/vault_auth_notifier.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Plus Jakarta Sans'], license);
  });
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

    // "inactive" also fires for the notification shade and system dialogs (including the
    // biometric prompt), so only a real move to the background counts as leaving the app.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
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
    final themeMode = ref.watch(themeModeProvider);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        ref.read(vaultAuthStateProvider.notifier).recordActivity();
      },
      child: MaterialApp.router(
        title: 'MyVault',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: router,
        builder: (context, child) => ThemeColorSync(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
