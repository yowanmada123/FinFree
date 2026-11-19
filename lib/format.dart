import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _num = NumberFormat.decimalPattern('id_ID');

String rupiah(int v, {bool sign = false}) {
  final s = 'Rp ${_num.format(v.abs())}';
  if (v < 0) return '-$s';
  if (sign && v > 0) return '+$s';
  return s;
}

String compact(int v) => NumberFormat.compact(locale: 'id_ID').format(v);

final dfDay = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
final dfShort = DateFormat('d MMM yyyy', 'id_ID');
final dfMonth = DateFormat('MMMM yyyy', 'id_ID');
final dfTime = DateFormat('HH:mm', 'id_ID');

int parseAmount(String s) =>
    int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

/// Memformat input angka dengan pemisah ribuan saat mengetik.
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final trimmed = digits.length > 15 ? digits.substring(0, 15) : digits;
    final text = _num.format(int.parse(trimmed));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

String formatAmountInput(int v) => v == 0 ? '' : _num.format(v);

class Period {
  final DateTime start; // inklusif
  final DateTime end; // eksklusif
  const Period(this.start, this.end);

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  DateTime get lastDay => end.subtract(const Duration(days: 1));

  String get label {
    if (start.day == 1 &&
        end.day == 1 &&
        ((end.month - start.month) % 12 == 1)) {
      return dfMonth.format(start);
    }
    return '${dfShort.format(start)} - ${dfShort.format(lastDay)}';
  }

  /// Periode siklus (mis. tanggal gajian) yang memuat [date].
  static Period cycle(DateTime date, int startDay) {
    final d = startDay.clamp(1, 28);
    final start = date.day >= d
        ? DateTime(date.year, date.month, d)
        : DateTime(date.year, date.month - 1, d);
    return Period(start, DateTime(start.year, start.month + 1, d));
  }

  Period shift(int months, int startDay) {
    final d = startDay.clamp(1, 28);
    final s = DateTime(start.year, start.month + months, d);
    return Period(s, DateTime(s.year, s.month + 1, d));
  }
}
