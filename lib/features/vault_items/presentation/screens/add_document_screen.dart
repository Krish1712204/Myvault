import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../../../shared/widgets/pressable_scale.dart';
import '../../../../shared/widgets/vault_form_kit.dart';
import '../../../auth/domain/vault_auth_notifier.dart';
import '../../data/vault_item_model.dart';

/// A file chosen in the picker. Only a reference is kept: bytes are read when the file is
/// encrypted, so selecting many large photos never loads them all into memory.
class _Picked {
  final PlatformFile file;
  final int size;

  const _Picked(this.file, this.size);

  String get name => file.name;
  String get extension => (file.extension ?? '').toLowerCase();
  Future<Uint8List> read() => file.readAsBytes();

  /// Small preview decoded straight from disk at [width] pixels.
  Widget preview({double? width, BoxFit fit = BoxFit.cover}) {
    final path = file.path;
    final cacheWidth = ((width ?? 240)).round();
    if (path != null) return Image.file(File(path), fit: fit, cacheWidth: cacheWidth);
    return FutureBuilder<Uint8List>(
      future: read(),
      builder: (context, snap) =>
          snap.hasData ? Image.memory(snap.data!, fit: fit, cacheWidth: cacheWidth) : const SizedBox(),
    );
  }

  bool get isImage => const ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic', 'heif'].contains(extension);
}

/// Adds or edits a Document or a Photo. The category is fixed by where the user came from
/// (Documents saves documents, Photos saves photos); photos can be added one at a time or
/// many at once.
class AddDocumentScreen extends ConsumerStatefulWidget {
  final String? itemId;
  final VaultCategory initialCategory;

  const AddDocumentScreen({
    super.key,
    this.itemId,
    this.initialCategory = VaultCategory.documents,
  });

  @override
  ConsumerState<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends ConsumerState<AddDocumentScreen> {
  static const _maxBytes = 50 * 1024 * 1024;

  /// Photos per bulk upload. Files are encrypted one at a time; this keeps a single batch to
  /// a couple of minutes on a typical phone. Larger sets can be added in further batches.
  static const maxBulkPhotos = 100;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  late VaultCategory _category = widget.initialCategory;
  bool _isFavourite = false;
  bool _isSaving = false;
  bool _initialized = false;
  int _savedCount = 0;

  final List<_Picked> _picked = [];
  String? _existingFileName;
  int? _existingFileSize;

  bool get _isEditing => widget.itemId != null;
  bool get _isPhoto => _category == VaultCategory.photos;
  bool get _isBulk => _picked.length > 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    if (!_isEditing) return;
    final item = ref.read(vaultItemsProvider).where((i) => i.id == widget.itemId).firstOrNull;
    if (item == null) return;
    _titleController.text = item.title;
    _category = item.category;
    _isFavourite = item.isFavourite;
    _existingFileName = item.fileName ?? item.title;
    _existingFileSize = item.fileSize;
  }

