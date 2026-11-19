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
    if (t.type == TxType.transfer) {
      final to = s.wallet(t.toWalletId);
      title = 'Transfer';
      leading = CircleIcon(
          icon: 'refund', color: Theme.of(context).colorScheme.primary.toARGB32());
      sub = '${w?.name ?? '?'} → ${to?.name ?? '?'}';
    } else {
      final c = s.category(t.categoryId);
      title = c?.name ?? 'Tanpa kategori';
      leading = CircleIcon(icon: c?.icon ?? 'other', color: c?.color ?? 0xFF546E7A);
      sub = w?.name ?? '';
    }
    if (t.note.isNotEmpty) sub = '${t.note} • $sub';
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
        money(sign == 0 ? t.amount : t.amount * sign, sign: sign > 0),
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
    {String ok = 'Hapus'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(msg),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
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
