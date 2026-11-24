import 'package:flutter_test/flutter_test.dart';
import 'package:goes_to_financial_freedom/format.dart';
import 'package:goes_to_financial_freedom/models.dart';
import 'package:goes_to_financial_freedom/storage.dart';
import 'package:goes_to_financial_freedom/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> _fresh() async {
  SharedPreferences.setMockInitialValues({});
  final s = AppStore.I;
  s.backend = PrefsBackend();
  await s.load();
  return s;
}

void main() {
  test('penyimpanan hanya menulis baris yang berubah', () async {
    final s = await _fresh();
    final b = s.backend as PrefsBackend;
    final cash = s.cashWallets.first;
    for (var i = 0; i < 50; i++) {
      await s.upsertTxn(Txn(id: newId(), type: TxType.expense, amount: 1000,
          walletId: cash.id, date: DateTime.now()));
    }
    b.writes = 0;
    await s.upsertTxn(Txn(id: newId(), type: TxType.expense, amount: 2000,
        walletId: cash.id, date: DateTime.now()));
    // 1 transaksi baru (+ pengaturan "terakhir dipakai" bila berubah)
    expect(b.writes, lessThanOrEqualTo(2));
    // dimuat ulang dari penyimpanan → utuh
    await s.load();
    expect(s.txns.length, 51);
  });

  test('cadangan ke file lalu pulihkan → data kembali utuh', () async {
    final s = await _fresh();
    final cash = s.cashWallets.first;
    await s.upsertTxn(Txn(id: 't1', type: TxType.income, amount: 750000,
        walletId: cash.id, date: DateTime(2026, 5, 1), note: 'gaji'));
    await s.upsertDebt(Debt(id: 'd1', kind: 'receivable', person: 'Budi',
        amount: 100000, date: DateTime(2026, 5, 2)));
    await s.setThemeColor(0xFF6A1B9A);
    final raw = await s.exportBackup();
    final info = AppStore.inspectBackup(raw);
    expect(info.txns, s.txns.length);

    await s.resetAll();
    expect(s.txns, isEmpty);
    await s.importBackup(raw);
    expect(s.txns.single.note, 'gaji');
    expect(s.debt('d1')?.person, 'Budi');
    expect(s.themeColor.value, 0xFF6A1B9A);
    await s.load(); // tersimpan permanen
    expect(s.txns.single.amount, 750000);

    expect(() => AppStore.inspectBackup('{"app":"lain"}'),
        throwsFormatException);
  });

  test('piutang & utang: saldo berubah, laporan pemasukan tidak', () async {
    final s = await _fresh();
    final cash = s.cashWallets.first;
    cash.initialBalance = 1000000;
    await s.upsertWallet(cash);
    final p = s.currentPeriod;

    final d = Debt(id: newId(), kind: 'receivable', person: 'Andi',
        amount: 300000, date: DateTime.now(), walletId: cash.id,
        dueDate: DateTime.now().subtract(const Duration(days: 1)));
    await s.upsertDebt(d);
    expect(s.walletBalance(cash.id), 700000);
    expect(s.totalReceivable, 300000);
    expect(d.overdue, isTrue);

    d.payments.add(DebtPayment(id: newId(), amount: 100000,
        date: DateTime.now(), walletId: cash.id));
    await s.upsertDebt(d);
    expect(s.walletBalance(cash.id), 800000);
    expect(d.remaining, 200000);

    d.payments.add(DebtPayment(id: newId(), amount: 200000,
        date: DateTime.now(), walletId: cash.id));
    await s.upsertDebt(d);
    expect(d.settled, isTrue);
    expect(s.walletBalance(cash.id), 1000000);
    expect(s.totalReceivable, 0);

    // utang: uang masuk saat pinjam, keluar saat bayar
    final u = Debt(id: newId(), kind: 'payable', person: 'Supplier',
        amount: 500000, date: DateTime.now(), walletId: cash.id);
    await s.upsertDebt(u);
    expect(s.walletBalance(cash.id), 1500000);
    expect(s.totalPayable, 500000);

    // tidak tercatat sebagai pemasukan/pengeluaran
    final list = s.txnsIn(p);
    expect(s.sumOf(list, TxType.income), 0);
    expect(s.sumOf(list, TxType.expense), 0);

    await s.deleteDebt(u.id);
    expect(s.walletBalance(cash.id), 1000000);
  });

  test('transaksi rutin: tercatat otomatis termasuk yang terlewat', () async {
    final s = await _fresh();
    final cash = s.cashWallets.first;
    final cat = s.categoriesOf(TxType.expense).first;
    final r = Recurring(id: newId(), type: TxType.expense, amount: 150000,
        categoryId: cat.id, walletId: cash.id, freq: 'monthly', day: 5,
        startDate: DateTime(2026, 1, 5), lastRun: DateTime(2026, 1, 5),
        note: 'Cicilan');
    s.recurrings.add(r);
    await s.runRecurringNow(DateTime(2026, 4, 10));
    final made = s.txns.where((t) => t.recurringId == r.id).toList();
    expect(made.map((t) => t.date.month).toSet(), {2, 3, 4});
    // dijalankan lagi hari yang sama → tidak dobel
    await s.runRecurringNow(DateTime(2026, 4, 10));
    expect(s.txns.where((t) => t.recurringId == r.id).length, 3);
    expect(r.nextDue(DateTime(2026, 4, 10)), DateTime(2026, 5, 5));

    final w = Recurring(id: newId(), type: TxType.income, amount: 1,
        walletId: cash.id, freq: 'weekly', day: DateTime.monday,
        startDate: DateTime(2026, 6, 1));
    expect(w.dueDates(DateTime(2026, 6, 15)).length, 3); // 1, 8, 15 Juni
  });

  test('anggaran: pengeluaran per periode', () async {
    final s = await _fresh();
    final cash = s.cashWallets.first;
    final cat = s.categoriesOf(TxType.expense).first..budget = 1000000;
    await s.upsertCategory(cat);
    await s.upsertTxn(Txn(id: newId(), type: TxType.expense, amount: 850000,
        categoryId: cat.id, walletId: cash.id, date: DateTime.now()));
    expect(s.budgetCategories.map((c) => c.id), contains(cat.id));
    expect(s.spentIn(s.currentPeriod, cat.id), 850000);
    expect(s.spentIn(s.currentPeriod.shift(-1, 1), cat.id), 0);
  });

  test('barang qty: jual sebagian, modal dibagi proporsional', () async {
    final s = await _fresh();
    final cash = s.cashWallets.first;
    cash.initialBalance = 1000000;
    await s.upsertWallet(cash);
    final asset = Wallet(id: newId(), name: 'Casing', icon: 'inventory',
        color: 1, kind: 'asset');
    await s.upsertWallet(asset);
    final it = Item(id: newId(), walletId: asset.id, name: 'Casing iPhone',
        qty: 5, buyPrice: 100000, buyDate: DateTime.now(),
        buyWalletId: cash.id, targetPrice: 150000,
        costs: [ItemCost(id: newId(), name: 'Ongkir', amount: 10000,
            date: DateTime.now(), walletId: cash.id)]);
    await s.upsertItem(it);
    expect(it.unitCost, 22000);
    expect(s.walletBalance(cash.id), 890000);

    final part = await s.sellItem(it, qty: 2, price: 70000,
        date: DateTime.now(), walletId: cash.id);
    expect(part.qty, 2);
    expect(part.totalCost, 44000); // 40.000 + ongkir 4.000
    expect(part.profit, 26000);
    expect(it.qty, 3);
    expect(it.totalCost, 66000);
    expect(it.targetPrice, 90000);
    expect(s.walletBalance(asset.id), 66000);
    expect(s.walletBalance(cash.id), 890000 + 70000);
    final sum = s.assetSummary(asset.id);
    expect((sum.stockCount, sum.soldCount, sum.profit), (3, 2, 26000));

    // jual sisa semuanya
    final rest = await s.sellItem(it, qty: 3, price: 99000,
        date: DateTime.now(), walletId: cash.id);
    expect(rest.id, it.id);
    expect(it.sold, isTrue);
    expect(s.walletBalance(asset.id), 0);
  });

  test('periode helper tetap benar', () {
    final p = Period.cycle(DateTime(2026, 3, 10), 25);
    expect(p.start, DateTime(2026, 2, 25));
  });
}
