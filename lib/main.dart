import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'store.dart';

const kAppName = 'FinFree';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await AppStore.I.load();
  runApp(const FinFreeApp());
}

class FinFreeApp extends StatelessWidget {
  const FinFreeApp({super.key});

  static ThemeData theme(Brightness b, [int seed = kDefaultThemeColor]) {
    final scheme = ColorScheme.fromSeed(seedColor: Color(seed), brightness: b);
    final text = _textTheme(Typography.material2021(platform: TargetPlatform.android)
        .englishLike
        .merge(b == Brightness.dark
            ? Typography.material2021().white
            : Typography.material2021().black));
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      textTheme: text,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: text.bodyLarge
            ?.copyWith(fontWeight: FontWeight.w500, color: scheme.onSurface),
        subtitleTextStyle:
            text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  /// Skala huruf yang nyaman untuk aplikasi keuangan (padat angka).
  /// Mengacu Material 3 (body 14–16sp, line-height ±1.4–1.5) tapi sedikit
  /// lebih ringkas di judul/headline supaya layar tidak terasa "berteriak".
  static TextTheme _textTheme(TextTheme base) {
    TextStyle? s(TextStyle? t, double size, FontWeight w, double h,
            [double ls = 0]) =>
        t?.copyWith(
            fontSize: size, fontWeight: w, height: h, letterSpacing: ls);
    return base.copyWith(
      displaySmall: s(base.displaySmall, 30, FontWeight.w700, 1.2),
      headlineMedium: s(base.headlineMedium, 24, FontWeight.w700, 1.25),
      headlineSmall: s(base.headlineSmall, 21, FontWeight.w700, 1.3),
      titleLarge: s(base.titleLarge, 18, FontWeight.w600, 1.3),
      titleMedium: s(base.titleMedium, 15, FontWeight.w600, 1.35, 0.1),
      titleSmall: s(base.titleSmall, 13.5, FontWeight.w600, 1.35, 0.1),
      bodyLarge: s(base.bodyLarge, 15, FontWeight.w400, 1.45, 0.15),
      bodyMedium: s(base.bodyMedium, 14, FontWeight.w400, 1.45, 0.2),
      bodySmall: s(base.bodySmall, 12.5, FontWeight.w400, 1.4, 0.2),
      labelLarge: s(base.labelLarge, 14, FontWeight.w600, 1.3, 0.1),
      labelMedium: s(base.labelMedium, 12, FontWeight.w500, 1.3, 0.3),
      labelSmall: s(base.labelSmall, 11, FontWeight.w500, 1.3, 0.3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStore.I;
    return ListenableBuilder(
      listenable: Listenable.merge([s.themeColor, s.themeMode]),
      builder: (context, _) => MaterialApp(
      // Ikuti ukuran huruf sistem HP, tapi dibatasi agar tata letak
      // tidak pecah bila HP di-set "huruf sangat besar".
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
              textScaler:
                  mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15)),
          child: child!,
        );
      },
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light, s.themeColor.value),
      darkTheme: theme(Brightness.dark, s.themeColor.value),
      themeMode: switch (s.themeMode.value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const LockGate(child: HomeScreen()),
      ),
    );
  }
}

/// Mengunci aplikasi dengan PIN/sidik jari saat dibuka dan saat kembali dari
/// latar belakang.
class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> {
  late bool _locked = AppStore.I.hasPin;
  DateTime? _pausedAt;
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onHide: () => _pausedAt ??= DateTime.now(),
      onShow: () {
        final p = _pausedAt;
        _pausedAt = null;
        if (AppStore.I.hasPin &&
            !LockScreen.suspend &&
            p != null &&
            DateTime.now().difference(p) > const Duration(seconds: 30)) {
          setState(() => _locked = true);
        }
      },
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: LockScreen(onUnlocked: () => setState(() => _locked = false)),
          ),
      ],
    );
  }
}
