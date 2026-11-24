import 'package:flutter/material.dart';

import '../store.dart';
import '../widgets.dart';
import 'categories_screen.dart';
import 'debt_screens.dart';
import 'tools_screens.dart';
import 'lock_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _pickCycleDay(BuildContext context) async {
    final s = AppStore.I;
    final d = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Tanggal awal periode'),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Pilih tanggal gajian Anda. Laporan bulanan akan dihitung mulai tanggal ini.',
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 300,
            height: 260,
            child: GridView.count(
              crossAxisCount: 7,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: List.generate(28, (i) {
                final day = i + 1;
                final sel = day == s.cycleStartDay;
                return InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(c, day),
                  child: CircleAvatar(
                    backgroundColor: sel
                        ? Theme.of(c).colorScheme.primary
                        : Colors.transparent,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: sel ? Theme.of(c).colorScheme.onPrimary : null,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
    if (d != null) await s.setCycleStartDay(d);
  }

  Future<void> _togglePin(BuildContext context, bool on) async {
    final s = AppStore.I;
    if (on) {
      final pin = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const PinSetupScreen()),
      );
      if (pin != null) {
        await s.setPin(pin);
        if (context.mounted) toast(context, 'PIN aktif');
      }
    } else {
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const PinVerifyScreen()),
      );
      if (ok == true) {
        await s.setPin(null);
        if (context.mounted) toast(context, 'PIN dinonaktifkan');
      }
    }
  }

  Future<void> _changePin(BuildContext context) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PinVerifyScreen()),
    );
    if (ok != true || !context.mounted) return;
    final pin = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
    if (pin != null) {
      await AppStore.I.setPin(pin);
      if (context.mounted) toast(context, 'PIN diperbarui');
    }
  }

  Future<void> _toggleBio(BuildContext context, bool on) async {
    final s = AppStore.I;
    if (!on) {
      await s.setBiometric(false);
      return;
    }
    if (!await Biometric.available()) {
      if (context.mounted) {
        toast(
          context,
          'Perangkat tidak mendukung / belum ada sidik jari terdaftar',
        );
      }
      return;
    }
    if (await Biometric.authenticate('Konfirmasi untuk mengaktifkan')) {
      await s.setBiometric(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStore.I;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          const _Header('Cadangan data (offline)'),
          ListTile(
            leading: Icon(Icons.save_alt_rounded,
                color: backupOverdue() ? Theme.of(context).colorScheme.error : null),
            title: const Text('Simpan cadangan ke file'),
            subtitle: Text(backupStatus(),
                style: backupOverdue()
                    ? TextStyle(color: Theme.of(context).colorScheme.error)
                    : null),
            onTap: () => saveBackup(context),
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore_rounded),
            title: const Text('Pulihkan dari file cadangan'),
            subtitle: const Text('Untuk pindah HP / setelah instal ulang'),
            onTap: () => restoreBackup(context),
          ),
          const _Header('Data'),
          ListTile(
            leading: const Icon(Icons.dashboard_customize_rounded),
            title: const Text('Kategori'),
            subtitle: const Text('Tambah, ubah ikon & warna, hapus'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.savings_rounded),
            title: const Text('Anggaran'),
            subtitle: Text(s.budgetCategories.isEmpty
                ? 'Batasi pengeluaran per kategori'
                : '${s.budgetCategories.length} kategori diberi anggaran'),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BudgetsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.repeat_rounded),
            title: const Text('Transaksi rutin'),
            subtitle: Text(s.recurrings.isEmpty
                ? 'Cicilan, tagihan, gaji yang tercatat otomatis'
                : '${s.recurrings.where((r) => r.active).length} jadwal aktif'),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RecurringScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.handshake_rounded),
            title: const Text('Utang & piutang'),
            subtitle: const Text('Pinjaman, DP pembeli, belum bayar supplier'),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DebtsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.event_repeat_rounded),
            title: const Text('Tanggal awal periode'),
            subtitle: Text(
              s.cycleStartDay == 1
                  ? 'Tanggal 1 (bulan kalender)'
                  : 'Tanggal ${s.cycleStartDay} setiap bulan',
            ),
            onTap: () => _pickCycleDay(context),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off_rounded),
            title: const Text('Sembunyikan nominal'),
            subtitle: const Text('Saldo & jumlah ditampilkan sebagai •••'),
            value: s.hideBalance,
            onChanged: (_) => s.toggleHideBalance(),
          ),
          const _Header('Tampilan'),
          ListenableBuilder(
            listenable: Listenable.merge([s.themeColor, s.themeMode]),
            builder: (context, _) => ListTile(
              leading: const Icon(Icons.palette_rounded),
              title: const Text('Tema warna'),
              subtitle: Text(
                '${themeName(s.themeColor.value)} · ${_modeLabel(s.themeMode.value)}',
              ),
              trailing: CircleAvatar(
                radius: 12,
                backgroundColor: Color(s.themeColor.value),
              ),
              onTap: () => showThemeSheet(context),
            ),
          ),
          const _Header('Keamanan'),
          SwitchListTile(
            secondary: const Icon(Icons.pin_rounded),
            title: const Text('Kunci dengan PIN'),
            subtitle: const Text('Diminta saat aplikasi dibuka'),
            value: s.hasPin,
            onChanged: (v) => _togglePin(context, v),
          ),
          if (s.hasPin) ...[
            ListTile(
              leading: const Icon(Icons.password_rounded),
              title: const Text('Ubah PIN'),
              onTap: () => _changePin(context),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint_rounded),
              title: const Text('Buka dengan sidik jari'),
              value: s.biometricEnabled,
              onChanged: (v) => _toggleBio(context, v),
            ),
          ],
          const _Header('Privasi'),
          const ListTile(
            leading: Icon(Icons.cloud_off_rounded),
            title: Text('100% offline'),
            subtitle: Text(
              'Semua data hanya tersimpan di perangkat ini. Tidak ada server, akun, atau sinkronisasi. Menghapus aplikasi akan menghapus seluruh data — rutin simpan cadangan ke file.',
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.restart_alt_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Hapus semua data',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () async {
              if (await confirm(
                context,
                'Hapus semua data?',
                'Semua transaksi, dompet, dan kategori akan dikembalikan ke awal. Tidak bisa dibatalkan.',
              )) {
                await s.resetAll();
                if (context.mounted) toast(context, 'Data telah direset');
              }
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'FinFree v1.0.0',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Pilihan warna tema (warna dasar; Material 3 menurunkan palet lengkap
/// yang serasi & kontrasnya terjaga, termasuk untuk mode gelap).
const kThemePresets = <(String, int)>[
  ('Biru Cerah', 0xFF0A6CD6),
  ('Biru Bank', 0xFF0057B8),
  ('Biru Langit', 0xFF0091EA),
  ('Biru Navy', 0xFF0B3D91),
  ('Toska', 0xFF00A19B),
  ('Hijau Segar', 0xFF00A651),
  ('Oranye', 0xFFF26522),
  ('Merah', 0xFFE53935),
  ('Merah Muda', 0xFFE91E63),
  ('Ungu', 0xFF8E24AA),
  ('Indigo', 0xFF3F51B5),
  ('Grafit', 0xFF37474F),
];

String themeName(int c) =>
    kThemePresets.where((p) => p.$2 == c).firstOrNull?.$1 ?? 'Kustom';

String _modeLabel(String m) => switch (m) {
  'light' => 'Terang',
  'dark' => 'Gelap',
  _ => 'Ikuti HP',
};

Future<void> showThemeSheet(BuildContext context) {
  final s = AppStore.I;
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => ListenableBuilder(
      listenable: Listenable.merge([s.themeColor, s.themeMode]),
      builder: (ctx, _) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tema warna', style: tt.titleLarge),
                const SizedBox(height: 12),
                // pratinjau kecil
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.tertiary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Total saldo  Rp 12.500.000',
                          style: tt.titleMedium?.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 12,
                  children: [
                    for (final (name, c) in kThemePresets)
                      SizedBox(
                        width: 70,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => s.setThemeColor(c),
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Color(c),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    width: 3,
                                    color: s.themeColor.value == c
                                        ? cs.onSurface
                                        : Colors.transparent,
                                  ),
                                ),
                                child: s.themeColor.value == c
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                name,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: tt.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Mode', style: tt.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: 'system',
                        icon: Icon(Icons.brightness_auto_rounded),
                        label: Text('Ikuti HP'),
                      ),
                      ButtonSegment(
                        value: 'light',
                        icon: Icon(Icons.light_mode_rounded),
                        label: Text('Terang'),
                      ),
                      ButtonSegment(
                        value: 'dark',
                        icon: Icon(Icons.dark_mode_rounded),
                        label: Text('Gelap'),
                      ),
                    ],
                    selected: {s.themeMode.value},
                    onSelectionChanged: (v) => s.setThemeMode(v.first),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
