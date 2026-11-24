import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../format.dart';
import '../icons.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'asset_screens.dart' show AmountField;
import 'tx_form_screen.dart' show repeatLabel;

// ============================================================================
// Cadangan & pulihkan — file biasa di HP, tanpa internet / akun Google
// ============================================================================

/// Simpan cadangan: pengguna memilih folder (mis. Download) lewat dialog
/// sistem. File bisa disalin ke laptop/flashdisk.
Future<void> saveBackup(BuildContext context) async {
  final s = AppStore.I;
  try {
    final raw = await s.exportBackup();
    final name =
        'FinFree-cadangan-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.json';
    final path = await FilePicker.saveFile(
      dialogTitle: 'Simpan cadangan FinFree',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: Uint8List.fromList(utf8.encode(raw)),
    );
    if (path == null) return; // dibatalkan
    await s.markBackedUp();
    if (context.mounted) {
      toast(context, 'Cadangan tersimpan ✔ Simpan juga salinannya di laptop/flashdisk.');
    }
  } catch (e) {
    if (context.mounted) toast(context, 'Gagal menyimpan cadangan: $e');
  }
}

/// Pulihkan dari file cadangan (mengganti seluruh data di HP ini).
Future<void> restoreBackup(BuildContext context) async {
  final s = AppStore.I;
  try {
    final res = await FilePicker.pickFiles(
      dialogTitle: 'Pilih file cadangan FinFree',
      type: FileType.any,
      withData: true,
    );
    final f = res?.files.singleOrNull;
    if (f == null) return;
    final bytes = f.bytes ?? await File(f.path!).readAsBytes();
    final raw = utf8.decode(bytes);
    final info = AppStore.inspectBackup(raw);
    if (!context.mounted) return;
    final ok = await confirm(
      context,
      'Pulihkan data?',
      'File: ${f.name}\n'
          'Dibuat: ${info.at != null ? dfDay.format(info.at!) : '-'}\n'
          'Isi: ${info.txns} transaksi, ${info.items} barang\n\n'
          'SEMUA data di HP ini akan DIGANTI dengan isi file tersebut.',
      ok: 'Pulihkan',
    );
    if (!ok) return;
    await s.importBackup(raw);
    if (context.mounted) toast(context, 'Data berhasil dipulihkan ✔');
  } on FormatException catch (e) {
    if (context.mounted) toast(context, 'File tidak valid: ${e.message}');
  } catch (e) {
    if (context.mounted) toast(context, 'Gagal memulihkan: $e');
  }
}

/// Teks status cadangan terakhir.
String backupStatus() {
  final at = AppStore.I.lastBackupAt;
  if (at == null) return 'Belum pernah dicadangkan';
  final days = DateTime.now().difference(at).inDays;
  return 'Terakhir: ${dfDay.format(at)}'
      '${days >= 1 ? ' ($days hari lalu)' : ''}';
}

bool backupOverdue() {
  final s = AppStore.I;
  if (s.txns.length < 10) return false;
  final at = s.lastBackupAt;
  return at == null || DateTime.now().difference(at).inDays >= 14;
}

