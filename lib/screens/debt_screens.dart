import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'asset_screens.dart';

// ============================================================================
// Utang & piutang
// ============================================================================

String debtKindLabel(bool receivable) => receivable ? 'Piutang' : 'Utang';

Future<void> openDebt(BuildContext context, String id) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => DebtDetailScreen(debtId: id)));

class DebtsScreen extends StatelessWidget {
  final bool receivable;
  const DebtsScreen({super.key, this.receivable = true});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: receivable ? 0 : 1,
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Utang & Piutang'),
            bottom: const TabBar(tabs: [
              Tab(text: 'Piutang (orang ke saya)'),
              Tab(text: 'Utang (saya)'),
            ]),
          ),
          body: const TabBarView(children: [
            _DebtList(receivable: true),
            _DebtList(receivable: false),
          ]),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => editDebt(context,
                receivable: DefaultTabController.of(context).index == 0),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Catat'),
          ),
        );
      }),
    );
  }
}

class _DebtList extends StatefulWidget {
  final bool receivable;
  const _DebtList({required this.receivable});

  @override
  State<_DebtList> createState() => _DebtListState();
}

class _DebtListState extends State<_DebtList> {
  bool _showSettled = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.I,
      builder: (context, _) {
        final s = AppStore.I;
        final all =
            s.debts.where((d) => d.isReceivable == widget.receivable).toList();
        final open = all.where((d) => !d.settled).toList()
          ..sort((a, b) => (a.dueDate ?? DateTime(2100))
              .compareTo(b.dueDate ?? DateTime(2100)));
        final done = all.where((d) => d.settled).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        final total = open.fold(0, (t, d) => t + d.remaining);
        final cs = Theme.of(context).colorScheme;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            GradientCard(
              color: widget.receivable ? cs.primary : const Color(0xFFE53935),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      widget.receivable
                          ? 'Total yang belum dibayar ke saya'
                          : 'Total utang saya yang belum lunas',
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(money(total),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                      '${open.length} belum lunas'
                      '${open.any((d) => d.overdue) ? ' • ${open.where((d) => d.overdue).length} lewat jatuh tempo' : ''}',
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (open.isEmpty)
              EmptyState(
                icon: Icons.handshake_outlined,
                text: widget.receivable
                    ? 'Tidak ada piutang.\nCatat bila ada yang meminjam uang\natau pembeli belum lunas.'
                    : 'Tidak ada utang. Mantap!',
              ),
            ...open.map((d) => _DebtCard(d)),
            if (done.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _showSettled = !_showSettled),
                icon: Icon(_showSettled
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded),
                label: Text('Sudah lunas (${done.length})'),
              ),
              if (_showSettled) ...done.map((d) => _DebtCard(d)),
            ],
          ],
        );
      },
    );
  }
}

