import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';

/// Daftar iPhone beserta pilihan storage-nya (terbaru dulu).
const List<(String, List<String>)> kIphones = [
  ('iPhone 17 Pro Max', ['256GB', '512GB', '1TB', '2TB']),
  ('iPhone 17 Pro', ['256GB', '512GB', '1TB']),
  ('iPhone Air', ['256GB', '512GB', '1TB']),
  ('iPhone 17', ['256GB', '512GB']),
  ('iPhone 16e', ['128GB', '256GB', '512GB']),
  ('iPhone 16 Pro Max', ['256GB', '512GB', '1TB']),
  ('iPhone 16 Pro', ['128GB', '256GB', '512GB', '1TB']),
  ('iPhone 16 Plus', ['128GB', '256GB', '512GB']),
  ('iPhone 16', ['128GB', '256GB', '512GB']),
  ('iPhone 15 Pro Max', ['256GB', '512GB', '1TB']),
  ('iPhone 15 Pro', ['128GB', '256GB', '512GB', '1TB']),
  ('iPhone 15 Plus', ['128GB', '256GB', '512GB']),
  ('iPhone 15', ['128GB', '256GB', '512GB']),
  ('iPhone 14 Pro Max', ['128GB', '256GB', '512GB', '1TB']),
  ('iPhone 14 Pro', ['128GB', '256GB', '512GB', '1TB']),
  ('iPhone 14 Plus', ['128GB', '256GB', '512GB']),
  ('iPhone 14', ['128GB', '256GB', '512GB']),
  ('iPhone SE (2022)', ['64GB', '128GB', '256GB']),
  ('iPhone 13 Pro Max', ['128GB', '256GB', '512GB', '1TB']),
  ('iPhone 13 Pro', ['128GB', '256GB', '512GB', '1TB']),
  ('iPhone 13', ['128GB', '256GB', '512GB']),
  ('iPhone 13 mini', ['128GB', '256GB', '512GB']),
  ('iPhone 12 Pro Max', ['128GB', '256GB', '512GB']),
  ('iPhone 12 Pro', ['128GB', '256GB', '512GB']),
  ('iPhone 12', ['64GB', '128GB', '256GB']),
  ('iPhone 12 mini', ['64GB', '128GB', '256GB']),
  ('iPhone SE (2020)', ['64GB', '128GB', '256GB']),
  ('iPhone 11 Pro Max', ['64GB', '256GB', '512GB']),
  ('iPhone 11 Pro', ['64GB', '256GB', '512GB']),
  ('iPhone 11', ['64GB', '128GB', '256GB']),
  ('iPhone XS Max', ['64GB', '256GB', '512GB']),
  ('iPhone XS', ['64GB', '256GB', '512GB']),
  ('iPhone XR', ['64GB', '128GB', '256GB']),
  ('iPhone X', ['64GB', '256GB']),
  ('iPhone 8 Plus', ['64GB', '128GB', '256GB']),
  ('iPhone 8', ['64GB', '128GB', '256GB']),
  ('iPhone 7 Plus', ['32GB', '128GB', '256GB']),
  ('iPhone 7', ['32GB', '128GB', '256GB']),
];

const kAllStorages = ['32GB', '64GB', '128GB', '256GB', '512GB', '1TB', '2TB'];

const kRegions = ['iBox', 'WiFi Only', 'Beacukai', 'All Op'];

/// Minus yang umum ditemui pada iPhone bekas.
const kPhoneMinus = [
  'Dent',
  'Lecet',
  'Retak kaca belakang',
  'Retak layar',
  'LCD ganti',
  'Baterai ganti',
  'Face ID mati',
  'True Tone mati',
  'Kamera bermasalah',
  'Speaker / mic',
  'Sinyal bermasalah',
  'Shadow / burn-in',
];

List<String> storagesOf(String model) =>
    kIphones.where((e) => e.$1 == model).firstOrNull?.$2 ?? kAllStorages;

/// Apakah nama barang tampak seperti iPhone.
bool looksLikeIphone(String name) => name.toLowerCase().contains('iphone');

/// Warna BH: ≥85 sehat, 80–84 cukup, <80 perlu ganti baterai.
Color bhColor(int bh) => bh >= 85
    ? const Color(0xFF2E7D32)
    : bh >= 80
        ? const Color(0xFFEF6C00)
        : const Color(0xFFC62828);

/// Isian spesifikasi iPhone. Mengubah [spec] langsung lalu memanggil
/// [onChanged] (dipakai untuk memperbarui nama barang otomatis).
class PhoneSpecEditor extends StatefulWidget {
  final PhoneSpec spec;
  final VoidCallback? onChanged;
  const PhoneSpecEditor({super.key, required this.spec, this.onChanged});

  @override
  State<PhoneSpecEditor> createState() => _PhoneSpecEditorState();
}

class _PhoneSpecEditorState extends State<PhoneSpecEditor> {
  late final _bh = TextEditingController(
      text: widget.spec.bh > 0 ? '${widget.spec.bh}' : '');
  late final _note = TextEditingController(text: widget.spec.note);

  PhoneSpec get s => widget.spec;

  void _set(VoidCallback f) {
    setState(f);
    widget.onChanged?.call();
  }

