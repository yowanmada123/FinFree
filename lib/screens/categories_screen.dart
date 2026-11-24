import 'package:flutter/material.dart';

import '../format.dart';
import '../icons.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'asset_screens.dart' show AmountField;

class CategoriesScreen extends StatelessWidget {
  final TxType initial;
  const CategoriesScreen({super.key, this.initial = TxType.expense});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initial == TxType.income ? 1 : 0,
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Kategori'),
            bottom: const TabBar(tabs: [
              Tab(text: 'Pengeluaran'),
              Tab(text: 'Pemasukan'),
            ]),
          ),
          body: const TabBarView(children: [
            _CatList(type: TxType.expense),
            _CatList(type: TxType.income),
          ]),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              final idx = DefaultTabController.of(context).index;
              editCategory(context,
                  type: idx == 0 ? TxType.expense : TxType.income);
            },
            child: const Icon(Icons.add_rounded),
          ),
        );
      }),
    );
  }
}

class _CatList extends StatelessWidget {
  final TxType type;
  const _CatList({required this.type});

  @override
  Widget build(BuildContext context) {
    // Pantau store langsung di sini: widget ini dibuat `const`, jadi tidak
    // akan ikut di-rebuild oleh parent saat data berubah.
    return ListenableBuilder(
      listenable: AppStore.I,
      builder: (context, _) => _list(context),
    );
  }

  Widget _list(BuildContext context) {
    final s = AppStore.I;
    final cats = s.categoriesOf(type);
    final period = s.currentPeriod;
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: cats.map((c) {
        // Kategori "masuk & keluar": tiap tab hanya menghitung sisinya
        // sendiri, jadi angka di tab Pengeluaran & Pemasukan berbeda.
        final used = s.categoryUsage(c.id, type: c.both ? type : null);
        final net = c.both ? s.categoryNet(period, c.id) : null;
        final side = type == TxType.income ? net?.income : net?.expense;
        return ListTile(
          leading: CircleIcon(
              icon: c.icon, color: typeColor(type, context).toARGB32()),
          title: Text(c.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(c.both
                    ? '$used ${type == TxType.income ? 'pemasukan' : 'pengeluaran'}'
                    : '$used transaksi'),
                if (c.both) ...[
                  const SizedBox(width: 8),
                  const _BothBadge(),
                ],
              ]),
              if (net != null)
                Text(
                  '${type == TxType.income ? 'Masuk' : 'Keluar'} periode ini ${money(side!)}'
                  ' · ${net.net >= 0 ? 'Untung' : 'Minus'} ${money(net.net.abs())}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: net.net >= 0 ? kIncomeColor : kExpenseColor,
                  ),
                ),
            ],
          ),
          isThreeLine: net != null,
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _delete(context, c),
          ),
          onTap: () => editCategory(context, type: type, edit: c),
        );
      }).toList(),
    );
  }

  Future<void> _delete(BuildContext context, Category c) async {
    final s = AppStore.I;
    final others = s.categoriesOf(c.type).where((e) => e.id != c.id).toList();
    if (others.isEmpty) {
      toast(context, 'Minimal harus ada satu kategori');
      return;
    }
    final used = s.categoryUsage(c.id);
    if (used == 0) {
      if (await confirm(context, 'Hapus kategori?', 'Hapus "${c.name}"?')) {
        await s.deleteCategory(c.id);
      }
      return;
    }
    if (!context.mounted) return;
    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Pindahkan $used transaksi "${c.name}" ke:'),
        children: others
            .map((o) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, o.id),
                  child: Row(children: [
                    CircleIcon(icon: o.icon, color: o.color, size: 28),
                    const SizedBox(width: 12),
                    Text(o.name),
                  ]),
                ))
            .toList(),
      ),
    );
    if (target != null) await s.deleteCategory(c.id, moveTo: target);
  }
}

