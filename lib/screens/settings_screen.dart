import 'package:flutter/material.dart';

import '../store.dart';
import '../widgets.dart';
import 'categories_screen.dart';
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
                'Pilih tanggal gajian Anda. Laporan bulanan akan dihitung mulai tanggal ini.'),
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
                    child: Text('$day',
                        style: TextStyle(
                            color: sel
                                ? Theme.of(c).colorScheme.onPrimary
                                : null)),
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
          context, MaterialPageRoute(builder: (_) => const PinSetupScreen()));
      if (pin != null) {
        await s.setPin(pin);
        if (context.mounted) toast(context, 'PIN aktif');
      }
    } else {
      final ok = await Navigator.push<bool>(
          context, MaterialPageRoute(builder: (_) => const PinVerifyScreen()));
      if (ok == true) {
        await s.setPin(null);
        if (context.mounted) toast(context, 'PIN dinonaktifkan');
      }
    }
  }

  Future<void> _changePin(BuildContext context) async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const PinVerifyScreen()));
    if (ok != true || !context.mounted) return;
    final pin = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const PinSetupScreen()));
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
        toast(context,
            'Perangkat tidak mendukung / belum ada sidik jari terdaftar');
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
          const _Header('Data'),
          ListTile(
            leading: const Icon(Icons.dashboard_customize_rounded),
            title: const Text('Kategori'),
            subtitle: const Text('Tambah, ubah ikon & warna, hapus'),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CategoriesScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.event_repeat_rounded),
            title: const Text('Tanggal awal periode'),
            subtitle: Text(s.cycleStartDay == 1
                ? 'Tanggal 1 (bulan kalender)'
                : 'Tanggal ${s.cycleStartDay} setiap bulan'),
            onTap: () => _pickCycleDay(context),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off_rounded),
            title: const Text('Sembunyikan nominal'),
            subtitle: const Text('Saldo & jumlah ditampilkan sebagai •••'),
            value: s.hideBalance,
            onChanged: (_) => s.toggleHideBalance(),
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
                'Semua data hanya tersimpan di perangkat ini. Tidak ada server, akun, atau sinkronisasi. Menghapus aplikasi akan menghapus seluruh data.'),
          ),
          ListTile(
            leading: Icon(Icons.restart_alt_rounded,
                color: Theme.of(context).colorScheme.error),
            title: Text('Hapus semua data',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () async {
              if (await confirm(context, 'Hapus semua data?',
                  'Semua transaksi, dompet, dan kategori akan dikembalikan ke awal. Tidak bisa dibatalkan.')) {
                await s.resetAll();
                if (context.mounted) toast(context, 'Data telah direset');
              }
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('FinFree v1.0.0',
                style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text,
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600)),
      );
}
