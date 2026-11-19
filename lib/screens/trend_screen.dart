import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../format.dart';
import '../icons.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'asset_screens.dart' show GradientCard;
import 'home_screen.dart';

enum TrendMode { profit, income, expense }

/// Riwayat bulanan: laba bersih / pemasukan / pengeluaran per bulan (dan per
/// kategori), perbandingan dengan bulan lalu, serta perkiraan bulan depan.
class TrendScreen extends StatefulWidget {
  final TrendMode mode;
  final String? categoryId;
  const TrendScreen({super.key, this.mode = TrendMode.profit, this.categoryId});

  @override
  State<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends State<TrendScreen> {
  late TrendMode _mode = widget.mode;
  late String? _cat = widget.categoryId; // null = semua kategori
  int _count = 6; // jumlah bulan yang ditampilkan
  int _offset = 0; // 0 = jendela berakhir di bulan ini; -1 = mundur 1 bulan

  TxType? get _type => switch (_mode) {
        TrendMode.income => TxType.income,
        TrendMode.expense => TxType.expense,
        TrendMode.profit => null,
      };

  /// [_count] bulan, urut dari terlama, berakhir di bulan ini + [_offset].
  List<Period> _months() {
    final s = AppStore.I;
    final end = s.currentPeriod.shift(_offset, s.cycleStartDay);
    return List.generate(
        _count, (i) => end.shift(i - (_count - 1), s.cycleStartDay));
  }

  int _sumType(Period p, TxType t, [String? catId]) => AppStore.I.txns
      .where((x) =>
          x.type == t &&
          p.contains(x.date) &&
          (catId == null || x.categoryId == catId))
      .fold(0, (a, x) => a + x.amount);

  int _value(Period p) => _valueFor(p, _cat);

  /// Mode laba: masuk - keluar (untuk semua kategori atau satu kategori).
  int _valueFor(Period p, String? catId) => _mode == TrendMode.profit
      ? _sumType(p, TxType.income, catId) - _sumType(p, TxType.expense, catId)
      : _sumType(p, _type!, catId);

  /// Kategori yang bisa dipilih pada mode sekarang.
  List<Category> _chipCats() => _mode == TrendMode.profit
      ? AppStore.I.bothCategories
      : AppStore.I.categoriesOf(_type!);

  /// Laba dari penjualan barang dagangan pada bulan [p].
  int _tradeProfit(Period p) => AppStore.I.items
      .where((i) => i.sold && i.sellDate != null && p.contains(i.sellDate!))
      .fold(0, (a, i) => a + i.profit);

  /// Naik itu baik untuk laba & pemasukan, buruk untuk pengeluaran.
  Color deltaColor(int delta) {
    if (delta == 0) return Theme.of(context).colorScheme.outline;
    final good = _mode == TrendMode.expense ? delta < 0 : delta > 0;
    return good ? kIncomeColor : kExpenseColor;
  }

  String _short(Period p) => AppStore.I.cycleStartDay == 1
      ? DateFormat('MMM yy', 'id_ID').format(p.start)
      : DateFormat('d MMM', 'id_ID').format(p.start);

  String get _metricName => switch (_mode) {
        TrendMode.profit => 'Laba bersih',
        TrendMode.income => 'Pemasukan',
        TrendMode.expense => 'Pengeluaran',
      };

  /// Perkiraan bulan depan = rata-rata 3 bulan terakhir yang sudah selesai.
  ({Period month, int value})? _forecast() {
    final s = AppStore.I;
    final cur = s.currentPeriod;
    final done = [for (var i = 1; i <= 3; i++) cur.shift(-i, s.cycleStartDay)];
    final vals = done.map(_value).toList();
    if (vals.every((v) => v == 0)) return null;
    return (
      month: cur.shift(1, s.cycleStartDay),
      value: vals.reduce((a, b) => a + b) ~/ vals.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.I,
      builder: (context, _) {
        final s = AppStore.I;
        if (_cat != null && s.category(_cat) == null) _cat = null;
        final months = _months();
        final values = months.map(_value).toList();
        final selCat = s.category(_cat);
        final chipCats = _chipCats();
        final isProfit = _mode == TrendMode.profit;
        final color = selCat != null
            ? Color(selCat.color)
            : switch (_mode) {
                TrendMode.profit => Theme.of(context).colorScheme.primary,
                TrendMode.income => kIncomeColor,
                TrendMode.expense => kExpenseColor,
              };
        final last = values.last;
        final prev = values.length > 1 ? values[values.length - 2] : 0;
        final total = values.fold(0, (a, b) => a + b);
        final avg = total ~/ values.length;
        var bestI = 0, worstI = 0;
        for (var i = 1; i < values.length; i++) {
          if (values[i] > values[bestI]) bestI = i;
          if (values[i] < values[worstI]) worstI = i;
        }
        final fc = _offset == 0 ? _forecast() : null;
        final tt = Theme.of(context).textTheme;

        return Scaffold(
          appBar: AppBar(title: const Text('Riwayat Bulanan')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              SegmentedButton<TrendMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: TrendMode.profit,
                      label: Text('Laba'),
                      icon: Icon(Icons.savings_rounded)),
                  ButtonSegment(
                      value: TrendMode.income,
                      label: Text('Masuk'),
                      icon: Icon(Icons.south_west_rounded)),
                  ButtonSegment(
                      value: TrendMode.expense,
                      label: Text('Keluar'),
                      icon: Icon(Icons.north_east_rounded)),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => setState(() {
                  _mode = v.first;
                  // kategori "masuk & keluar" tetap terpilih saat ganti mode
                  if (!(s.category(_cat)?.both ?? false)) _cat = null;
                }),
              ),
              if (chipCats.isNotEmpty) ...[
                const SizedBox(height: 12),
                _categoryChips(chipCats),
              ],
              const SizedBox(height: 12),

              // ---- navigasi bulan ----
              Row(children: [
                IconButton.filledTonal(
                  tooltip: 'Bulan sebelumnya',
                  onPressed: () => setState(() => _offset--),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _offset = 0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(children: [
                        Text('${_short(months.first)} – ${_short(months.last)}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                            _offset == 0
                                ? '$_count bulan terakhir'
                                : 'ketuk untuk kembali ke bulan ini',
                            style: tt.bodySmall),
                      ]),
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Bulan berikutnya',
                  onPressed:
                      _offset < 0 ? () => setState(() => _offset++) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ]),
              const SizedBox(height: 8),
              Center(
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(value: 3, label: Text('3 bln')),
                    ButtonSegment(value: 6, label: Text('6 bln')),
                    ButtonSegment(value: 12, label: Text('12 bln')),
                  ],
                  selected: {_count},
                  onSelectionChanged: (v) => setState(() => _count = v.first),
                ),
              ),
              const SizedBox(height: 14),

              // ---- ringkasan: bulan ini vs bulan lalu ----
              GradientCard(
                color: _mode == TrendMode.profit
                    ? (last >= 0 ? kIncomeColor : kExpenseColor)
                    : color,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${selCat != null ? (isProfit ? 'Untung/rugi ${selCat.name}' : selCat.name) : _metricName} • ${months.last.label}',
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 2),
                    Text(
                        _mode == TrendMode.profit
                            ? money(last, sign: true)
                            : money(last),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    DeltaPill(
                      current: last,
                      previous: prev,
                      suffix: 'vs bulan lalu',
                      onDark: true,
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      _stat('Bulan lalu', money(prev)),
                      _stat('Rata-rata/bln', money(avg)),
                      _stat('Total $_count bln', money(total)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Row(children: [
                Expanded(
                  child: _miniCard(
                    icon: _mode == TrendMode.expense
                        ? Icons.local_fire_department_rounded
                        : Icons.emoji_events_rounded,
                    color: _mode == TrendMode.expense
                        ? kExpenseColor
                        : kIncomeColor,
                    title: _mode == TrendMode.expense
                        ? 'Paling boros'
                        : 'Bulan terbaik',
                    month: months[bestI].label,
                    value: values[bestI],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniCard(
                    icon: _mode == TrendMode.expense
                        ? Icons.eco_rounded
                        : Icons.south_rounded,
                    color: _mode == TrendMode.expense
                        ? kIncomeColor
                        : kExpenseColor,
                    title: _mode == TrendMode.expense
                        ? 'Paling hemat'
                        : 'Bulan terendah',
                    month: months[worstI].label,
                    value: values[worstI],
                  ),
                ),
              ]),

              if (fc != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.auto_graph_rounded),
                    title: Text(
                        'Perkiraan ${_metricName.toLowerCase()} ${fc.month.label}'),
                    subtitle:
                        const Text('Rata-rata 3 bulan terakhir yang sudah lewat'),
                    trailing: Text(
                        _mode == TrendMode.profit
                            ? money(fc.value, sign: true)
                            : money(fc.value),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ],
              const SizedBox(height: 18),

              Text('Grafik per bulan',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SizedBox(height: 230, child: _chart(months, values, color, fc)),
              if (fc != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Garis putus-putus = perkiraan bulan depan',
                      textAlign: TextAlign.center, style: tt.bodySmall),
                ),
              const SizedBox(height: 20),

              // ---- tabel per bulan ----
              Text('Rincian per bulan',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...List.generate(months.length, (k) {
                final i = months.length - 1 - k; // terbaru di atas
                return _monthCard(months[i], values[i],
                    i > 0 ? values[i - 1] : null, selCat);
              }),

              if (_cat == null && chipCats.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(isProfit ? 'Untung/rugi per kategori' : 'Per kategori',
                    style:
                        tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text('${months.last.label} dibanding bulan sebelumnya',
                    style: tt.bodySmall),
                const SizedBox(height: 8),
                ..._categoryRows(chipCats, months),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _categoryChips(List<Category> cats) => SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_mode == TrendMode.profit
                    ? 'Semua (laba total)'
                    : 'Semua kategori'),
                selected: _cat == null,
                onSelected: (_) => setState(() => _cat = null),
              ),
            ),
            ...cats.map((c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar:
                        Icon(iconOf(c.icon), size: 18, color: Color(c.color)),
                    label: Text(c.name),
                    selected: _cat == c.id,
                    onSelected: (_) => setState(() => _cat = c.id),
                  ),
                )),
          ],
        ),
      );

  Widget _monthCard(Period p, int v, int? pv, Category? cat) {
    final tt = Theme.of(context).textTheme;
    final isProfit = _mode == TrendMode.profit;
    final inc = isProfit ? _sumType(p, TxType.income, cat?.id) : 0;
    final exp = isProfit ? _sumType(p, TxType.expense, cat?.id) : 0;
    final trade = isProfit && cat == null ? _tradeProfit(p) : 0;
    final isCurrent = AppStore.I.currentPeriod.contains(p.start);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showMonthTx(p, cat),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(p.label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (isCurrent) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('berjalan', style: tt.labelSmall),
                  ),
                ],
                const Spacer(),
                Text(isProfit ? money(v, sign: true) : money(v),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isProfit
                            ? (v >= 0 ? kIncomeColor : kExpenseColor)
                            : null)),
              ]),
              const SizedBox(height: 6),
              if (pv == null)
                Text('Bulan pertama di tampilan', style: tt.bodySmall)
              else
                DeltaPill(current: v, previous: pv, suffix: 'vs bulan lalu'),
              if (isProfit) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: _kv(Icons.south_west_rounded, kIncomeColor,
                          'Masuk', money(inc))),
                  Expanded(
                      child: _kv(Icons.north_east_rounded, kExpenseColor,
                          'Keluar', money(exp))),
                ]),
                if (trade != 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _kv(Icons.storefront_rounded,
                        trade > 0 ? kIncomeColor : kExpenseColor,
                        'Dari dagangan', money(trade, sign: true)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(IconData icon, Color c, String k, String v) => Row(children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Text('$k ', style: Theme.of(context).textTheme.bodySmall),
        Flexible(
          child: Text(v,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ),
      ]);

  Widget _miniCard({
    required IconData icon,
    required Color color,
    required String title,
    required String month,
    required int value,
  }) =>
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(title,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium),
                ),
              ]),
              const SizedBox(height: 4),
              Text(month,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                    _mode == TrendMode.profit
                        ? money(value, sign: true)
                        : money(value),
                    style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );

  List<Widget> _categoryRows(List<Category> cats, List<Period> months) {
    final rows = cats
        .map((c) => (
              c: c,
              vals: months.map((p) => _valueFor(p, c.id)).toList()
            ))
        .where((r) => r.vals.any((v) => v != 0))
        .toList()
      ..sort((a, b) => b.vals.last.compareTo(a.vals.last));
    if (rows.isEmpty) {
      return [
        const EmptyState(
            icon: Icons.insights_rounded,
            text: 'Belum ada data pada bulan-bulan ini')
      ];
    }
    return rows.map((r) {
      final cur = r.vals.last;
      final prev = r.vals.length > 1 ? r.vals[r.vals.length - 2] : 0;
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _cat = r.c.id),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              CircleIcon(icon: r.c.icon, color: r.c.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.c.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    DeltaPill(current: cur, previous: prev),
                  ],
                ),
              ),
              SizedBox(
                  width: 64, height: 30, child: _sparkline(r.vals, Color(r.c.color))),
              const SizedBox(width: 10),
              Text(
                  _mode == TrendMode.profit
                      ? money(cur, sign: true)
                      : money(cur),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _mode == TrendMode.profit
                          ? (cur >= 0 ? kIncomeColor : kExpenseColor)
                          : null)),
            ]),
          ),
        ),
      );
    }).toList();
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

  Widget _chart(List<Period> months, List<int> values, Color color,
      ({Period month, int value})? fc) {
    final all = [...values, if (fc != null) fc.value];
    final maxV = all.fold(0, (a, b) => a > b ? a : b);
    final minV = all.fold(0, (a, b) => a < b ? a : b);
    final span = (maxV - minV) == 0 ? 1 : (maxV - minV);
    final cs = Theme.of(context).colorScheme;
    final n = months.length;
    final labels = [...months, if (fc != null) fc.month];
    final spots =
        List.generate(n, (i) => FlSpot(i.toDouble(), values[i].toDouble()));

    return LineChart(LineChartData(
      minY: minV < 0 ? minV - span * 0.15 : 0,
      maxY: maxV + span * 0.2,
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: span / 3,
        getDrawingHorizontalLine: (v) => FlLine(
            color: v == 0 ? cs.outline : cs.outlineVariant,
            strokeWidth: v == 0 ? 1 : 0.6),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 46,
            interval: span / 3,
            getTitlesWidget: (v, meta) => v == meta.max || v == meta.min
                ? const SizedBox.shrink()
                : Text(compact(v.toInt()), style: const TextStyle(fontSize: 10)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            interval: 1,
            getTitlesWidget: (v, meta) {
              final i = v.toInt();
              if (i < 0 || i >= labels.length || v != i.toDouble()) {
                return const SizedBox.shrink();
              }
              if (labels.length > 7 && i % 2 == 1 && i != labels.length - 1) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_short(labels[i]),
                    style: TextStyle(
                        fontSize: 10,
                        fontStyle:
                            i >= n ? FontStyle.italic : FontStyle.normal)),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touched) => touched.map((sp) {
            final i = sp.x.toInt();
            final isFc = i >= n;
            final v = isFc ? fc!.value : values[i];
            var txt = '${isFc ? 'Perkiraan ' : ''}${labels[i].label}\n${rupiah(v)}';
            if (!isFc && i > 0 && values[i - 1] != 0) {
              final p = (v - values[i - 1]) * 100 / values[i - 1].abs();
              txt += '\n${p >= 0 ? '+' : ''}${p.toStringAsFixed(1)}% vs bln lalu';
            }
            return LineTooltipItem(
                txt, const TextStyle(color: Colors.white, fontSize: 12));
          }).toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          preventCurveOverShooting: true,
          color: color,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            cutOffY: 0,
            applyCutOffY: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.3),
                color.withValues(alpha: 0.0)
              ],
            ),
          ),
        ),
        if (fc != null)
          LineChartBarData(
            spots: [spots.last, FlSpot(n.toDouble(), fc.value.toDouble())],
            color: color.withValues(alpha: 0.7),
            barWidth: 2,
            dashArray: [6, 4],
            dotData: FlDotData(
              checkToShowDot: (s, _) => s.x == n,
              getDotPainter: (s, a, b, c) => FlDotCirclePainter(
                radius: 5,
                color: cs.surface,
                strokeColor: color,
                strokeWidth: 2,
              ),
            ),
          ),
      ],
    ));
  }

  Widget _sparkline(List<int> vals, Color color) {
    final maxV = vals.fold(0, (a, b) => a > b ? a : b);
    final minV = vals.fold(0, (a, b) => a < b ? a : b);
    return LineChart(LineChartData(
      minY: minV.toDouble(),
      maxY: maxV == minV ? minV + 1 : maxV.toDouble(),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: List.generate(
              vals.length, (i) => FlSpot(i.toDouble(), vals[i].toDouble())),
          isCurved: true,
          preventCurveOverShooting: true,
          color: color,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      ],
    ));
  }

  void _showMonthTx(Period p, Category? cat) {
    final s = AppStore.I;
    final list = s.txns
        .where((t) =>
            p.contains(t.date) &&
            (cat == null || t.categoryId == cat.id) &&
            (_type == null ? t.type != TxType.transfer : t.type == _type))
        .toList();
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
              child: Text('${cat?.name ?? _metricName} • ${p.label}',
                  style: Theme.of(c).textTheme.titleMedium),
            ),
            if (list.isEmpty)
              const EmptyState(
                  icon: Icons.inventory_2_outlined, text: 'Tidak ada transaksi'),
            ...list.map((t) => TxTile(
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
}

/// Label perubahan: ↑ +12,5% (+Rp 500.000) atau ↓ …
class DeltaPill extends StatelessWidget {
  final int current;
  final int previous;
  final String? suffix;
  final bool onDark;
  const DeltaPill({
    super.key,
    required this.current,
    required this.previous,
    this.suffix,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_TrendScreenState>();
    final delta = current - previous;
    final color = onDark
        ? Colors.white
        : (state?.deltaColor(delta) ??
            (delta >= 0 ? kIncomeColor : kExpenseColor));
    String text;
    IconData icon;
    if (previous == 0 && current == 0) {
      text = 'Tidak ada data';
      icon = Icons.remove_rounded;
    } else if (previous == 0) {
      text = 'Baru (${delta > 0 ? '+' : '-'}${money(delta.abs())})';
      icon = Icons.fiber_new_rounded;
    } else if (delta == 0) {
      text = 'Tetap';
      icon = Icons.trending_flat_rounded;
    } else {
      final pct = delta * 100 / previous.abs();
      text =
          '${delta > 0 ? '+' : ''}${pct.toStringAsFixed(1)}% (${delta > 0 ? '+' : '-'}${money(delta.abs())})';
      icon =
          delta > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    }
    if (suffix != null) text = '$text $suffix';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: onDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