class _BothBadge extends StatelessWidget {
  const _BothBadge();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.tertiary;
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.swap_vert_rounded, size: 12, color: c),
          const SizedBox(width: 2),
          Flexible(
            child: Text('Masuk & Keluar',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, color: c, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

Future<void> editCategory(BuildContext context,
    {required TxType type, Category? edit}) async {
  final name = TextEditingController(text: edit?.name ?? '');
  var icon = edit?.icon ?? (type == TxType.income ? 'income_other' : 'other');
  var color = edit?.color ?? kColors.first;
  var both = edit?.both ?? false;
  final budget = TextEditingController(
      text: edit != null && edit.budget > 0 ? formatAmountInput(edit.budget) : '');
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: IconColorForm(
          title: edit == null ? 'Kategori baru' : 'Ubah kategori',
          nameController: name,
          icon: icon,
          color: color,
          onIcon: (v) => setState(() => icon = v),
          onColor: (v) => setState(() => color = v),
          extra: Column(children: [
            Material(
              color: Theme.of(ctx).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
              child: SwitchListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                secondary: const Icon(Icons.swap_vert_circle_rounded),
                title: const Text('Masuk & Keluar'),
                subtitle: const Text(
                    'Untuk pemasukan & pengeluaran sekaligus, jadi untung/rugi kategori ini terlihat.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                value: both,
                onChanged: (v) => setState(() => both = v),
              ),
            ),
            if (both || (edit?.type ?? type) == TxType.expense) ...[
              const SizedBox(height: 12),
              AmountField(budget, 'Anggaran pengeluaran per periode (opsional)',
                  helper: 'Diberi peringatan saat mendekati batas'),
            ],
          ]),
          onSave: () async {
            final n = name.text.trim();
            if (n.isEmpty) return;
            final twin = AppStore.I.sameNameOther(
                n, edit?.type ?? type, exceptId: edit?.id);
            final catType =
                edit != null && (both || !edit.both) ? edit.type : type;
            final c = Category(
              id: edit?.id ?? newId(),
              name: n,
              type: catType,
              icon: icon,
              color: color,
              both: both,
              budget: both || catType == TxType.expense
                  ? parseAmount(budget.text)
                  : 0,
            );
            await AppStore.I.upsertCategory(c);
            if (ctx.mounted) Navigator.pop(ctx);
            // nama sama di sisi lain → tawarkan gabung (bukan otomatis)
            if (twin != null && context.mounted) {
              final side = twin.both
                  ? 'Masuk & Keluar'
                  : (twin.type == TxType.income ? 'Pemasukan' : 'Pengeluaran');
              if (await confirm(
                  context,
                  'Gabungkan kategori?',
                  'Sudah ada kategori "${twin.name}" di $side. Gabungkan jadi SATU kategori Masuk & Keluar supaya untung/ruginya terhitung?\n\nPilih "Tetap terpisah" bila memang ingin dibedakan.',
                  ok: 'Gabungkan',
                  cancel: 'Tetap terpisah')) {
                await AppStore.I.mergeCategories(c.id, twin.id);
                if (context.mounted) {
                  toast(context, '"$n" kini kategori Masuk & Keluar');
                }
              }
            }
          },
        ),
      ),
    ),
  );
}

/// Form nama + pemilih ikon + pemilih warna (dipakai kategori & dompet).
class IconColorForm extends StatelessWidget {
  final String title;
  final TextEditingController nameController;
  final String icon;
  final int color;
  final ValueChanged<String> onIcon;
  final ValueChanged<int> onColor;
  final VoidCallback onSave;
  final Widget? extra;

  const IconColorForm({
    super.key,
    required this.title,
    required this.nameController,
    required this.icon,
    required this.color,
    required this.onIcon,
    required this.onColor,
    required this.onSave,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleIcon(icon: icon, color: color, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            autofocus: nameController.text.isEmpty,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama'),
          ),
          if (extra != null) ...[const SizedBox(height: 12), extra!],
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: kColors
                  .map((c) => GestureDetector(
                        onTap: () => onColor(c),
                        child: Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: c == color
                                ? Border.all(
                                    width: 3,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface)
                                : null,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              crossAxisCount: 6,
              children: kIcons.keys
                  .map((k) => InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onIcon(k),
                        child: Center(
                          child: k == icon
                              ? CircleIcon(icon: k, color: color, size: 40)
                              : Icon(iconOf(k),
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                      ))
                  .toList(),
            ),
          ),
          FilledButton(
            onPressed: onSave,
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
