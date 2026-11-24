import 'package:flutter/material.dart';

import '../format.dart';
import '../icons.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'asset_screens.dart';
import 'debt_screens.dart';
import 'tools_screens.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'trend_screen.dart';
import 'tx_form_screen.dart';
import 'wallets_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.I,
      builder: (context, _) => Scaffold(
        body: IndexedStack(
          index: _tab,
          // sengaja non-const agar tiap tab ikut rebuild saat data berubah
          children: [
            TransactionsTab(),
            ReportScreen(),
            WalletsScreen(),
            SettingsScreen(),
          ],
        ),
        floatingActionButton: _tab <= 1
            ? FloatingActionButton.extended(
                heroTag: 'fab-catat',
                onPressed: () => openTxForm(context),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Catat'),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.view_agenda_outlined),
                selectedIcon: Icon(Icons.view_agenda_rounded),
                label: 'Catatan'),
            NavigationDestination(
                icon: Icon(Icons.donut_large_outlined),
                selectedIcon: Icon(Icons.donut_large_rounded),
                label: 'Laporan'),
            NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Dompet'),
            NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune_rounded),
                label: 'Atur'),
          ],
        ),
      ),
    );
  }
}

Future<void> openTxForm(BuildContext context, {Txn? edit, Txn? copyFrom}) {
  // transaksi otomatis dari barang dagangan → buka detail barangnya
  final itemId = edit?.itemId ?? copyFrom?.itemId;
  if (itemId != null && AppStore.I.item(itemId) != null) {
    return openItem(context, itemId);
  }
  // transaksi otomatis dari utang/piutang → buka catatannya
  final debtId = edit?.debtId ?? copyFrom?.debtId;
  if (debtId != null && AppStore.I.debt(debtId) != null) {
    return openDebt(context, debtId);
  }
  return Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TxFormScreen(edit: edit, copyFrom: copyFrom),
      ),
    );
}

