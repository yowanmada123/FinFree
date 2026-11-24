import 'package:flutter/material.dart';

import 'format.dart';
import 'icons.dart';
import 'models.dart';
import 'store.dart';

const kIncomeColor = Color(0xFF2E7D32);
const kExpenseColor = Color(0xFFC62828);

Color typeColor(TxType t, BuildContext context) => switch (t) {
      TxType.income => kIncomeColor,
      TxType.expense => kExpenseColor,
      TxType.transfer => Theme.of(context).colorScheme.primary,
    };

String typeLabel(TxType t) => switch (t) {
      TxType.income => 'Pemasukan',
      TxType.expense => 'Pengeluaran',
      TxType.transfer => 'Transfer',
    };

String money(int v, {bool sign = false}) =>
    AppStore.I.hideBalance ? 'Rp •••••' : rupiah(v, sign: sign);

class TxTile extends StatelessWidget {
  final Txn t;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showDate;
  const TxTile({
    super.key,
    required this.t,
    this.onTap,
    this.onLongPress,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStore.I;
    final w = s.wallet(t.walletId);
    String title;
    Widget leading;
    String sub;
    if (t.debtId != null) {
      // uang keluar/masuk karena utang-piutang (bukan pemasukan/pengeluaran)
      final d = s.debt(t.debtId);
      final out = t.toWalletId == null;
      title = d == null
          ? 'Utang/Piutang'
          : (d.isReceivable ? 'Piutang • ${d.person}' : 'Utang • ${d.person}');
      leading = CircleIcon(
          icon: 'handshake',
          color: Theme.of(context).colorScheme.tertiary.toARGB32());
      sub = '${out ? 'Keluar dari' : 'Masuk ke'} '
          '${s.wallet(out ? t.walletId : t.toWalletId)?.name ?? '?'}';
    } else if (t.type == TxType.transfer) {
      final to = s.wallet(t.toWalletId);
      title = 'Transfer';
      leading = CircleIcon(
          icon: 'refund', color: Theme.of(context).colorScheme.primary.toARGB32());
      sub = '${w?.name ?? '?'} → ${to?.name ?? '?'}';
    } else {
      final c = s.category(t.categoryId);
      title = c?.name ?? 'Tanpa kategori';
      // ikon diwarnai sesuai jenis: hijau = pemasukan, merah = pengeluaran
      leading = CircleIcon(
          icon: c?.icon ?? 'other', color: typeColor(t.type, context).toARGB32());
      sub = w?.name ?? '';
    }
    if (t.note.isNotEmpty && t.debtId == null) sub = '${t.note} • $sub';
    if (t.recurringId != null) sub = 'Rutin • $sub';
    if (showDate) sub = '${dfShort.format(t.date)} • $sub';
    final sign = switch (t.type) {
      TxType.income => 1,
      TxType.expense => -1,
      TxType.transfer => 0,
    };
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: leading,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        t.debtId != null
            ? money(t.toWalletId == null ? -t.amount : t.amount,
                sign: t.toWalletId != null)
            : money(sign == 0 ? t.amount : t.amount * sign, sign: sign > 0),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: typeColor(t.type, context),
        ),
      ),
    );
  }
}

class SummaryChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const SummaryChip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelSmall),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(money(value),
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PeriodBar extends StatelessWidget {
  final Period period;
  final ValueChanged<Period> onChanged;

  /// Opsi tambahan "Rentang tanggal" di pemilih bulan (mis. di Laporan).
  final VoidCallback? onCustomRange;
  const PeriodBar({
    super.key,
    required this.period,
    required this.onChanged,
    this.onCustomRange,
  });

  @override
  Widget build(BuildContext context) {
    final d = AppStore.I.cycleStartDay;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconButton(
          tooltip: 'Bulan sebelumnya',
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => onChanged(period.shift(-1, d)),
        ),
        Expanded(
          child: InkWell(
            key: const ValueKey('period-label'),
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final p = await showMonthPicker(context, period,
                  onCustomRange: onCustomRange);
              if (p != null) onChanged(p);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      period.label,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down_rounded, color: cs.primary),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Bulan berikutnya',
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () => onChanged(period.shift(1, d)),
        ),
      ],
    );
  }
}

