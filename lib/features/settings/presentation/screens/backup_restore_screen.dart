import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/backup/vault_backup_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/ui/formatters.dart';
import '../../../../core/ui/user_message.dart';
import '../../../../shared/state/vault_insights_provider.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../../../shared/widgets/vault_sheet.dart';
import '../../../auth/domain/vault_auth_notifier.dart';
import '../../../auth/domain/vault_auth_state.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  DateTime? _lastBackupAt;
  bool _loadedLastBackup = false;

  /// Shown full-screen while a backup or restore runs; null when idle.
  String? _busyMessage;
  double? _busyProgress;

  @override
  void initState() {
    super.initState();
    _loadLastBackupDate();
  }

  Future<void> _loadLastBackupDate() async {
    DateTime? saved;
    try {
      saved = await ref.read(vaultStorageServiceProvider).getLastBackupAt();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _lastBackupAt = saved;
        _loadedLastBackup = true;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  /// The key that opens this vault, or null (with a message) when the vault is locked.
  Uint8List? _unlockedVek() {
    final vek = ref.read(vaultSessionProvider).vek;
    if (ref.read(vaultAuthStateProvider).status != VaultStatus.unlocked || vek == null) {
      _showError('Unlock your vault first.');
      return null;
    }
    return vek;
  }

  // ---------------------------------------------------------------------------
  // Create a backup

  Future<void> _showCreateBackupSheet() async {
    final vek = _unlockedVek();
    if (vek == null) return;

    final passphrase = await showVaultSheet<String>(context, builder: (_) => const _CreateBackupSheet());
    if (passphrase == null || !mounted) return;
    await _createBackup(passphrase, vek);
  }

  Future<void> _createBackup(String passphrase, Uint8List vek) async {
    setState(() => _busyMessage = 'Encrypting your backup…');
    final backupService = ref.read(vaultBackupServiceProvider);

    try {
      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final fileName = 'myvault_backup_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}.myvault';

      // If some attachments can't be read, say which ones and let the user decide,
      // rather than silently leaving them out.
      Uint8List backupBytes;
      try {
        backupBytes = await backupService.createBackupBytes(passphrase: passphrase, vek: vek);
      } on BackupIncompleteException catch (e) {
        if (!mounted) return;
        final proceed = await showConfirmDialog(
          context,
          icon: Icons.broken_image_outlined,
          title: 'Some attachments can’t be read',
          message: '${e.message}\n\nCreate the backup without them?',
          confirmLabel: 'Back Up Anyway',
        );
        if (!proceed) return;
        backupBytes = await backupService.createBackupBytes(
          passphrase: passphrase,
          vek: vek,
          allowMissingAttachments: true,
        );
      }

      if (mounted) setState(() => _busyMessage = 'Choose where to save the file…');
      ref.read(vaultAuthStateProvider.notifier).allowExternalActivity();
      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Save MyVault Backup',
        fileName: fileName,
        bytes: backupBytes,
        mimeType: 'application/octet-stream',
      );
      if (savedUri == null) return; // The user closed the save dialog.

      try {
        await ref.read(vaultStorageServiceProvider).setLastBackupAt(now);
      } catch (_) {}
      refreshVaultAlerts(ref);
      if (!mounted) return;
      setState(() => _lastBackupAt = now);
      await showResultDialog(
        context,
        tone: NoticeTone.success,
        title: 'Backup saved',
        message: 'Saved as $fileName.\n\nKeep the file and its passphrase somewhere safe, away from this phone.',
        buttonLabel: 'Done',
      );
    } catch (e) {
      if (!mounted) return;
      await showResultDialog(
        context,
        tone: NoticeTone.error,
        title: 'Backup failed',
        message: userMessage(e, fallback: 'The backup could not be created. Please try again.'),
      );
    } finally {
      if (mounted) setState(() => _busyMessage = null);
    }
  }

  // ---------------------------------------------------------------------------
  // Restore a backup

  Future<void> _startRestoreFlow() async {
    final vek = _unlockedVek();
    if (vek == null) return;

    final PlatformFile file;
    final Uint8List bytes;
    try {
      ref.read(vaultAuthStateProvider.notifier).allowExternalActivity();
      final picked = await FilePicker.pickFiles(
        dialogTitle: 'Choose a MyVault backup (.myvault)',
        type: FileType.custom,
        allowedExtensions: ['myvault', 'enc', 'bin'],
      );
      if (picked.isEmpty) return;
      file = picked.first;
      bytes = await file.readAsBytes();
      // The picker leaves an unencrypted copy in the app cache; remove it now.
      FilePicker.clearTemporaryFiles().ignore();
    } catch (e) {
      if (mounted) _showError(userMessage(e, fallback: 'Could not open that file.'));
      return;
    }

    final backupService = ref.read(vaultBackupServiceProvider);
    final BackupInspectResult inspect;
    try {
      inspect = await backupService.inspectBackupFile(bytes);
    } catch (e) {
      if (!mounted) return;
      await showResultDialog(
        context,
        tone: NoticeTone.error,
        title: 'Not a MyVault backup',
        message: userMessage(e, fallback: 'This file isn’t a MyVault backup, or it is damaged.'),
      );
      return;
    }
    if (!mounted) return;

    // The sheet checks the passphrase itself, so a typo can be corrected in place.
    final payload = await showVaultSheet<BackupPayload>(
      context,
      builder: (_) => _RestoreBackupSheet(fileName: file.name, fileBytes: bytes, inspect: inspect),
    );
    if (payload == null || !mounted) return;
    await _restore(payload, vek);
  }

  Future<void> _restore(BackupPayload payload, Uint8List vek) async {
    setState(() => _busyMessage = 'Restoring your vault…');
    try {
      final result = await ref.read(vaultBackupServiceProvider).restoreBackupPayload(
            payload: payload,
            currentVek: vek,
            replaceExisting: true, // Confirmed in the restore sheet.
            onProgress: (fraction, _) {
              if (mounted) setState(() => _busyProgress = fraction);
            },
          );
      await ref.read(vaultItemsProvider.notifier).loadItems();
      refreshVaultAlerts(ref);
      ref.invalidate(storageUsageProvider);

      if (!mounted) return;
      final items = result.itemsRestored == 1 ? '1 item' : '${result.itemsRestored} items';
      final files = result.filesRestored == 1 ? '1 attachment' : '${result.filesRestored} attachments';
      await showResultDialog(
        context,
        tone: NoticeTone.success,
        title: 'Vault restored',
        message: 'Your vault now has $items and $files from the backup.',
        buttonLabel: 'Done',
      );
    } catch (e) {
      if (!mounted) return;
      await showResultDialog(
        context,
        tone: NoticeTone.error,
        title: 'Restore failed',
        message: userMessage(e, fallback: 'The backup could not be restored. Your vault was not changed.'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyMessage = null;
          _busyProgress = null;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final busy = _busyMessage != null;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: busy ? null : () => context.pop(),
          ),
          title: Text(
            'Backup & Restore',
            style: TextStyle(color: AppColors.textPrimaryNavy, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        body: SafeArea(child: busy ? _BusyView(message: _busyMessage!, progress: _busyProgress) : _buildContent()),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
      children: [
        _LastBackupCard(lastBackupAt: _lastBackupAt, loaded: _loadedLastBackup),
        const SizedBox(height: AppSpacing.lg),
        _sectionLabel('Backup file'),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              _ActionTile(
                icon: Icons.cloud_upload_outlined,
                title: 'Create Backup',
                subtitle: 'Save an encrypted copy of every item and attachment to a file.',
                onTap: _showCreateBackupSheet,
              ),
              Divider(color: AppColors.border, height: 1, indent: 64),
              _ActionTile(
                icon: Icons.settings_backup_restore_rounded,
                title: 'Restore from File',
                subtitle: 'Replace this vault with the contents of a .myvault backup.',
                onTap: _startRestoreFlow,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const NoticeBanner(
          tone: NoticeTone.info,
          icon: Icons.shield_outlined,
          title: 'How backup files work',
          message: 'Each file is locked with its own passphrase, separate from your master password. '
              'It works on any phone with MyVault, so keep it somewhere other than this phone, '
              'such as a computer or USB drive.',
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: AppColors.textMutedNavy,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      );
}

/// How recent the last backup is, coloured by whether it needs attention.
class _LastBackupCard extends StatelessWidget {
  final DateTime? lastBackupAt;
  final bool loaded;

  const _LastBackupCard({required this.lastBackupAt, required this.loaded});

  @override
  Widget build(BuildContext context) {
    final last = lastBackupAt;
    final stale = last == null || DateTime.now().difference(last).inDays >= backupReminderDays;
    final color = !loaded ? AppColors.textMutedNavy : (stale ? AppColors.warning : AppColors.success);
    final headline = !loaded
        ? 'Checking…'
        : last == null
            ? 'No backup yet'
            : 'Backed up ${relativeTime(last.millisecondsSinceEpoch, DateTime.now()).toLowerCase()}';
    final detail = !loaded
        ? ''
        : last == null
            ? 'If this phone is lost or reset, a backup is the only way to get your vault back.'
            : stale
                ? '${formatDateTime(last)}. Anything added since then isn’t in a backup.'
                : formatDateTime(last);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconTile(
            stale && loaded ? Icons.history_rounded : Icons.verified_user_rounded,
            color: color,
            size: 52,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LAST BACKUP',
                    style: TextStyle(
                      color: AppColors.textMutedNavy,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    )),
                const SizedBox(height: 3),
                Text(
                  headline,
                  style: TextStyle(color: AppColors.textPrimaryNavy, fontSize: 17, fontWeight: FontWeight.w800),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(detail, style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12.5, height: 1.35)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: IconTile(icon, size: 40),
      title: Text(title, style: TextStyle(color: AppColors.textPrimaryNavy, fontWeight: FontWeight.w700, fontSize: 15)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(subtitle, style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12.5, height: 1.35)),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMutedNavy),
      onTap: onTap,
    );
  }
}

class _BusyView extends StatelessWidget {
  final String message;
  final double? progress;

  const _BusyView({required this.message, this.progress});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 3.5,
                color: AppColors.primaryOnSurface,
                backgroundColor: progress == null ? null : AppColors.border,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimaryNavy, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Keep MyVault open until this finishes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for a new backup passphrase twice. Pops with the passphrase once both match.
class _CreateBackupSheet extends StatefulWidget {
  const _CreateBackupSheet();

  @override
  State<_CreateBackupSheet> createState() => _CreateBackupSheetState();
}

class _CreateBackupSheetState extends State<_CreateBackupSheet> {
  final _passphrase = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _passphrase.clear();
    _confirm.clear();
    _passphrase.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final passphrase = _passphrase.text;
    if (passphrase.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    if (passphrase != _confirm.text) {
      setState(() => _error = 'The two passphrases don’t match.');
      return;
    }
    Navigator.pop(context, passphrase);
  }

  @override
  Widget build(BuildContext context) {
    return VaultSheet(
      icon: Icons.cloud_upload_outlined,
      title: 'Create Backup',
      subtitle: 'Choose a passphrase to lock this backup file',
      children: [
        const NoticeBanner(
          tone: NoticeTone.info,
          icon: Icons.key_rounded,
          message: 'This passphrase is separate from your master password. '
              'Without it, the backup can’t be opened, so write it down somewhere safe.',
        ),
        const SizedBox(height: 16),
        PassphraseField(
          controller: _passphrase,
          label: 'Backup passphrase',
          hint: 'At least 8 characters',
          autofocus: true,
        ),
        const SizedBox(height: 14),
        PassphraseField(
          controller: _confirm,
          label: 'Confirm passphrase',
          hint: 'Type it again',
          icon: Icons.key_outlined,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          NoticeBanner.error(_error!),
        ],
        const SizedBox(height: 20),
        BusyButton(label: 'Create Backup File', icon: Icons.lock_rounded, onPressed: _submit),
      ],
    );
  }
}

/// Shows what's in a backup file and unlocks it. Pops with the decrypted payload once the
/// passphrase is right; a wrong passphrase is reported in place.
class _RestoreBackupSheet extends ConsumerStatefulWidget {
  final String fileName;
  final Uint8List fileBytes;
  final BackupInspectResult inspect;

  const _RestoreBackupSheet({required this.fileName, required this.fileBytes, required this.inspect});

  @override
  ConsumerState<_RestoreBackupSheet> createState() => _RestoreBackupSheetState();
}

class _RestoreBackupSheetState extends ConsumerState<_RestoreBackupSheet> {
  final _passphrase = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _passphrase.clear();
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final passphrase = _passphrase.text;
    if (passphrase.isEmpty) {
      setState(() => _error = 'Enter the passphrase this backup was created with.');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final payload = await ref.read(vaultBackupServiceProvider).decryptAndValidateBackup(
            fileBytes: widget.fileBytes,
            passphrase: passphrase,
          );
      if (mounted) Navigator.pop(context, payload);
    } catch (e) {
      if (mounted) {
        setState(() {
          _checking = false;
          _error = userMessage(e, fallback: 'That passphrase didn’t open this backup.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inspect = widget.inspect;
    String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
    final size = inspect.fileSize >= 1024 * 1024
        ? '${(inspect.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(inspect.fileSize / 1024).toStringAsFixed(1)} KB';

    return PopScope(
      canPop: !_checking,
      child: VaultSheet(
        icon: Icons.settings_backup_restore_rounded,
        title: 'Restore Backup',
        subtitle: widget.fileName,
        children: [
          InfoPanel(children: [
            InfoRow(
              'Created',
              inspect.createdAt > 0 ? formatDateTime(DateTime.fromMillisecondsSinceEpoch(inspect.createdAt)) : 'Unknown',
            ),
            InfoRow('Items', plural(inspect.itemCount, 'item')),
            InfoRow('Attachments', plural(inspect.fileCount, 'file')),
            InfoRow('Size', size),
          ]),
          const SizedBox(height: 14),
          const NoticeBanner(
            tone: NoticeTone.warning,
            title: 'This replaces your current vault',
            message: 'Everything in this vault now is replaced with the backup’s contents. '
                'If the restore fails partway, your vault is left as it was.',
          ),
          const SizedBox(height: 16),
          PassphraseField(
            controller: _passphrase,
            label: 'Backup passphrase',
            hint: 'The passphrase used to create this backup',
            enabled: !_checking,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            NoticeBanner.error(_error!),
          ],
          const SizedBox(height: 20),
          BusyButton(
            label: 'Replace & Restore',
            busyLabel: 'Unlocking backup…',
            icon: Icons.settings_backup_restore_rounded,
            color: AppColors.error,
            busy: _checking,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
