import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/vault_auth_notifier.dart';
import '../../domain/vault_auth_state.dart';
import '../widgets/aurora_background.dart';
import '../widgets/vault_shield_logo.dart';
import '../widgets/welcome_illustrations.dart';

/// First screen of the app: a short animated introduction for new users,
/// and a calm "welcome back" entry point for an existing (locked) vault.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

enum _Illustration { orbit, shield, fingerprint }

class _Slide {
  final _Illustration illustration;
  final String title;
  final String body;

  const _Slide(this.illustration, this.title, this.body);
}

const _slides = [
  _Slide(
    _Illustration.orbit,
    'Your Personal Digital Vault',
    'Passwords, IDs, documents, notes and contacts — all in one private place.',
  ),
  _Slide(
    _Illustration.shield,
    'Locked down by design',
    'Encrypted on this phone with a key only your master password can open.',
  ),
  _Slide(
    _Illustration.fingerprint,
    'Open it in a touch',
    'Unlock with your fingerprint. Step away and your vault locks itself.',
  ),
];

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> with TickerProviderStateMixin {
  static final bool _isTest = Platform.environment.containsKey('FLUTTER_TEST');
  static const _autoAdvance = Duration(seconds: 5);

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  final PageController _pages = PageController();
  Timer? _autoplay;
  int _page = 0;
  bool _animate = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = !_isTest && !MediaQuery.disableAnimationsOf(context);
    if (animate == _animate && (_entrance.isAnimating || _entrance.isCompleted)) return;
    _animate = animate;

    if (_animate) {
      if (!_entrance.isCompleted) _entrance.forward();
      _shimmer.repeat();
      _restartAutoplay();
    } else {
      _entrance.value = 1;
      _shimmer.stop();
      _autoplay?.cancel();
    }
  }

  void _restartAutoplay() {
    _autoplay?.cancel();
    if (!_animate) return;
    _autoplay = Timer.periodic(_autoAdvance, (_) {
      if (!mounted || !_pages.hasClients) return;
      _pages.animateToPage(
        (_page + 1) % _slides.length,
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _entrance.dispose();
    _shimmer.dispose();
    _pages.dispose();
    super.dispose();
  }

  /// Fade + rise for a slice of the entrance timeline.
  Widget _reveal({required double start, required double end, double rise = 24, required Widget child}) {
    final curve = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      child: child,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(offset: Offset(0, rise * (1 - curve.value)), child: child),
      ),
    );
  }

  void _onPrimaryPressed(bool isVaultCreated) {
    HapticFeedback.lightImpact();
    _autoplay?.cancel();
    context.push(isVaultCreated ? '/unlock' : '/create-vault').then((_) => _restartAutoplay());
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(vaultAuthStateProvider);
    final isVaultCreated = authState.status == VaultStatus.locked || authState.status == VaultStatus.unlocked;
    final fingerprintReady = authState.isBiometricAvailable && authState.isBiometricEnabled;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimaryNavy;
    final textMuted = AppColors.textMutedNavy;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AuroraBackground(
          animate: _animate,
          child: SafeArea(
            child: Column(
              children: [
                _reveal(
                  start: 0.0,
                  end: 0.4,
                  rise: -12,
                  child: _Header(textPrimary: textPrimary, textMuted: textMuted, isDark: isDark),
                ),
                Expanded(
                  child: _reveal(
                    start: 0.12,
                    end: 0.65,
                    rise: 36,
                    child: NotificationListener<ScrollStartNotification>(
                      onNotification: (n) {
                        if (n.dragDetails != null) _restartAutoplay(); // user swiped: reset the clock
                        return false;
                      },
                      child: PageView.builder(
                        controller: _pages,
                        itemCount: _slides.length,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (context, i) => _SlideView(
                          slide: _slides[i],
                          index: i,
                          pages: _pages,
                          animate: _animate,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                _reveal(
                  start: 0.45,
                  end: 0.8,
                  child: _PageIndicator(pages: _pages, count: _slides.length, isDark: isDark),
                ),
                const SizedBox(height: 28),
                _reveal(
                  start: 0.55,
                  end: 1.0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _PrimaryButton(
                          label: isVaultCreated ? 'Unlock Vault' : 'Get Started',
                          icon: isVaultCreated
                              ? (fingerprintReady ? Icons.fingerprint_rounded : Icons.lock_open_rounded)
                              : Icons.arrow_forward_rounded,
                          iconTrailing: !isVaultCreated,
                          shimmer: _shimmer,
                          onPressed: () => _onPrimaryPressed(isVaultCreated),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 14, color: textMuted),
                            const SizedBox(width: 6),
                            Text(
                              isVaultCreated
                                  ? 'Welcome back. Your vault is locked.'
                                  : 'Your data stays on this phone. Always.',
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Color textPrimary;
  final Color textMuted;
  final bool isDark;

  const _Header({required this.textPrimary, required this.textMuted, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          const VaultShieldLogo(size: 40),
          const SizedBox(width: 10),
          Text(
            'MyVault',
            style: TextStyle(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface.withAlpha(200),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  'Offline · Encrypted',
                  style: TextStyle(color: textMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  final int index;
  final PageController pages;
  final bool animate;
  final Color textPrimary;
  final Color textMuted;

  const _SlideView({
    required this.slide,
    required this.index,
    required this.pages,
    required this.animate,
    required this.textPrimary,
    required this.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Leave room for the title + body block (~170px) under the illustration.
        final heroSize = math.max(
          120.0,
          math.min(constraints.maxWidth * 0.84, constraints.maxHeight - 190),
        );
        final illustration = switch (slide.illustration) {
          _Illustration.orbit => VaultOrbitIllustration(size: heroSize, animate: animate),
          _Illustration.shield => ShieldIllustration(size: heroSize, animate: animate),
          _Illustration.fingerprint => FingerprintIllustration(size: heroSize, animate: animate),
        };

        // Parallax: the illustration lags behind the swipe and fades, the text follows closer.
        return AnimatedBuilder(
          animation: pages,
          builder: (context, _) {
            final page = pages.hasClients && pages.position.haveDimensions ? pages.page ?? 0 : 0.0;
            final delta = (index - page).clamp(-1.0, 1.0);
            final fade = 1 - delta.abs() * 0.7;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: fade.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(delta * constraints.maxWidth * 0.35, 0),
                      child: Transform.scale(
                        scale: 1 - delta.abs() * 0.12,
                        // Same box for every slide so the title never jumps while swiping.
                        child: SizedBox(
                          width: heroSize,
                          height: heroSize * 0.86,
                          child: OverflowBox(
                            maxWidth: heroSize,
                            maxHeight: heroSize,
                            child: RepaintBoundary(child: ExcludeSemantics(child: illustration)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Transform.translate(
                    offset: Offset(delta * constraints.maxWidth * 0.12, 0),
                    child: Opacity(
                      opacity: fade.clamp(0.0, 1.0),
                      child: Column(
                        children: [
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 28,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.9,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 330),
                            child: Text(
                              slide.body,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 15,
                                height: 1.55,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Pills that stretch and recolour continuously with the swipe position.
class _PageIndicator extends StatelessWidget {
  final PageController pages;
  final int count;
  final bool isDark;

  const _PageIndicator({required this.pages, required this.count, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pages,
      builder: (context, _) {
        final page = pages.hasClients && pages.position.haveDimensions ? pages.page ?? 0 : 0.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              Builder(builder: (context) {
                final t = (1 - (page - i).abs()).clamp(0.0, 1.0);
                return GestureDetector(
                  onTap: () => pages.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOutCubic,
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8 + 22 * t,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Color.lerp(
                        AppColors.handle,
                        AppColors.primaryAccent,
                        t,
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

/// Gradient call-to-action that sinks slightly under the finger and catches a periodic sheen.
class _PrimaryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool iconTrailing;
  final Animation<double> shimmer;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.iconTrailing,
    required this.shimmer,
    required this.onPressed,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(widget.icon, color: Colors.white, size: 22);
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!widget.iconTrailing) ...[icon, const SizedBox(width: 10)],
        Text(
          widget.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        if (widget.iconTrailing) ...[const SizedBox(width: 10), icon],
      ],
    );

    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 58,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.buttonGradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryAccent.withAlpha(_pressed ? 60 : 100),
                  blurRadius: _pressed ? 12 : 24,
                  offset: Offset(0, _pressed ? 4 : 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Sheen sweeping across the button
                  AnimatedBuilder(
                    animation: widget.shimmer,
                    builder: (context, _) {
                      final x = -1.6 + widget.shimmer.value * 4.2;
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(x - 0.6, -1),
                            end: Alignment(x + 0.6, 1),
                            colors: [
                              Colors.white.withAlpha(0),
                              Colors.white.withAlpha(45),
                              Colors.white.withAlpha(0),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  content,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
