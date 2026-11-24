import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../format.dart';
import '../icons.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'phone_spec.dart';
import 'wallets_screen.dart';

// ============================================================================
// Komponen kecil
// ============================================================================

/// Badge untung (hijau) / rugi (merah) / impas.
class ProfitBadge extends StatelessWidget {
  final int value;
  final String? prefix;
  final bool large;
  const ProfitBadge(this.value, {super.key, this.prefix, this.large = false});

  @override
  Widget build(BuildContext context) {
    final up = value > 0, down = value < 0;
    final color = up
        ? kIncomeColor
        : down
            ? kExpenseColor
            : Theme.of(context).colorScheme.outline;
    final label = up ? 'Untung' : (down ? 'Rugi' : 'Impas');
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 12 : 8, vertical: large ? 6 : 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              up
                  ? Icons.trending_up_rounded
                  : down
                      ? Icons.trending_down_rounded
                      : Icons.trending_flat_rounded,
              size: large ? 18 : 14,
              color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${prefix ?? label} ${money(value.abs())}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: large ? 14 : 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool sold;
  const _StatusChip(this.sold);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = sold ? cs.tertiary : cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: c),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(sold ? 'TERJUAL' : 'STOK',
          style: TextStyle(
              color: c,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8)),
    );
  }
}

/// Kartu gradien untuk header.
class GradientCard extends StatelessWidget {
  final Color color;
  final Widget child;
  const GradientCard({super.key, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(color);
    final dark = hsl.withLightness((hsl.lightness - 0.15).clamp(0, 1)).toColor();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [color, dark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: IconTheme(
          data: const IconThemeData(color: Colors.white),
          child: IconButtonTheme(
            data: IconButtonThemeData(
                style: IconButton.styleFrom(foregroundColor: Colors.white)),
            child: child,
          ),
        ),
      ),
    );
  }
}

class HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  const HeaderStat(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ),
          ],
        ),
      );
}

class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? helper;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  const AmountField(this.controller, this.label,
      {super.key, this.helper, this.autofocus = false, this.onChanged});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: TextInputType.number,
        inputFormatters: [ThousandsFormatter()],
        onChanged: onChanged,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          prefixText: 'Rp ',
        ),
      );
}

class DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  const DateField(this.label, this.value, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: value,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (d != null) onChanged(d);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.edit_calendar_rounded),
          ),
          child: Text(dfShort.format(value)),
        ),
      );
}

/// Pemilih dompet kas, dengan opsi "tidak tercatat di kas".
class CashWalletPicker extends StatelessWidget {
  final String label;
  final String? value;
  final String noneLabel;
  final ValueChanged<String?> onChanged;
  const CashWalletPicker({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.noneLabel = 'Tidak memengaruhi saldo',
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStore.I;
    return DropdownButtonFormField<String?>(
      key: ValueKey('$label-$value'),
      initialValue: s.wallet(value) != null ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Row(children: [
            Icon(Icons.block_rounded,
                size: 22, color: Theme.of(context).colorScheme.outline),
            const SizedBox(width: 10),
            Expanded(
                child: Text(noneLabel, overflow: TextOverflow.ellipsis)),
          ]),
        ),
        ...s.cashWallets.map((w) => DropdownMenuItem<String?>(
              value: w.id,
              child: Row(children: [
                CircleIcon(icon: w.icon, color: w.color, size: 26),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(w.name, overflow: TextOverflow.ellipsis)),
                Text(money(s.walletBalance(w.id)),
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            )),
      ],
      onChanged: onChanged,
    );
  }
}

Widget sheetTitle(BuildContext context, IconData icon, String title) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge),
        ),
      ]),
    );

// ============================================================================
// Halaman dompet aset (daftar barang dagangan)
// ============================================================================

class AssetWalletScreen extends StatefulWidget {
  final String walletId;
  const AssetWalletScreen({super.key, required this.walletId});

  @override
  State<AssetWalletScreen> createState() => _AssetWalletScreenState();
}

