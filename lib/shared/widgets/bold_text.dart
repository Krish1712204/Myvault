import 'package:flutter/material.dart';

/// Notes mark bold text as `**like this**` (the same convention as WhatsApp/Markdown),
/// so it stays readable as plain text, survives backups unchanged, and needs no schema change.
final RegExp _boldPattern = RegExp(r'\*\*([\s\S]+?)\*\*');

/// Removes the `**` markers, e.g. for previews, copying and search.
String stripBoldMarkers(String text) => text.replaceAllMapped(_boldPattern, (m) => m.group(1)!);

/// One-line preview of a note's content (bold markers removed, whitespace collapsed,
/// at most 50 characters), used as the note's subtitle in lists.
String notePreview(String content) {
  final oneLine = stripBoldMarkers(content).replaceAll(RegExp(r'\s+'), ' ').trim();
  return oneLine.length > 50 ? '${oneLine.substring(0, 50)}…' : oneLine;
}

/// Spans with bold runs applied and the markers hidden (read-only display).
List<InlineSpan> boldSpans(String text, TextStyle base) {
  final spans = <InlineSpan>[];
  var index = 0;
  for (final match in _boldPattern.allMatches(text)) {
    if (match.start > index) spans.add(TextSpan(text: text.substring(index, match.start), style: base));
    spans.add(TextSpan(text: match.group(1), style: base.copyWith(fontWeight: FontWeight.w800)));
    index = match.end;
  }
  if (index < text.length) spans.add(TextSpan(text: text.substring(index), style: base));
  return spans;
}

/// Text controller that shows `**bold**` runs in bold while editing. The markers stay in the
/// text (so cursor positions are unchanged) but are drawn faint.
class BoldTextEditingController extends TextEditingController {
  BoldTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final base = style ?? const TextStyle();
    if (withComposing && value.isComposingRangeValid) {
      // Keep the IME's composing underline intact while a word is being typed.
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final marker = base.copyWith(color: (base.color ?? Colors.grey).withAlpha(90), fontWeight: FontWeight.w400);
    final children = <InlineSpan>[];
    var index = 0;
    for (final match in _boldPattern.allMatches(text)) {
      if (match.start > index) children.add(TextSpan(text: text.substring(index, match.start)));
      children
        ..add(TextSpan(text: '**', style: marker))
        ..add(TextSpan(text: match.group(1), style: const TextStyle(fontWeight: FontWeight.w800)))
        ..add(TextSpan(text: '**', style: marker));
      index = match.end;
    }
    if (index < text.length) children.add(TextSpan(text: text.substring(index)));
    return TextSpan(style: base, children: children);
  }

  /// Bolds the selection (or un-bolds it if it is already bold). With no selection, inserts
  /// an empty bold pair and places the cursor inside it.
  void toggleBold() {
    final sel = selection;
    final t = text;
    if (!sel.isValid) {
      value = TextEditingValue(text: '$t****', selection: TextSelection.collapsed(offset: t.length + 2));
      return;
    }
    final start = sel.start;
    final end = sel.end;

    // Already wrapped: **[selection]**  -> unwrap
    if (start >= 2 && end + 2 <= t.length && t.substring(start - 2, start) == '**' && t.substring(end, end + 2) == '**') {
      final newText = t.replaceRange(end, end + 2, '').replaceRange(start - 2, start, '');
      value = TextEditingValue(text: newText, selection: TextSelection(baseOffset: start - 2, extentOffset: end - 2));
      return;
    }
    // Selection includes the markers: [**text**] -> unwrap
    final selected = t.substring(start, end);
    if (selected.length >= 4 && selected.startsWith('**') && selected.endsWith('**')) {
      final inner = selected.substring(2, selected.length - 2);
      value = TextEditingValue(
        text: t.replaceRange(start, end, inner),
        selection: TextSelection(baseOffset: start, extentOffset: start + inner.length),
      );
      return;
    }

    final newText = t.replaceRange(start, end, '**$selected**');
    value = TextEditingValue(
      text: newText,
      selection: sel.isCollapsed
          ? TextSelection.collapsed(offset: start + 2)
          : TextSelection(baseOffset: start + 2, extentOffset: end + 2),
    );
  }
}
