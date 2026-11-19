import 'package:flutter_test/flutter_test.dart';
import 'package:goes_to_financial_freedom/format.dart';

void main() {
  test('periode siklus gajian', () {
    final p = Period.cycle(DateTime(2026, 3, 10), 25);
    expect(p.start, DateTime(2026, 2, 25));
    expect(p.end, DateTime(2026, 3, 25));
    expect(p.contains(DateTime(2026, 3, 24, 23)), isTrue);
    expect(p.contains(DateTime(2026, 3, 25)), isFalse);
    final q = Period.cycle(DateTime(2026, 1, 3), 1);
    expect(q.start, DateTime(2026, 1, 1));
    expect(q.shift(-1, 1).start, DateTime(2025, 12, 1));
  });

  test('parse nominal', () {
    expect(parseAmount('1.250.000'), 1250000);
    expect(parseAmount(''), 0);
  });
}
