import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, ValueNotifier;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'format.dart';
import 'models.dart';
import 'storage.dart';

const _uuid = Uuid();
const kDefaultThemeColor = 0xFF0F766E;
String newId() => _uuid.v4();

/// Penyimpanan lokal (offline) seluruh data aplikasi.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore I = AppStore._();

  /// Format lama (satu blok JSON di SharedPreferences) — dimigrasi otomatis.
  static const _kLegacyData = 'finfree_data_v1';
  static const _kSecurity = 'finfree_security_v1';

  /// Diganti ke [SqliteBackend] oleh main(); test memakai [PrefsBackend].
  DataBackend backend = PrefsBackend();
  late SharedPreferences _prefs;
  Rows _saved = {};

  List<Wallet> wallets = [];
  List<Category> categories = [];
  List<Txn> txns = [];
  List<Item> items = [];
  List<Debt> debts = [];
  List<Recurring> recurrings = [];

  // pengaturan
  int cycleStartDay = 1;
  bool hideBalance = false;
  String? lastExpenseCategoryId;
  String? lastIncomeCategoryId;
  String? lastWalletId;
  DateTime? lastBackupAt;

  /// Tampilan: warna tema & mode terang/gelap ('system' | 'light' | 'dark').
  /// Dipisah sebagai notifier sendiri agar MaterialApp hanya rebuild saat
  /// tema berubah, bukan setiap ada transaksi baru.
  final themeColor = ValueNotifier<int>(kDefaultThemeColor);
  final themeMode = ValueNotifier<String>('system');

  // keamanan
  String? _pinHash;
  String _pinSalt = '';
  bool biometricEnabled = false;

  bool get hasPin => _pinHash != null;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final rows = await backend.readAll();
    _saved = {};
    if (rows.values.any((m) => m.isNotEmpty)) {
      _fromRows(rows);
      _saved = rows;
    } else {
      final legacy = _prefs.getString(_kLegacyData);
      if (legacy != null) {
        // pindahkan data format lama ke penyimpanan baru
        _fromJson(jsonDecode(legacy) as Map<String, dynamic>, notify: false);
      } else {
        _seed();
      }
      await _save();
      if (legacy != null) await _prefs.remove(_kLegacyData);
    }
    if (_runRecurring()) await _save();
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
    debts = [];
    recurrings = [];
  }

  // ---------- persistensi ----------
  Map<String, dynamic> _settingsJson() => {
        'cycleStartDay': cycleStartDay,
        'hideBalance': hideBalance,
        'lastExpenseCategoryId': lastExpenseCategoryId,
        'lastIncomeCategoryId': lastIncomeCategoryId,
        'lastWalletId': lastWalletId,
        'lastBackupAt': lastBackupAt?.toIso8601String(),
        'themeColor': themeColor.value,
        'themeMode': themeMode.value,
      };

  void _applySettings(Map<String, dynamic> s) {
    cycleStartDay = s['cycleStartDay'] ?? 1;
    hideBalance = s['hideBalance'] ?? false;
    lastExpenseCategoryId = s['lastExpenseCategoryId'];
    lastIncomeCategoryId = s['lastIncomeCategoryId'];
    lastWalletId = s['lastWalletId'];
    lastBackupAt = s['lastBackupAt'] != null
        ? DateTime.tryParse(s['lastBackupAt'])
        : null;
    themeColor.value = s['themeColor'] ?? kDefaultThemeColor;
    themeMode.value = s['themeMode'] ?? 'system';
  }

  /// Format cadangan (dan format lama): satu objek JSON berisi semuanya.
  Map<String, dynamic> _toJson() => {
        'app': 'finfree',
        'version': 2,
        'exportedAt': DateTime.now().toIso8601String(),
        'wallets': wallets.map((e) => e.toJson()).toList(),
        'categories': categories.map((e) => e.toJson()).toList(),
        'txns': txns.map((e) => e.toJson()).toList(),
        'items': items.map((e) => e.toJson()).toList(),
        'debts': debts.map((e) => e.toJson()).toList(),
        'recurrings': recurrings.map((e) => e.toJson()).toList(),
        'settings': _settingsJson(),
      };

  void _fromJson(Map<String, dynamic> j, {bool notify = true}) {
    // parse dulu semuanya; bila ada yang rusak, data lama tidak tersentuh
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] ?? []) as List).map((e) => f(e as Map<String, dynamic>)).toList();
    final w = list('wallets', Wallet.fromJson);
    final c = list('categories', Category.fromJson);
    final t = list('txns', Txn.fromJson);
    final it = list('items', Item.fromJson);
    final d = list('debts', Debt.fromJson);
    final r = list('recurrings', Recurring.fromJson);
    if (w.isEmpty) throw const FormatException('Tidak ada dompet');
    wallets = w;
    categories = c;
    txns = t;
    items = it;
    debts = d;
    recurrings = r;
    _applySettings(
        (j['settings'] ?? <String, dynamic>{}) as Map<String, dynamic>);
    _sortTxns();
    if (notify) notifyListeners();
  }

  static const _collections = [
    'wallets', 'categories', 'txns', 'items', 'debts', 'recurrings'
  ];

  Rows _snapshot() {
    Map<String, String> enc<T>(List<T> l, String Function(T) id,
            Map<String, dynamic> Function(T) js) =>
        {for (final e in l) id(e): jsonEncode(js(e))};
    return {
      'wallets': enc(wallets, (e) => e.id, (e) => e.toJson()),
      'categories': enc(categories, (e) => e.id, (e) => e.toJson()),
      'txns': enc(txns, (e) => e.id, (e) => e.toJson()),
      'items': enc(items, (e) => e.id, (e) => e.toJson()),
      'debts': enc(debts, (e) => e.id, (e) => e.toJson()),
      'recurrings': enc(recurrings, (e) => e.id, (e) => e.toJson()),
      'meta': {'settings': jsonEncode(_settingsJson())},
    };
  }

  void _fromRows(Rows rows) {
    List<T> dec<T>(String coll, T Function(Map<String, dynamic>) f) =>
        (rows[coll] ?? {}).values.map((s) => f(jsonDecode(s))).toList();
    wallets = dec('wallets', Wallet.fromJson);
    categories = dec('categories', Category.fromJson);
    txns = dec('txns', Txn.fromJson);
    items = dec('items', Item.fromJson);
    debts = dec('debts', Debt.fromJson);
    recurrings = dec('recurrings', Recurring.fromJson);
    final s = rows['meta']?['settings'];
    _applySettings(s != null ? jsonDecode(s) : <String, dynamic>{});
    _sortTxns();
  }

  /// Tulis hanya baris yang berubah sejak penyimpanan terakhir.
  /// Selisih dihitung seketika (sinkron) sehingga urutan tulis selalu
  /// sesuai urutan perubahan; backend menjalankannya berurutan (FIFO).
  Future<void> _save() {
    final now = _snapshot();
    final changes = <String, Map<String, String?>>{};
    for (final coll in {..._collections, 'meta', ..._saved.keys}) {
      final a = _saved[coll] ?? const {}, b = now[coll] ?? const {};
      final ch = <String, String?>{};
      b.forEach((id, js) {
        if (a[id] != js) ch[id] = js;
      });
      for (final id in a.keys) {
        if (!b.containsKey(id)) ch[id] = null;
      }
      if (ch.isNotEmpty) changes[coll] = ch;
    }
    _saved = now;
    if (changes.isEmpty) return Future.value();
    return backend.apply(changes);
  }

  Future<void> _commit() async {
    _sortTxns();
    notifyListeners();
    await _save();
  }

  void _sortTxns() => txns.sort((a, b) => b.date.compareTo(a.date));

  // ---------- cadangan (file lokal, tanpa internet) ----------
  /// Lokasi folder foto (diisi di main(); null saat test).
  static String? photoPath;

  static Future<Directory> photoDir() async {
    final d = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/photos');
    if (!d.existsSync()) d.createSync(recursive: true);
    photoPath = d.path;
    return d;
  }

  /// Isi file cadangan (JSON). Foto barang ikut disertakan.
  Future<String> exportBackup() async {
    final j = _toJson();
    final names = {for (final i in items) ...i.photos};
    if (names.isNotEmpty) {
      final dir = await photoDir();
      j['photos'] = {
        for (final n in names)
          if (File('${dir.path}/$n').existsSync())
            n: base64Encode(File('${dir.path}/$n').readAsBytesSync()),
      };
    }
    return jsonEncode(j);
  }

  Future<void> markBackedUp() async {
    lastBackupAt = DateTime.now();
    await _commit();
  }

  /// Ringkasan isi file cadangan (untuk konfirmasi sebelum dipulihkan).
  static ({int txns, int items, DateTime? at}) inspectBackup(String raw) {
    final j = jsonDecode(raw);
    if (j is! Map<String, dynamic> || j['app'] != 'finfree') {
      throw const FormatException('Bukan file cadangan FinFree');
    }
    return (
      txns: (j['txns'] as List? ?? []).length,
      items: (j['items'] as List? ?? []).length,
      at: DateTime.tryParse(j['exportedAt'] ?? ''),
    );
  }

  /// Ganti seluruh data dengan isi file cadangan.
  Future<void> importBackup(String raw) async {
    inspectBackup(raw);
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final theme = (themeColor.value, themeMode.value);
    _fromJson(j, notify: false);
    final photos = (j['photos'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    if (photos.isNotEmpty) {
      final dir = await photoDir();
      photos.forEach((n, b64) =>
          File('${dir.path}/$n').writeAsBytesSync(base64Decode(b64)));
    }
    if (j['settings']?['themeColor'] == null) {
      themeColor.value = theme.$1;
      themeMode.value = theme.$2;
    }
    final snap = _snapshot();
    await backend.replaceAll(snap);
    _saved = snap;
    notifyListeners();
  }

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

  // ---------- anggaran ----------
  List<Category> get budgetCategories => categories
      .where((c) => c.budget > 0 && c.usableFor(TxType.expense))
      .toList();

  /// Pengeluaran kategori pada periode (untuk anggaran).
  int spentIn(Period p, String catId) => txns
      .where((t) =>
          t.type == TxType.expense &&
          t.categoryId == catId &&
          p.contains(t.date))
      .fold(0, (s, t) => s + t.amount);

  // ---------- barang dagangan ----------
  List<Item> itemsOf(String walletId) =>
      items.where((i) => i.walletId == walletId).toList()
        ..sort((a, b) => (b.sellDate ?? b.buyDate).compareTo(a.sellDate ?? a.buyDate));

  Item? item(String? id) => items.where((i) => i.id == id).firstOrNull;

  Category _ensureCategory(String name, TxType type, String icon, int color) {
    final c = categories
        .where((c) => c.usableFor(type) && c.name == name)
        .firstOrNull;
    if (c != null) return c;
    final n = Category(id: newId(), name: name, type: type, icon: icon, color: color);
    categories.add(n);
    return n;
  }

  bool _isCash(String? id) =>
      id != null && id.isNotEmpty && wallet(id) != null && !wallet(id)!.isAsset;

  /// Bangun ulang transaksi kas yang terhubung ke barang.
  void _syncItemTxns(Item it) {
    txns.removeWhere((t) => t.itemId == it.id);
    final label = it.qty > 1 ? '${it.name} ×${it.qty}' : it.name;
    if (_isCash(it.buyWalletId) && it.buyPrice > 0) {
      txns.add(Txn(
        id: newId(), itemId: it.id, type: TxType.transfer,
        amount: it.buyPrice, walletId: it.buyWalletId!, toWalletId: it.walletId,
        date: it.buyDate, note: 'Beli $label',
      ));
    }
    for (final c in it.costs) {
      if (_isCash(c.walletId) && c.amount > 0) {
        txns.add(Txn(
          id: newId(), itemId: it.id, type: TxType.transfer,
          amount: c.amount, walletId: c.walletId!, toWalletId: it.walletId,
          date: c.date, note: '${c.name.isEmpty ? 'Biaya' : c.name} • $label',
        ));
      }
    }
    if (it.sold && _isCash(it.sellWalletId)) {
      final date = it.sellDate ?? DateTime.now();
      // modal kembali ke kas. Bila tukar tambah, sebagian "pembayaran" berupa
      // barang (masuk ke stok), jadi uang kas yang kembali berkurang sebesar
      // nilai barang itu — bisa juga negatif (saya yang menambah uang).
      final back = it.totalCost - it.tradeInValue;
      if (back > 0) {
        txns.add(Txn(
          id: newId(), itemId: it.id, type: TxType.transfer,
          amount: back, walletId: it.walletId, toWalletId: it.sellWalletId,
          date: date,
          note: it.tradeInValue > 0
              ? 'Modal kembali (tukar tambah) • $label'
              : 'Modal kembali • $label',
        ));
      } else if (back < 0) {
        txns.add(Txn(
          id: newId(), itemId: it.id, type: TxType.transfer,
          amount: -back, walletId: it.sellWalletId!, toWalletId: it.walletId,
          date: date, note: 'Tambah uang tukar tambah • $label',
        ));
      }
      // selisih = laba (pemasukan) atau rugi (pengeluaran)
      if (it.profit > 0) {
        final c = _ensureCategory('Laba Penjualan', TxType.income, 'business', 0xFF2E7D32);
        txns.add(Txn(
          id: newId(), itemId: it.id, type: TxType.income, amount: it.profit,
          categoryId: c.id, walletId: it.sellWalletId!, date: date,
          note: 'Laba jual $label',
        ));
      } else if (it.profit < 0) {
        final c = _ensureCategory('Rugi Penjualan', TxType.expense, 'debt', 0xFFC62828);
        txns.add(Txn(
          id: newId(), itemId: it.id, type: TxType.expense, amount: -it.profit,
          categoryId: c.id, walletId: it.sellWalletId!, date: date,
          note: 'Rugi jual $label',
        ));
      }
    }
  }

  Future<void> upsertItem(Item it) async {
    final i = items.indexWhere((e) => e.id == it.id);
    i >= 0 ? items[i] = it : items.add(it);
    // barang hasil tukar tambah: modalnya = nilai tukar, tidak memotong kas.
    // Bila nilainya dikoreksi, uang yang diterima tetap → harga jual barang
    // asal ikut menyesuaikan.
    final from = tradeSource(it);
    if (from != null) {
      it.buyWalletId = null;
      // (tidak berlaku bila barang tukar ini sudah dipecah karena jual sebagian)
      final split = items.where((x) => x.tradeFromId == from.id).length > 1;
      if (!split && from.tradeInValue != it.buyPrice) {
        from.sellPrice += it.buyPrice - from.tradeInValue;
        from.tradeInValue = it.buyPrice;
        _syncItemTxns(from);
      }
    }
    _syncItemTxns(it);
    await _commit();
  }

  /// Barang yang dijual dengan cara ditukar dengan [it] (bila [it] masuk
  /// dari tukar tambah).
  Item? tradeSource(Item it) {
    final f = item(it.tradeFromId);
    return f != null && f.sold && f.tradeInId == it.id ? f : null;
  }

  /// Barang yang diterima saat [it] dijual (tukar tambah).
  Item? tradeIn(Item it) {
    final t = item(it.tradeInId);
    return t != null && t.tradeFromId == it.id ? t : null;
  }

  /// Batalkan penjualan: barang kembali ke stok. Barang tukar tambah yang
  /// diterima ikut dihapus. Gagal (false) bila barang tukar itu sudah dijual.
  Future<bool> cancelSale(Item it) async {
    final got = it.tradeInId == null
        ? <Item>[]
        : items.where((i) => i.tradeFromId == it.id).toList();
    if (got.any((t) => t.sold)) return false;
    for (final t in got) {
      items.removeWhere((i) => i.id == t.id);
      txns.removeWhere((x) => x.itemId == t.id);
    }
    for (final ph in got.expand((t) => t.photos).toSet()) {
      await deletePhotoIfUnused(ph);
    }
    it
      ..sold = false
      ..sellPrice = 0
      ..sellDate = null
      ..sellWalletId = null
      ..buyer = ''
      ..tradeInId = null
      ..tradeInValue = 0;
    await upsertItem(it);
    return true;
  }

  /// Jual [qty] unit dari barang. Bila sebagian, barang dipecah: bagian yang
  /// terjual jadi catatan sendiri (modal & biaya dibagi proporsional), sisanya
  /// tetap di stok. [price] = total harga jual untuk unit yang terjual.
  Future<Item> sellItem(Item it,
      {required int qty,
      required int price,
      required DateTime date,
      String? walletId,
      String buyer = '',
      Item? tradeIn}) async {
    if (qty >= it.qty) {
      it
        ..sold = true
        ..sellPrice = price
        ..sellDate = date
        ..sellWalletId = walletId
        ..buyer = buyer;
      _attachTradeIn(it, tradeIn);
      await upsertItem(it);
      return it;
    }
    final f = qty / it.qty;
    final part = Item(
      id: newId(),
      walletId: it.walletId,
      name: it.name,
      detail: it.detail,
      buyPrice: (it.buyPrice * f).round(),
      buyDate: it.buyDate,
      buyWalletId: it.buyWalletId,
      supplier: it.supplier,
      costs: [
        for (final c in it.costs)
          ItemCost(
              id: newId(),
              name: c.name,
              amount: (c.amount * f).round(),
              date: c.date,
              walletId: c.walletId),
      ],
      targetPrice: (it.targetPrice * f).round(),
      qty: qty,
      sold: true,
      sellPrice: price,
      sellDate: date,
      sellWalletId: walletId,
      buyer: buyer,
      photos: List.of(it.photos),
      tradeFromId: it.tradeFromId,
      phone: it.phone?.copy(),
    );
    it.buyPrice -= part.buyPrice;
    for (var i = 0; i < it.costs.length; i++) {
      it.costs[i].amount -= part.costs[i].amount;
    }
    it.targetPrice -= part.targetPrice;
    it.qty -= qty;
    items.add(part);
    _attachTradeIn(part, tradeIn);
    _syncItemTxns(it);
    _syncItemTxns(part);
    await _commit();
    return part;
  }

  /// Barang yang diterima saat tukar tambah masuk ke stok (modal = nilai
  /// tukarnya, tanpa memotong kas — "dibayar" dengan barang yang dijual).
  void _attachTradeIn(Item sold, Item? t) {
    if (t == null || t.buyPrice <= 0) return;
    t
      ..buyDate = sold.sellDate ?? DateTime.now()
      ..buyWalletId = null
      ..supplier = t.supplier.isEmpty ? sold.buyer : t.supplier
      ..tradeFromId = sold.id;
    sold
      ..tradeInId = t.id
      ..tradeInValue = t.buyPrice;
    items.add(t);
    _syncItemTxns(t);
  }

  Future<void> deleteItem(String id) async {
    final it = item(id);
    // barang tukar yang pernah diterima tetap di stok (sudah jadi milik saya)
    for (final x in items.where((x) => x.tradeFromId == id)) {
      x.tradeFromId = null;
    }
    items.removeWhere((i) => i.id == id);
    txns.removeWhere((t) => t.itemId == id);
    for (final ph in it?.photos ?? const <String>[]) {
      await deletePhotoIfUnused(ph);
    }
    await _commit();
  }

  /// Hapus file foto bila tidak dipakai barang lain (barang hasil pecahan
  /// jual sebagian berbagi foto yang sama).
  Future<void> deletePhotoIfUnused(String name) async {
    if (items.any((i) => i.photos.contains(name))) return;
    try {
      final f = File('${(await photoDir()).path}/$name');
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  /// Riwayat keluar-masuk barang di dompet aset, terbaru dulu.
  /// Barang hasil pecahan jual sebagian digabung kembali jadi satu baris masuk.
  List<StockMove> stockMoves(String walletId) {
    final list = itemsOf(walletId);
    final ins = <String, StockMove>{};
    for (final i in list) {
      final key = '${i.name}|${i.buyDate.toIso8601String()}|${i.supplier}|'
          '${i.tradeFromId ?? ''}';
      final from = item(i.tradeFromId);
      final m = ins[key];
      if (m == null) {
        ins[key] = StockMove(
          inbound: true, date: i.buyDate, itemId: i.id, name: i.name,
          qty: i.qty, value: i.buyPrice, party: i.supplier,
          walletId: i.buyWalletId,
          via: from != null ? 'Tukar tambah dari ${from.name}' : null,
        );
      } else {
        ins[key] = m.add(i.qty, i.buyPrice);
      }
    }
    final outs = list.where((i) => i.sold).map((i) {
      final t = tradeIn(i);
      return StockMove(
        inbound: false, date: i.sellDate ?? i.buyDate, itemId: i.id,
        name: i.name, qty: i.qty, value: i.sellPrice, party: i.buyer,
        profit: i.profit, walletId: i.sellWalletId,
        cash: i.cashReceived,
        via: t != null ? 'Ditukar dengan ${t.name}' : null,
      );
    });
    return [...ins.values, ...outs]
      ..sort((a, b) {
        final c = b.date.compareTo(a.date);
        // di hari yang sama, keluar ditampilkan setelah masuk-nya (tukar tambah)
        return c != 0 ? c : (a.inbound ? -1 : 1);
      });
  }

  /// Ringkasan jual-beli aset + pemasukan/pengeluaran lain pada periode.
  FlowSummary flowSummary(Period p) {
    var buy = 0, buyUnits = 0, tradeIn = 0, tradeInUnits = 0, costs = 0;
    var sales = 0, salesUnits = 0, cogs = 0, profit = 0, tradeOut = 0;
    for (final i in items) {
      if (p.contains(i.buyDate)) {
        if (i.tradeFromId != null) {
          tradeIn += i.buyPrice;
          tradeInUnits += i.qty;
        } else {
          buy += i.buyPrice;
          buyUnits += i.qty;
        }
      }
      for (final c in i.costs) {
        if (p.contains(c.date)) costs += c.amount;
      }
      if (i.sold && i.sellDate != null && p.contains(i.sellDate!)) {
        sales += i.sellPrice;
        salesUnits += i.qty;
        cogs += i.totalCost;
        profit += i.profit;
        tradeOut += i.tradeInValue;
      }
    }
    var otherIn = 0, otherOut = 0;
    for (final t in txns) {
      if (t.itemId != null || t.debtId != null || !p.contains(t.date)) continue;
      if (t.type == TxType.income) otherIn += t.amount;
      if (t.type == TxType.expense) otherOut += t.amount;
    }
    return FlowSummary(
      buy: buy, buyUnits: buyUnits, tradeIn: tradeIn,
      tradeInUnits: tradeInUnits, costs: costs, sales: sales,
      salesUnits: salesUnits, tradePaid: tradeOut, cogs: cogs, profit: profit,
      otherIn: otherIn, otherOut: otherOut,
    );
  }

  /// Ringkasan dompet aset.
  ({int stockCount, int stockValue, int soldCount, int revenue, int profit, int potential})
      assetSummary(String walletId) {
    final list = itemsOf(walletId);
    final stock = list.where((i) => !i.sold);
    final sold = list.where((i) => i.sold);
    return (
      stockCount: stock.fold(0, (s, i) => s + i.qty),
      stockValue: stock.fold(0, (s, i) => s + i.totalCost),
      soldCount: sold.fold(0, (s, i) => s + i.qty),
      revenue: sold.fold(0, (s, i) => s + i.sellPrice),
      profit: sold.fold(0, (s, i) => s + i.profit),
      potential: stock.fold(0, (s, i) => s + i.potentialProfit),
    );
  }

  // ---------- utang & piutang ----------
  Debt? debt(String? id) => debts.where((d) => d.id == id).firstOrNull;

  /// Total sisa piutang (orang berutang ke saya) & utang (saya berutang).
  int get totalReceivable => debts
      .where((d) => d.isReceivable && !d.settled)
      .fold(0, (s, d) => s + d.remaining);
  int get totalPayable => debts
      .where((d) => !d.isReceivable && !d.settled)
      .fold(0, (s, d) => s + d.remaining);

  /// Transaksi kas otomatis dari utang/piutang. Memakai tipe transfer
  /// dengan satu sisi kosong ('' / null), jadi saldo dompet berubah tapi
  /// TIDAK dihitung sebagai pemasukan/pengeluaran di laporan.
  void _syncDebtTxns(Debt d) {
    txns.removeWhere((t) => t.debtId == d.id);
    final recv = d.isReceivable;
    void move(int amount, String w, DateTime date, String note,
        {required bool out}) {
      if (amount <= 0) return;
      txns.add(Txn(
        id: newId(), debtId: d.id, type: TxType.transfer, amount: amount,
        walletId: out ? w : '', toWalletId: out ? null : w,
        date: date, note: note,
      ));
    }

    if (_isCash(d.walletId)) {
      move(d.amount, d.walletId!, d.date,
          recv ? 'Pinjamkan ke ${d.person}' : 'Pinjam dari ${d.person}',
          out: recv);
    }
    for (final p in d.payments) {
      if (_isCash(p.walletId)) {
        move(p.amount, p.walletId!, p.date,
            recv ? 'Terima cicilan ${d.person}' : 'Bayar utang ke ${d.person}',
            out: !recv);
      }
    }
  }

  Future<void> upsertDebt(Debt d) async {
    final i = debts.indexWhere((e) => e.id == d.id);
    i >= 0 ? debts[i] = d : debts.add(d);
    _syncDebtTxns(d);
    await _commit();
  }

  Future<void> deleteDebt(String id) async {
    debts.removeWhere((d) => d.id == id);
    txns.removeWhere((t) => t.debtId == id);
    await _commit();
  }

  // ---------- transaksi rutin ----------
  Recurring? recurring(String? id) =>
      recurrings.where((r) => r.id == id).firstOrNull;

  /// Catat semua transaksi rutin yang sudah jatuh tempo (termasuk yang
  /// terlewat saat aplikasi tidak dibuka).
  bool _runRecurring([DateTime? now]) {
    now ??= DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var changed = false;
    for (final r in recurrings.where((r) => r.active)) {
      for (final d in r.dueDates(today)) {
        txns.add(Txn(
          id: newId(), recurringId: r.id, type: r.type, amount: r.amount,
          categoryId: r.categoryId, walletId: r.walletId,
          toWalletId: r.toWalletId, note: r.note,
          date: DateTime(d.year, d.month, d.day, 8),
        ));
        r.lastRun = d;
        changed = true;
      }
    }
    if (changed) _sortTxns();
    return changed;
  }

  /// Dipanggil saat aplikasi dibuka kembali (mis. besok paginya).
  Future<void> runRecurringNow([DateTime? now]) async {
    if (_runRecurring(now)) await _commit();
  }

  Future<void> upsertRecurring(Recurring r) async {
    final i = recurrings.indexWhere((e) => e.id == r.id);
    i >= 0 ? recurrings[i] = r : recurrings.add(r);
    _runRecurring();
    await _commit();
  }

  /// Hapus aturan rutin; transaksi yang sudah tercatat tetap ada.
  Future<void> deleteRecurring(String id) async {
    recurrings.removeWhere((r) => r.id == id);
    for (final t in txns.where((t) => t.recurringId == id)) {
      t.recurringId = null;
    }
    await _commit();
  }

  // ---------- query ----------
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
      if (t.type != type || t.isLinked) continue;
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
    for (final d in debts) {
      if (d.walletId == id) d.walletId = null;
      for (final p in d.payments) {
        if (p.walletId == id) p.walletId = null;
      }
    }
    recurrings.removeWhere((r) => r.walletId == id || r.toWalletId == id);
    wallets.removeWhere((w) => w.id == id);
    await _commit();
  }

  // ---------- kategori ----------
  Future<void> upsertCategory(Category c) async {
    final i = categories.indexWhere((e) => e.id == c.id);
    i >= 0 ? categories[i] = c : categories.add(c);
    await _commit();
  }

  /// Gabungkan [otherId] ke [keepId] jadi satu kategori "masuk & keluar".
  /// Transaksi, anggaran & transaksi rutinnya ikut pindah.
  Future<void> mergeCategories(String keepId, String otherId) async {
    final keep = category(keepId), other = category(otherId);
    if (keep == null || other == null || keepId == otherId) return;
    keep.both = true;
    if (keep.budget == 0) keep.budget = other.budget;
    for (final t in txns) {
      if (t.categoryId == otherId) t.categoryId = keepId;
    }
    for (final r in recurrings) {
      if (r.categoryId == otherId) r.categoryId = keepId;
    }
    if (lastExpenseCategoryId == otherId) lastExpenseCategoryId = keepId;
    if (lastIncomeCategoryId == otherId) lastIncomeCategoryId = keepId;
    categories.removeWhere((e) => e.id == otherId);
    await _commit();
  }

  /// Kategori bernama sama di sisi lain (calon digabung).
  Category? sameNameOther(String name, TxType type, {String? exceptId}) {
    final key = name.trim().toLowerCase();
    if (key.isEmpty || key == 'lainnya') return null;
    return categories
        .where((c) =>
            c.id != exceptId &&
            c.name.trim().toLowerCase() == key &&
            (c.both || c.type != type))
        .firstOrNull;
  }

  /// Jumlah transaksi kategori; [type] untuk menghitung satu sisi saja
  /// (berguna untuk kategori "masuk & keluar").
  int categoryUsage(String id, {TxType? type}) => txns
      .where((t) => t.categoryId == id && (type == null || t.type == type))
      .length;

  /// Hapus kategori; transaksinya dipindah ke [moveTo] (jika ada).
  Future<void> deleteCategory(String id, {String? moveTo}) async {
    for (final t in txns.where((t) => t.categoryId == id)) {
      t.categoryId = moveTo;
    }
    for (final r in recurrings.where((r) => r.categoryId == id)) {
      r.categoryId = moveTo;
    }
    categories.removeWhere((c) => c.id == id);
    await _commit();
  }

  // ---------- pengaturan ----------
  Future<void> setCycleStartDay(int d) async {
    cycleStartDay = d.clamp(1, 28);
    await _commit();
  }

  Future<void> setThemeColor(int c) async {
    themeColor.value = c;
    await _save();
  }

  Future<void> setThemeMode(String m) async {
    themeMode.value = m;
    await _save();
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

/// Satu baris riwayat keluar-masuk barang.
class StockMove {
  final bool inbound; // true = barang masuk (beli / terima tukar)
  final DateTime date;
  final String itemId;
  final String name;
  final int qty;
  final int value; // masuk: modal beli; keluar: harga jual
  final String party; // pemasok / pembeli
  final String? via; // keterangan tukar tambah
  final int profit;
  final String? walletId; // dompet uang: sumber modal / tujuan hasil jual
  final int? cash; // keluar: uang yang benar-benar diterima
  const StockMove({
    required this.inbound,
    required this.date,
    required this.itemId,
    required this.name,
    required this.qty,
    required this.value,
    this.party = '',
    this.via,
    this.profit = 0,
    this.walletId,
    this.cash,
  });

  StockMove add(int q, int v) => StockMove(
      inbound: inbound, date: date, itemId: itemId, name: name,
      qty: qty + q, value: value + v, party: party, via: via, profit: profit,
      walletId: walletId, cash: cash);
}

/// Ringkasan arus jual-beli aset & pemasukan/pengeluaran lain.
class FlowSummary {
  final int buy; // nilai pembelian barang (dibayar uang)
  final int buyUnits;
  final int tradeIn; // nilai barang masuk dari tukar tambah
  final int tradeInUnits;
  final int costs; // biaya barang: servis, ongkir, dll
  final int sales; // omzet penjualan (termasuk nilai barang tukar)
  final int salesUnits;
  final int tradePaid; // bagian omzet yang dibayar dengan barang
  final int cogs; // modal barang yang terjual
  final int profit; // laba/rugi kotor jual-beli
  final int otherIn; // pemasukan di luar jual-beli
  final int otherOut; // pengeluaran di luar jual-beli
  const FlowSummary({
    required this.buy,
    required this.buyUnits,
    required this.tradeIn,
    required this.tradeInUnits,
    required this.costs,
    required this.sales,
    required this.salesUnits,
    required this.tradePaid,
    required this.cogs,
    required this.profit,
    required this.otherIn,
    required this.otherOut,
  });

  bool get hasTrade =>
      buy + tradeIn + costs + sales > 0 || buyUnits + salesUnits > 0;

  /// Aset masuk (beli + tukar) & aset keluar (terjual, nilai jual).
  int get assetIn => buy + tradeIn;
  int get assetInUnits => buyUnits + tradeInUnits;

  /// Total perputaran jual-beli = semua pembelian + biaya + penjualan.
  int get turnover => buy + tradeIn + costs + sales;

  /// Total masuk/keluar gabungan (jual-beli + lain-lain).
  int get totalIn => sales + otherIn;
  int get totalOut => buy + tradeIn + costs + otherOut;

  /// Laba bersih = laba jual-beli + pemasukan lain − pengeluaran lain.
  int get netProfit => profit + otherIn - otherOut;
}
