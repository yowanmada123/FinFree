import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../format.dart';
import '../icons.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'home_screen.dart';
import 'lock_screen.dart';
import 'trend_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late Period _period = AppStore.I.currentPeriod;
  bool _custom = false;
  TxType _view = TxType.expense;
  int _cycleDay = AppStore.I.cycleStartDay;

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange:
          DateTimeRange(start: _period.start, end: _period.lastDay),
    );
    if (r == null) return;
    setState(() {
      _custom = true;
      _period = Period(
        DateTime(r.start.year, r.start.month, r.start.day),
        DateTime(r.end.year, r.end.month, r.end.day + 1),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStore.I;
    if (_cycleDay != s.cycleStartDay) {
      _cycleDay = s.cycleStartDay;
      _period = s.currentPeriod;
      _custom = false;
    }
    final list = s.txnsIn(_period);
    final inc = s.sumOf(list, TxType.income);
    final exp = s.sumOf(list, TxType.expense);
    final days = _period.end.difference(_period.start).inDays;

    // total per kategori
    final byCat = <String?, int>{};
    for (final t in list.where((t) => t.type == _view)) {
      byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
    }
    final entries = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final viewTotal = _view == TxType.expense ? exp : inc;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        actions: [
          IconButton(
            tooltip: 'Riwayat bulanan',
            icon: const Icon(Icons.insights_rounded),
            onPressed: () => _openTrend(),
          ),
          IconButton(
            tooltip: 'Pilih rentang tanggal',
            icon: const Icon(Icons.date_range_rounded),
            onPressed: _pickRange,
          ),
          IconButton(
            tooltip: 'Bagikan CSV',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: list.isEmpty ? null : () => _exportCsv(list),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          if (_custom)
            Row(
              children: [
                Expanded(
                  child: Text(_period.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _custom = false;
                    _period = s.currentPeriod;
                  }),
                  child: const Text('Reset'),
                ),
              ],
            )
          else
            PeriodBar(
              period: _period,
              onChanged: (p) => setState(() => _period = p),
              onTapLabel: _pickRange,
            ),
          if (!_custom && s.cycleStartDay != 1)
            Text(
              'Periode dihitung dari tanggal ${s.cycleStartDay} tiap bulan (siklus gajian)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          Row(children: [
            SummaryChip(
                label: 'Pemasukan',
                value: inc,
                color: kIncomeColor,
                icon: Icons.south_west_rounded),
            const SizedBox(width: 8),
            SummaryChip(
                label: 'Pengeluaran',
                value: exp,
                color: kExpenseColor,
                icon: Icons.north_east_rounded),
          ]),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _row('Selisih (sisa uang)', money(inc - exp, sign: true),
                      bold: true),
                  _row('Rata-rata pengeluaran / hari',
                      money(days > 0 ? exp ~/ days : 0)),
                  _row('Rasio tabungan',
                      inc > 0 ? '${((inc - exp) * 100 / inc).toStringAsFixed(1)}%' : '-'),
                  _row('Jumlah transaksi', '${list.length}'),
                ],
              ),
            ),
          ),
          if (s.assetWallets.isNotEmpty || s.flowSummary(_period).hasTrade) ...[
            const SizedBox(height: 16),
            _flowCard(s.flowSummary(_period)),
          ],
          const SizedBox(height: 16),
          Text('Pengeluaran harian',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(height: 180, child: _dailyChart(list)),
          const SizedBox(height: 16),
          if (s.budgetCategories.isNotEmpty) ...[
            Text('Anggaran',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text('Atur di Kategori → ubah kategori → Anggaran',
                style: Theme.of(context).textTheme.bodySmall),
            ...(s.budgetCategories
                  ..sort((a, b) => (s.spentIn(_period, b.id) / b.budget)
                      .compareTo(s.spentIn(_period, a.id) / a.budget)))
                .map((c) => BudgetTile(
                    c: c,
                    period: _period,
                    onTap: () => _openTrend(categoryId: c.id))),
            const SizedBox(height: 16),
          ],
          if (s.bothCategories.isNotEmpty) ...[
            Text('Untung/rugi per kategori',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text('Kategori "Masuk & Keluar" pada periode ini',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            ...s.bothCategories.map((c) => _netTile(c)),
            const SizedBox(height: 16),
          ],
          SegmentedButton<TxType>(
            segments: const [
              ButtonSegment(value: TxType.expense, label: Text('Pengeluaran')),
              ButtonSegment(value: TxType.income, label: Text('Pemasukan')),
            ],
            selected: {_view},
            onSelectionChanged: (v) => setState(() => _view = v.first),
          ),
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: ListTile(
              leading: const Icon(Icons.insights_rounded),
              title: const Text('Riwayat bulanan'),
              subtitle: const Text(
                  'Laba, pemasukan & pengeluaran per bulan, dibanding bulan lalu + perkiraan bulan depan'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openTrend(),
            ),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const EmptyState(
                icon: Icons.donut_large_outlined,
                text: 'Belum ada data untuk periode ini')
          else ...[
            SizedBox(
              height: 200,
              child: PieChart(PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: entries.map((e) {
                  final c = s.category(e.key);
                  return PieChartSectionData(
                    value: e.value.toDouble(),
                    color: Color(c?.color ?? 0xFF9E9E9E),
                    radius: 42,
                    title: '',
                  );
                }).toList(),
              )),
            ),
            const SizedBox(height: 8),
            ...entries.map((e) {
              final c = s.category(e.key);
              final pct = viewTotal > 0 ? e.value / viewTotal : 0.0;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleIcon(
                    icon: c?.icon ?? 'other', color: c?.color ?? 0xFF9E9E9E),
                title: Text(c?.name ?? 'Tanpa kategori'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: LinearProgressIndicator(
                    value: pct,
                    color: Color(c?.color ?? 0xFF9E9E9E),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onTap: () => _openTrend(categoryId: e.key),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(money(e.value),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${(pct * 100).toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                onLongPress: () => _showCategoryTx(
                    c?.name ?? 'Tanpa kategori',
                    list
                        .where((t) =>
                            t.type == _view && t.categoryId == e.key)
                        .toList()),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _netTile(Category c) {
    final n = AppStore.I.categoryNet(_period, c.id);
    final col = n.net >= 0 ? kIncomeColor : kExpenseColor;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => TrendScreen(
                    mode: TrendMode.profit, categoryId: c.id))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            CircleIcon(icon: c.icon, color: c.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Masuk ${money(n.income)} • Keluar ${money(n.expense)}',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(n.net >= 0 ? 'Untung' : 'Minus',
                    style: TextStyle(color: col, fontSize: 11)),
                Text(money(n.net.abs()),
                    style: TextStyle(
                        color: col, fontWeight: FontWeight.w800)),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  void _openTrend({String? categoryId}) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              TrendScreen(
                  mode: categoryId == null
                      ? TrendMode.profit
                      : (_view == TxType.income
                          ? TrendMode.income
                          : TrendMode.expense),
                  categoryId: categoryId)));

  /// Ringkasan: jual-beli aset, pemasukan/pengeluaran lain, dan gabungannya.
  Widget _flowCard(FlowSummary f) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    String units(int n) => n > 0 ? ' ($n unit)' : '';
    Widget head(IconData icon, String t, Color c) => Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Row(children: [
            Icon(icon, size: 18, color: c),
            const SizedBox(width: 8),
            Expanded(
              child: Text(t,
                  style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700, color: c)),
            ),
          ]),
        );
    Widget line(String a, int v,
            {Color? color, bool bold = false, bool sign = false, String? sub}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a,
                      style: bold
                          ? const TextStyle(fontWeight: FontWeight.w700)
                          : null),
                  if (sub != null)
                    Text(sub,
                        style: tt.bodySmall?.copyWith(color: cs.outline)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(money(v, sign: sign),
                style: TextStyle(
                    color: color,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ]),
        );
    Color pl(int v) => v >= 0 ? kIncomeColor : kExpenseColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            head(Icons.swap_vert_circle_rounded, 'Jual-beli aset', cs.primary),
            line('Aset masuk (beli)${units(f.buyUnits)}', f.buy,
                color: kExpenseColor),
            if (f.tradeIn > 0)
              line('Aset masuk (tukar tambah)${units(f.tradeInUnits)}',
                  f.tradeIn,
                  color: kExpenseColor),
            line('Biaya barang', f.costs,
                color: kExpenseColor, sub: 'servis, ongkir, part, dll'),
            line('Aset keluar (terjual)${units(f.salesUnits)}', f.sales,
                color: kIncomeColor,
                sub: f.tradePaid > 0
                    ? 'termasuk ${money(f.tradePaid)} dibayar barang'
                    : null),
            line('Modal barang terjual', f.cogs),
            line('Total perputaran jual-beli', f.turnover,
                sub: 'beli + biaya + jual'),
            line(f.profit >= 0 ? 'Laba jual-beli' : 'Rugi jual-beli',
                f.profit.abs(),
                color: pl(f.profit), bold: true),
            const Divider(height: 20),
            head(Icons.receipt_long_rounded, 'Di luar jual-beli',
                cs.tertiary),
            line('Pemasukan lain', f.otherIn, color: kIncomeColor),
            line('Pengeluaran lain', f.otherOut, color: kExpenseColor),
            line('Selisih', f.otherIn - f.otherOut,
                color: pl(f.otherIn - f.otherOut), sign: true, bold: true),
            const Divider(height: 20),
            head(Icons.functions_rounded, 'Total semuanya', cs.onSurface),
            line('Total masuk', f.totalIn,
                color: kIncomeColor, sub: 'penjualan + pemasukan lain'),
            line('Total keluar', f.totalOut,
                color: kExpenseColor,
                sub: 'beli aset + biaya + pengeluaran lain'),
            line('Total perputaran', f.totalIn + f.totalOut,
                sub: 'masuk + keluar'),
            line('Arus bersih', f.totalIn - f.totalOut,
                color: pl(f.totalIn - f.totalOut),
                sign: true,
                sub: 'negatif = uang jadi stok'),
            line(f.netProfit >= 0 ? 'Laba bersih' : 'Rugi bersih',
                f.netProfit.abs(),
                color: pl(f.netProfit),
                bold: true,
                sub: 'laba jual-beli + pemasukan lain − pengeluaran lain'),
          ],
        ),
      ),
    );
  }

  Widget _row(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(a)),
          Text(b,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ]),
      );

  Widget _dailyChart(List<Txn> list) {
    final days = _period.end.difference(_period.start).inDays.clamp(1, 62);
    final totals = List<int>.filled(days, 0);
    for (final t in list.where((t) => t.type == TxType.expense)) {
      final i = DateTime(t.date.year, t.date.month, t.date.day)
          .difference(_period.start)
          .inDays;
      if (i >= 0 && i < days) totals[i] += t.amount;
    }
    final maxV = totals.fold(0, (a, b) => a > b ? a : b);
    final cs = Theme.of(context).colorScheme;
    return BarChart(BarChartData(
      maxY: maxV == 0 ? 1 : maxV * 1.15,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        topTitles: const AxisTitles(),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            getTitlesWidget: (v, meta) {
              final i = v.toInt();
              if (i % 5 != 0) return const SizedBox.shrink();
              final d = _period.start.add(Duration(days: i));
              return Text('${d.day}', style: const TextStyle(fontSize: 10));
            },
          ),
        ),
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, _, rod, __) {
            final d = _period.start.add(Duration(days: group.x));
            return BarTooltipItem(
              '${DateFormat('d MMM', 'id_ID').format(d)}\n${rupiah(rod.toY.toInt())}',
              const TextStyle(color: Colors.white, fontSize: 12),
            );
          },
        ),
      ),
      barGroups: List.generate(
        days,
        (i) => BarChartGroupData(x: i, barRods: [
          BarChartRodData(
            toY: totals[i].toDouble(),
            color: cs.primary,
            width: days > 40 ? 3 : 6,
            borderRadius: BorderRadius.circular(2),
          ),
        ]),
      ),
    ));
  }

  void _showCategoryTx(String title, List<Txn> txns) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (c, ctrl) => ListView(
          controller: ctrl,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(title, style: Theme.of(c).textTheme.titleLarge),
            ),
            ...txns.map((t) => TxTile(
                  t: t,
                  showDate: true,
                  onTap: () {
                    Navigator.pop(c);
                    openTxForm(context, edit: t);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(List<Txn> list) async {
    final s = AppStore.I;
    String esc(String v) => '"${v.replaceAll('"', '""')}"';
    final b = StringBuffer('Tanggal,Jenis,Kategori,Dompet,Dompet Tujuan,Nominal,Catatan\n');
    for (final t in list.reversed) {
      b.writeln([
        DateFormat('yyyy-MM-dd HH:mm').format(t.date),
        typeLabel(t.type),
        esc(s.category(t.categoryId)?.name ?? ''),
        esc(s.wallet(t.walletId)?.name ?? ''),
        esc(s.wallet(t.toWalletId)?.name ?? ''),
        t.amount,
        esc(t.note),
      ].join(','));
    }
    final name =
        'laporan_${DateFormat('yyyyMMdd').format(_period.start)}_${DateFormat('yyyyMMdd').format(_period.lastDay)}.csv';
    LockScreen.suspend = true;
    try {
      if (kIsWeb) {
        await SharePlus.instance.share(ShareParams(text: b.toString()));
      } else {
        final dir = await getTemporaryDirectory();
        final f = File('${dir.path}/$name');
        await f.writeAsString(b.toString());
        await SharePlus.instance.share(ShareParams(
          files: [XFile(f.path, mimeType: 'text/csv')],
          subject: 'Laporan keuangan ${_period.label}',
        ));
      }
    } finally {
      Future.delayed(
          const Duration(seconds: 1), () => LockScreen.suspend = false);
    }
  }
}