class _DebtCard extends StatelessWidget {
  final Debt d;
  const _DebtCard(this.d);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = d.settled
        ? kIncomeColor
        : d.overdue
            ? kExpenseColor
            : cs.primary;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openDebt(context, d.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(
                      d.person.isEmpty ? '?' : d.person[0].toUpperCase(),
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.person,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleMedium),
                      if (d.note.isNotEmpty)
                        Text(d.note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(d.settled ? 'Lunas' : money(d.remaining),
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: color)),
                    Text(d.settled ? money(d.amount) : 'sisa',
                        style: tt.bodySmall),
                  ],
                ),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: d.progress,
                  minHeight: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: Text(
                      'Dibayar ${money(d.paid)} dari ${money(d.amount)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall),
                ),
                if (d.dueDate != null && !d.settled)
                  Text(
                      d.overdue
                          ? 'Lewat ${dfShort.format(d.dueDate!)}'
                          : 'Jatuh tempo ${dfShort.format(d.dueDate!)}',
                      style: tt.bodySmall?.copyWith(
                          color: d.overdue ? kExpenseColor : null,
                          fontWeight: d.overdue ? FontWeight.w700 : null)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class DebtDetailScreen extends StatelessWidget {
  final String debtId;
  const DebtDetailScreen({super.key, required this.debtId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.I,
      builder: (context, _) {
        final s = AppStore.I;
        final d = s.debt(debtId);
        if (d == null) return const Scaffold();
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        final payments = [...d.payments]
          ..sort((a, b) => b.date.compareTo(a.date));
        return Scaffold(
          appBar: AppBar(
            title: Text(debtKindLabel(d.isReceivable)),
            actions: [
              IconButton(
                tooltip: 'Ubah',
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => editDebt(context,
                    receivable: d.isReceivable, edit: d),
              ),
              IconButton(
                tooltip: 'Hapus',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  if (await confirm(context, 'Hapus catatan?',
                      'Catatan ${debtKindLabel(d.isReceivable).toLowerCase()} "${d.person}" dan semua pembayarannya akan dihapus. Saldo dompet ikut dikembalikan.')) {
                    await s.deleteDebt(d.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              GradientCard(
                color: d.settled
                    ? kIncomeColor
                    : (d.isReceivable ? cs.primary : const Color(0xFFB23A2E)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.person,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(d.settled ? 'Sudah lunas' : 'Sisa belum dibayar',
                        style: const TextStyle(color: Colors.white70)),
                    Text(money(d.settled ? d.amount : d.remaining),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: d.progress,
                        minHeight: 8,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      HeaderStat('Total', money(d.amount)),
                      HeaderStat('Sudah dibayar', money(d.paid)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Column(children: [
                  _info(context, Icons.event_rounded, 'Tanggal',
                      dfDay.format(d.date)),
                  if (d.dueDate != null)
                    _info(
                        context,
                        Icons.alarm_rounded,
                        'Jatuh tempo',
                        dfDay.format(d.dueDate!) +
                            (d.overdue ? ' (lewat)' : '')),
                  _info(
                      context,
                      Icons.account_balance_wallet_rounded,
                      d.isReceivable ? 'Uang keluar dari' : 'Uang masuk ke',
                      s.wallet(d.walletId)?.name ?? 'Tidak memengaruhi saldo'),
                  if (d.note.isNotEmpty)
                    _info(context, Icons.notes_rounded, 'Catatan', d.note),
                ]),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: Text('Riwayat pembayaran', style: tt.titleMedium)),
                Text('${payments.length}x', style: tt.bodySmall),
              ]),
              const SizedBox(height: 4),
              if (payments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Belum ada pembayaran.',
                      style: tt.bodyMedium?.copyWith(color: cs.outline)),
                ),
              ...payments.map((p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: kIncomeColor.withValues(alpha: 0.12),
                      child: const Icon(Icons.payments_rounded,
                          color: kIncomeColor, size: 20),
                    ),
                    title: Text(money(p.amount)),
                    subtitle: Text([
                      dfShort.format(p.date),
                      s.wallet(p.walletId)?.name ?? 'tanpa dompet',
                      if (p.note.isNotEmpty) p.note,
                    ].join(' • ')),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Hapus pembayaran',
                      onPressed: () async {
                        if (await confirm(context, 'Hapus pembayaran?',
                            'Pembayaran ${rupiah(p.amount)} akan dihapus.')) {
                          d.payments.removeWhere((e) => e.id == p.id);
                          await s.upsertDebt(d);
                        }
                      },
                    ),
                  )),
            ],
          ),
          floatingActionButton: d.settled
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => showPaymentSheet(context, d),
                  icon: const Icon(Icons.payments_rounded),
                  label: Text(d.isReceivable ? 'Terima bayaran' : 'Bayar'),
                ),
        );
      },
    );
  }

  Widget _info(BuildContext context, IconData icon, String label, String v) =>
      ListTile(
        dense: true,
        leading: Icon(icon, size: 20),
        title: Text(label, style: Theme.of(context).textTheme.bodySmall),
        subtitle: Text(v, style: Theme.of(context).textTheme.bodyLarge),
      );
}

/// Catat pembayaran/cicilan.
Future<void> showPaymentSheet(BuildContext context, Debt d) async {
  final s = AppStore.I;
  final amount = TextEditingController(text: formatAmountInput(d.remaining));
  final note = TextEditingController();
  var date = DateTime.now();
  String? walletId = d.walletId ?? s.defaultWallet.id;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sheetTitle(ctx, Icons.payments_rounded,
                  d.isReceivable ? 'Terima bayaran' : 'Bayar utang'),
              AmountField(amount, 'Jumlah',
                  helper: 'Sisa ${rupiah(d.remaining)}', autofocus: true),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                ActionChip(
                  label: const Text('Lunas'),
                  onPressed: () => setState(
                      () => amount.text = formatAmountInput(d.remaining)),
                ),
                ActionChip(
                  label: const Text('Setengah'),
                  onPressed: () => setState(() =>
                      amount.text = formatAmountInput((d.remaining / 2).round())),
                ),
              ]),
              const SizedBox(height: 12),
              DateField('Tanggal', date, (v) => setState(() => date = v)),
              const SizedBox(height: 12),
              CashWalletPicker(
                label: d.isReceivable ? 'Uang masuk ke' : 'Dibayar dari',
                value: walletId,
                onChanged: (v) => setState(() => walletId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration:
                    const InputDecoration(labelText: 'Catatan (opsional)'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                onPressed: () async {
                  final a = parseAmount(amount.text);
                  if (a <= 0) return;
                  d.payments.add(DebtPayment(
                    id: newId(),
                    amount: a,
                    date: date,
                    walletId: walletId,
                    note: note.text.trim(),
                  ));
                  await s.upsertDebt(d);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    toast(
                        context,
                        d.settled
                            ? '${d.person}: LUNAS 🎉'
                            : 'Tercatat. Sisa ${rupiah(d.remaining)}');
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Form tambah/ubah utang atau piutang.
Future<void> editDebt(BuildContext context,
    {required bool receivable, Debt? edit}) async {
  final s = AppStore.I;
  final person = TextEditingController(text: edit?.person ?? '');
  final amount = TextEditingController(
      text: edit != null ? formatAmountInput(edit.amount) : '');
  final note = TextEditingController(text: edit?.note ?? '');
  var recv = edit?.isReceivable ?? receivable;
  var date = edit?.date ?? DateTime.now();
  DateTime? due = edit?.dueDate;
  String? walletId = edit != null ? edit.walletId : s.defaultWallet.id;
  final people = {for (final d in s.debts) d.person}.toList();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sheetTitle(ctx, Icons.handshake_rounded,
                  edit == null ? 'Catat utang/piutang' : 'Ubah catatan'),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: true,
                      icon: Icon(Icons.call_received_rounded),
                      label: Text('Piutang')),
                  ButtonSegment(
                      value: false,
                      icon: Icon(Icons.call_made_rounded),
                      label: Text('Utang')),
                ],
                selected: {recv},
                onSelectionChanged: (v) => setState(() => recv = v.first),
              ),
              const SizedBox(height: 6),
              Text(
                  recv
                      ? 'Orang lain berutang ke saya (mis. pinjam uang, pembeli belum lunas).'
                      : 'Saya berutang ke orang lain (mis. pinjam modal, belum bayar supplier).',
                  style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 12),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: person.text),
                optionsBuilder: (v) => v.text.isEmpty
                    ? const Iterable<String>.empty()
                    : people.where((p) =>
                        p.toLowerCase().contains(v.text.toLowerCase())),
                onSelected: (v) => person.text = v,
                fieldViewBuilder: (c, ctl, focus, _) => TextField(
                  controller: ctl,
                  focusNode: focus,
                  autofocus: edit == null,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) => person.text = v,
                  decoration: InputDecoration(
                      labelText: recv ? 'Nama peminjam / pembeli' : 'Berutang ke'),
                ),
              ),
              const SizedBox(height: 12),
              AmountField(amount, 'Jumlah'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: DateField(
                        'Tanggal', date, (v) => setState(() => date = v))),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      final v = await showDatePicker(
                        context: ctx,
                        initialDate:
                            due ?? date.add(const Duration(days: 30)),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (v != null) setState(() => due = v);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Jatuh tempo',
                        suffixIcon: due == null
                            ? const Icon(Icons.alarm_add_rounded)
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => setState(() => due = null),
                              ),
                      ),
                      child: Text(due == null ? '-' : dfShort.format(due!)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              CashWalletPicker(
                label: recv ? 'Uang dipinjamkan dari' : 'Uang pinjaman masuk ke',
                value: walletId,
                noneLabel: 'Tidak memengaruhi saldo',
                onChanged: (v) => setState(() => walletId = v),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                    'Pilih "Tidak memengaruhi saldo" bila tidak ada uang yang berpindah saat ini (mis. pembeli belum lunas).',
                    style: Theme.of(ctx).textTheme.bodySmall),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration:
                    const InputDecoration(labelText: 'Catatan (opsional)'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                onPressed: () async {
                  final n = person.text.trim();
                  final a = parseAmount(amount.text);
                  if (n.isEmpty || a <= 0) {
                    toast(ctx, 'Isi nama dan jumlah');
                    return;
                  }
                  final d = edit ??
                      Debt(
                          id: newId(),
                          kind: '',
                          person: '',
                          amount: 0,
                          date: date);
                  d
                    ..kind = recv ? 'receivable' : 'payable'
                    ..person = n
                    ..amount = a
                    ..date = date
                    ..dueDate = due
                    ..walletId = walletId
                    ..note = note.text.trim();
                  await s.upsertDebt(d);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