const _kMonthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Pemilih bulan & tahun: tinggal ketuk bulan yang diinginkan.
/// Bulan yang punya transaksi diberi titik kecil.
Future<Period?> showMonthPicker(BuildContext context, Period current,
    {VoidCallback? onCustomRange}) {
  final d = AppStore.I.cycleStartDay.clamp(1, 28);
  Period of(int y, int m) => Period(DateTime(y, m, d), DateTime(y, m + 1, d));
  final now = AppStore.I.currentPeriod.start;
  final hasData = <int>{};
  for (final t in AppStore.I.txns) {
    final p = Period.cycle(t.date, d);
    hasData.add(p.start.year * 12 + p.start.month);
  }
  var year = current.start.year;
  return showModalBottomSheet<Period>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final cs = Theme.of(ctx).colorScheme;
        Widget month(int m) {
          final sel = current.start.year == year &&
              current.start.month == m &&
              current.start.day == d;
          final isNow = now.year == year && now.month == m;
          final data = hasData.contains(year * 12 + m);
          return Material(
            color: sel ? cs.primary : cs.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.pop(ctx, of(year, m)),
              child: Container(
                decoration: isNow && !sel
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.primary, width: 1.5))
                    : null,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_kMonthShort[m - 1],
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: sel
                                ? cs.onPrimary
                                : (isNow ? cs.primary : null))),
                    const SizedBox(height: 3),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: data
                            ? (sel ? cs.onPrimary : cs.primary)
                            : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                IconButton.filledTonal(
                  tooltip: 'Tahun sebelumnya',
                  onPressed: () => setState(() => year--),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text('$year',
                      textAlign: TextAlign.center,
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton.filledTonal(
                  tooltip: 'Tahun berikutnya',
                  onPressed: () => setState(() => year++),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ]),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.6,
                children: [for (var m = 1; m <= 12; m++) month(m)],
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pop(ctx, AppStore.I.currentPeriod),
                    icon: const Icon(Icons.today_rounded),
                    label: const Text('Bulan ini'),
                  ),
                ),
                if (onCustomRange != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onCustomRange();
                      },
                      icon: const Icon(Icons.date_range_rounded),
                      label: const Text('Rentang tanggal',
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ]),
            ]),
          ),
        );
      },
    ),
  );
}

Future<bool> confirm(BuildContext context, String title, String msg,
    {String ok = 'Hapus', String cancel = 'Batal'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(msg),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false), child: Text(cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(icon, size: 64, color: c),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: c)),
        ],
      ),
    );
  }
}

/// Warna status anggaran: aman → hampir habis (≥80%) → lewat batas.
Color budgetColor(double pct, BuildContext context) => pct >= 1
    ? kExpenseColor
    : pct >= 0.8
        ? const Color(0xFFE65100)
        : Theme.of(context).colorScheme.primary;

/// Baris progres anggaran satu kategori pada periode.
class BudgetTile extends StatelessWidget {
  final Category c;
  final Period period;
  final VoidCallback? onTap;
  const BudgetTile(
      {super.key, required this.c, required this.period, this.onTap});

  @override
  Widget build(BuildContext context) {
    final spent = AppStore.I.spentIn(period, c.id);
    final pct = c.budget > 0 ? spent / c.budget : 0.0;
    final col = budgetColor(pct, context);
    final left = c.budget - spent;
    final now = DateTime.now();
    final daysLeft = period.contains(now)
        ? period.end.difference(DateTime(now.year, now.month, now.day)).inDays
        : 0;
    final tt = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleIcon(icon: c.icon, color: c.color),
      title: Row(children: [
        Expanded(
            child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text('${(pct * 100).round()}%',
            style: TextStyle(color: col, fontWeight: FontWeight.w700)),
      ]),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 6,
            color: col,
            backgroundColor: col.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 4),
          Text(
            left >= 0
                ? '${money(spent)} dari ${money(c.budget)} • sisa ${money(left)}'
                    '${daysLeft > 0 ? ' (±${money((left / daysLeft).floor())}/hari)' : ''}'
                : 'Lewat ${money(-left)} dari anggaran ${money(c.budget)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tt.bodySmall?.copyWith(color: left < 0 ? kExpenseColor : null),
          ),
        ],
      ),
    );
  }
}