  @override
  void dispose() {
    _bh.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickModel() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ModelPicker(current: s.model),
    );
    if (picked == null) return;
    _set(() {
      s.model = picked;
      // storage yang tidak tersedia di model baru dikosongkan
      if (!storagesOf(picked).contains(s.storage)) s.storage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    const gap = SizedBox(height: 12);
    final bh = s.bh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _pickModel,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Tipe iPhone',
              prefixIcon: Icon(Icons.phone_iphone_rounded),
              suffixIcon: Icon(Icons.arrow_drop_down_rounded),
            ),
            child: Text(s.model.isEmpty ? 'Pilih tipe…' : s.model,
                style: s.model.isEmpty
                    ? TextStyle(color: cs.onSurfaceVariant)
                    : const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        gap,
        Text('Storage', style: tt.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: storagesOf(s.model)
              .map((g) => ChoiceChip(
                    label: Text(g),
                    selected: s.storage == g,
                    onSelected: (v) => _set(() => s.storage = v ? g : ''),
                  ))
              .toList(),
        ),
        gap,
        Text('Garansi / asal', style: tt.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: kRegions
              .map((r) => ChoiceChip(
                    label: Text(r),
                    selected: s.region == r,
                    onSelected: (v) => _set(() => s.region = v ? r : ''),
                  ))
              .toList(),
        ),
        gap,
        TextField(
          controller: _bh,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          onChanged: (v) =>
              _set(() => s.bh = (int.tryParse(v) ?? 0).clamp(0, 100)),
          decoration: InputDecoration(
            labelText: 'Battery health (BH)',
            hintText: 'mis. 87',
            suffixText: '%',
            prefixIcon: Icon(Icons.battery_5_bar_rounded,
                color: bh > 0 ? bhColor(bh) : null),
            helperText: bh == 0
                ? null
                : bh >= 85
                    ? 'Baterai sehat'
                    : bh >= 80
                        ? 'Cukup'
                        : 'Di bawah 80% — "Service" baterai',
            helperStyle: bh > 0 ? TextStyle(color: bhColor(bh)) : null,
          ),
        ),
        gap,
        Text('Minus / kondisi', style: tt.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            FilterChip(
              label: const Text('Mulus, no minus'),
              selected: s.minus.isEmpty,
              onSelected: (_) => _set(() => s.minus.clear()),
            ),
            ...{...kPhoneMinus, ...s.minus}.map((m) => FilterChip(
                  label: Text(m),
                  selected: s.minus.contains(m),
                  onSelected: (v) =>
                      _set(() => v ? s.minus.add(m) : s.minus.remove(m)),
                )),
          ],
        ),
        gap,
        TextField(
          controller: _note,
          maxLines: 2,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (v) => _set(() => s.note = v.trim()),
          decoration: const InputDecoration(
            labelText: 'Keterangan minus (opsional)',
            hintText: 'mis. dent halus pojok kanan atas',
            prefixIcon: Icon(Icons.report_gmailerrorred_rounded),
          ),
        ),
      ],
    );
  }
}

class _ModelPicker extends StatefulWidget {
  final String current;
  const _ModelPicker({required this.current});

  @override
  State<_ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends State<_ModelPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = kIphones
        .map((e) => e.$1)
        .where((m) => q.isEmpty || m.toLowerCase().contains(q))
        .toList();
    final custom = _q.trim().isNotEmpty &&
        !kIphones.any((e) => e.$1.toLowerCase() == q);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 0, 16, 8 + MediaQuery.of(context).viewInsets.bottom * 0),
          child: TextField(
            autofocus: false,
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(
              hintText: 'Cari tipe, mis. 13 pro',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.only(
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom),
            children: [
              if (custom)
                ListTile(
                  leading: const Icon(Icons.add_rounded),
                  title: Text('Pakai "${_q.trim()}"'),
                  onTap: () => Navigator.pop(context, _q.trim()),
                ),
              ...list.map((m) => ListTile(
                    leading: const Icon(Icons.phone_iphone_rounded),
                    title: Text(m),
                    subtitle: Text(storagesOf(m).join(' / ')),
                    trailing: m == widget.current
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () => Navigator.pop(context, m),
                  )),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Chip ringkas spesifikasi iPhone untuk kartu & detail barang.
class PhoneSpecChips extends StatelessWidget {
  final PhoneSpec spec;
  final bool dense;
  const PhoneSpecChips({super.key, required this.spec, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget chip(String t, {Color? color, IconData? icon}) {
      final c = color ?? cs.onSurfaceVariant;
      return Container(
        padding: EdgeInsets.symmetric(
            horizontal: dense ? 7 : 9, vertical: dense ? 2 : 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: c),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(t,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: dense ? 11.5 : 12.5,
                    color: c,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );
    }

    final s = spec;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (s.storage.isNotEmpty) chip(s.storage, icon: Icons.sd_storage_rounded),
        if (s.region.isNotEmpty)
          chip(s.region,
              color: s.region == 'iBox' ? cs.primary : cs.tertiary,
              icon: Icons.verified_rounded),
        if (s.bh > 0)
          chip('BH ${s.bh}%',
              color: bhColor(s.bh), icon: Icons.battery_5_bar_rounded),
        if (s.minus.isEmpty && s.note.isEmpty)
          chip('No minus', color: const Color(0xFF2E7D32))
        else
          ...s.minus.map((m) =>
              chip(m, color: const Color(0xFFC62828), icon: Icons.error_outline_rounded)),
      ],
    );
  }
}
