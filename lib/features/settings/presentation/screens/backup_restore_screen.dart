import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/backup/vault_backup_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../../auth/domain/vault_auth_notifier.dart';
import '../../../auth/domain/vault_auth_state.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  static const String _lastBackupStorageKey = 'myvault_last_backup_timestamp';
  final _secureStorage = const FlutterSecureStorage();

  String _lastBackupDate = 'Never';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLastBackupDate();
  }

  Future<void> _loadLastBackupDate() async {
    try {
      final saved = await _secureStorage.read(key: _lastBackupStorageKey);
      if (saved != null && saved.isNotEmpty) {
        setState(() => _lastBackupDate = saved);
      }
    } catch (_) {}
  }

  Future<void> _saveLastBackupDate(String dateStr) async {
    try {
      await _secureStorage.write(key: _lastBackupStorageKey, value: dateStr);
      setState(() => _lastBackupDate = dateStr);
    } catch (_) {}
  }

  String _formatTimestamp(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[dt.month - 1];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} $month ${dt.year}, $hour:$minute $ampm';
  }

  /// Opens the Create Backup dialog
  Future<void> _showCreateBackupDialog() async {
    final authState = ref.read(vaultAuthStateProvider);
    if (authState.status != VaultStatus.unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vault is locked. Unlock your vault before creating a backup.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final session = ref.read(vaultSessionProvider);
    final vek = session.vek;
    if (vek == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Active vault session not found. Please re-authenticate.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final passphraseController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscurePassphrase = true;
    bool obscureConfirm = true;
    String? errorMessage;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: AppColors.primary, size: 26),
                          SizedBox(width: 10),
                          Text(
                            'Create Vault Backup',
                            style: TextStyle(
                              color: AppColors.textPrimaryNavy,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Important Passphrase Information',
                              style: TextStyle(
                                color: AppColors.textPrimaryNavy,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• This backup passphrase is separate from your vault master password.\n'
                              '• The backup is secured with high-grade security.\n'
                              '• If you lose this passphrase, this backup file cannot be restored.',
                              style: TextStyle(
                                color: AppColors.textPrimaryNavy,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const Text(
                        'Backup Passphrase (min 8 chars) *',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimaryNavy),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: passphraseController,
                        obscureText: obscurePassphrase,
                        decoration: InputDecoration(
                          hintText: 'Enter backup passphrase',
                          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMutedNavy),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassphrase ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: AppColors.textMutedNavy,
                            ),
                            onPressed: () => setModalState(() => obscurePassphrase = !obscurePassphrase),
                          ),
                          fillColor: AppColors.background,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Confirm Passphrase *',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimaryNavy),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: confirmController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          hintText: 'Re-enter backup passphrase',
                          prefixIcon: const Icon(Icons.lock_clock_outlined, color: AppColors.textMutedNavy),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: AppColors.textMutedNavy,
                            ),
                            onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                          ),
                          fillColor: AppColors.background,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                final pass = passphraseController.text;
                                final confirm = confirmController.text;
                                if (pass.length < 8) {
                                  setModalState(() => errorMessage = 'Passphrase must be at least 8 characters long.');
                                  return;
                                }
                                if (pass != confirm) {
                                  setModalState(() => errorMessage = 'Passphrases do not match.');
                                  return;
                                }

                                Navigator.pop(sheetContext);
                                await _executeCreateBackup(pass, vek);
                              },
                              child: const Text('Export Backup'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    // Best-effort in-memory cleanup of passphrase fields
    passphraseController.clear();
    confirmController.clear();
    passphraseController.dispose();
    confirmController.dispose();
  }

  Future<void> _executeCreateBackup(String passphrase, Uint8List vek) async {
    setState(() => _isLoading = true);
    final backupService = ref.read(vaultBackupServiceProvider);

    try {
      final now = DateTime.now();
      final dateTag = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'myvault_backup_$dateTag.myvault';

      // Generate encrypted backup bytes
      final backupBytes = await backupService.createBackupBytes(
        passphrase: passphrase,
        vek: vek,
      );

      // Prompt user to save file via Storage Access Framework / FilePicker
      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Save MyVault Backup',
        fileName: fileName,
        bytes: backupBytes,
        mimeType: 'application/octet-stream',
      );

      if (savedUri == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup creation canceled by user.'),
            backgroundColor: AppColors.textPrimaryNavy,
          ),
        );
        return;
      }

      final formattedDate = _formatTimestamp(now);
      await _saveLastBackupDate(formattedDate);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup saved successfully ($fileName)!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Opens the Restore Backup picker and verification dialog
  Future<void> _startRestoreFlow() async {
    final authState = ref.read(vaultAuthStateProvider);
    if (authState.status != VaultStatus.unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vault is locked. Unlock your vault before restoring a backup.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final session = ref.read(vaultSessionProvider);
    final vek = session.vek;
    if (vek == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Active vault session not found. Please re-authenticate.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final picked = await FilePicker.pickFiles(
        dialogTitle: 'Select MyVault Backup File (.myvault)',
        type: FileType.custom,
        allowedExtensions: ['myvault', 'enc', 'bin'],
      );

      if (picked.isEmpty) return;

      final file = picked.first;
      final bytes = await file.readAsBytes();

      final backupService = ref.read(vaultBackupServiceProvider);
      BackupInspectResult inspect;
      try {
        inspect = await backupService.inspectBackupFile(bytes);
      } catch (e) {
        if (!mounted) return;
        await _showErrorDialog(
          title: 'Invalid Backup File',
          message: e.toString(),
        );
        return;
      }

      if (!mounted) return;
      await _showRestoreConfirmationDialog(bytes, inspect, vek);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reading backup file: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showRestoreConfirmationDialog(
    Uint8List fileBytes,
    BackupInspectResult inspect,
    Uint8List currentVek,
  ) async {
    final passphraseController = TextEditingController();
    bool obscurePassphrase = true;
    bool replaceExisting = true;
    String? errorMessage;

    final createdDateStr = inspect.createdAt > 0
        ? _formatTimestamp(DateTime.fromMillisecondsSinceEpoch(inspect.createdAt))
        : 'Unknown';
    final sizeKb = (inspect.fileSize / 1024).toStringAsFixed(1);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Icon(Icons.restore_page_rounded, color: AppColors.primary, size: 26),
                          SizedBox(width: 10),
                          Text(
                            'Restore from Backup',
                            style: TextStyle(
                              color: AppColors.textPrimaryNavy,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Backup metadata overview card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            _buildInfoLine('Format Version', 'v${inspect.version} (${inspect.kdfAlgorithm} + AES-256-GCM)'),
                            const SizedBox(height: 4),
                            _buildInfoLine('Created Date', createdDateStr),
                            const SizedBox(height: 4),
                            _buildInfoLine('Vault Items', '${inspect.itemCount} items (${inspect.fileCount} attachments)'),
                            const SizedBox(height: 4),
                            _buildInfoLine('Backup Size', '$sizeKb KB'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Warning alert
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Restoring this backup will replace current vault items with the backup contents. An automatic recovery rollback point is created before writing.',
                                style: TextStyle(
                                  color: AppColors.textPrimaryNavy,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Replace confirmation switch
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Replace Existing Vault Items',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textPrimaryNavy,
                              ),
                            ),
                            Switch(
                              value: replaceExisting,
                              activeThumbColor: AppColors.error,
                              onChanged: (val) => setModalState(() => replaceExisting = val),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      if (errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      const Text(
                        'Backup Passphrase *',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimaryNavy),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: passphraseController,
                        obscureText: obscurePassphrase,
                        decoration: InputDecoration(
                          hintText: 'Enter passphrase used to create this backup',
                          prefixIcon: const Icon(Icons.key_rounded, color: AppColors.textMutedNavy),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassphrase ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: AppColors.textMutedNavy,
                            ),
                            onPressed: () => setModalState(() => obscurePassphrase = !obscurePassphrase),
                          ),
                          fillColor: AppColors.background,
                        ),
                      ),

                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                final pass = passphraseController.text;
                                if (pass.isEmpty) {
                                  setModalState(() => errorMessage = 'Please enter the backup passphrase.');
                                  return;
                                }

                                Navigator.pop(sheetContext);
                                await _executeRestore(fileBytes, pass, currentVek, replaceExisting);
                              },
                              child: const Text('Authenticate & Restore'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    passphraseController.clear();
    passphraseController.dispose();
  }

  Future<void> _executeRestore(
    Uint8List fileBytes,
    String passphrase,
    Uint8List currentVek,
    bool replaceExisting,
  ) async {
    setState(() => _isLoading = true);
    final backupService = ref.read(vaultBackupServiceProvider);

    try {
      // 1. Authenticate and decrypt backup
      final payload = await backupService.decryptAndValidateBackup(
        fileBytes: fileBytes,
        passphrase: passphrase,
      );

      // 2. Perform atomic restore with rollback protection
      final result = await backupService.restoreBackupPayload(
        payload: payload,
        currentVek: currentVek,
        replaceExisting: replaceExisting,
      );

      // 3. Reload vault items in state
      await ref.read(vaultItemsProvider.notifier).loadItems();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
              SizedBox(width: 10),
              Text(
                'Restoration Complete',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy),
              ),
            ],
          ),
          content: Text(
            result.message,
            style: const TextStyle(color: AppColors.textPrimaryNavy, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(
        title: 'Restoration Failed',
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showErrorDialog({required String title, required String message}) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textPrimaryNavy, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMutedNavy, fontSize: 12)),
        Text(value, style: const TextStyle(color: AppColors.textPrimaryNavy, fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Backup & Restore',
          style: TextStyle(
            color: AppColors.textPrimaryNavy,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)),
                    SizedBox(height: 16),
                    Text(
                      'Processing backup cryptographic operation...',
                      style: TextStyle(color: AppColors.textPrimaryNavy, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Zero plaintext written to disk.',
                      style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                children: [
                  // Top Hero illustration card
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.cloud_done_rounded, color: AppColors.primary, size: 36),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Keep your data safe',
                          style: TextStyle(
                            color: AppColors.textPrimaryNavy,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Create a secure backup of your\nvault and restore it anytime.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textMutedNavy,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Backup Section
                  const Text(
                    'Backup',
                    style: TextStyle(color: AppColors.textPrimaryNavy, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.cloud_upload_outlined, color: AppColors.primary),
                          title: const Text('Create Vault Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: const Text('Export all vault items and attachments to a portable .myvault file.', style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMutedNavy),
                          onTap: _showCreateBackupDialog,
                        ),
                        const Divider(color: AppColors.border, height: 1),
                        ListTile(
                          leading: const Icon(Icons.check_circle_rounded, color: AppColors.success),
                          title: const Text('Last Backup', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(_lastBackupDate, style: const TextStyle(fontSize: 12, color: AppColors.textMutedNavy)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Restore Section
                  const Text(
                    'Restore',
                    style: TextStyle(color: AppColors.textPrimaryNavy, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.cloud_download_outlined, color: AppColors.primary),
                      title: const Text('Restore from Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: const Text('Import and authenticate a .myvault backup file.', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMutedNavy),
                      onTap: _startRestoreFlow,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Security Invariants Notice
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.security_rounded, color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Cryptographic Portability',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimaryNavy,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Backups are protected with high-grade security derived from your backup passphrase. '
                          'Device-specific Keystore keys and master passwords are never included, allowing safe transfer to another device.',
                          style: TextStyle(
                            color: AppColors.textMutedNavy,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
      ),
    );
  }
}
