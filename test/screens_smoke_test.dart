import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goes_to_financial_freedom/models.dart';
import 'package:goes_to_financial_freedom/screens/asset_screens.dart';
import 'package:goes_to_financial_freedom/screens/categories_screen.dart';
import 'package:goes_to_financial_freedom/screens/home_screen.dart';
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

Widget _wrap(Widget w) => MaterialApp(home: w);

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
      expect(t.takeException(), isNull);
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
  });
}
