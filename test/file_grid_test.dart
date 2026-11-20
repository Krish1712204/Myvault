import 'package:flutter_test/flutter_test.dart';
import 'package:myvault/features/categories/presentation/widgets/file_grid.dart';

void main() {
  final now = DateTime(2026, 10, 31, 17, 15);

  test('Day labels read like a phone gallery', () {
    expect(photoDayLabel(DateTime(2026, 10, 31, 8), now), 'Today');
    expect(photoDayLabel(DateTime(2026, 10, 30, 23), now), 'Yesterday');
    expect(photoDayLabel(DateTime(2026, 10, 28), now), 'Wed, 28 Oct');
    expect(photoDayLabel(DateTime(2025, 12, 25), now), 'Thu, 25 Dec 2025');
  });
}