class _AssetWalletScreenState extends State<AssetWalletScreen> {
  int _filter = 0; // 0 stok, 1 terjual, 2 semua, 3 riwayat keluar-masuk
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.I,
      builder: (context, _) {
        final s = AppStore.I;
        final w = s.wallet(widget.walletId);
        if (w == null) return const Scaffold();
        final sum = s.assetSummary(w.id);
        var list = s.itemsOf(w.id);
        list = switch (_filter) {
          0 => list.where((i) => !i.sold).toList(),
          1 => list.where((i) => i.sold).toList(),
          _ => list,
        };
        if (_q.isNotEmpty) {
          final q = _q.toLowerCase();
          list = list
              .where((i) =>
                  i.name.toLowerCase().contains(q) ||
                  i.detail.toLowerCase().contains(q) ||
                  (i.phone?.searchText.contains(q) ?? false) ||
                  i.buyer.toLowerCase().contains(q) ||
                  i.supplier.toLowerCase().contains(q))
              .toList();
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(w.name),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') editWallet(context, edit: w);
                  if (v == 'delete') {
                    final n = s.itemsOf(w.id).length;
                    if (await confirm(context, 'Hapus dompet aset?',
                        'Dompet "${w.name}" beserta $n barang dan transaksi terkait akan dihapus permanen.')) {
                      await s.deleteWallet(w.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Ubah dompet')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus dompet')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              GradientCard(
                color: Color(w.color),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(iconOf(w.icon)),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text('Nilai stok (modal)',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white70)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(money(sum.stockValue),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    Row(children: [
                      HeaderStat('Stok', '${sum.stockCount} unit'),
                      HeaderStat('Terjual', '${sum.soldCount} unit'),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      HeaderStat(
                          sum.profit >= 0 ? 'Total untung' : 'Total rugi',
                          money(sum.profit.abs())),
                      HeaderStat('Potensi untung stok', money(sum.potential)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => _q = v.trim()),
                decoration: const InputDecoration(
                  hintText: 'Cari barang, IMEI, iBox, minus…',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ('Stok (${sum.stockCount})', 0),
                  ('Terjual (${sum.soldCount})', 1),
                  ('Semua', 2),
                  ('Keluar-masuk', 3),
                ]
                    .map((e) => ChoiceChip(
                          label: Text(e.$1),
                          selected: _filter == e.$2,
                          onSelected: (_) => setState(() => _filter = e.$2),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              if (_filter == 3)
                ..._moves(context, s.stockMoves(w.id))
              else if (list.isEmpty)
                EmptyState(
                  icon: Icons.inventory_2_outlined,
                  text: _filter == 1
                      ? 'Belum ada barang terjual'
                      : 'Belum ada barang.\nTekan "Tambah barang" untuk mencatat dagangan pertama Anda.',
                ),
              if (_filter != 3) ...list.map((i) => _ItemCard(item: i)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => ItemFormScreen(walletId: w.id))),
            icon: const Icon(Icons.add_box_rounded),
            label: const Text('Tambah barang'),
          ),
        );
      },
    );
  }
}

/// Riwayat: uang keluar → barang masuk (beli), barang keluar → uang masuk (jual).
List<Widget> _moves(BuildContext context, List<StockMove> moves) {
  final s = AppStore.I;
  final cs = Theme.of(context).colorScheme;
  if (moves.isEmpty) {
    return const [
      EmptyState(
          icon: Icons.swap_vert_rounded, text: 'Belum ada barang keluar-masuk')
    ];
  }
  String? lastDay;
  final out = <Widget>[];
  for (final m in moves) {
    final day = dfDay.format(m.date);
    if (day != lastDay) {
      lastDay = day;
      out.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
        child: Text(day,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: cs.outline)),
      ));
    }
    final wn = s.wallet(m.walletId)?.name;
    final flow = m.inbound
        ? (m.via ?? (wn != null ? 'Uang keluar dari $wn' : 'Tanpa potong saldo'))
        : [
            if (m.via != null) m.via!,
            if (wn != null)
              (m.cash ?? 0) < 0 ? 'tambah uang dari $wn' : 'uang masuk ke $wn',
          ].join(' • ');
    final party = m.party.isEmpty
        ? ''
        : (m.inbound ? ' • dari ${m.party}' : ' • ke ${m.party}');
    final color = m.inbound ? kExpenseColor : kIncomeColor;
    out.add(Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        onTap: () => openItem(context, m.itemId),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (m.inbound ? cs.primary : kIncomeColor)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
              m.inbound ? Icons.move_to_inbox_rounded : Icons.outbox_rounded,
              color: m.inbound ? cs.primary : kIncomeColor),
        ),
        title: Text(
            '${m.inbound ? 'Masuk' : 'Keluar'} • ${m.name}${m.qty > 1 ? ' ×${m.qty}' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${flow.isEmpty ? (m.inbound ? 'Dibeli' : 'Dijual') : flow}$party',
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(money(m.inbound ? -m.value : m.value, sign: !m.inbound),
                style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            if (!m.inbound)
              Text(
                  m.profit >= 0
                      ? 'untung ${money(m.profit)}'
                      : 'rugi ${money(-m.profit)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: m.profit >= 0 ? kIncomeColor : kExpenseColor)),
          ],
        ),
      ),
    ));
  }
  return out;
}

