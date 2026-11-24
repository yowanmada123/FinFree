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
  final VoidCallback? onTapLabel;
  const PeriodBar({
    super.key,
    required this.period,
    required this.onChanged,
    this.onTapLabel,
  });

  @override
  Widget build(BuildContext context) {
    final d = AppStore.I.cycleStartDay;
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => onChanged(period.shift(-1, d)),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTapLabel,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                period.label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () => onChanged(period.shift(1, d)),
        ),
      ],
    );
  }
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
