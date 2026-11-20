import 'package:flutter/material.dart';

import '../format.dart';
import '../icons.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'asset_screens.dart';
import 'categories_screen.dart';
import 'home_screen.dart';

class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  void _open(BuildContext context, Wallet w) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => w.isAsset
              ? AssetWalletScreen(walletId: w.id)
              : WalletDetailScreen(walletId: w.id)));

  @override
  Widget build(BuildContext context) {
    final s = AppStore.I;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Dompet & Aset')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          GradientCard(
            color: cs.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kekayaan bersih',
                    style: TextStyle(color: Colors.white70)),
                Text(money(s.totalBalance + s.totalAssets),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: _pill(Icons.payments_rounded, 'Uang',
                        money(s.totalBalance)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _pill(Icons.inventory_2_rounded, 'Aset/stok',
                        money(s.totalAssets)),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle(context, 'Uang', Icons.payments_rounded),
          ...s.cashWallets.map((w) => _WalletTile(
                wallet: w,
                subtitle: 'Saldo',
                value: money(s.walletBalance(w.id)),
                onTap: () => _open(context, w),
              )),
          const SizedBox(height: 16),
          _sectionTitle(context, 'Aset & Dagangan', Icons.inventory_2_rounded),
          if (s.assetWallets.isEmpty)
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => editWallet(context, kind: 'asset'),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(children: [
                    CircleIcon(
                        icon: 'smartphone_box', color: cs.tertiary.toARGB32(),
                        size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Punya barang dagangan?',
                              style: tt.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                              'Buat dompet aset (mis. "Dagangan iPhone") untuk mencatat modal, harga jual, dan untung-rugi tiap barang.',
                              style: tt.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.add_circle_rounded),
                  ]),
                ),
              ),
            ),
          ...s.assetWallets.map((w) {
            final sum = s.assetSummary(w.id);
            return _WalletTile(
              wallet: w,
              subtitle:
                  '${sum.stockCount} stok • ${sum.soldCount} terjual',
              value: money(sum.stockValue),
              trailing: sum.soldCount > 0 ? ProfitBadge(sum.profit) : null,
              onTap: () => _open(context, w),
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _chooseKind(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Dompet'),
      ),
    );
  }

  Future<void> _chooseKind(BuildContext context) async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Jenis dompet', style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 12),
              _KindOption(
                icon: 'cash',
                color: 0xFF43A047,
                title: 'Dompet uang',
                desc: 'Tunai, rekening bank, e-wallet. Untuk catat pemasukan & pengeluaran.',
                onTap: () => Navigator.pop(c, 'cash'),
              ),
              const SizedBox(height: 10),
              _KindOption(
                icon: 'smartphone_box',
                color: 0xFF5E35B1,
                title: 'Dompet aset / dagangan',
                desc: 'Berisi barang (mis. iPhone) lengkap dengan modal, harga jual & untung-rugi.',
                onTap: () => Navigator.pop(c, 'asset'),
              ),
            ],
          ),
        ),
      ),
    );
    if (kind != null && context.mounted) editWallet(context, kind: kind);
  }

  Widget _pill(IconData icon, String label, String value) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
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
          ),
        ]),
      );

  Widget _sectionTitle(BuildContext context, String t, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Row(children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(t,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ]),
      );
}

class _WalletTile extends StatelessWidget {
  final Wallet wallet;
  final String subtitle;
  final String value;
  final Widget? trailing;
  final VoidCallback onTap;
  const _WalletTile({
    required this.wallet,
    required this.subtitle,
    required this.value,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleIcon(icon: wallet.icon, color: wallet.color, size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(wallet.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  if (trailing != null) ...[
                    const SizedBox(height: 6),
                    trailing!,
                  ],
                ],
              ),
            ),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const Icon(Icons.chevron_right_rounded),
          ]),
        ),
      ),
    );
  }
}

class _KindOption extends StatelessWidget {
  final String icon;
  final int color;
  final String title;
  final String desc;
  final VoidCallback onTap;
  const _KindOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Color(color).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleIcon(icon: icon, color: color, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(desc, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );
}

class WalletDetailScreen extends StatelessWidget {
  final String walletId;
  const WalletDetailScreen({super.key, required this.walletId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.I,
      builder: (context, _) {
        final s = AppStore.I;
        final w = s.wallet(walletId);
        if (w == null) return const Scaffold();
        final list = s.txns
            .where((t) => t.walletId == w.id || t.toWalletId == w.id)
            .toList();
        return Scaffold(
          appBar: AppBar(
            title: Text(w.name),
            actions: [
              IconButton(
                  onPressed: () => editWallet(context, edit: w),
                  icon: const Icon(Icons.edit_rounded)),
              IconButton(
                onPressed: () async {
                  if (s.cashWallets.length <= 1) {
                    toast(context, 'Minimal harus ada satu dompet uang');
                    return;
                  }
                  final n = list.length;
                  if (await confirm(
                      context,
                      'Hapus dompet?',
                      n > 0
                          ? 'Dompet "${w.name}" beserta $n transaksinya akan dihapus permanen.'
                          : 'Hapus dompet "${w.name}"?')) {
                    await s.deleteWallet(w.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: GradientCard(
                  color: Color(w.color),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(iconOf(w.icon)),
                        const SizedBox(width: 8),
                        const Text('Saldo saat ini',
                            style: TextStyle(color: Colors.white70)),
                      ]),
                      Text(money(s.walletBalance(w.id)),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800)),
                      Text('Saldo awal ${money(w.initialBalance)}',
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
              if (list.isEmpty)
                const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    text: 'Belum ada transaksi'),
              ...list.map((t) => TxTile(
                    t: t,
                    showDate: true,
                    onTap: () => openTxForm(context, edit: t),
                    onLongPress: () => showTxActions(context, t),
                  )),
            ],
          ),
        );
      },
    );
  }
}

Future<void> editWallet(BuildContext context,
    {Wallet? edit, String kind = 'cash'}) async {
  final k = edit?.kind ?? kind;
  final isAsset = k == 'asset';
  final name = TextEditingController(text: edit?.name ?? '');
  final initial =
      TextEditingController(text: formatAmountInput(edit?.initialBalance ?? 0));
  var icon = edit?.icon ?? (isAsset ? 'smartphone_box' : 'wallet');
  var color = edit?.color ?? (isAsset ? 0xFF5E35B1 : kColors.first);
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: IconColorForm(
          title: edit == null
              ? (isAsset ? 'Dompet aset baru' : 'Dompet baru')
              : 'Ubah dompet',
          nameController: name,
          icon: icon,
          color: color,
          onIcon: (v) => setState(() => icon = v),
          onColor: (v) => setState(() => color = v),
          extra: isAsset
              ? Text(
                  'Nilai dompet aset dihitung otomatis dari total modal barang yang belum terjual.',
                  style: Theme.of(ctx).textTheme.bodySmall)
              : TextField(
                  controller: initial,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsFormatter()],
                  decoration: const InputDecoration(
                      labelText: 'Saldo awal', prefixText: 'Rp '),
                ),
          onSave: () async {
            final n = name.text.trim();
            if (n.isEmpty) return;
            await AppStore.I.upsertWallet(Wallet(
              id: edit?.id ?? newId(),
              name: n,
              icon: icon,
              color: color,
              kind: k,
              initialBalance: isAsset ? 0 : parseAmount(initial.text),
            ));
            if (ctx.mounted) Navigator.pop(ctx);
          },
        ),
      ),
    ),
  );
}
