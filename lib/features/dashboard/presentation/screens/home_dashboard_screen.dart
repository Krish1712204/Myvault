import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/profile/user_profile_provider.dart';
import '../../../../core/ui/motion.dart';
import '../../../../shared/state/vault_insights_provider.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../../../shared/widgets/notifications_sheet.dart';
import '../../../../shared/widgets/pressable_scale.dart';
import '../../../../shared/widgets/user_profile_sheet.dart';
import '../../../vault_items/data/vault_item_model.dart';
import '../widgets/category_tile.dart';
import '../widgets/quick_actions_row.dart';
import '../widgets/recent_items_section.dart';
import '../widgets/vault_health_card.dart';
import '../widgets/vault_tips_card.dart';

/// Time-of-day greeting, e.g. "Good evening".
String greetingFor(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'Good morning';
  if (h >= 12 && h < 17) return 'Good afternoon';
  if (h >= 17 && h < 22) return 'Good evening';
  return 'Good night';
}

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (motionEnabled(context)) {
      _entrance.forward();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _wave.forward(from: 0);
      });
    } else {
      _entrance.value = 1;
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _wave.dispose();
    super.dispose();
  }

  Widget _reveal(int index, Widget child) {
    final start = (index * 0.09).clamp(0.0, 0.6);
    final curve = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, (start + 0.45).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      child: child,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(offset: Offset(0, 28 * (1 - curve.value)), child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(vaultItemsProvider);
    final counts = ref.watch(categoryCountsProvider);
    final favourites = ref.watch(favouriteItemsProvider);
    final profile = ref.watch(userProfileProvider);
    final allAlerts = ref.watch(vaultAlertsProvider).valueOrNull ?? const <VaultAlert>[];
    final visibleAlerts = ref.watch(visibleAlertsProvider).valueOrNull ?? const <VaultAlert>[];
    final storage = ref.watch(storageUsageProvider).valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimaryNavy;

    final latestByCategory = <VaultCategory, VaultItem>{};
    for (final item in items) {
      final current = latestByCategory[item.category];
      if (current == null || (item.updatedAt ?? 0) > (current.updatedAt ?? 0)) {
        latestByCategory[item.category] = item;
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverList.list(
                  children: [
                    _reveal(
                      0,
                      _GreetingHeader(
                        name: profile.name,
                        photo: ref.watch(profilePhotoProvider).valueOrNull,
                        alertCount: visibleAlerts.length,
                        wave: _wave,
                        textPrimary: textPrimary,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _reveal(
                      1,
                      VaultHealthCard(
                        score: vaultHealthScore(allAlerts),
                        totalItems: items.length,
                        favourites: favourites.length,
                        alerts: visibleAlerts.length,
                      ),
                    ),
                    const SizedBox(height: 26),
                    _reveal(2, const VaultTipsCard()),
                    const SizedBox(height: 24),
                    _reveal(
                      2,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Vault',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    '${items.length} item${items.length == 1 ? '' : 's'}',
                                    if (storage != null) '${formatBytes(storage.totalBytes)} encrypted',
                                  ].join(' · '),
                                  style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12.5, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/categories'),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            child: const Text('See all', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.98,
                  children: [
                    for (final (i, category) in VaultCategory.values.indexed)
                      _reveal(
                        3 + i ~/ 2,
                        CategoryTile(
                          category: category,
                          count: counts[category] ?? 0,
                          latestTitle: latestByCategory[category]?.title,
                        ),
                      ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 120),
                sliver: SliverList.list(
                  children: [
                    _reveal(6, const QuickActionsRow()),
                    const SizedBox(height: 26),
                    _reveal(7, RecentItemsSection(items: items)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  final String name;
  final Uint8List? photo;
  final int alertCount;
  final AnimationController wave;
  final Color textPrimary;
  final bool isDark;

  const _GreetingHeader({
    required this.name,
    required this.photo,
    required this.alertCount,
    required this.wave,
    required this.textPrimary,
    required this.isDark,
  });

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstName = name.trim().isEmpty ? 'Welcome' : name.trim().split(RegExp(r'\s+')).first;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    final photo = this.photo;

    return Row(
      children: [
        PressableScale(
          onTap: () => UserProfileSheet.show(context),
          child: Container(
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(colors: AppColors.avatarRingGradient),
            ),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: isDark ? AppColors.canvas : Colors.white, width: 2),
              ),
              child: ClipOval(
                child: photo != null
                    ? Image.memory(photo, fit: BoxFit.cover, gaplessPlayback: true)
                    : Center(
                        child: initials.isEmpty
                            ? const Icon(Icons.person_rounded, color: AppColors.primary, size: 26)
                            : Text(
                                initials,
                                style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.trim().isEmpty ? greetingFor(now) : '${greetingFor(now)},',
                style: TextStyle(color: AppColors.textMutedNavy, fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      firstName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => wave.forward(from: 0),
                    child: AnimatedBuilder(
                      animation: wave,
                      builder: (context, child) {
                        // Two and a half wiggles that settle back to rest.
                        final t = wave.value;
                        final angle = math.sin(t * math.pi * 5) * 0.45 * (1 - t);
                        return Transform.rotate(
                          angle: angle,
                          alignment: const Alignment(0.4, 0.8),
                          child: child,
                        );
                      },
                      child: const Text('👋', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}',
                style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        _BellButton(count: alertCount, isDark: isDark),
      ],
    );
  }
}

class _BellButton extends StatefulWidget {
  final int count;
  final bool isDark;

  const _BellButton({required this.count, required this.isDark});

  @override
  State<_BellButton> createState() => _BellButtonState();
}

class _BellButtonState extends State<_BellButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeRing();
  }

  @override
  void didUpdateWidget(_BellButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count) _maybeRing();
  }

  void _maybeRing() {
    if (widget.count > 0 && motionEnabled(context)) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) _ring.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => NotificationsSheet.show(context),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(widget.isDark ? 40 : 10), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _ring,
              builder: (context, child) => Transform.rotate(
                angle: math.sin(_ring.value * math.pi * 6) * 0.35 * (1 - _ring.value),
                alignment: Alignment.topCenter,
                child: child,
              ),
              child: Icon(
                widget.count > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded,
                color: AppColors.textPrimaryNavy,
                size: 23,
              ),
            ),
            if (widget.count > 0)
              Positioned(
                top: 6,
                right: 6,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.elasticOut,
                  builder: (context, s, child) => Transform.scale(scale: s, child: child),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${widget.count}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, height: 1),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
