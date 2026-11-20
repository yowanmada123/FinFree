import 'package:flutter/material.dart';

import '../format.dart';
import '../icons.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
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

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeaderStat(this.label, this.value);

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

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? helper;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  const _AmountField(this.controller, this.label,
      {this.helper, this.autofocus = false, this.onChanged});

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

class _DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  const _DateField(this.label, this.value, this.onChanged);

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
class _CashWalletPicker extends StatelessWidget {
  final String label;
  final String? value;
  final String noneLabel;
  final ValueChanged<String?> onChanged;
  const _CashWalletPicker({
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

Widget _sheetTitle(BuildContext context, IconData icon, String title) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
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
  int _filter = 0; // 0 stok, 1 terjual, 2 semua
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
                      const Text('Nilai stok (modal)',
                          style: TextStyle(color: Colors.white70)),
                    ]),
                    const SizedBox(height: 4),
                    Text(money(sum.stockValue),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    Row(children: [
                      _HeaderStat('Stok', '${sum.stockCount} barang'),
                      _HeaderStat('Terjual', '${sum.soldCount} barang'),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      _HeaderStat(
                          sum.profit >= 0 ? 'Total untung' : 'Total rugi',
                          money(sum.profit.abs())),
                      _HeaderStat('Potensi untung stok', money(sum.potential)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => _q = v.trim()),
                decoration: const InputDecoration(
                  hintText: 'Cari barang, IMEI, pembeli…',
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
                ]
                    .map((e) => ChoiceChip(
                          label: Text(e.$1),
                          selected: _filter == e.$2,
                          onSelected: (_) => setState(() => _filter = e.$2),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                EmptyState(
                  icon: Icons.inventory_2_outlined,
                  text: _filter == 1
                      ? 'Belum ada barang terjual'
                      : 'Belum ada barang.\nTekan "Tambah barang" untuk mencatat dagangan pertama Anda.',
                ),
              ...list.map((i) => _ItemCard(item: i)),
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
                        Text(i.name,
                            style: tt.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
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
                  _mini(context, 'Modal', money(i.totalCost)),
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
                        child: Text(i.name,
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
              const SizedBox(height: 16),

              // ---- rincian perhitungan ----
              _Section(
                title: 'Rincian modal & keuntungan',
                icon: Icons.calculate_rounded,
                children: [
                  _line(context, 'Harga beli', money(i.buyPrice)),
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
                    _info(context, Icons.account_balance_wallet_rounded,
                        'Uang masuk ke',
                        s.wallet(i.sellWalletId)?.name ?? 'Tidak ke saldo'),
                    _info(context, Icons.timer_rounded, 'Lama terjual',
                        '${i.holdDays} hari sejak dibeli'),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (await confirm(context, 'Batalkan penjualan?',
                            'Barang akan kembali ke stok dan transaksi penjualannya dihapus.',
                            ok: 'Batalkan')) {
                          i
                            ..sold = false
                            ..sellPrice = 0
                            ..sellDate = null
                            ..sellWalletId = null
                            ..buyer = '';
                          await s.upsertItem(i);
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
                      label: const Text('Tandai Terjual',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
        );
      },
    );
  }

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
  DateTime _buyDate = DateTime.now();
  DateTime _sellDate = DateTime.now();
  String? _buyWallet;
  String? _sellWallet;
  bool _sold = false;

  @override
  void initState() {
    super.initState();
    final src = widget.edit ?? widget.template;
    _buyWallet = AppStore.I.defaultWallet.isAsset
        ? null
        : AppStore.I.defaultWallet.id;
    if (src != null) {
      _name.text = src.name;
      _detail.text = src.detail;
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
          TextField(
            controller: _name,
            autofocus: widget.edit == null && widget.template == null,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama barang *',
              hintText: 'mis. iPhone 13 Pro 256GB',
              prefixIcon: Icon(Icons.inventory_2_rounded),
            ),
          ),
          gap,
          TextField(
            controller: _detail,
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(
              labelText: 'Detail / spesifikasi',
              hintText: 'Warna, kondisi, IMEI, kelengkapan…',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 20),
          _groupLabel(context, '2', 'Pembelian (modal)'),
          _AmountField(_buy, 'Harga beli *',
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
                child: _DateField('Tanggal beli', _buyDate,
                    (d) => setState(() => _buyDate = d))),
          ]),
          gap,
          _CashWalletPicker(
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
          _AmountField(_target, 'Target harga jual (opsional)',
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
            _AmountField(_sell, 'Harga jual *',
                onChanged: (_) => setState(() {})),
            gap,
            _DateField('Tanggal jual', _sellDate,
                (d) => setState(() => _sellDate = d)),
            gap,
            _CashWalletPicker(
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
  final price = TextEditingController(text: formatAmountInput(i.targetPrice));
  final buyer = TextEditingController();
  var date = DateTime.now();
  String? walletId = AppStore.I.defaultWallet.isAsset
      ? null
      : AppStore.I.defaultWallet.id;
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
              _sheetTitle(ctx, Icons.sell_rounded, 'Jual ${i.name}'),
              _AmountField(price, 'Harga jual',
                  autofocus: true, onChanged: (_) => setState(() {})),
              const SizedBox(height: 12),
              _DateField('Tanggal jual', date, (d) => setState(() => date = d)),
              const SizedBox(height: 12),
              _CashWalletPicker(
                label: 'Uang masuk ke dompet',
                value: walletId,
                noneLabel: 'Tidak masuk saldo',
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
                  cost: i.totalCost, price: parseAmount(price.text), sold: true),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: kIncomeColor),
                onPressed: () async {
                  final p = parseAmount(price.text);
                  if (p <= 0) return;
                  i
                    ..sold = true
                    ..sellPrice = p
                    ..sellDate = date
                    ..sellWalletId = walletId
                    ..buyer = buyer.text.trim();
                  await AppStore.I.upsertItem(i);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    toast(
                        context,
                        i.profit >= 0
                            ? 'Terjual! Untung ${rupiah(i.profit)} 🎉'
                            : 'Terjual. Rugi ${rupiah(-i.profit)}');
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
              _sheetTitle(ctx, Icons.build_circle_rounded,
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
              _AmountField(amount, 'Nominal'),
              const SizedBox(height: 12),
              _DateField('Tanggal', date, (d) => setState(() => date = d)),
              const SizedBox(height: 12),
              _CashWalletPicker(
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