class _ItemCard extends StatelessWidget {
  final Item item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final i = item;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openItem(context, i.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.qty > 1 ? '${i.name}  ×${i.qty}' : i.name,
                            style: tt.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        if (i.phone != null && !i.phone!.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 2),
                            child: PhoneSpecChips(spec: i.phone!, dense: true),
                          ),
                        if (i.detail.isNotEmpty)
                          Text(i.detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  _StatusChip(i.sold),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _mini(
                      context,
                      i.qty > 1 ? 'Modal (${money(i.unitCost)}/unit)' : 'Modal',
                      money(i.totalCost)),
                  _mini(
                      context,
                      i.sold ? 'Terjual' : 'Target jual',
                      i.sold
                          ? money(i.sellPrice)
                          : (i.targetPrice > 0 ? money(i.targetPrice) : '-')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: i.sold
                          ? ProfitBadge(i.profit)
                          : i.targetPrice > 0
                              ? ProfitBadge(i.potentialProfit,
                                  prefix: 'Potensi')
                              : Text('Belum ada target harga',
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodySmall
                                      ?.copyWith(color: cs.outline)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.schedule_rounded, size: 14, color: cs.outline),
                  const SizedBox(width: 4),
                  Text(
                      i.sold
                          ? 'Laku ${i.holdDays} hari'
                          : '${i.holdDays} hari di stok',
                      style: tt.bodySmall?.copyWith(color: cs.outline)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mini(BuildContext context, String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

Future<void> openItem(BuildContext context, String itemId) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: itemId)));

// ============================================================================
// Detail barang
// ============================================================================

class ItemDetailScreen extends StatelessWidget {
  final String itemId;
  const ItemDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.I,
      builder: (context, _) {
        final s = AppStore.I;
        final i = s.item(itemId);
        if (i == null) return const Scaffold();
        final w = s.wallet(i.walletId);
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        final shown = i.sold ? i.profit : i.potentialProfit;
        final heroColor = !i.sold && i.targetPrice == 0
            ? Color(w?.color ?? cs.primary.toARGB32())
            : (shown >= 0 ? kIncomeColor : kExpenseColor);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Detail Barang'),
            actions: [
              IconButton(
                tooltip: 'Ubah',
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) =>
                            ItemFormScreen(walletId: i.walletId, edit: i))),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'copy') {
                    final copy = Item.fromJson(i.toJson()
                      ..['id'] = newId()
                      ..['sold'] = false
                      ..['sellPrice'] = 0
                      ..['sellDate'] = null
                      ..['sellWalletId'] = null
                      ..['buyer'] = ''
                      ..['costs'] = []
                      ..['photos'] = []
                      ..['tradeInId'] = null
                      ..['tradeInValue'] = 0
                      ..['tradeFromId'] = null
                      ..['buyDate'] = DateTime.now().toIso8601String());
                    if (!context.mounted) return;
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => ItemFormScreen(
                                walletId: i.walletId, template: copy)));
                  }
                  if (v == 'delete' &&
                      context.mounted &&
                      await confirm(context, 'Hapus barang?',
                          '"${i.name}" beserta transaksi kas terkait akan dihapus.')) {
                    await s.deleteItem(i.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'copy', child: Text('Duplikat (barang serupa)')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus barang')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            children: [
              GradientCard(
                color: heroColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(i.qty > 1 ? '${i.name}  ×${i.qty}' : i.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(i.sold ? 'TERJUAL' : 'STOK',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 0.8)),
                      ),
                    ]),
                    if (i.detail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(i.detail,
                          style: const TextStyle(color: Colors.white70)),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      i.sold
                          ? (i.profit >= 0 ? 'UNTUNG' : 'RUGI')
                          : (i.targetPrice > 0
                              ? 'POTENSI ${shown >= 0 ? 'UNTUNG' : 'RUGI'}'
                              : 'TOTAL MODAL'),
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 1),
                    ),
                    Text(
                      money(!i.sold && i.targetPrice == 0
                          ? i.totalCost
                          : shown.abs()),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800),
                    ),
                    if (i.sold || i.targetPrice > 0)
                      Text(
                          'Margin ${i.marginPct.toStringAsFixed(1)}% dari modal',
                          style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PhotoStrip(item: i),
              const SizedBox(height: 12),
              if (i.phone != null && !i.phone!.isEmpty) ...[
                _Section(
                  title: 'Spesifikasi iPhone',
                  icon: Icons.phone_iphone_rounded,
                  children: [
                    if (i.phone!.model.isNotEmpty)
                      _info(context, Icons.phone_iphone_rounded, 'Tipe',
                          i.phone!.title),
                    const SizedBox(height: 4),
                    PhoneSpecChips(spec: i.phone!),
                    if (i.phone!.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _info(context, Icons.report_gmailerrorred_rounded,
                          'Keterangan minus', i.phone!.note),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // ---- rincian perhitungan ----
              _Section(
                title: 'Rincian modal & keuntungan',
                icon: Icons.calculate_rounded,
                children: [
                  if (i.qty > 1)
                    _line(context, 'Jumlah', '${i.qty} unit'),
                  _line(context, i.qty > 1 ? 'Harga beli (total)' : 'Harga beli',
                      money(i.buyPrice)),
                  ...i.costs.map((c) => _line(
                        context,
                        '+ ${c.name.isEmpty ? 'Biaya' : c.name}',
                        money(c.amount),
                        sub: dfShort.format(c.date),
                        onTap: () => showCostSheet(context, i, edit: c),
                      )),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => showCostSheet(context, i),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Tambah biaya (servis, ongkir, dll)'),
                    ),
                  ),
                  const Divider(),
                  _line(context, 'Total modal', money(i.totalCost),
                      bold: true),
                  if (i.qty > 1)
                    _line(context, 'Modal per unit', money(i.unitCost)),
                  if (i.sold)
                    _line(context, 'Harga jual', money(i.sellPrice),
                        bold: true)
                  else
                    _line(
                        context,
                        'Target harga jual',
                        i.targetPrice > 0 ? money(i.targetPrice) : 'Belum diisi'),
                  const Divider(),
                  Row(children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                          i.sold ? 'Hasil' : 'Perkiraan hasil',
                          style: tt.titleSmall),
                    ),
                    Flexible(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: i.sold
                            ? ProfitBadge(i.profit, large: true)
                            : i.targetPrice > 0
                                ? ProfitBadge(i.potentialProfit, large: true)
                                : const Text('-'),
                      ),
                    ),
                  ]),
                ],
              ),
              const SizedBox(height: 12),

              _Section(
                title: 'Pembelian',
                icon: Icons.shopping_cart_checkout_rounded,
                children: [
                  _info(context, Icons.event_rounded, 'Tanggal beli',
                      dfDay.format(i.buyDate)),
                  _info(context, Icons.storefront_rounded, 'Beli dari',
                      i.supplier.isEmpty ? '-' : i.supplier),
                  if (s.item(i.tradeFromId) != null)
                    _tradeLink(context, s.item(i.tradeFromId), 'Didapat dari',
                        'Tukar tambah ${s.item(i.tradeFromId)!.name}')
                  else
                    _info(context, Icons.account_balance_wallet_rounded,
                        'Modal diambil dari',
                        s.wallet(i.buyWalletId)?.name ?? 'Tidak dari saldo'),
                  _info(context, Icons.inventory_2_rounded, 'Disimpan di',
                      w?.name ?? '-'),
                ],
              ),
              const SizedBox(height: 12),
              if (i.sold)
                _Section(
                  title: 'Penjualan',
                  icon: Icons.sell_rounded,
                  children: [
                    _info(context, Icons.event_available_rounded,
                        'Tanggal jual', dfDay.format(i.sellDate!)),
                    _info(context, Icons.person_rounded, 'Pembeli',
                        i.buyer.isEmpty ? '-' : i.buyer),
                    if (i.tradeInValue > 0) ...[
                      _tradeLink(context, s.tradeIn(i), 'Ditukar dengan',
                          '${s.tradeIn(i)?.name ?? 'barang'} (${money(i.tradeInValue)})'),
                      _info(
                          context,
                          Icons.payments_rounded,
                          i.cashReceived >= 0
                              ? 'Uang diterima'
                              : 'Anda menambah uang',
                          money(i.cashReceived.abs())),
                    ],
                    _info(
                        context,
                        Icons.account_balance_wallet_rounded,
                        i.cashReceived < 0 ? 'Uang diambil dari' : 'Uang masuk ke',
                        s.wallet(i.sellWalletId)?.name ?? 'Tidak ke saldo'),
                    _info(context, Icons.timer_rounded, 'Lama terjual',
                        '${i.holdDays} hari sejak dibeli'),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (await confirm(context, 'Batalkan penjualan?',
                            i.tradeInId != null
                                ? 'Barang akan kembali ke stok, transaksi penjualannya dihapus, dan barang tukar tambah yang diterima dikeluarkan dari stok.'
                                : 'Barang akan kembali ke stok dan transaksi penjualannya dihapus.',
                            ok: 'Batalkan')) {
                          final ok = await s.cancelSale(i);
                          if (!ok && context.mounted) {
                            toast(context,
                                'Barang tukar tambahnya sudah dijual. Batalkan penjualan barang itu dulu.');
                          }
                        }
                      },
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Batalkan penjualan'),
                    ),
                  ],
                )
              else
                _Section(
                  title: 'Status',
                  icon: Icons.timer_rounded,
                  children: [
                    _info(context, Icons.hourglass_bottom_rounded,
                        'Lama di stok', '${i.holdDays} hari'),
                  ],
                ),
            ],
          ),
          bottomNavigationBar: i.sold
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        backgroundColor: kIncomeColor,
                      ),
                      onPressed: () => showSellSheet(context, i),
                      icon: const Icon(Icons.sell_rounded),
                      label: Text(
                          i.qty > 1 ? 'Jual (stok ${i.qty})' : 'Tandai Terjual',
                          style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _tradeLink(
          BuildContext context, Item? other, String label, String value) =>
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: other == null ? null : () => openItem(context, other.id),
        child: Row(children: [
          Expanded(
              child: _info(context, Icons.swap_horiz_rounded, label, value)),
          if (other != null)
            Icon(Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.outline),
        ]),
      );

  Widget _line(BuildContext context, String a, String b,
          {bool bold = false, String? sub, VoidCallback? onTap}) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a,
                      style: TextStyle(
                          fontWeight:
                              bold ? FontWeight.w700 : FontWeight.normal)),
                  if (sub != null)
                    Text(sub, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Text(b,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.edit_rounded,
                  size: 14, color: Theme.of(context).colorScheme.outline),
            ],
          ]),
        ),
      );

  Widget _info(BuildContext context, IconData icon, String a, String b) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(child: Text(a)),
          Flexible(
            child: Text(b,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Section(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(icon,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );
}

// ============================================================================
// Form tambah / ubah barang
// ============================================================================

class ItemFormScreen extends StatefulWidget {
  final String walletId;
  final Item? edit;
  final Item? template;
  const ItemFormScreen(
      {super.key, required this.walletId, this.edit, this.template});

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _name = TextEditingController();
  final _detail = TextEditingController();
  final _buy = TextEditingController();
  final _target = TextEditingController();
  final _supplier = TextEditingController();
  final _sell = TextEditingController();
  final _buyer = TextEditingController();
  int _qty = 1;
  DateTime _buyDate = DateTime.now();
  DateTime _sellDate = DateTime.now();
  String? _buyWallet;
  String? _sellWallet;
  bool _sold = false;
  bool _isPhone = false;
  PhoneSpec _phone = PhoneSpec();
  bool _autoName = true; // nama mengikuti tipe + storage sampai diubah manual

  void _phoneChanged() => setState(() {
        if (_autoName && _phone.title.isNotEmpty) _name.text = _phone.title;
      });

  @override
  void initState() {
    super.initState();
    final src = widget.edit ?? widget.template;
    // dompet berisi iPhone → form langsung mode iPhone
    final w = AppStore.I.wallet(widget.walletId);
    _isPhone = src != null
        ? (src.phone != null || looksLikeIphone(src.name))
        : (looksLikeIphone(w?.name ?? '') ||
            AppStore.I.itemsOf(widget.walletId).any((i) => i.phone != null));
    _phone = src?.phone?.copy() ?? PhoneSpec();
    _autoName = src == null || src.name == _phone.title;
    _buyWallet = AppStore.I.defaultWallet.isAsset
        ? null
        : AppStore.I.defaultWallet.id;
    if (src != null) {
      _name.text = src.name;
      _detail.text = src.detail;
      _qty = src.qty;
      _buy.text = formatAmountInput(src.buyPrice);
      _target.text = formatAmountInput(src.targetPrice);
      _supplier.text = src.supplier;
      _buyDate = src.buyDate;
      _buyWallet = src.buyWalletId;
      _sold = src.sold;
      _sell.text = formatAmountInput(src.sellPrice);
      _buyer.text = src.buyer;
      _sellDate = src.sellDate ?? DateTime.now();
      _sellWallet = src.sellWalletId;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _detail, _buy, _target, _supplier, _sell, _buyer]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_isPhone && _name.text.trim().isEmpty) _name.text = _phone.title;
    final name = _name.text.trim();
    final buy = parseAmount(_buy.text);
    if (name.isEmpty || buy <= 0) {
      toast(context, 'Nama barang dan harga beli wajib diisi');
      return;
    }
    if (_sold && parseAmount(_sell.text) <= 0) {
      toast(context, 'Isi harga jual');
      return;
    }
    final e = widget.edit;
    final it = Item(
      id: e?.id ?? newId(),
      walletId: widget.walletId,
      name: name,
      detail: _detail.text.trim(),
      buyPrice: buy,
      buyDate: _buyDate,
      buyWalletId: _buyWallet,
      supplier: _supplier.text.trim(),
      costs: e?.costs ?? [],
      targetPrice: parseAmount(_target.text),
      sold: _sold,
      sellPrice: _sold ? parseAmount(_sell.text) : 0,
      sellDate: _sold ? _sellDate : null,
      sellWalletId: _sold ? _sellWallet : null,
      buyer: _sold ? _buyer.text.trim() : '',
      qty: _qty,
      photos: e?.photos ?? [],
      tradeInId: e?.tradeInId,
      tradeInValue: e?.tradeInValue ?? 0,
      tradeFromId: e?.tradeFromId,
      phone: _isPhone && !_phone.isEmpty ? _phone : null,
    );
    await AppStore.I.upsertItem(it);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final extra = widget.edit?.extraCost ?? 0;
    final cost = parseAmount(_buy.text) + extra;
    final target = parseAmount(_target.text);
    final sell = parseAmount(_sell.text);
    final preview = _sold ? sell - cost : (target > 0 ? target - cost : null);
    const gap = SizedBox(height: 12);

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.edit == null ? 'Tambah Barang' : 'Ubah Barang')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _groupLabel(context, '1', 'Info barang'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.phone_iphone_rounded),
            title: const Text('Barang iPhone'),
            subtitle: const Text('Isi tipe, storage, iBox/Inter, BH & minus'),
            value: _isPhone,
            onChanged: (v) => setState(() => _isPhone = v),
          ),
          if (_isPhone) ...[
            PhoneSpecEditor(spec: _phone, onChanged: _phoneChanged),
            gap,
          ],
          TextField(
            controller: _name,
            autofocus:
                !_isPhone && widget.edit == null && widget.template == null,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) => _autoName =
                v.trim().isEmpty || (_isPhone && v.trim() == _phone.title),
            decoration: InputDecoration(
              labelText: 'Nama barang *',
              hintText: 'mis. iPhone 13 Pro 256GB',
              helperText: _isPhone && _autoName
                  ? 'Terisi otomatis dari tipe & storage'
                  : null,
              prefixIcon: const Icon(Icons.inventory_2_rounded),
            ),
          ),
          gap,
          TextField(
            controller: _detail,
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(
              labelText: _isPhone ? 'Detail lain (opsional)' : 'Detail / spesifikasi',
              hintText: _isPhone
                  ? 'Warna, IMEI, kelengkapan (fullset / unit only)…'
                  : 'Warna, kondisi, IMEI, kelengkapan…',
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
          ),
          gap,
          Row(children: [
            const Icon(Icons.numbers_rounded),
            const SizedBox(width: 12),
            const Expanded(child: Text('Jumlah unit')),
            IconButton.filledTonal(
              tooltip: 'Kurangi',
              onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 44,
              child: Text('$_qty',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton.filledTonal(
              tooltip: 'Tambah',
              onPressed: () => setState(() => _qty++),
              icon: const Icon(Icons.add_rounded),
            ),
          ]),
          const SizedBox(height: 20),
          _groupLabel(context, '2', 'Pembelian (modal)'),
          AmountField(_buy, _qty > 1 ? 'Harga beli total ($_qty unit) *' : 'Harga beli *',
              helper: _qty > 1 && parseAmount(_buy.text) > 0
                  ? '= ${rupiah((parseAmount(_buy.text) / _qty).round())} per unit'
                  : null,
              onChanged: (_) => setState(() {})),
          if (extra > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text('+ biaya tambahan ${rupiah(extra)} (kelola di detail)',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          gap,
          Row(children: [
            Expanded(
                child: DateField('Tanggal beli', _buyDate,
                    (d) => setState(() => _buyDate = d))),
          ]),
          gap,
          CashWalletPicker(
            label: 'Bayar pakai dompet',
            value: _buyWallet,
            noneLabel: 'Stok lama / tidak potong saldo',
            onChanged: (v) => setState(() => _buyWallet = v),
          ),
          gap,
          TextField(
            controller: _supplier,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Beli dari (opsional)',
              prefixIcon: Icon(Icons.storefront_rounded),
            ),
          ),
          const SizedBox(height: 20),
          _groupLabel(context, '3', 'Penjualan'),
          AmountField(_target,
              _qty > 1 ? 'Target harga jual total (opsional)' : 'Target harga jual (opsional)',
              helper: 'Untuk melihat perkiraan untung',
              onChanged: (_) => setState(() {})),
          gap,
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sudah terjual'),
            value: _sold,
            onChanged: (v) => setState(() => _sold = v),
          ),
          if (_sold) ...[
            AmountField(_sell, 'Harga jual *',
                onChanged: (_) => setState(() {})),
            gap,
            DateField('Tanggal jual', _sellDate,
                (d) => setState(() => _sellDate = d)),
            gap,
            CashWalletPicker(
              label: 'Uang masuk ke dompet',
              value: _sellWallet,
              noneLabel: 'Tidak masuk saldo',
              onChanged: (v) => setState(() => _sellWallet = v),
            ),
            gap,
            TextField(
              controller: _buyer,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Pembeli (opsional)',
                prefixIcon: Icon(Icons.person_rounded),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (preview != null)
            _PreviewCard(cost: cost, price: _sold ? sell : target, sold: _sold),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _save,
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Simpan', style: TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }

  Widget _groupLabel(BuildContext context, String n, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(n,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onPrimary)),
          ),
          const SizedBox(width: 10),
          Text(t,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Kartu perhitungan langsung: modal vs harga → untung/rugi.
class _PreviewCard extends StatelessWidget {
  final int cost;
  final int price;
  final bool sold;
  const _PreviewCard(
      {required this.cost, required this.price, required this.sold});

  @override
  Widget build(BuildContext context) {
    final p = price - cost;
    final c = p >= 0 ? kIncomeColor : kExpenseColor;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        border: Border.all(color: c.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(children: [
            const Expanded(child: Text('Total modal')),
            Text(rupiah(cost)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: Text(sold ? 'Harga jual' : 'Target jual')),
            Text(rupiah(price)),
          ]),
          const Divider(height: 20),
          Row(children: [
            Icon(p >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: c),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  '${sold ? '' : 'Perkiraan '}${p >= 0 ? 'Untung' : 'Rugi'}',
                  style: TextStyle(color: c, fontWeight: FontWeight.w700)),
            ),
            Text(rupiah(p.abs()),
                style: TextStyle(
                    color: c, fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
          if (cost > 0)
            Align(
              alignment: Alignment.centerRight,
              child: Text('margin ${(p * 100 / cost).toStringAsFixed(1)}%',
                  style: TextStyle(color: c, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// Bottom sheet: tandai terjual & biaya tambahan
// ============================================================================

Future<void> showSellSheet(BuildContext context, Item i) async {
  var n = i.qty;
  int defaultPrice(int n) => (i.targetPrice * n / i.qty).round();
  final price = TextEditingController(text: formatAmountInput(i.targetPrice));
  final buyer = TextEditingController();
  var date = DateTime.now();
  String? walletId = AppStore.I.defaultWallet.isAsset
      ? null
      : AppStore.I.defaultWallet.id;
  // tukar tambah: pembeli membayar (sebagian) dengan barang
  var trade = false;
  final tName = TextEditingController();
  final tDetail = TextEditingController();
  final tValue = TextEditingController();
  var tWallet = i.walletId;
  var tIsPhone = i.phone != null || looksLikeIphone(i.name);
  final tPhone = PhoneSpec();
  var tAuto = true;
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sheetTitle(ctx, Icons.sell_rounded, 'Jual ${i.name}'),
              if (i.qty > 1) ...[
                Row(children: [
                  const Expanded(child: Text('Jumlah terjual')),
                  IconButton.filledTonal(
                    tooltip: 'Kurangi',
                    onPressed: n > 1
                        ? () => setState(() {
                              n--;
                              price.text = formatAmountInput(defaultPrice(n));
                            })
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  SizedBox(
                      width: 64,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('$n / ${i.qty}',
                            style: Theme.of(ctx).textTheme.titleMedium),
                      )),
                  IconButton.filledTonal(
                    tooltip: 'Tambah',
                    onPressed: n < i.qty
                        ? () => setState(() {
                              n++;
                              price.text = formatAmountInput(defaultPrice(n));
                            })
                        : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ]),
                const SizedBox(height: 12),
              ],
              AmountField(price, n > 1 ? 'Harga jual total ($n unit)' : 'Harga jual',
                  helper: n > 1 && parseAmount(price.text) > 0
                      ? '= ${rupiah((parseAmount(price.text) / n).round())} per unit'
                      : null,
                  autofocus: true, onChanged: (_) => setState(() {})),
              const SizedBox(height: 12),
              DateField('Tanggal jual', date, (d) => setState(() => date = d)),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: trade,
                onChanged: (v) => setState(() => trade = v),
                secondary: const Icon(Icons.swap_horiz_rounded),
                title: const Text('Tukar tambah / barter'),
                subtitle: const Text(
                    'Dibayar dengan barang lain (+/− uang). Barangnya masuk ke stok.'),
              ),
              if (trade) ...[
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Barang yang diterima iPhone'),
                  value: tIsPhone,
                  onChanged: (v) => setState(() => tIsPhone = v),
                ),
                if (tIsPhone) ...[
                  PhoneSpecEditor(
                    spec: tPhone,
                    onChanged: () => setState(() {
                      if (tAuto && tPhone.title.isNotEmpty) {
                        tName.text = tPhone.title;
                      }
                    }),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: tName,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (v) => tAuto = v.trim().isEmpty,
                  decoration: const InputDecoration(
                    labelText: 'Barang yang diterima',
                    hintText: 'mis. iPhone 11 64GB',
                    prefixIcon: Icon(Icons.move_to_inbox_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tDetail,
                  decoration: const InputDecoration(
                    labelText: 'Detail (opsional)',
                    hintText: 'warna, kondisi, IMEI…',
                  ),
                ),
                const SizedBox(height: 12),
                AmountField(tValue, 'Nilai barang yang diterima',
                    onChanged: (_) => setState(() {})),
                if (AppStore.I.assetWallets.length > 1) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: tWallet,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Masuk ke dompet aset'),
                    items: AppStore.I.assetWallets
                        .map((w) => DropdownMenuItem(
                            value: w.id,
                            child: Text(w.name, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => tWallet = v ?? tWallet),
                  ),
                ],
                const SizedBox(height: 12),
                TradeCashInfo(
                    cash: parseAmount(price.text) - parseAmount(tValue.text)),
                const SizedBox(height: 12),
              ] else
                const SizedBox(height: 8),
              CashWalletPicker(
                label: !trade
                    ? 'Uang masuk ke dompet'
                    : (parseAmount(price.text) - parseAmount(tValue.text) < 0
                        ? 'Uang tambahan diambil dari'
                        : 'Sisa uang masuk ke dompet'),
                value: walletId,
                noneLabel: 'Tidak memengaruhi saldo',
                onChanged: (v) => setState(() => walletId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: buyer,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Pembeli (opsional)',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
              ),
              const SizedBox(height: 16),
              _PreviewCard(
                  cost: (i.totalCost * n / i.qty).round(),
                  price: parseAmount(price.text),
                  sold: true),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: kIncomeColor),
                onPressed: () async {
                  final p = parseAmount(price.text);
                  if (p <= 0) return;
                  final tv = parseAmount(tValue.text);
                  if (trade && (tName.text.trim().isEmpty || tv <= 0)) {
                    toast(ctx, 'Isi nama & nilai barang yang diterima');
                    return;
                  }
                  final sold = await AppStore.I.sellItem(i,
                      qty: n,
                      price: p,
                      date: date,
                      walletId: walletId,
                      buyer: buyer.text.trim(),
                      tradeIn: trade
                          ? Item(
                              id: newId(),
                              walletId: tWallet,
                              name: tName.text.trim(),
                              detail: tDetail.text.trim(),
                              buyPrice: tv,
                              buyDate: date,
                              phone: tIsPhone && !tPhone.isEmpty
                                  ? tPhone
                                  : null)
                          : null);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    final left = sold.id == i.id ? '' : ' • sisa stok ${i.qty}';
                    toast(
                        context,
                        sold.profit >= 0
                            ? 'Terjual! Untung ${rupiah(sold.profit)} 🎉$left'
                            : 'Terjual. Rugi ${rupiah(-sold.profit)}$left');
                  }
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Simpan penjualan'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Ringkasan uang pada tukar tambah: harga jual − nilai barang diterima.
class TradeCashInfo extends StatelessWidget {
  final int cash;
  const TradeCashInfo({super.key, required this.cash});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, text, color) = cash > 0
        ? (Icons.south_west_rounded, 'Pembeli menambah uang ${rupiah(cash)}',
            kIncomeColor)
        : cash < 0
            ? (Icons.north_east_rounded,
                'Anda menambah uang ${rupiah(-cash)}', kExpenseColor)
            : (Icons.swap_horiz_rounded, 'Tukar impas, tanpa uang',
                cs.primary);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: TextStyle(color: color, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

const _costPresets = [
  'Servis',
  'Ganti part',
  'Ongkir',
  'Aksesoris',
  'Cuci / poles',
  'Admin / fee',
];

Future<void> showCostSheet(BuildContext context, Item i,
    {ItemCost? edit}) async {
  final name = TextEditingController(text: edit?.name ?? '');
  final amount = TextEditingController(text: formatAmountInput(edit?.amount ?? 0));
  var date = edit?.date ?? DateTime.now();
  String? walletId = edit != null
      ? edit.walletId
      : (AppStore.I.defaultWallet.isAsset ? null : AppStore.I.defaultWallet.id);
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sheetTitle(ctx, Icons.build_circle_rounded,
                  edit == null ? 'Tambah biaya' : 'Ubah biaya'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _costPresets
                    .map((p) => ChoiceChip(
                          label: Text(p),
                          selected: name.text == p,
                          onSelected: (_) => setState(() => name.text = p),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Keterangan biaya'),
              ),
              const SizedBox(height: 12),
              AmountField(amount, 'Nominal'),
              const SizedBox(height: 12),
              DateField('Tanggal', date, (d) => setState(() => date = d)),
              const SizedBox(height: 12),
              CashWalletPicker(
                label: 'Dibayar dari dompet',
                value: walletId,
                onChanged: (v) => setState(() => walletId = v),
              ),
              const SizedBox(height: 16),
              Row(children: [
                if (edit != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52)),
                      onPressed: () async {
                        i.costs.removeWhere((c) => c.id == edit.id);
                        await AppStore.I.upsertItem(i);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Hapus'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    onPressed: () async {
                      final a = parseAmount(amount.text);
                      if (a <= 0) return;
                      if (edit != null) {
                        edit
                          ..name = name.text.trim()
                          ..amount = a
                          ..date = date
                          ..walletId = walletId;
                      } else {
                        i.costs.add(ItemCost(
                          id: newId(),
                          name: name.text.trim(),
                          amount: a,
                          date: date,
                          walletId: walletId,
                        ));
                      }
                      await AppStore.I.upsertItem(i);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Simpan'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    ),
  );
}

// ============================================================================
// Foto barang / nota (disimpan di HP, ikut di file cadangan)
// ============================================================================

class PhotoStrip extends StatelessWidget {
  final Item item;
  const PhotoStrip({super.key, required this.item});

  Future<void> _add(BuildContext context) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: const Text('Ambil foto'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Pilih dari galeri'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (src == null) return;
    final x = await ImagePicker()
        .pickImage(source: src, maxWidth: 1600, imageQuality: 80);
    if (x == null) return;
    final dir = await AppStore.photoDir();
    final name = '${newId()}.jpg';
    await File(x.path).copy('${dir.path}/$name');
    item.photos.add(name);
    await AppStore.I.upsertItem(item);
  }

  void _view(BuildContext context, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Hapus foto',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  if (await confirm(c, 'Hapus foto?', 'Foto ini akan dihapus.')) {
                    item.photos.remove(name);
                    await AppStore.I.upsertItem(item);
                    await AppStore.I.deletePhotoIfUnused(name);
                    if (c.mounted) Navigator.pop(c);
                  }
                },
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              maxScale: 5,
              child: Image.file(File('${AppStore.photoPath}/$name')),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final path = AppStore.photoPath;
    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final ph in item.photos)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: path == null ? null : () => _view(context, ph),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: path == null
                      ? Container(
                          width: 84,
                          color: cs.surfaceContainerHighest,
                          child: const Icon(Icons.image_rounded))
                      : Image.file(File('$path/$ph'),
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                          cacheWidth: 250,
                          errorBuilder: (_, _, _) => Container(
                              width: 84,
                              color: cs.surfaceContainerHighest,
                              child: const Icon(Icons.broken_image_rounded))),
                ),
              ),
            ),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _add(context),
            child: Container(
              width: item.photos.isEmpty ? 210 : 84,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_rounded, color: cs.primary),
                  if (item.photos.isEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('Foto barang / nota',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cs.primary)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Jalan pintas dari "Catat": jual / beli barang tanpa membuka dompet aset
// ============================================================================

/// Pilih barang stok (dari semua dompet aset) lalu langsung buka lembar jual.
Future<void> quickSell(BuildContext context) async {
  final picked = await showModalBottomSheet<Item>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _StockPicker(),
  );
  if (picked != null && context.mounted) await showSellSheet(context, picked);
}

/// Pilih dompet aset (bila lebih dari satu) lalu buka form tambah barang.
Future<void> quickBuy(BuildContext context) async {
  final wallets = AppStore.I.assetWallets;
  if (wallets.isEmpty) return;
  var id = wallets.first.id;
  if (wallets.length > 1) {
    final w = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: sheetTitle(c, Icons.add_box_rounded, 'Simpan di dompet aset'),
          ),
          ...wallets.map((w) => ListTile(
                leading: CircleIcon(icon: w.icon, color: w.color),
                title: Text(w.name),
                subtitle: Text(
                    '${AppStore.I.assetSummary(w.id).stockCount} unit di stok'),
                onTap: () => Navigator.pop(c, w.id),
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (w == null) return;
    id = w;
  }
  if (!context.mounted) return;
  await Navigator.push(
      context,
      MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => ItemFormScreen(walletId: id)));
}

class _StockPicker extends StatefulWidget {
  const _StockPicker();

  @override
  State<_StockPicker> createState() => _StockPickerState();
}

class _StockPickerState extends State<_StockPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final s = AppStore.I;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final q = _q.trim().toLowerCase();
    final stock = s.items.where((i) => !i.sold).where((i) =>
        q.isEmpty ||
        i.name.toLowerCase().contains(q) ||
        i.detail.toLowerCase().contains(q) ||
        (i.phone?.searchText.contains(q) ?? false)).toList()
      ..sort((a, b) => b.buyDate.compareTo(a.buyDate));
    final multi = s.assetWallets.length > 1;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: sheetTitle(context, Icons.sell_rounded, 'Jual barang'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(
              hintText: 'Cari tipe, IMEI, iBox, minus…',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: stock.isEmpty
              ? EmptyState(
                  icon: Icons.inventory_2_outlined,
                  text: q.isEmpty
                      ? 'Belum ada barang di stok'
                      : 'Tidak ada barang yang cocok')
              : ListView.builder(
                  padding: EdgeInsets.only(
                      bottom: 16 + MediaQuery.of(context).viewInsets.bottom),
                  itemCount: stock.length,
                  itemBuilder: (_, n) {
                    final i = stock[n];
                    final w = s.wallet(i.walletId);
                    return ListTile(
                      onTap: () => Navigator.pop(context, i),
                      leading: CircleIcon(
                          icon: i.phone != null ? 'smartphone_box' : (w?.icon ?? 'inventory'),
                          color: w?.color ?? cs.primary.toARGB32()),
                      title: Text(i.qty > 1 ? '${i.name}  ×${i.qty}' : i.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (i.phone != null && !i.phone!.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3, bottom: 2),
                              child: PhoneSpecChips(spec: i.phone!, dense: true),
                            ),
                          Text(
                              [
                                'Modal ${money(i.totalCost)}',
                                if (i.targetPrice > 0)
                                  'target ${money(i.targetPrice)}',
                                if (multi && w != null) w.name,
                              ].join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall),
                        ],
                      ),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: cs.outline),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
