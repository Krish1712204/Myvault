import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/vault_auth_notifier.dart';
import '../../domain/vault_auth_state.dart';

/// Wraps the unlocked app and, once, offers to turn on fingerprint unlock: right after a vault
/// is created, or after the security upgrade removed an old fingerprint setup.
class BiometricSetupPrompter extends ConsumerStatefulWidget {
  final Widget child;

  const BiometricSetupPrompter({super.key, required this.child});

  @override
  ConsumerState<BiometricSetupPrompter> createState() => _BiometricSetupPrompterState();
}

class _BiometricSetupPrompterState extends ConsumerState<BiometricSetupPrompter> {
  bool _offering = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOffer(ref.read(vaultAuthStateProvider)));
  }

  Future<void> _maybeOffer(VaultAuthState auth) async {
    if (_offering || !mounted) return;
    if (auth.status != VaultStatus.unlocked || !auth.offerBiometricSetup) return;
    _offering = true;

    final notifier = ref.read(vaultAuthStateProvider.notifier);
    final shouldOffer = await notifier.takeBiometricSetupOffer();
    if (!shouldOffer || !mounted) {
      _offering = false;
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
          child: const Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 36),
        ),
        title: const Text('Unlock with your fingerprint?', textAlign: TextAlign.center),
        content: const Text(
          'Open your vault with a touch instead of typing your master password. '
          'Your fingerprint never leaves this phone, and adding a new fingerprint '
          'turns this off automatically.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Turn on'),
          ),
        ],
      ),
    );

    if (accepted == true) {
      final enabled = await notifier.setBiometricEnabled(true);
      if (mounted && enabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fingerprint unlock is on.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
    _offering = false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VaultAuthState>(vaultAuthStateProvider, (_, next) => _maybeOffer(next));
    return widget.child;
  }
}
