import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

/// Width of grid thumbnails in pixels (about 3 columns on a 1080px-wide screen).
const int thumbnailWidth = 360;

/// Image file extensions the grids can show.
const Set<String> imageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic', '.heif'};

String _dotted(String? extension) {
  final ext = (extension ?? '').toLowerCase();
  return ext.isEmpty || ext.startsWith('.') ? ext : '.$ext';
}

bool isImageFile({String? extension, String? mimeType}) =>
    imageExtensions.contains(_dotted(extension)) || (mimeType ?? '').toLowerCase().startsWith('image/');

bool isPdfFile({String? extension, String? mimeType}) =>
    _dotted(extension) == '.pdf' || (mimeType ?? '').toLowerCase().contains('pdf');

/// Whether a grid preview can be made for this file type (images and PDFs).
bool canMakeThumbnail({String? extension, String? mimeType}) =>
    isImageFile(extension: extension, mimeType: mimeType) || isPdfFile(extension: extension, mimeType: mimeType);

/// Grid preview for an image (downscaled) or a PDF (first page). Null for other types or
/// for files that cannot be rendered.
Future<Uint8List?> makeFileThumbnail(Uint8List bytes, {String? extension, String? mimeType}) async {
  if (isImageFile(extension: extension, mimeType: mimeType)) return makeThumbnail(bytes);
  if (isPdfFile(extension: extension, mimeType: mimeType)) return renderPdfThumbnail(bytes);
  return null;
}

/// Decodes [imageBytes] downscaled to [thumbnailWidth] and re-encodes it as PNG.
/// The engine downsamples while decoding, so even large camera photos stay cheap.
Future<Uint8List?> makeThumbnail(Uint8List imageBytes) async {
  try {
    final codec = await ui.instantiateImageCodec(imageBytes, targetWidth: thumbnailWidth);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

const MethodChannel _pdfChannel = MethodChannel('myvault/pdf_thumbnail');

/// First page of a PDF as a JPEG, rendered by Android's PdfRenderer (PdfThumbnailChannel.kt).
Future<Uint8List?> renderPdfThumbnail(Uint8List pdfBytes) async {
  if (!Platform.isAndroid) return null;
  try {
    return await _pdfChannel.invokeMethod<Uint8List>('renderFirstPage', {
      'bytes': pdfBytes,
      'width': thumbnailWidth,
    });
  } catch (_) {
    return null;
  }
}
