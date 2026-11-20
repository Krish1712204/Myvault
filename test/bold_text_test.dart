import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvault/shared/widgets/bold_text.dart';

void main() {
  BoldTextEditingController withSelection(String text, int start, int end) =>
      BoldTextEditingController(text: text)..selection = TextSelection(baseOffset: start, extentOffset: end);

  test('Bolds the selected words', () {
    final c = withSelection('router admin', 7, 12)..toggleBold();
    expect(c.text, 'router **admin**');
    expect(c.selection, const TextSelection(baseOffset: 9, extentOffset: 14));
  });

  test('Tapping Bold again un-bolds the same selection', () {
    final c = withSelection('router admin', 7, 12)
      ..toggleBold()
      ..toggleBold();
    expect(c.text, 'router admin');
  });

  test('With no selection, inserts a bold pair with the cursor inside', () {
    final c = BoldTextEditingController(text: 'hi ')..selection = const TextSelection.collapsed(offset: 3);
    c.toggleBold();
    expect(c.text, 'hi ****');
    expect(c.selection.baseOffset, 5);
  });

  test('Markers are stripped for previews and copying', () {
    expect(stripBoldMarkers('Pin is **1234** and **5678**'), 'Pin is 1234 and 5678');
  });

  test('Display spans hide the markers and bold the run', () {
    final spans = boldSpans('a **b** c', const TextStyle());
    expect(spans.map((s) => (s as TextSpan).text).join(), 'a b c');
    expect((spans[1] as TextSpan).style!.fontWeight, FontWeight.w800);
  });
}
