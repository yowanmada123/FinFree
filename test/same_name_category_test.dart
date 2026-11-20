import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:goes_to_financial_freedom/models.dart';
import 'package:goes_to_financial_freedom/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('kategori nama sama di keluar & masuk otomatis digabung', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore.I;
    await s.load();
    final cash = s.cashWallets.first;
    final now = DateTime.now();

    // user bikin "Laundry" di tab Pengeluaran, lalu "laundry" di Pemasukan
    final exp = Category(id: newId(), name: 'Laundry', type: TxType.expense,
        icon: 'business', color: 0xFF1E88E5);
    await s.upsertCategory(exp);
    await s.upsertTxn(Txn(id: newId(), type: TxType.expense, amount: 300000,
        walletId: cash.id, categoryId: exp.id, date: now));
    final inc = Category(id: newId(), name: 'laundry ', type: TxType.income,
        icon: 'business', color: 0xFF1E88E5);
    await s.upsertCategory(inc);
    await s.upsertTxn(Txn(id: newId(), type: TxType.income, amount: 1000000,
        walletId: cash.id, categoryId: inc.id, date: now));

    final merged = s.categories
        .where((c) => c.name.trim().toLowerCase() == 'laundry')
        .toList();
    expect(merged.length, 1);
    expect(merged.single.both, isTrue);
    final n = s.categoryNet(s.currentPeriod, merged.single.id);
    expect((n.income, n.expense, n.net), (1000000, 300000, 700000));
    // "Lainnya" bawaan tetap terpisah
    expect(s.categories.where((c) => c.name == 'Lainnya').length, 2);
  });

  test('data lama dengan kategori kembar ikut digabung saat dibuka', () async {
    final now = DateTime.now().toIso8601String();
    SharedPreferences.setMockInitialValues({
      'finfree_data_v1': jsonEncode({
        'wallets': [
          {'id': 'w', 'name': 'Tunai', 'icon': 'cash', 'color': 1}
        ],
        'categories': [
          {'id': 'a', 'name': 'Warung', 'type': 'expense'},
          {'id': 'b', 'name': 'Warung', 'type': 'income'},
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
    expect(s.categories.length, 1);
    final n = s.categoryNet(s.currentPeriod, s.categories.single.id);
    expect(n.net, -300);
  });
}
