import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:goes_to_financial_freedom/models.dart';
import 'package:goes_to_financial_freedom/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('kategori nama sama: dideteksi, digabung hanya bila dikonfirmasi',
      () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore.I;
    await s.load();
    final cash = s.cashWallets.first;
    final now = DateTime.now();

    final exp = Category(id: newId(), name: 'Laundry', type: TxType.expense,
        icon: 'business', color: 0xFF1E88E5);
    await s.upsertCategory(exp);
    await s.upsertTxn(Txn(id: newId(), type: TxType.expense, amount: 300000,
        walletId: cash.id, categoryId: exp.id, date: now));

    // user membuat "laundry " di Pemasukan → terdeteksi kembar
    final twin = s.sameNameOther('laundry ', TxType.income);
    expect(twin?.id, exp.id);
    final inc = Category(id: newId(), name: 'laundry ', type: TxType.income,
        icon: 'business', color: 0xFF1E88E5);
    await s.upsertCategory(inc);
    await s.upsertTxn(Txn(id: newId(), type: TxType.income, amount: 1000000,
        walletId: cash.id, categoryId: inc.id, date: now));

    // tanpa konfirmasi: tetap terpisah
    expect(
        s.categories.where((c) => c.name.trim().toLowerCase() == 'laundry').length,
        2);

    // dikonfirmasi "Gabungkan"
    await s.mergeCategories(inc.id, exp.id);
    final merged = s.categories
        .where((c) => c.name.trim().toLowerCase() == 'laundry')
        .toList();
    expect(merged.length, 1);
    expect(merged.single.both, isTrue);
    final n = s.categoryNet(s.currentPeriod, merged.single.id);
    expect((n.income, n.expense, n.net), (1000000, 300000, 700000));
    expect(s.categories.where((c) => c.name == 'Lainnya').length, 2);
    expect(s.sameNameOther('Lainnya', TxType.income), isNull);
  });

  test('data format lama dimigrasi ke penyimpanan baru tanpa digabung paksa',
      () async {
    final now = DateTime.now().toIso8601String();
    SharedPreferences.setMockInitialValues({
      'finfree_data_v1': jsonEncode({
        'wallets': [
          {'id': 'w', 'name': 'Tunai', 'icon': 'cash', 'color': 1}
        ],
        'categories': [
          {'id': 'a', 'name': 'Warung', 'type': 'expense'},
          {'id': 'b', 'name': 'Warung', 'type': 'income', 'both': false},
        ],
        'txns': [
          {'id': 't1', 'type': 'expense', 'amount': 500, 'walletId': 'w',
            'categoryId': 'a', 'date': now},
          {'id': 't2', 'type': 'income', 'amount': 200, 'walletId': 'w',
            'categoryId': 'b', 'date': now},
        ],
      }),
    });
    final s = AppStore.I;
    await s.load();
    expect(s.categories.length, 2);
    expect(s.txns.length, 2);
    expect(s.walletBalance('w'), -300);
    // format lama dihapus setelah dipindah
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('finfree_data_v1'), isNull);
    // dimuat ulang dari penyimpanan baru → data sama
    await s.load();
    expect(s.txns.length, 2);
  });
}