  @override
  void dispose() {
    _titleController.dispose();
    // The picker copies chosen files into the app cache unencrypted; remove those copies.
    FilePicker.clearTemporaryFiles();
    super.dispose();
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  Future<void> _pick({required bool multiple}) async {
    try {
      ref.read(vaultAuthStateProvider.notifier).allowExternalActivity();
      final type = _isPhoto ? FileType.image : FileType.any;
      final List<PlatformFile> files;
      if (multiple) {
        files = await FilePicker.pickFiles(type: type);
      } else {
        final single = await FilePicker.pickFile(type: type);
        files = single == null ? const [] : [single];
      }
      if (files.isEmpty) return;

      final accepted = <_Picked>[];
      var tooLarge = 0;
      for (final file in files) {
        final size = file.lengthSync() ?? await file.length() ?? 0;
        if (size > _maxBytes) {
          tooLarge++;
          continue;
        }
        accepted.add(_Picked(file, size));
      }
      if (tooLarge > 0 && mounted) {
        _toast('$tooLarge file${tooLarge == 1 ? '' : 's'} over 50 MB skipped.', error: true);
      }
      if (accepted.isEmpty) return;

      setState(() {
        if (multiple) {
          // Add to the current selection, skipping exact duplicates by name.
          final names = _picked.map((p) => p.name).toSet();
          final room = maxBulkPhotos - _picked.length;
          final fresh = accepted.where((p) => names.add(p.name)).toList();
          _picked.addAll(fresh.take(room));
          if (fresh.length > room) {
            _toast('Up to $maxBulkPhotos photos at a time. Save these, then add the rest.', error: true);
          }
        } else {
          _picked
            ..clear()
            ..add(accepted.first);
        }
        if (_picked.length == 1 && _titleController.text.trim().isEmpty) {
          final name = _picked.first.name;
          final dot = name.lastIndexOf('.');
          _titleController.text = dot > 0 ? name.substring(0, dot) : name;
        }
      });
    } catch (e) {
      if (mounted) _toast('Could not pick file: $e', error: true);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_isEditing && _picked.isEmpty) {
      _toast(_isPhoto ? 'Choose at least one photo first.' : 'Choose a file first.', error: true);
      return;
    }
    if (!_isBulk && !_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _savedCount = 0;
    });
    final notifier = ref.read(vaultItemsProvider.notifier);

    try {
      if (_isBulk) {
        final saved = await notifier.saveDocumentItems(
          files: [for (final p in _picked) (name: p.name, read: p.read)],
          category: _category,
          isFavourite: _isFavourite,
          onProgress: (done, _) {
            if (mounted) setState(() => _savedCount = done);
          },
        );
        if (!mounted) return;
        _toast('$saved photos encrypted and saved');
      } else if (_picked.isNotEmpty) {
        await notifier.saveDocumentItem(
          id: widget.itemId,
          title: _titleController.text.trim(),
          category: _category,
          originalFileName: _picked.first.name,
          fileBytes: await _picked.first.read(),
          isFavourite: _isFavourite,
        );
        if (!mounted) return;
        _toast(_isEditing ? 'Saved' : '${_isPhoto ? 'Photo' : 'Document'} encrypted and saved');
      } else {
        await notifier.updateDocumentMetadata(
          id: widget.itemId!,
          title: _titleController.text.trim(),
          category: _category,
          isFavourite: _isFavourite,
        );
        if (!mounted) return;
        _toast('Saved');
      }
      context.pop();
    } catch (e) {
      if (mounted) _toast('Failed to save: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  static String _formatSize(int? bytes) {
    if (bytes == null || bytes == 0) return '0 KB';
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  void _previewImage(_Picked picked) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: InteractiveViewer(child: picked.preview(width: 1080, fit: BoxFit.contain)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _isPhoto ? AppColors.categoryPhotos : AppColors.categoryDocuments;
    final noun = _isPhoto ? 'Photo' : 'Document';
    final totalSize = _picked.fold<int>(0, (sum, p) => sum + p.size);

    final saveLabel = _isSaving && _isBulk
        ? 'Encrypting $_savedCount of ${_picked.length}…'
        : _isEditing
            ? 'Save Changes'
            : _isBulk
                ? 'Encrypt & Save ${_picked.length} Photos'
                : 'Encrypt & Save';

    return Form(
      key: _formKey,
      child: VaultFormScaffold(
        category: _category,
        title: _isEditing ? 'Edit $noun' : (_isPhoto ? 'Add Photos' : 'Add Document'),
        subtitle: _isPhoto ? 'Private images, encrypted on this phone' : 'PDFs, scans and files of any type',
        isFavourite: _isFavourite,
        onFavouriteChanged: (v) => setState(() => _isFavourite = v),
        saving: _isSaving,
        onSave: _save,
        saveLabel: saveLabel,
        children: [
          FormSectionCard(
            title: _isPhoto ? (_isEditing ? 'Photo' : 'Photos') : 'File',
            icon: _isPhoto ? Icons.photo_library_rounded : Icons.attach_file_rounded,
            children: [
              if (_picked.isEmpty && !_isEditing && _isPhoto)
                Row(
                  children: [
                    Expanded(
                      child: _PickTile(
                        color: accent,
                        icon: Icons.add_photo_alternate_rounded,
                        title: 'One photo',
                        subtitle: 'Pick a single image',
                        onTap: () => _pick(multiple: false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickTile(
                        color: accent,
                        icon: Icons.collections_rounded,
                        title: 'Multiple photos',
                        subtitle: 'Select many at once',
                        onTap: () => _pick(multiple: true),
                      ),
                    ),
                  ],
                )
              else if (_isBulk)
                _BulkGrid(
                  picked: _picked,
                  accent: accent,
                  onRemove: (i) => setState(() => _picked.removeAt(i)),
                  onPreview: _previewImage,
                  onAddMore: _isSaving || _picked.length >= maxBulkPhotos ? null : () => _pick(multiple: true),
                )
              else
                UploadZone(
                  color: accent,
                  icon: _isPhoto ? Icons.add_photo_alternate_rounded : Icons.upload_file_rounded,
                  title: _isPhoto ? 'Choose a photo' : 'Choose a document',
                  subtitle: _isPhoto ? 'JPG, PNG, WEBP… up to 50 MB' : 'PDF, Word, any file type · up to 50 MB',
                  onPick: () => _pick(multiple: false),
                  fileName: _picked.isNotEmpty ? _picked.first.name : _existingFileName,
                  fileDetail: _picked.isNotEmpty
                      ? '${_picked.first.extension.toUpperCase()} · ${_formatSize(_picked.first.size)}'
                      : (_existingFileName != null ? '${_formatSize(_existingFileSize)} · already in your vault' : null),
                  preview: _picked.isNotEmpty && _picked.first.isImage
                      ? GestureDetector(
                          onTap: () => _previewImage(_picked.first),
                          child: _picked.first.preview(width: 200),
                        )
                      : null,
                  onRemove: _picked.isEmpty ? null : () => setState(_picked.clear),
                ),
              if (_isBulk)
                Text(
                  '${_picked.length} photos · ${_formatSize(totalSize)} · titles come from file names',
                  style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
            ],
          ),
          if (!_isBulk)
            FormSectionCard(
              title: 'Details',
              icon: Icons.info_outline_rounded,
              children: [
                LabeledField(
                  label: 'Title',
                  required: true,
                  child: TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a title' : null,
                    decoration: InputDecoration(
                      hintText: _isPhoto ? 'e.g. Passport photo, Family trip' : 'e.g. Rent agreement, Tax return',
                      prefixIcon: const Icon(Icons.title_rounded),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PickTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(AppColors.isDark ? 26 : 14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withAlpha(90), width: 1.4),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withAlpha(AppColors.isDark ? 50 : 30)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(color: AppColors.textPrimaryNavy, fontSize: 14.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMutedNavy, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkGrid extends StatelessWidget {
  final List<_Picked> picked;
  final Color accent;
  final ValueChanged<int> onRemove;
  final ValueChanged<_Picked> onPreview;
  final VoidCallback? onAddMore;

  const _BulkGrid({
    required this.picked,
    required this.accent,
    required this.onRemove,
    required this.onPreview,
    required this.onAddMore,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: picked.length + (onAddMore == null ? 0 : 1),
      itemBuilder: (context, i) {
        if (i == picked.length) {
          return PressableScale(
            onTap: onAddMore,
            child: Container(
              decoration: BoxDecoration(
                color: accent.withAlpha(AppColors.isDark ? 26 : 14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withAlpha(90)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: accent, size: 28),
                  Text('Add more', style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ),
            ),
          );
        }
        final p = picked[i];
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => onPreview(p),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: p.isImage
                    ? p.preview()
                    : Container(color: accent.withAlpha(30), child: Icon(Icons.insert_drive_file, color: accent)),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => onRemove(i),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
