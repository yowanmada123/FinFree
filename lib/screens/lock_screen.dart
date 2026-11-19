import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../store.dart';

class Biometric {
  static final _auth = LocalAuthentication();

  static Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported() &&
          await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate(String reason) async {
    LockScreen.suspend = true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    } finally {
      Future.delayed(const Duration(seconds: 1), () => LockScreen.suspend = false);
    }
  }
}

class LockScreen extends StatefulWidget {
  /// true saat dialog sistem (biometrik, pemilih file, share) sedang terbuka,
  /// supaya aplikasi tidak terkunci ulang karenanya.
  static bool suspend = false;

  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _error = '';
  final _padKey = GlobalKey<PinPadState>();

  @override
  void initState() {
    super.initState();
    if (AppStore.I.biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
    }
  }

  Future<void> _bio() async {
    if (await Biometric.authenticate('Buka FinFree')) widget.onUnlocked();
  }

  void _submit(String pin) {
    if (AppStore.I.verifyPin(pin)) {
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'PIN salah, coba lagi');
      _padKey.currentState?.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(Icons.shield_moon_rounded, size: 56, color: cs.primary),
            const SizedBox(height: 12),
            Text('Masukkan PIN',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(_error, style: TextStyle(color: cs.error)),
            const SizedBox(height: 12),
            PinPad(
              key: _padKey,
              onCompleted: _submit,
              extraButton: AppStore.I.biometricEnabled
                  ? IconButton(
                      iconSize: 32,
                      onPressed: _bio,
                      icon: Icon(Icons.fingerprint_rounded, color: cs.primary),
                    )
                  : null,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Keypad PIN 6 digit.
class PinPad extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;
  final Widget? extraButton;
  const PinPad({
    super.key,
    required this.onCompleted,
    this.length = 6,
    this.extraButton,
  });

  @override
  State<PinPad> createState() => PinPadState();
}

class PinPadState extends State<PinPad> {
  String _pin = '';

  void clear() => setState(() => _pin = '');

  void _tap(String d) {
    if (_pin.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
    if (_pin.length == widget.length) {
      final p = _pin;
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) widget.onCompleted(p);
      });
    }
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget key(String d) => SizedBox(
          width: 76,
          height: 76,
          child: TextButton(
            style: TextButton.styleFrom(shape: const CircleBorder()),
            onPressed: () => _tap(d),
            child: Text(d,
                style: TextStyle(fontSize: 28, color: cs.onSurface)),
          ),
        );
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (i) {
            final filled = i < _pin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.all(8),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? cs.primary : Colors.transparent,
                border: Border.all(color: cs.primary, width: 2),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map(key).toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                width: 76, height: 76, child: Center(child: widget.extraButton)),
            key('0'),
            SizedBox(
              width: 76,
              height: 76,
              child: IconButton(
                onPressed: _back,
                icon: const Icon(Icons.backspace_outlined),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Alur membuat PIN baru (masukkan lalu konfirmasi). Mengembalikan PIN.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _first;
  String _msg = '';
  final _padKey = GlobalKey<PinPadState>();

  void _done(String pin) {
    if (_first == null) {
      setState(() {
        _first = pin;
        _msg = '';
      });
      _padKey.currentState?.clear();
    } else if (_first == pin) {
      Navigator.pop(context, pin);
    } else {
      setState(() {
        _first = null;
        _msg = 'PIN tidak sama, ulangi dari awal';
      });
      _padKey.currentState?.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Atur PIN')),
      body: Column(
        children: [
          const Spacer(),
          Text(_first == null ? 'Buat PIN 6 digit' : 'Ulangi PIN',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(_msg,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
          PinPad(key: _padKey, onCompleted: _done),
          const Spacer(),
        ],
      ),
    );
  }
}

/// Meminta PIN saat ini (untuk ubah/hapus PIN). Mengembalikan true bila benar.
class PinVerifyScreen extends StatefulWidget {
  const PinVerifyScreen({super.key});

  @override
  State<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends State<PinVerifyScreen> {
  String _msg = '';
  final _padKey = GlobalKey<PinPadState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi PIN')),
      body: Column(
        children: [
          const Spacer(),
          Text('Masukkan PIN saat ini',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(_msg,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
          PinPad(
            key: _padKey,
            onCompleted: (p) {
              if (AppStore.I.verifyPin(p)) {
                Navigator.pop(context, true);
              } else {
                setState(() => _msg = 'PIN salah');
                _padKey.currentState?.clear();
              }
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