// ============================================================================
// Transaksi rutin
// ============================================================================

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.I,
      builder: (context, _) {
        final s = AppStore.I;
        final list = [...s.recurrings]
          ..sort((a, b) => a.nextDue(DateTime.now())
              .compareTo(b.nextDue(DateTime.now())));
        final tt = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(title: const Text('Transaksi Rutin')),
          body: list.isEmpty
              ? const EmptyState(
                  icon: Icons.repeat_rounded,
                  text:
                      'Belum ada transaksi rutin.\nSaat mencatat transaksi, pilih\n"Ulangi otomatis: Tiap tgl …".',
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                          'Dicatat otomatis saat jatuh tempo (termasuk yang terlewat saat aplikasi tidak dibuka).',
                          style: tt.bodySmall),
                    ),
                    ...list.map((r) {
                      final c = s.category(r.categoryId);
                      final w = s.wallet(r.walletId);
                      final title = r.type == TxType.transfer
                          ? 'Transfer ke ${s.wallet(r.toWalletId)?.name ?? '?'}'
                          : (r.note.isNotEmpty ? r.note : c?.name ?? '-');
                      return ListTile(
                        leading: CircleIcon(
                            icon: c?.icon ?? 'refund',
                            color: c?.color ??
                                Theme.of(context).colorScheme.primary.toARGB32()),
                        title: Text(title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${repeatLabel(r)} • ${w?.name ?? '?'}\n'
                          '${r.active ? 'Berikutnya ${dfShort.format(r.nextDue(DateTime.now()))}' : 'Dijeda'}',
                        ),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(money(r.amount),
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: typeColor(r.type, context))),
                          ],
                        ),
                        onTap: () => _actions(context, r),
                      );
                    }),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _actions(BuildContext context, Recurring r) async {
    final s = AppStore.I;
    final amount = TextEditingController(text: formatAmountInput(r.amount));
    final v = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(repeatLabel(r), style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 12),
            AmountField(amount, 'Nominal berikutnya',
                helper: 'Transaksi yang sudah tercatat tidak berubah'),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.pop(c, 'save'),
              child: const Text('Simpan nominal'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.pop(c, 'toggle'),
              icon: Icon(r.active
                  ? Icons.pause_circle_outline_rounded
                  : Icons.play_circle_outline_rounded),
              label: Text(r.active ? 'Jeda' : 'Lanjutkan'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.pop(c, 'delete'),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Hapus jadwal'),
            ),
          ],
        ),
      ),
    );
    switch (v) {
      case 'save':
        final a = parseAmount(amount.text);
        if (a > 0) {
          r.amount = a;
          await s.upsertRecurring(r);
        }
      case 'toggle':
        // saat dilanjutkan, jangan mencatat semua yang terlewat selama dijeda
        if (!r.active) {
          final now = DateTime.now();
          r.lastRun = DateTime(now.year, now.month, now.day - 1);
        }
        r.active = !r.active;
        await s.upsertRecurring(r);
      case 'delete':
        if (context.mounted &&
            await confirm(context, 'Hapus jadwal?',
                'Transaksi yang sudah tercatat tetap ada. Hanya jadwal ke depan yang dihapus.')) {
          await s.deleteRecurring(r.id);
        }
    }
  }
}

// ============================================================================
// Anggaran
// ============================================================================

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStore.I,
      builder: (context, _) {
        final s = AppStore.I;
        final p = s.currentPeriod;
        final withBudget = s.budgetCategories;
        final without = s
            .categoriesOf(TxType.expense)
            .where((c) => c.budget <= 0)
            .toList();
        final total = withBudget.fold(0, (t, c) => t + c.budget);
        final spent = withBudget.fold(0, (t, c) => t + s.spentIn(p, c.id));
        final tt = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(title: const Text('Anggaran')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (withBudget.isNotEmpty) ...[
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Periode ${p.label}', style: tt.bodySmall),
                        const SizedBox(height: 4),
                        Text('${money(spent)} dari ${money(total)}',
                            style: tt.titleMedium),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: total > 0 ? (spent / total).clamp(0.0, 1.0) : 0,
                          minHeight: 8,
                          color: budgetColor(
                              total > 0 ? spent / total : 0, context),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...withBudget.map((c) => BudgetTile(
                    c: c, period: p, onTap: () => _edit(context, c))),
                const Divider(height: 24),
              ],
              Text(
                  withBudget.isEmpty
                      ? 'Pilih kategori untuk diberi batas pengeluaran per periode:'
                      : 'Kategori tanpa anggaran',
                  style: tt.titleSmall),
              ...without.map((c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleIcon(icon: c.icon, color: c.color),
                    title: Text(c.name),
                    subtitle: Text(
                        'Periode ini ${money(s.spentIn(p, c.id))}'),
                    trailing: const Icon(Icons.add_circle_outline_rounded),
                    onTap: () => _edit(context, c),
                  )),
            ],
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, Category c) async {
    final ctl = TextEditingController(
        text: c.budget > 0 ? formatAmountInput(c.budget) : '');
    final avg = _avgSpent(c);
    final v = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Anggaran ${c.name}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          AmountField(ctl, 'Batas per periode',
              autofocus: true,
              helper: avg > 0
                  ? 'Rata-rata 3 periode terakhir: ${rupiah(avg)}'
                  : null),
        ]),
        actions: [
          if (c.budget > 0)
            TextButton(
                onPressed: () => Navigator.pop(d, 0),
                child: const Text('Hapus anggaran')),
          TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(d, parseAmount(ctl.text)),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (v == null) return;
    c.budget = v;
    await AppStore.I.upsertCategory(c);
  }

  int _avgSpent(Category c) {
    final s = AppStore.I;
    var p = s.currentPeriod;
    var sum = 0;
    for (var i = 0; i < 3; i++) {
      p = p.shift(-1, s.cycleStartDay);
      sum += s.spentIn(p, c.id);
    }
    return (sum / 3).round();
  }
}
