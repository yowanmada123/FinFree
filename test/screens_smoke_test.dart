import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goes_to_financial_freedom/main.dart';
import 'package:goes_to_financial_freedom/models.dart';
import 'package:goes_to_financial_freedom/screens/asset_screens.dart';
import 'package:goes_to_financial_freedom/screens/categories_screen.dart';
import 'package:goes_to_financial_freedom/screens/debt_screens.dart';
import 'package:goes_to_financial_freedom/screens/home_screen.dart';
import 'package:goes_to_financial_freedom/screens/tools_screens.dart';
import 'package:goes_to_financial_freedom/screens/tx_form_screen.dart';
import 'package:goes_to_financial_freedom/screens/wallets_screen.dart';
import 'package:goes_to_financial_freedom/screens/settings_screen.dart';
import 'package:goes_to_financial_freedom/screens/trend_screen.dart';
import 'package:goes_to_financial_freedom/store.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _seed() async {
  SharedPreferences.setMockInitialValues({});
  await initializeDateFormatting('id_ID');
  final s = AppStore.I;
  await s.load();
  final cash = s.cashWallets.first;
  final salary = s.categoriesOf(TxType.income).first;
  final food = s.categoriesOf(TxType.expense).first;
  final now = DateTime.now();
  for (var m = 0; m < 8; m++) {
    final d = DateTime(now.year, now.month - m, 5);
    await s.upsertTxn(Txn(id: newId(), type: TxType.income, amount: 5000000 + m * 250000,
        walletId: cash.id, categoryId: salary.id, date: d));
    await s.upsertTxn(Txn(id: newId(), type: TxType.expense, amount: 3000000 + m * 100000,
        walletId: cash.id, categoryId: food.id, date: d, note: 'makan'));
  }
  final asset = Wallet(id: newId(), name: 'Dagangan iPhone', icon: 'smartphone_box',
      color: 0xFF5E35B1, kind: 'asset');
  await s.upsertWallet(asset);
  await s.upsertItem(Item(id: 'i1', walletId: asset.id, name: 'iPhone 13',
      buyPrice: 9000000, buyDate: now.subtract(const Duration(days: 10)),
      buyWalletId: cash.id, targetPrice: 10500000, sold: true, sellPrice: 10000000,
      sellDate: now, sellWalletId: cash.id));
}

Widget _wrap(Widget w) =>
    MaterialApp(theme: FinFreeApp.theme(Brightness.light), home: w);

