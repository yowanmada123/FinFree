import 'package:flutter_test/flutter_test.dart';
import 'package:goes_to_financial_freedom/models.dart';
import 'package:goes_to_financial_freedom/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('dagangan iPhone: modal, biaya, jual, untung & saldo', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore.I;
    await s.load();
    final cash = s.cashWallets.first;
    cash.initialBalance = 20000000;
    await s.upsertWallet(cash);
    final asset = Wallet(
        id: newId(), name: 'Dagangan iPhone', icon: 'smartphone_box',
        color: 0xFF5E35B1, kind: 'asset');
    await s.upsertWallet(asset);

    final it = Item(
      id: newId(), walletId: asset.id, name: 'iPhone 13',
      buyPrice: 10000000, buyDate: DateTime(2026, 1, 1),
      buyWalletId: cash.id, targetPrice: 12500000,
    );
    await s.upsertItem(it);
    expect(s.walletBalance(cash.id), 10000000);
    expect(s.walletBalance(asset.id), 10000000);
    expect(it.potentialProfit, 2500000);

    it.costs.add(ItemCost(id: newId(), name: 'Ganti baterai', amount: 500000,
        date: DateTime(2026, 1, 3), walletId: cash.id));
    await s.upsertItem(it);
    expect(it.totalCost, 10500000);
    expect(s.walletBalance(cash.id), 9500000);
    expect(s.walletBalance(asset.id), 10500000);

    it
      ..sold = true
      ..sellPrice = 12000000
      ..sellDate = DateTime(2026, 1, 10)
      ..sellWalletId = cash.id;
    await s.upsertItem(it);
    expect(it.profit, 1500000);
    expect(s.walletBalance(asset.id), 0);
    expect(s.walletBalance(cash.id), 21500000); // 20jt + untung 1,5jt
    final inc = s.txns.where((t) => t.itemId == it.id && t.type == TxType.income);
    expect(inc.single.amount, 1500000);

    // jual rugi
    it.sellPrice = 9000000;
    await s.upsertItem(it);
    expect(it.profit, -1500000);
    expect(s.walletBalance(cash.id), 18500000);
    expect(s.txns.where((t) => t.itemId == it.id && t.type == TxType.expense).single.amount, 1500000);

    await s.deleteItem(it.id);
    expect(s.walletBalance(cash.id), 20000000);
  });
}
