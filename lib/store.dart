import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'format.dart';
import 'models.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// Penyimpanan lokal (offline) seluruh data aplikasi.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore I = AppStore._();

  static const _kData = 'finfree_data_v1';
  static const _kSecurity = 'finfree_security_v1';

  late SharedPreferences _prefs;

  List<Wallet> wallets = [];
  List<Category> categories = [];
  List<Txn> txns = [];
  List<Item> items = [];

  // pengaturan
  int cycleStartDay = 1;
  bool hideBalance = false;
  String? lastExpenseCategoryId;
  String? lastIncomeCategoryId;
  String? lastWalletId;

  // keamanan
  String? _pinHash;
  String _pinSalt = '';
  bool biometricEnabled = false;

  bool get hasPin => _pinHash != null;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_kData);
    if (raw == null) {
      _seed();
      await _save();
    } else {
      _fromJson(jsonDecode(raw) as Map<String, dynamic>, notify: false);
    }
    final sec = _prefs.getString(_kSecurity);
    if (sec != null) {
      final j = jsonDecode(sec) as Map<String, dynamic>;
      _pinHash = j['pinHash'];
      _pinSalt = j['pinSalt'] ?? '';
      biometricEnabled = j['biometric'] ?? false;
    }
  }

  void _seed() {
    wallets = [
      Wallet(id: newId(), name: 'Tunai', icon: 'cash', color: 0xFF43A047),
      Wallet(id: newId(), name: 'Rekening Bank', icon: 'bank', color: 0xFF1E88E5),
      Wallet(id: newId(), name: 'E-Wallet', icon: 'ewallet', color: 0xFF8E24AA),
    ];
    Category e(String n, String i, int c) =>
        Category(id: newId(), name: n, type: TxType.expense, icon: i, color: c);
    Category inc(String n, String i, int c) =>
        Category(id: newId(), name: n, type: TxType.income, icon: i, color: c);
    categories = [
      e('Makan & Minum', 'food', 0xFFFB8C00),
      e('Belanja Harian', 'grocery', 0xFF7CB342),
      e('Transportasi', 'transport', 0xFF039BE5),
      e('Bensin', 'fuel', 0xFFF4511E),
      e('Tagihan', 'bills', 0xFF5E35B1),
      e('Listrik', 'electric', 0xFFF9A825),
      e('Pulsa & Internet', 'internet', 0xFF00ACC1),
      e('Rumah', 'home', 0xFF6D4C41),
      e('Belanja', 'shopping', 0xFFD81B60),
      e('Kesehatan', 'health', 0xFFE53935),
      e('Pendidikan', 'education', 0xFF3949AB),
      e('Hiburan', 'entertain', 0xFF8E24AA),
      e('Sedekah', 'charity', 0xFF00897B),
      e('Cicilan', 'debt', 0xFF546E7A),
      e('Lainnya', 'other', 0xFF546E7A),
      inc('Gaji', 'salary', 0xFF43A047),
      inc('Bonus', 'bonus', 0xFFF9A825),
      inc('Usaha', 'business', 0xFF1E88E5),
      inc('Investasi', 'invest', 0xFF00897B),
      inc('Lainnya', 'income_other', 0xFF546E7A),
    ];
    txns = [];
    items = [];
  }

  // ---------- persistensi ----------
  Map<String, dynamic> _toJson() => {
        'app': 'finfree',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'wallets': wallets.map((e) => e.toJson()).toList(),
        'categories': categories.map((e) => e.toJson()).toList(),
        'txns': txns.map((e) => e.toJson()).toList(),
        'items': items.map((e) => e.toJson()).toList(),
        'settings': {
          'cycleStartDay': cycleStartDay,
          'hideBalance': hideBalance,
          'lastExpenseCategoryId': lastExpenseCategoryId,
          'lastIncomeCategoryId': lastIncomeCategoryId,
          'lastWalletId': lastWalletId,
        },
      };

  void _fromJson(Map<String, dynamic> j, {bool notify = true}) {
    wallets = (j['wallets'] as List).map((e) => Wallet.fromJson(e)).toList();
    categories =
        (j['categories'] as List).map((e) => Category.fromJson(e)).toList();
    txns = (j['txns'] as List).map((e) => Txn.fromJson(e)).toList();
    items = ((j['items'] ?? []) as List).map((e) => Item.fromJson(e)).toList();
    final s = (j['settings'] ?? {}) as Map<String, dynamic>;
    cycleStartDay = s['cycleStartDay'] ?? 1;
    hideBalance = s['hideBalance'] ?? false;
    lastExpenseCategoryId = s['lastExpenseCategoryId'];
    lastIncomeCategoryId = s['lastIncomeCategoryId'];
    lastWalletId = s['lastWalletId'];
    _sortTxns();
    if (notify) notifyListeners();
  }

  Future<void> _save() async {
    await _prefs.setString(_kData, jsonEncode(_toJson()));
  }

  Future<void> _commit() async {
    _sortTxns();
    notifyListeners();
    await _save();
  }

  void _sortTxns() => txns.sort((a, b) => b.date.compareTo(a.date));

  // ---------- lookup ----------
  Wallet? wallet(String? id) =>
      wallets.where((w) => w.id == id).firstOrNull;
  Category? category(String? id) =>
      categories.where((c) => c.id == id).firstOrNull;
  List<Category> categoriesOf(TxType t) =>
      categories.where((c) => c.usableFor(t)).toList();

  /// Kategori "masuk & keluar" (bisa dihitung untung/rugi-nya).
  List<Category> get bothCategories =>
      categories.where((c) => c.both).toList();

  /// Ringkasan satu kategori pada periode: masuk, keluar, dan selisihnya.
  ({int income, int expense, int net}) categoryNet(Period p, String catId) {
    var inc = 0, exp = 0;
    for (final t in txns) {
      if (t.categoryId != catId || !p.contains(t.date)) continue;
      if (t.type == TxType.income) inc += t.amount;
      if (t.type == TxType.expense) exp += t.amount;
    }
    return (income: inc, expense: exp, net: inc - exp);
  }

  List<Wallet> get cashWallets => wallets.where((w) => !w.isAsset).toList();
  List<Wallet> get assetWallets => wallets.where((w) => w.isAsset).toList();

  Wallet get defaultWallet {
    final w = wallet(lastWalletId);
    if (w != null && !w.isAsset) return w;
    return cashWallets.firstOrNull ?? wallets.first;
  }

  Category? defaultCategory(TxType t) {
    final id = t == TxType.income ? lastIncomeCategoryId : lastExpenseCategoryId;
    return category(id) ?? categoriesOf(t).firstOrNull;
  }

  int walletBalance(String walletId) {
    final w = wallet(walletId);
    // nilai dompet aset = total modal barang yang belum terjual
    if (w != null && w.isAsset) {
      return itemsOf(walletId)
          .where((i) => !i.sold)
          .fold(0, (s, i) => s + i.totalCost);
    }
    var b = w?.initialBalance ?? 0;
    for (final t in txns) {
      switch (t.type) {
        case TxType.income:
          if (t.walletId == walletId) b += t.amount;
        case TxType.expense:
          if (t.walletId == walletId) b -= t.amount;
        case TxType.transfer:
          if (t.walletId == walletId) b -= t.amount;
          if (t.toWalletId == walletId) b += t.amount;
      }
    }
    return b;
  }

  /// Total uang (dompet kas saja).
  int get totalBalance =>
      cashWallets.fold(0, (s, w) => s + walletBalance(w.id));

  /// Total nilai aset/stok dagangan (berdasarkan modal).
  int get totalAssets =>
      assetWallets.fold(0, (s, w) => s + walletBalance(w.id));

  // ---------- barang dagangan ----------
  List<Item> itemsOf(String walletId) =>
      items.where((i) => i.walletId == walletId).toList()
        ..sort((a, b) => (b.sellDate ?? b.buyDate).compareTo(a.sellDate ?? a.buyDate));

  Item? item(String? id) => items.where((i) => i.id == id).firstOrNull;

  Category _ensureCategory(String name, TxType type, String icon, int color) {
    final c = categories
        .where((c) => c.type == type && c.name == name)
        .firstOrNull;
    if (c != null) return c;
    final n = Category(id: newId(), name: name, type: type, icon: icon, color: color);
    categories.add(n);
    return n;
  }

  /// Bangun ulang transaksi kas yang terhubung ke barang.
  void _syncItemTxns(Item it) {
    txns.removeWhere((t) => t.itemId == it.id);
    bool cash(String? id) => id != null && wallet(id) != null && !wallet(id)!.isAsset;
    if (cash(it.buyWalletId) && it.buyPrice > 0) {
      txns.add(Txn(
        id: newId(), itemId: it.id, type: TxType.transfer,
        amount: it.buyPrice, walletId: it.buyWalletId!, toWalletId: it.walletId,
        date: it.buyDate, note: 'Beli ${it.name}',
      ));
    }
    for (final c in it.costs) {
      if (cash(c.walletId) && c.amount > 0) {
        txns.add(Txn(
          id: newId(), itemId: it.id, type: TxType.transfer,
          amount: c.amount, walletId: c.walletId!, toWalletId: it.walletId,
          date: c.date, note: '${c.name.isEmpty ? 'Biaya' : c.name} • ${it.name}',
        ));
      }
    }
    if (it.sold && cash(it.sellWalletId)) {
      final date = it.sellDate ?? DateTime.now();
      // modal kembali ke kas
      txns.add(Txn(
        id: newId(), itemId: it.id, type: TxType.transfer,
        amount: it.totalCost, walletId: it.walletId, toWalletId: it.sellWalletId,
        date: date, note: 'Modal kembali • ${it.name}',
      ));
      // selisih = laba (pemasukan) atau rugi (pengeluaran)
      if (it.profit > 0) {
        final c = _ensureCategory('Laba Penjualan', TxType.income, 'business', 0xFF2E7D32);
        txns.add(Txn(
          id: newId(), itemId: it.id, type: TxType.income, amount: it.profit,
          categoryId: c.id, walletId: it.sellWalletId!, date: date,
          note: 'Laba jual ${it.name}',
        ));
      } else if (it.profit < 0) {
        final c = _ensureCategory('Rugi Penjualan', TxType.expense, 'debt', 0xFFC62828);
        txns.add(Txn(
          id: newId(), itemId: it.id, type: TxType.expense, amount: -it.profit,
          categoryId: c.id, walletId: it.sellWalletId!, date: date,
          note: 'Rugi jual ${it.name}',
        ));
      }
    }
  }

  Future<void> upsertItem(Item it) async {
    final i = items.indexWhere((e) => e.id == it.id);
    i >= 0 ? items[i] = it : items.add(it);
    _syncItemTxns(it);
    await _commit();
  }

  Future<void> deleteItem(String id) async {
    items.removeWhere((i) => i.id == id);
    txns.removeWhere((t) => t.itemId == id);
    await _commit();
  }

  /// Ringkasan dompet aset.
  ({int stockCount, int stockValue, int soldCount, int revenue, int profit, int potential})
      assetSummary(String walletId) {
    final list = itemsOf(walletId);
    final stock = list.where((i) => !i.sold);
    final sold = list.where((i) => i.sold);
    return (
      stockCount: stock.length,
      stockValue: stock.fold(0, (s, i) => s + i.totalCost),
      soldCount: sold.length,
      revenue: sold.fold(0, (s, i) => s + i.sellPrice),
      profit: sold.fold(0, (s, i) => s + i.profit),
      potential: stock.fold(0, (s, i) => s + i.potentialProfit),
    );
  }

  List<Txn> txnsIn(Period p, {String? walletId}) => txns
      .where((t) =>
          p.contains(t.date) &&
          (walletId == null ||
              t.walletId == walletId ||
              t.toWalletId == walletId))
      .toList();

  int sumOf(Iterable<Txn> list, TxType type) => list
      .where((t) => t.type == type)
      .fold(0, (s, t) => s + t.amount);

  Period get currentPeriod => Period.cycle(DateTime.now(), cycleStartDay);

  /// Transaksi unik terakhir (kategori+catatan+nominal) untuk input ulang cepat.
  List<Txn> recentTemplates(TxType type, {int limit = 8}) {
    final seen = <String>{};
    final out = <Txn>[];
    for (final t in txns) {
      if (t.type != type) continue;
      final key = '${t.categoryId}|${t.note.trim().toLowerCase()}|${t.amount}';
      if (seen.add(key)) out.add(t);
      if (out.length >= limit) break;
    }
    return out;
  }

  List<String> noteSuggestions(String query, {String? categoryId}) {
    final q = query.trim().toLowerCase();
    final seen = <String>{};
    final res = <String>[];
    for (final t in txns) {
      final n = t.note.trim();
      if (n.isEmpty) continue;
      if (categoryId != null && t.categoryId != categoryId && q.isEmpty) {
        continue;
      }
      if (q.isNotEmpty && !n.toLowerCase().contains(q)) continue;
      if (seen.add(n.toLowerCase())) res.add(n);
      if (res.length >= 6) break;
    }
    return res;
  }

  // ---------- mutasi transaksi ----------
  Future<void> upsertTxn(Txn t) async {
    final i = txns.indexWhere((e) => e.id == t.id);
    if (i >= 0) {
      txns[i] = t;
    } else {
      txns.add(t);
    }
    if (t.type == TxType.expense) lastExpenseCategoryId = t.categoryId;
    if (t.type == TxType.income) lastIncomeCategoryId = t.categoryId;
    lastWalletId = t.walletId;
    await _commit();
  }

  Future<void> deleteTxn(String id) async {
    txns.removeWhere((t) => t.id == id);
    await _commit();
  }

  // ---------- dompet ----------
  Future<void> upsertWallet(Wallet w) async {
    final i = wallets.indexWhere((e) => e.id == w.id);
    i >= 0 ? wallets[i] = w : wallets.add(w);
    await _commit();
  }

  bool walletInUse(String id) =>
      txns.any((t) => t.walletId == id || t.toWalletId == id) ||
      items.any((i) => i.walletId == id);

  Future<void> deleteWallet(String id) async {
    final itemIds = items.where((i) => i.walletId == id).map((i) => i.id).toSet();
    items.removeWhere((i) => i.walletId == id);
    txns.removeWhere((t) =>
        t.walletId == id || t.toWalletId == id || itemIds.contains(t.itemId));
    // barang di dompet aset lain yang memakai dompet ini sebagai sumber/tujuan
    for (final it in items) {
      if (it.buyWalletId == id) it.buyWalletId = null;
      if (it.sellWalletId == id) it.sellWalletId = null;
      for (final c in it.costs) {
        if (c.walletId == id) c.walletId = null;
      }
    }
    wallets.removeWhere((w) => w.id == id);
    await _commit();
  }

  // ---------- kategori ----------
  Future<void> upsertCategory(Category c) async {
    final i = categories.indexWhere((e) => e.id == c.id);
    i >= 0 ? categories[i] = c : categories.add(c);
    await _commit();
  }

  int categoryUsage(String id) => txns.where((t) => t.categoryId == id).length;

  /// Hapus kategori; transaksinya dipindah ke [moveTo] (jika ada).
  Future<void> deleteCategory(String id, {String? moveTo}) async {
    for (final t in txns.where((t) => t.categoryId == id)) {
      t.categoryId = moveTo;
    }
    categories.removeWhere((c) => c.id == id);
    await _commit();
  }

  // ---------- pengaturan ----------
  Future<void> setCycleStartDay(int d) async {
    cycleStartDay = d.clamp(1, 28);
    await _commit();
  }

  Future<void> toggleHideBalance() async {
    hideBalance = !hideBalance;
    await _commit();
  }

  Future<void> resetAll() async {
    _seed();
    lastExpenseCategoryId = null;
    lastIncomeCategoryId = null;
    lastWalletId = null;
    await _commit();
  }

  // ---------- keamanan ----------
  String _hash(String pin) =>
      sha256.convert(utf8.encode('$_pinSalt:$pin')).toString();

  bool verifyPin(String pin) => _pinHash != null && _hash(pin) == _pinHash;

  Future<void> setPin(String? pin) async {
    if (pin == null) {
      _pinHash = null;
      biometricEnabled = false;
    } else {
      final r = Random.secure();
      _pinSalt = base64Url.encode(List.generate(16, (_) => r.nextInt(256)));
      _pinHash = _hash(pin);
    }
    await _saveSecurity();
    notifyListeners();
  }

  Future<void> setBiometric(bool v) async {
    biometricEnabled = v;
    await _saveSecurity();
    notifyListeners();
  }

  Future<void> _saveSecurity() => _prefs.setString(
      _kSecurity,
      jsonEncode({
        'pinHash': _pinHash,
        'pinSalt': _pinSalt,
        'biometric': biometricEnabled,
      }));
}
