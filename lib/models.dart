enum TxType { expense, income, transfer }

TxType txTypeFrom(String s) =>
    TxType.values.firstWhere((e) => e.name == s, orElse: () => TxType.expense);

class Wallet {
  final String id;
  String name;
  String icon;
  int color;
  int initialBalance;

  /// 'cash' = dompet uang biasa, 'asset' = dompet aset/dagangan (berisi barang).
  String kind;

  bool get isAsset => kind == 'asset';

  Wallet({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.initialBalance = 0,
    this.kind = 'cash',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'initialBalance': initialBalance,
        'kind': kind,
      };

  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
        id: j['id'],
        name: j['name'],
        icon: j['icon'] ?? 'wallet',
        color: j['color'] ?? 0xFF00897B,
        initialBalance: (j['initialBalance'] ?? 0) as int,
        kind: j['kind'] ?? 'cash',
      );
}

class Category {
  final String id;
  String name;
  TxType type; // expense / income
  String icon;
  int color;

  /// true = bisa dipakai untuk pemasukan DAN pengeluaran, sehingga
  /// untung/rugi (masuk - keluar) kategori ini bisa dihitung.
  bool both;

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.both = false,
  });

  bool usableFor(TxType t) => t != TxType.transfer && (both || type == t);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'icon': icon,
        'color': color,
        'both': both,
      };

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'],
        name: j['name'],
        type: txTypeFrom(j['type']),
        icon: j['icon'] ?? 'other',
        color: j['color'] ?? 0xFF607D8B,
        both: j['both'] ?? false,
      );
}

class Txn {
  final String id;
  TxType type;
  int amount;
  String? categoryId;
  String walletId;
  String? toWalletId;
  String note;
  DateTime date;

  /// Terisi bila transaksi dibuat otomatis dari barang dagangan.
  String? itemId;

  Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.walletId,
    required this.date,
    this.categoryId,
    this.toWalletId,
    this.note = '',
    this.itemId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemId': itemId,
        'type': type.name,
        'amount': amount,
        'categoryId': categoryId,
        'walletId': walletId,
        'toWalletId': toWalletId,
        'note': note,
        'date': date.toIso8601String(),
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'],
        type: txTypeFrom(j['type']),
        amount: (j['amount'] as num).toInt(),
        categoryId: j['categoryId'],
        walletId: j['walletId'],
        toWalletId: j['toWalletId'],
        note: j['note'] ?? '',
        date: DateTime.parse(j['date']),
        itemId: j['itemId'],
      );
}

/// Biaya tambahan barang dagangan (servis, ongkir, aksesoris, dll).
class ItemCost {
  final String id;
  String name;
  int amount;
  DateTime date;
  String? walletId; // dibayar dari dompet mana (opsional)

  ItemCost({
    required this.id,
    required this.name,
    required this.amount,
    required this.date,
    this.walletId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'date': date.toIso8601String(),
        'walletId': walletId,
      };

  factory ItemCost.fromJson(Map<String, dynamic> j) => ItemCost(
        id: j['id'],
        name: j['name'] ?? '',
        amount: (j['amount'] as num).toInt(),
        date: DateTime.parse(j['date']),
        walletId: j['walletId'],
      );
}

/// Barang dagangan / aset di dalam dompet aset.
class Item {
  final String id;
  String walletId; // dompet aset tempat barang ini
  String name;
  String detail; // spesifikasi: warna, kapasitas, IMEI, kondisi, dll
  int buyPrice; // modal beli
  DateTime buyDate;
  String? buyWalletId; // uang modal diambil dari dompet mana (opsional)
  String supplier;
  List<ItemCost> costs;
  int targetPrice; // rencana harga jual (opsional)

  bool sold;
  int sellPrice;
  DateTime? sellDate;
  String? sellWalletId; // uang hasil jual masuk ke dompet mana (opsional)
  String buyer;

  Item({
    required this.id,
    required this.walletId,
    required this.name,
    required this.buyPrice,
    required this.buyDate,
    this.detail = '',
    this.buyWalletId,
    this.supplier = '',
    List<ItemCost>? costs,
    this.targetPrice = 0,
    this.sold = false,
    this.sellPrice = 0,
    this.sellDate,
    this.sellWalletId,
    this.buyer = '',
  }) : costs = costs ?? [];

  int get extraCost => costs.fold(0, (s, c) => s + c.amount);

  /// Total modal = harga beli + semua biaya tambahan.
  int get totalCost => buyPrice + extraCost;

  /// Laba/rugi: jika sudah terjual pakai harga jual, jika belum pakai target.
  int get profit => sold ? sellPrice - totalCost : 0;
  int get potentialProfit => targetPrice > 0 ? targetPrice - totalCost : 0;

  double get marginPct =>
      totalCost > 0 ? (sold ? profit : potentialProfit) * 100 / totalCost : 0;

  int get holdDays =>
      ((sold ? sellDate : null) ?? DateTime.now()).difference(buyDate).inDays;

  Map<String, dynamic> toJson() => {
        'id': id,
        'walletId': walletId,
        'name': name,
        'detail': detail,
        'buyPrice': buyPrice,
        'buyDate': buyDate.toIso8601String(),
        'buyWalletId': buyWalletId,
        'supplier': supplier,
        'costs': costs.map((c) => c.toJson()).toList(),
        'targetPrice': targetPrice,
        'sold': sold,
        'sellPrice': sellPrice,
        'sellDate': sellDate?.toIso8601String(),
        'sellWalletId': sellWalletId,
        'buyer': buyer,
      };

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: j['id'],
        walletId: j['walletId'],
        name: j['name'],
        detail: j['detail'] ?? '',
        buyPrice: (j['buyPrice'] as num).toInt(),
        buyDate: DateTime.parse(j['buyDate']),
        buyWalletId: j['buyWalletId'],
        supplier: j['supplier'] ?? '',
        costs: ((j['costs'] ?? []) as List)
            .map((e) => ItemCost.fromJson(e))
            .toList(),
        targetPrice: (j['targetPrice'] ?? 0) as int,
        sold: j['sold'] ?? false,
        sellPrice: (j['sellPrice'] ?? 0) as int,
        sellDate:
            j['sellDate'] != null ? DateTime.parse(j['sellDate']) : null,
        sellWalletId: j['sellWalletId'],
        buyer: j['buyer'] ?? '',
      );
}