void main() {
  setUp(_seed);

  for (final mode in TrendMode.values) {
    testWidgets('TrendScreen $mode renders', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.75;
      await t.pumpWidget(_wrap(TrendScreen(mode: mode)));
      await t.pumpAndSettle();
      expect(find.text('Riwayat Bulanan'), findsOneWidget);
      await t.tap(find.text('12 bln'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Bulan sebelumnya'));
      await t.pumpAndSettle();
      final e = t.takeException();
      if (e is FlutterError) {
        debugPrint('EXC: ${e.toStringDeep()}');
      }
      expect(e, isNull);
    });
  }

  testWidgets('Home & item detail render', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    await t.pumpWidget(_wrap(const HomeScreen()));
    await t.pumpAndSettle();
    await t.tap(find.text('Dompet'));
    await t.pumpAndSettle();
    await t.pumpWidget(_wrap(const ItemDetailScreen(itemId: 'i1')));
    await t.pumpAndSettle();
    expect(find.text('UNTUNG'), findsOneWidget);
    final assetId = AppStore.I.assetWallets.first.id;
    await t.pumpWidget(_wrap(AssetWalletScreen(walletId: assetId)));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Terjual ('));
    await t.pumpAndSettle();
    expect(find.text('iPhone 13'), findsOneWidget);
  });

  testWidgets('kategori baru langsung muncul tanpa refresh', (t) async {
    await t.pumpWidget(_wrap(const CategoriesScreen()));
    await t.pumpAndSettle();
    expect(find.text('Kopi Susu'), findsNothing);
    await AppStore.I.upsertCategory(Category(
        id: newId(), name: 'Kopi Susu', type: TxType.expense,
        icon: 'coffee', color: 0xFF6D4C41));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Kopi Susu'), 200,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    expect(find.text('Kopi Susu'), findsOneWidget);
  });

  testWidgets('kategori masuk & keluar: untung/minus per bulan', (t) async {
    final s = AppStore.I;
    final cash = s.cashWallets.first;
    final c = Category(id: 'laundry', name: 'Usaha Laundry',
        type: TxType.income, icon: 'business', color: 0xFF1E88E5, both: true);
    await s.upsertCategory(c);
    expect(s.categoriesOf(TxType.expense).contains(c), isTrue);
    expect(s.categoriesOf(TxType.income).contains(c), isTrue);
    final now = DateTime.now();
    await s.upsertTxn(Txn(id: newId(), type: TxType.income, amount: 2000000,
        walletId: cash.id, categoryId: c.id, date: now));
    await s.upsertTxn(Txn(id: newId(), type: TxType.expense, amount: 2500000,
        walletId: cash.id, categoryId: c.id, date: now));
    final n = s.categoryNet(s.currentPeriod, c.id);
    expect(n.net, -500000);

    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    await t.pumpWidget(_wrap(TrendScreen(mode: TrendMode.profit, categoryId: c.id)));
    await t.pumpAndSettle();
    expect(find.textContaining('Untung/rugi Usaha Laundry'), findsOneWidget);
    await t.tap(find.text('Masuk'));
    await t.pumpAndSettle();
    await t.pumpWidget(_wrap(const CategoriesScreen()));
    await t.pumpAndSettle();
    expect(s.categoryUsage(c.id, type: TxType.expense), 1);
    expect(s.categoryUsage(c.id, type: TxType.income), 1);
    final list = find.descendant(
        of: find.byType(ListView).first, matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.text('Usaha Laundry'), 200, scrollable: list);
    expect(find.textContaining('Keluar periode ini Rp'), findsOneWidget);
    expect(find.textContaining('Minus Rp'), findsWidgets);
    await t.tap(find.text('Pemasukan').last);
    await t.pumpAndSettle();
    final list2 = find.descendant(
        of: find.byType(ListView).last, matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.text('Usaha Laundry'), 200, scrollable: list2);
    expect(find.textContaining('Masuk periode ini Rp'), findsOneWidget);
  });

  testWidgets('huruf HP diperbesar (1.15x) tidak bikin teks meluber', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    for (final w in <Widget>[
      const HomeScreen(),
      const TrendScreen(),
      const TrendScreen(mode: TrendMode.expense),
      const CategoriesScreen(),
      const ItemDetailScreen(itemId: 'i1'),
    ]) {
      await t.pumpWidget(MaterialApp(
        theme: FinFreeApp.theme(Brightness.light),
        home: Builder(
          builder: (c) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(1.15)),
            child: w,
          ),
        ),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '$w');
    }
  });

  testWidgets('ganti tema warna & mode gelap, tersimpan', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    final s = AppStore.I;
    await t.pumpWidget(const FinFreeApp());
    await t.pumpAndSettle();
    await t.tap(find.text('Atur'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Tema warna'), 200,
        scrollable: find
            .descendant(
                of: find.byType(SettingsScreen),
                matching: find.byType(Scrollable))
            .first);
    await t.tap(find.text('Tema warna'));
    await t.pumpAndSettle();
    await t.tap(find.text('Ungu'));
    await t.tap(find.text('Gelap'));
    await t.pumpAndSettle();
    expect(s.themeColor.value, 0xFF6A1B9A);
    expect(s.themeMode.value, 'dark');
    final ctx = t.element(find.byType(SettingsScreen));
    expect(Theme.of(ctx).brightness, Brightness.dark);
    expect(t.takeException(), isNull);

    // tersimpan: muat ulang dari penyimpanan
    s.themeColor.value = 0;
    s.themeMode.value = 'system';
    await s.load();
    expect(s.themeColor.value, 0xFF6A1B9A);
    expect(s.themeMode.value, 'dark');

    // layar utama aman di mode gelap
    for (final w in <Widget>[
      const HomeScreen(),
      const TrendScreen(),
      const ItemDetailScreen(itemId: 'i1'),
    ]) {
      await t.pumpWidget(MaterialApp(
          theme: FinFreeApp.theme(Brightness.dark, s.themeColor.value),
          home: w));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '$w');
    }
  });

  testWidgets('layar baru: utang, anggaran, rutin, qty — tanpa teks meluber',
      (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    final s = AppStore.I;
    final cash = s.cashWallets.first;
    final cat = s.categoriesOf(TxType.expense).first..budget = 3000000;
    await s.upsertCategory(cat);
    await s.upsertDebt(Debt(id: 'd1', kind: 'receivable',
        person: 'Budi Santoso Wijaya', amount: 2500000,
        date: DateTime.now(), walletId: cash.id,
        dueDate: DateTime.now().subtract(const Duration(days: 3)),
        note: 'DP iPhone 13 Pro Max', payments: [
          DebtPayment(id: 'p1', amount: 500000, date: DateTime.now(),
              walletId: cash.id),
        ]));
    await s.upsertDebt(Debt(id: 'd2', kind: 'payable', person: 'Supplier',
        amount: 1000000, date: DateTime.now()));
    await s.upsertRecurring(Recurring(id: 'r1', type: TxType.expense,
        amount: 750000, categoryId: cat.id, walletId: cash.id,
        freq: 'monthly', day: 28, startDate: DateTime.now(),
        lastRun: DateTime.now(), note: 'Cicilan motor'));
    final asset = s.assetWallets.first;
    await s.upsertItem(Item(id: 'q1', walletId: asset.id,
        name: 'Casing iPhone 15 Pro Max MagSafe', qty: 12,
        buyPrice: 1200000, buyDate: DateTime.now(), targetPrice: 1800000));

    for (final w in <Widget>[
      const DebtsScreen(),
      const DebtsScreen(receivable: false),
      const DebtDetailScreen(debtId: 'd1'),
      const BudgetsScreen(),
      const RecurringScreen(),
      const SettingsScreen(),
      const WalletsScreen(),
      const TxFormScreen(),
      const ItemDetailScreen(itemId: 'q1'),
      AssetWalletScreen(walletId: asset.id),
      const HomeScreen(),
    ]) {
      await t.pumpWidget(MaterialApp(
        theme: FinFreeApp.theme(Brightness.light),
        home: Builder(
          builder: (c) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(1.15)),
            child: w,
          ),
        ),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '$w');
    }

    // lembar jual sebagian & bayar cicilan terbuka tanpa error
    await t.pumpWidget(MaterialApp(
        theme: FinFreeApp.theme(Brightness.light),
        home: const ItemDetailScreen(itemId: 'q1')));
    await t.pumpAndSettle();
    expect(find.textContaining('×12'), findsWidgets);
    await t.tap(find.text('Jual (stok 12)'));
    await t.pumpAndSettle();
    expect(find.text('12 / 12'), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.pumpWidget(MaterialApp(
        theme: FinFreeApp.theme(Brightness.light),
        home: const DebtDetailScreen(debtId: 'd1')));
    await t.pumpAndSettle();
    await t.tap(find.text('Terima bayaran'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

}
