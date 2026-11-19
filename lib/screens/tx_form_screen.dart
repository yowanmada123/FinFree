import 'package:flutter/material.dart';

import '../format.dart';
import '../icons.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'categories_screen.dart';

class TxFormScreen extends StatefulWidget {
  final Txn? edit;
  final Txn? copyFrom;
  const TxFormScreen({super.key, this.edit, this.copyFrom});

  @override
  State<TxFormScreen> createState() => _TxFormScreenState();
}

class _TxFormScreenState extends State<TxFormScreen> {
  final s = AppStore.I;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _amountFocus = FocusNode();
  final _noteFocus = FocusNode();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _amountFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  TxType _type = TxType.expense;
  String? _categoryId;
  late String _walletId;
  String? _toWalletId;
  DateTime _date = DateTime.now();

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    _walletId = s.defaultWallet.id;
    final src = widget.edit ?? widget.copyFrom;
    if (src != null) {
      _fill(src);
      if (_isEdit) _date = src.date;
    } else {
      _categoryId = s.defaultCategory(_type)?.id;
    }
  }

  void _fill(Txn t) {
    _type = t.type;
    _categoryId = t.categoryId;
    _walletId = s.wallet(t.walletId) != null ? t.walletId : s.defaultWallet.id;
    _toWalletId = t.toWalletId;
    _amount.text = formatAmountInput(t.amount);
    _note.text = t.note;
  }

  void _setType(TxType t) {
    setState(() {
      _type = t;
      if (t == TxType.transfer) {
        _categoryId = null;
        _toWalletId ??=
            s.wallets.where((w) => w.id != _walletId).firstOrNull?.id;
      } else {
        final cur = s.category(_categoryId);
        if (cur == null || !cur.usableFor(t)) {
          _categoryId = s.defaultCategory(t)?.id;
        }
      }
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    final tm = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_date));
    setState(() => _date = DateTime(
        d.year, d.month, d.day, tm?.hour ?? _date.hour, tm?.minute ?? _date.minute));
  }

  Future<void> _save({bool again = false}) async {
    final amount = parseAmount(_amount.text);
    if (amount <= 0) {
      toast(context, 'Masukkan nominal terlebih dahulu');
      _amountFocus.requestFocus();
      return;
    }
    if (_type == TxType.transfer) {
      if (_toWalletId == null || _toWalletId == _walletId) {
        toast(context, 'Pilih dompet tujuan yang berbeda');
        return;
      }
    } else if (_categoryId == null) {
      toast(context, 'Pilih kategori');
      return;
    }
    final t = Txn(
      id: widget.edit?.id ?? newId(),
      type: _type,
      amount: amount,
      categoryId: _type == TxType.transfer ? null : _categoryId,
      walletId: _walletId,
      toWalletId: _type == TxType.transfer ? _toWalletId : null,
      note: _note.text.trim(),
      date: _date,
    );
    await s.upsertTxn(t);
    if (!mounted) return;
    if (again) {
      toast(context, 'Tersimpan: ${rupiah(amount)}');
      setState(() {
        _amount.clear();
        _note.clear();
        _date = DateTime.now();
      });
      _amountFocus.requestFocus();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    if (await confirm(context, 'Hapus transaksi?', 'Tindakan ini permanen.')) {
      await s.deleteTxn(widget.edit!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = typeColor(_type, context);
    final templates = _isEdit ? <Txn>[] : s.recentTemplates(_type);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Ubah Transaksi' : 'Catat Transaksi'),
        actions: [
          if (_isEdit)
            IconButton(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SegmentedButton<TxType>(
            segments: const [
              ButtonSegment(
                  value: TxType.expense,
                  label: Text('Keluar'),
                  icon: Icon(Icons.north_east_rounded)),
              ButtonSegment(
                  value: TxType.income,
                  label: Text('Masuk'),
                  icon: Icon(Icons.south_west_rounded)),
              ButtonSegment(
                  value: TxType.transfer,
                  label: Text('Transfer'),
                  icon: Icon(Icons.sync_alt_rounded)),
            ],
            selected: {_type},
            onSelectionChanged: (v) => _setType(v.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            focusNode: _amountFocus,
            autofocus: !_isEdit,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.w700, color: color),
            decoration: InputDecoration(
              prefixText: 'Rp ',
              prefixStyle: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w700, color: color),
              hintText: '0',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [10000, 20000, 50000, 100000].map((v) {
              return ActionChip(
                label: Text('+${compact(v)}'),
                onPressed: () => setState(() => _amount.text =
                    formatAmountInput(parseAmount(_amount.text) + v)),
              );
            }).toList(),
          ),
          if (templates.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Catat ulang cepat',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: templates.map((t) {
                  final c = s.category(t.categoryId);
                  final label = t.note.isNotEmpty
                      ? t.note
                      : (c?.name ?? 'Transfer');
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(iconOf(c?.icon ?? 'refund'), size: 18),
                      label: Text('$label • ${compact(t.amount)}'),
                      onPressed: () => setState(() => _fill(t)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_type == TxType.transfer) ...[
            _walletDropdown('Dari dompet', _walletId,
                (v) => setState(() => _walletId = v!)),
            const SizedBox(height: 12),
            _walletDropdown('Ke dompet', _toWalletId,
                (v) => setState(() => _toWalletId = v)),
          ] else ...[
            Row(
              children: [
                Text('Kategori',
                    style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CategoriesScreen(initial: _type)));
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
                  label: const Text('Kelola'),
                ),
              ],
            ),
            _categoryGrid(),
            const SizedBox(height: 12),
            _walletDropdown(
                'Dompet', _walletId, (v) => setState(() => _walletId = v!)),
          ],
          const SizedBox(height: 12),
          _noteField(),
          const SizedBox(height: 12),
          ListTile(
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: const Icon(Icons.event_rounded),
            title: Text(dfDay.format(_date)),
            subtitle: Text('Pukul ${dfTime.format(_date)}'),
            trailing: const Icon(Icons.edit_calendar_rounded),
            onTap: _pickDate,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              if (!_isEdit) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _save(again: true),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    child: const Text('Simpan & lagi'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryGrid() {
    final cats = s.categoriesOf(_type);
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.9,
      children: cats.map((c) {
        final sel = c.id == _categoryId;
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _categoryId = c.id),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: sel ? Color(c.color) : Colors.transparent,
                width: 2,
              ),
              color: sel ? Color(c.color).withValues(alpha: 0.08) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleIcon(icon: c.icon, color: c.color, size: 36),
                const SizedBox(height: 4),
                Text(
                  c.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _walletDropdown(
      String label, String? value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: s.wallet(value) != null ? value : null,
      decoration: InputDecoration(labelText: label),
      items: s.cashWallets
          .map((w) => DropdownMenuItem(
                value: w.id,
                child: Row(
                  children: [
                    CircleIcon(icon: w.icon, color: w.color, size: 28),
                    const SizedBox(width: 10),
                    Text(w.name),
                    const SizedBox(width: 8),
                    Text(money(s.walletBalance(w.id)),
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _noteField() {
    return RawAutocomplete<String>(
      textEditingController: _note,
      focusNode: _noteFocus,
      optionsBuilder: (v) =>
          s.noteSuggestions(v.text, categoryId: _categoryId),
      fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
        controller: controller,
        focusNode: focus,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Catatan (opsional)',
          prefixIcon: Icon(Icons.sticky_note_2_outlined),
        ),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 360),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: options
                  .map((o) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.history_rounded, size: 18),
                        title: Text(o),
                        onTap: () => onSelected(o),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}
