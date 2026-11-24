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

  /// Batas pengeluaran per periode (0 = tanpa anggaran).
  int budget;

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.both = false,
    this.budget = 0,
  });

  bool usableFor(TxType t) => t != TxType.transfer && (both || type == t);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'icon': icon,
        'color': color,
        'both': both,
        'budget': budget,
      };

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'],
        name: j['name'],
        type: txTypeFrom(j['type']),
        icon: j['icon'] ?? 'other',
        color: j['color'] ?? 0xFF607D8B,
        both: j['both'] ?? false,
        budget: ((j['budget'] ?? 0) as num).toInt(),
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

  /// Terisi bila transaksi dibuat otomatis dari catatan utang/piutang.
  String? debtId;

  /// Terisi bila transaksi dibuat dari transaksi rutin.
  String? recurringId;

  /// Transaksi otomatis (barang/utang) diubah lewat sumbernya, bukan form biasa.
  bool get isLinked => itemId != null || debtId != null;

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
    this.debtId,
    this.recurringId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemId': itemId,
        'debtId': debtId,
        'recurringId': recurringId,
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
        debtId: j['debtId'],
        recurringId: j['recurringId'],
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

  /// Jumlah unit (mis. beli 5 casing sekaligus). Harga beli & biaya = total.
  int qty;

  /// Nama file foto barang/nota (disimpan di folder aplikasi).
  List<String> photos;

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
    this.qty = 1,
    List<String>? photos,
  })  : costs = costs ?? [],
        photos = photos ?? [];

  /// Modal per unit.
  int get unitCost => qty > 1 ? (totalCost / qty).round() : totalCost;

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
        'qty': qty,
        'photos': photos,
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
        qty: ((j['qty'] ?? 1) as num).toInt(),
        photos: ((j['photos'] ?? []) as List).cast<String>().toList(),
      );
}

/// Pembayaran/cicilan utang atau piutang.
class DebtPayment {
  final String id;
  int amount;
  DateTime date;
  String? walletId; // uang masuk/keluar dompet mana (opsional)
  String note;

  DebtPayment({
    required this.id,
    required this.amount,
    required this.date,
    this.walletId,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'walletId': walletId,
        'note': note,
      };

  factory DebtPayment.fromJson(Map<String, dynamic> j) => DebtPayment(
        id: j['id'],
        amount: (j['amount'] as num).toInt(),
        date: DateTime.parse(j['date']),
        walletId: j['walletId'],
        note: j['note'] ?? '',
      );
}

/// Utang (saya berutang ke orang) atau piutang (orang berutang ke saya).
class Debt {
  final String id;

  /// 'receivable' = piutang (orang lain berutang ke saya),
  /// 'payable' = utang (saya berutang).
  String kind;
  String person;
  int amount;
  DateTime date;
  DateTime? dueDate;
  String note;

  /// Dompet tempat uang keluar (piutang) / masuk (utang) saat dicatat.
  /// null = tidak memengaruhi saldo (mis. sisa bayar pembeli / DP).
  String? walletId;
  List<DebtPayment> payments;

  Debt({
    required this.id,
    required this.kind,
    required this.person,
    required this.amount,
    required this.date,
    this.dueDate,
    this.note = '',
    this.walletId,
    List<DebtPayment>? payments,
  }) : payments = payments ?? [];

  bool get isReceivable => kind == 'receivable';
  int get paid => payments.fold(0, (s, p) => s + p.amount);
  int get remaining => amount - paid;
  bool get settled => remaining <= 0;
  bool get overdue {
    final d = dueDate;
    if (settled || d == null) return false;
    return DateTime.now().isAfter(DateTime(d.year, d.month, d.day, 23, 59, 59));
  }

  double get progress => amount > 0 ? (paid / amount).clamp(0.0, 1.0) : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'person': person,
        'amount': amount,
        'date': date.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'note': note,
        'walletId': walletId,
        'payments': payments.map((p) => p.toJson()).toList(),
      };

  factory Debt.fromJson(Map<String, dynamic> j) => Debt(
        id: j['id'],
        kind: j['kind'] ?? 'receivable',
        person: j['person'] ?? '',
        amount: (j['amount'] as num).toInt(),
        date: DateTime.parse(j['date']),
        dueDate: j['dueDate'] != null ? DateTime.parse(j['dueDate']) : null,
        note: j['note'] ?? '',
        walletId: j['walletId'],
        payments: ((j['payments'] ?? []) as List)
            .map((e) => DebtPayment.fromJson(e))
            .toList(),
      );
}

/// Transaksi rutin yang dicatat otomatis (mis. cicilan tiap tanggal 5).
class Recurring {
  final String id;
  TxType type;
  int amount;
  String? categoryId;
  String walletId;
  String? toWalletId;
  String note;

  /// 'monthly' (tiap tanggal [day], 1–28) atau 'weekly' (hari ke-[day], 1=Senin).
  String freq;
  int day;
  DateTime startDate;

  /// Tanggal jatuh tempo terakhir yang sudah dicatat.
  DateTime? lastRun;
  bool active;

  Recurring({
    required this.id,
    required this.type,
    required this.amount,
    required this.walletId,
    required this.freq,
    required this.day,
    required this.startDate,
    this.categoryId,
    this.toWalletId,
    this.note = '',
    this.lastRun,
    this.active = true,
  });

  /// Tanggal jatuh tempo yang belum dicatat, sampai [until].
  List<DateTime> dueDates(DateTime until) {
    final out = <DateTime>[];
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    bool fresh(DateTime d) =>
        !d.isBefore(start) && (lastRun == null || d.isAfter(lastRun!));
    if (freq == 'weekly') {
      var d = start;
      while (d.weekday != day) {
        d = DateTime(d.year, d.month, d.day + 1);
      }
      while (!d.isAfter(until)) {
        if (fresh(d)) out.add(d);
        d = DateTime(d.year, d.month, d.day + 7);
      }
    } else {
      var d = DateTime(start.year, start.month, day);
      while (!d.isAfter(until)) {
        if (fresh(d)) out.add(d);
        d = DateTime(d.year, d.month + 1, day);
      }
    }
    return out;
  }

  /// Jatuh tempo berikutnya setelah hari ini.
  DateTime nextDue(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final probe = freq == 'weekly'
        ? DateTime(today.year, today.month, today.day + 8)
        : DateTime(today.year, today.month + 2, 1);
    return dueDates(probe).firstWhere((d) => d.isAfter(today),
        orElse: () => probe);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'categoryId': categoryId,
        'walletId': walletId,
        'toWalletId': toWalletId,
        'note': note,
        'freq': freq,
        'day': day,
        'startDate': startDate.toIso8601String(),
        'lastRun': lastRun?.toIso8601String(),
        'active': active,
      };

  factory Recurring.fromJson(Map<String, dynamic> j) => Recurring(
        id: j['id'],
        type: txTypeFrom(j['type']),
        amount: (j['amount'] as num).toInt(),
        categoryId: j['categoryId'],
        walletId: j['walletId'],
        toWalletId: j['toWalletId'],
        note: j['note'] ?? '',
        freq: j['freq'] ?? 'monthly',
        day: ((j['day'] ?? 1) as num).toInt(),
        startDate: DateTime.parse(j['startDate']),
        lastRun: j['lastRun'] != null ? DateTime.parse(j['lastRun']) : null,
        active: j['active'] ?? true,
      );
}