Future<void> showTxActions(BuildContext context, Txn t) async {
  if (t.isLinked) return openTxForm(context, edit: t);
  final r = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_rounded),
            title: const Text('Ubah'),
            onTap: () => Navigator.pop(c, 'edit'),
          ),
          ListTile(
            leading: const Icon(Icons.copy_all_rounded),
            title: const Text('Catat ulang (salin)'),
            onTap: () => Navigator.pop(c, 'copy'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: const Text('Hapus'),
            onTap: () => Navigator.pop(c, 'delete'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  switch (r) {
    case 'edit':
      await openTxForm(context, edit: t);
    case 'copy':
      await openTxForm(context, copyFrom: t);
    case 'delete':
      if (await confirm(context, 'Hapus transaksi?',
          'Transaksi ${rupiah(t.amount)} akan dihapus permanen.')) {
        await AppStore.I.deleteTxn(t.id);
        if (context.mounted) toast(context, 'Transaksi dihapus');
      }
  }
}

class TransactionsTab extends StatefulWidget {
  const TransactionsTab({super.key});

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  late Period _period = AppStore.I.currentPeriod;
  String? _walletFilter;
  int _cycleDay = AppStore.I.cycleStartDay;

  @override
  Widget build(BuildContext context) {
    final s = AppStore.I;
    if (_cycleDay != s.cycleStartDay) {
      _cycleDay = s.cycleStartDay;
      _period = s.currentPeriod;
    }
    final list = s.txnsIn(_period, walletId: _walletFilter);
    final inc = s.sumOf(list, TxType.income);
    final exp = s.sumOf(list, TxType.expense);
    final cs = Theme.of(context).colorScheme;

    // kelompokkan per hari
    final groups = <DateTime, List<Txn>>{};
    for (final t in list) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      groups.putIfAbsent(d, () => []).add(t);
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: const Text('FinFree'),
          actions: [
            IconButton(
              tooltip: 'Cari',
              icon: const Icon(Icons.manage_search_rounded),
              onPressed: () => showSearch(
                  context: context, delegate: TxSearchDelegate()),
            ),
            PopupMenuButton<String?>(
              tooltip: 'Filter dompet',
              icon: Icon(_walletFilter == null
                  ? Icons.filter_alt_outlined
                  : Icons.filter_alt_rounded),
              onSelected: (v) => setState(() => _walletFilter = v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: null, child: Text('Semua dompet')),
                ...s.wallets.map(
                    (w) => PopupMenuItem(value: w.id, child: Text(w.name))),
              ],
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: GradientCard(
              color: cs.primary,
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: cs.copyWith(onPrimaryContainer: Colors.white),
                  iconTheme: const IconThemeData(color: Colors.white),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                            _walletFilter == null
                                ? 'Total saldo'
                                : 'Saldo ${s.wallet(_walletFilter)?.name}',
                            style: const TextStyle(color: Colors.white70)),
                        const Spacer(),
                        InkWell(
                          onTap: s.toggleHideBalance,
                          child: Icon(
                            s.hideBalance
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      money(_walletFilter == null
                          ? s.totalBalance
                          : s.walletBalance(_walletFilter!)),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                    if (_walletFilter == null && s.assetWallets.isNotEmpty)
                      Text('+ aset/stok dagangan ${money(s.totalAssets)}',
                          style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    PeriodBar(
                      period: _period,
                      onChanged: (p) => setState(() => _period = p),
                    ),
                    Row(
                      children: [
                        SummaryChip(
                            label: 'Pemasukan',
                            value: inc,
                            color: Colors.white,
                            icon: Icons.south_west_rounded),
                        const SizedBox(width: 8),
                        SummaryChip(
                            label: 'Pengeluaran',
                            value: exp,
                            color: Colors.white,
                            icon: Icons.north_east_rounded),
                      ],
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TrendScreen())),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Expanded(
                            child: Text(
                              'Laba periode ini: ${money(inc - exp, sign: true)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Text('Riwayat bulanan',
                              style: TextStyle(color: Colors.white70)),
                          const Icon(Icons.chevron_right_rounded,
                              color: Colors.white70),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_walletFilter == null && backupOverdue())
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.save_alt_rounded),
                  title: const Text('Cadangkan data Anda'),
                  subtitle: Text(
                      '${backupStatus()}. Tanpa cadangan, data hilang bila HP rusak/ganti.'),
                  trailing: FilledButton.tonal(
                    onPressed: () => saveBackup(context),
                    child: const Text('Simpan'),
                  ),
                ),
              ),
            ),
          ),
        if (_walletFilter == null)
          if (s.budgetCategories
                  .where((c) => s.spentIn(_period, c.id) >= c.budget * 0.8)
                  .toList()
              case final warn when warn.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFE65100)),
                    title: const Text('Anggaran hampir habis'),
                    subtitle: Text(
                        warn
                            .map((c) =>
                                '${c.name} ${(s.spentIn(_period, c.id) * 100 / c.budget).round()}%')
                            .join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BudgetsScreen())),
                  ),
                ),
              ),
            ),
        // Untung/rugi kategori "masuk & keluar" yang aktif di periode ini.
        if (_walletFilter == null)
          for (final c in s.bothCategories)
            if (s.categoryNet(_period, c.id)
                case final n when n.income > 0 || n.expense > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: CircleIcon(icon: c.icon, color: c.color),
                      title: Text('Untung/rugi ${c.name}',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          'Masuk ${money(n.income)} · Keluar ${money(n.expense)}'),
                      trailing: Text(
                        '${n.net >= 0 ? 'Untung' : 'Minus'}\n${money(n.net.abs())}',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: n.net >= 0 ? kIncomeColor : kExpenseColor),
                      ),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => TrendScreen(
                                  mode: TrendMode.profit, categoryId: c.id))),
                    ),
                  ),
                ),
              ),
        if (list.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.inventory_2_outlined,
              text: 'Belum ada catatan di periode ini.\nTekan "Catat" untuk mulai.',
            ),
          ),
        for (final e in groups.entries) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(dfDay.format(e.key),
                        style: Theme.of(context).textTheme.labelLarge),
                  ),
                  Text(
                    money(s.sumOf(e.value, TxType.income) -
                        s.sumOf(e.value, TxType.expense), sign: true),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ),
          SliverList.list(
            children: e.value
                .map((t) => TxTile(
                      t: t,
                      onTap: () => openTxForm(context, edit: t),
                      onLongPress: () => showTxActions(context, t),
                    ))
                .toList(),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}

class TxSearchDelegate extends SearchDelegate<void> {
  TxSearchDelegate() : super(searchFieldLabel: 'Cari catatan, kategori, nominal');

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
              onPressed: () => query = '', icon: const Icon(Icons.clear)),
      ];

  @override
  Widget? buildLeading(BuildContext context) =>
      BackButton(onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final s = AppStore.I;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return const EmptyState(
          icon: Icons.manage_search_rounded, text: 'Ketik kata kunci');
    }
    final qNum = parseAmount(q);
    final res = s.txns.where((t) {
      final c = s.category(t.categoryId)?.name.toLowerCase() ?? '';
      final w = s.wallet(t.walletId)?.name.toLowerCase() ?? '';
      return t.note.toLowerCase().contains(q) ||
          c.contains(q) ||
          w.contains(q) ||
          (qNum > 0 && t.amount.toString().contains(qNum.toString()));
    }).toList();
    if (res.isEmpty) {
      return const EmptyState(
          icon: Icons.search_off_rounded, text: 'Tidak ditemukan');
    }
    final total = s.sumOf(res, TxType.expense);
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
                '${res.length} transaksi • total pengeluaran ${rupiah(total)}'),
          ),
          ...res.map((t) => TxTile(
                t: t,
                showDate: true,
                onTap: () => openTxForm(context, edit: t),
                onLongPress: () => showTxActions(context, t),
              )),
        ],
      ),
    );
  }
}
