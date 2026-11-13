import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class StockScreen extends StatefulWidget {
  final bool inbound;
  final int? productId;
  const StockScreen({super.key, required this.inbound, this.productId});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(),
      description = TextEditingController(),
      batch = TextEditingController();
  final operationId = const Uuid().v4();
  int? selected, shelf;
  DateTime? expiry;
  bool busy = false;
  late String type;
  List<Json> products = [], shelves = [], batches = [];
  @override
  void initState() {
    super.initState();
    selected = widget.productId;
    type = widget.inbound ? 'In' : 'Out';
  }

  @override
  void dispose() {
    amount.dispose();
    description.dispose();
    batch.dispose();
    super.dispose();
  }

  Future<void> select(int? id) async {
    setState(() {
      selected = id;
      shelf =
          products.where((p) => p.n('id') == id).firstOrNull?['shelfId']
              as int?;
      batches = [];
    });
    if (id != null) {
      try {
        final list = await context.read<AppState>().api.list(
          '/products/$id/batches',
        );
        if (mounted && selected == id) setState(() => batches = list);
      } catch (e) {
        if (mounted) toast(context, e.toString(), error: true);
      }
    }
  }

  Future<dynamic> load() async {
    final api = context.read<AppState>().api;
    products = await api.allProducts();
    shelves = await api.list('/shelves');
    if (selected != null) {
      shelf =
          products.where((p) => p.n('id') == selected).firstOrNull?['shelfId']
              as int?;
      batches = await api.list('/products/$selected/batches');
    }
    return true;
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final result = asJson(
        await context.read<AppState>().api.post(
          '/stock/${widget.inbound ? 'in' : 'out'}',
          {
            'productId': selected,
            'quantity': int.parse(amount.text),
            'description': description.text.trim(),
            'operationId': operationId,
            'type': type,
            if (widget.inbound) 'shelfId': shelf,
            if (widget.inbound && batch.text.trim().isNotEmpty)
              'batchNumber': batch.text.trim(),
            if (widget.inbound && expiry != null)
              'expiryDate': expiry!.toIso8601String().split('T').first,
          },
        ),
      );
      if (mounted) {
        toast(
          context,
          'Stok güncellendi: ${result.n('previousStock')} → ${result.n('nextStock')}',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.inbound ? 'Stok girişi' : 'Stok çıkışı')),
    body: RemoteView(
      load: load,
      builder: (data, reload) {
        final current = products
            .where((p) => p.n('id') == selected)
            .firstOrNull;
        return Form(
          key: form,
          child: PageBody(
            children: [
              SectionTitle(
                widget.inbound ? 'Yeni sevkiyat kaydı' : 'Malzeme çıkış kaydı',
                subtitle: 'Her işlem stok geçmişine kaydedilir.',
              ),
              ChoiceField(
                label: 'Ürün',
                value: selected,
                items: products,
                display: (p) =>
                    '${p.s('name')} (${p.n('quantity')} ${p.s('measureUnit')})',
                onChanged: select,
              ),
              if (current != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(
                        'Mevcut stok: ${quantity(current['quantity'])} ${current.s('measureUnit')}',
                      ),
                      subtitle: Text(
                        '${current.s('warehouse')} / ${current.s('aisle')} / ${current.s('shelf')}',
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amount,
                validator: positiveNumber,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Miktar'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Hareket türü'),
                items:
                    (widget.inbound
                            ? ['In', 'Return', 'Correction', 'Count']
                            : ['Out', 'Correction', 'Count'])
                        .map(
                          (x) => DropdownMenuItem(
                            value: x,
                            child: Text(movementLabel(x)),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => type = v!),
              ),
              const SizedBox(height: 16),
              if (widget.inbound) ...[
                ChoiceField(
                  label: 'Depo / Koridor / Raf',
                  value: shelf,
                  items: shelves,
                  display: (s) =>
                      '${s.s('warehouse')} / ${s.s('aisle')} / ${s.s('code')}',
                  onChanged: (v) => setState(() => shelf = v),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: batch,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Parti numarası (isteğe bağlı)',
                    helperText: 'Boş bırakılırsa otomatik parti oluşturulur.',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(
                    expiry == null
                        ? 'Son kullanma tarihi ekle'
                        : dateOnly(expiry!.toIso8601String()),
                  ),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate:
                          expiry ??
                          DateTime.now().add(const Duration(days: 180)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (d != null && mounted) setState(() => expiry = d);
                  },
                  trailing: expiry == null
                      ? const Icon(Icons.add)
                      : IconButton(
                          onPressed: () => setState(() => expiry = null),
                          icon: const Icon(Icons.close),
                        ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                const Text(
                  'FEFO: kullanılabilir partiler, en yakın SKT önce olacak şekilde otomatik seçilir. Süresi geçmiş stok yalnızca düzeltme / sayım farkı ile düşülebilir.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                for (final b
                    in batches.where((x) => x.n('quantity') > 0).take(5))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(b.s('batchNumber')),
                    subtitle: Text(dateOnly(b['expiryDate'])),
                    trailing: Text('${b.n('quantity')}'),
                  ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: description,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                validator: (v) => v == null || v.trim().length < 3
                    ? 'En az 3 karakter açıklama / neden girin.'
                    : null,
                decoration: InputDecoration(
                  labelText: widget.inbound
                      ? 'Açıklama'
                      : 'Çıkış nedeni / açıklama',
                ),
              ),
              const SizedBox(height: 20),
              BusyButton(
                busy: busy,
                label: widget.inbound ? 'Stoğa ekle' : 'Stoktan düş',
                icon: widget.inbound ? Icons.add : Icons.remove,
                action: save,
              ),
            ],
          ),
        );
      },
    ),
  );
}
