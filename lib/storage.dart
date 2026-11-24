import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Isi penyimpanan: koleksi → (id → JSON string).
typedef Rows = Map<String, Map<String, String>>;

/// Perubahan: koleksi → (id → JSON string, atau null = hapus).
typedef RowChanges = Map<String, Map<String, String?>>;

/// Penyimpanan baris (per transaksi/dompet/barang/...). Hanya baris yang
/// berubah yang ditulis, jadi tetap cepat walau data sudah bertahun-tahun.
abstract class DataBackend {
  Future<Rows> readAll();
  Future<void> apply(RowChanges changes);

  /// Ganti seluruh isi (dipakai saat pulihkan cadangan / reset).
  Future<void> replaceAll(Rows rows);
}

/// Backend utama aplikasi: SQLite lokal di HP.
class SqliteBackend implements DataBackend {
  Future<Database>? _db;

  // satu koneksi; semua transaksi sqflite dijalankan berurutan (FIFO)
  Future<Database> get _database => _db ??= _open();

  Future<Database> _open() async => openDatabase(
        p.join(await getDatabasesPath(), 'finfree.db'),
        version: 1,
        onCreate: (db, _) => db.execute('''
          CREATE TABLE rows(
            coll TEXT NOT NULL,
            id TEXT NOT NULL,
            json TEXT NOT NULL,
            PRIMARY KEY (coll, id)
          )'''),
      );

  @override
  Future<Rows> readAll() async {
    final db = await _database;
    final out = <String, Map<String, String>>{};
    for (final r in await db.query('rows')) {
      (out[r['coll'] as String] ??= {})[r['id'] as String] = r['json'] as String;
    }
    return out;
  }

  @override
  Future<void> apply(RowChanges changes) async {
    if (changes.values.every((m) => m.isEmpty)) return;
    final db = await _database;
    await db.transaction((tx) async {
      final b = tx.batch();
      changes.forEach((coll, rows) {
        rows.forEach((id, json) {
          if (json == null) {
            b.delete('rows', where: 'coll = ? AND id = ?', whereArgs: [coll, id]);
          } else {
            b.insert('rows', {'coll': coll, 'id': id, 'json': json},
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        });
      });
      await b.commit(noResult: true);
    });
  }

  @override
  Future<void> replaceAll(Rows rows) async {
    final db = await _database;
    await db.transaction((tx) async {
      await tx.delete('rows');
      final b = tx.batch();
      rows.forEach((coll, m) => m.forEach((id, json) =>
          b.insert('rows', {'coll': coll, 'id': id, 'json': json})));
      await b.commit(noResult: true);
    });
  }
}

/// Backend sederhana di SharedPreferences (dipakai untuk test).
class PrefsBackend implements DataBackend {
  static const key = 'finfree_rows_v2';
  int writes = 0; // jumlah baris yang ditulis (untuk test)
  Rows? _cache;

  Future<Rows> _read() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) =>
        MapEntry(k, (v as Map<String, dynamic>).cast<String, String>()));
  }

  Future<void> _write(Rows rows) async =>
      (await SharedPreferences.getInstance()).setString(key, jsonEncode(rows));

  @override
  Future<Rows> readAll() async {
    final r = await _read();
    _cache = {for (final e in r.entries) e.key: Map.of(e.value)};
    return r;
  }

  @override
  Future<void> apply(RowChanges changes) async {
    // ubah cache secara sinkron supaya penulisan beruntun tidak saling timpa
    final rows = _cache ??= {};
    changes.forEach((coll, m) {
      final c = rows[coll] ??= {};
      m.forEach((id, json) {
        writes++;
        json == null ? c.remove(id) : c[id] = json;
      });
    });
    await _write(rows);
  }

  @override
  Future<void> replaceAll(Rows rows) {
    _cache = {for (final e in rows.entries) e.key: Map.of(e.value)};
    return _write(rows);
  }
}
