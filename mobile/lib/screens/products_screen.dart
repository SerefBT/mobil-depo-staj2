import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'stock_screen.dart';
import 'insight_screens.dart';

class ProductsScreen extends StatefulWidget {
  final bool criticalOnly, standalone;
  const ProductsScreen({
    super.key,
    this.criticalOnly = false,
    this.standalone = false,
  });
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String search = '';
  Timer? timer;
  int page = 1, revision = 0;
  int? category, warehouse, shelf;
  bool out = false, includeInactive = false;
  late bool critical;
  @override
  void initState() {
    super.initState();
    critical = widget.criticalOnly;
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> filters() async {
    try {
      final api = context.read<AppState>().api;
      final data = await Future.wait([
        api.list('/categories'),
        api.list('/warehouses'),
        api.list('/shelves'),
      ]);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModal) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.viewInsetsOf(ctx).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle('Ürünleri filtrele'),
                    ChoiceField(
                      label: 'Kategori',
                      required: false,
                      value: category,
                      items: data[0],
                      display: (x) => x.s('name'),
                      onChanged: (v) => setModal(() => category = v),
                    ),
                    const SizedBox(height: 14),
                    ChoiceField(
                      label: 'Depo',
                      required: false,
                      value: warehouse,
                      items: data[1],
                      display: (x) => x.s('name'),
                      onChanged: (v) => setModal(() {
                        warehouse = v;
                        shelf = null;
                      }),
                    ),
                    const SizedBox(height: 14),
                    ChoiceField(
                      label: 'Raf',
                      required: false,
                      value: shelf,
                      items: data[2]
                          .where(
                            (x) =>
                                warehouse == null ||
                                x.n('warehouseId') == warehouse,
                          )
                          .toList(),
                      display: (x) => '${x.s('warehouse')} / ${x.s('code')}',
                      onChanged: (v) => setModal(() => shelf = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Yalnızca kritik stoklar'),
                      value: critical,
                      onChanged: (v) => setModal(() => critical = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Stokta olmayanlar'),
                      value: out,
                      onChanged: (v) => setModal(() => out = v),
                    ),
                    if (context.read<AppState>().user!.isOperator)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Pasif ürünleri de göster'),
                        value: includeInactive,
                        onChanged: (v) => setModal(() => includeInactive = v),
                      ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Filtreleri uygula'),
                    ),
                    TextButton(
                      onPressed: () => setModal(() {
                        category = null;
                        warehouse = null;
                        shelf = null;
                        critical = false;
                        out = false;
                        includeInactive = false;
                      }),
                      child: const Text('Filtreleri temizle'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      if (mounted) setState(() => page = 1);
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      critical ? 'Kritik stoklar' : 'Ürün envanteri',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (app.user!.isOperator)
                    IconButton.filledTonal(
                      tooltip: 'Ürün ekle',
                      onPressed: () async {
                        await go(context, const ProductFormScreen());
                        if (mounted) setState(() => revision++);
                      },
                      icon: const Icon(Icons.add),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                onChanged: (v) {
                  timer?.cancel();
                  timer = Timer(const Duration(milliseconds: 350), () {
                    if (mounted) {
                      setState(() {
                        search = v;
                        page = 1;
                      });
                    }
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Ad, kod, barkod veya konum ara',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Filtreler',
                    onPressed: filters,
                    icon: Badge(
                      isLabelVisible:
                          category != null ||
                          warehouse != null ||
                          shelf != null ||
                          out ||
                          critical,
                      child: const Icon(Icons.tune),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RemoteView(
            key: ValueKey(
              '$revision:$search:$page:$critical:$out:$category:$warehouse:$shelf:$includeInactive',
            ),
            load: () => app.api.get(
              '/products',
              query: {
                'search': search,
                'critical': critical,
                'outOfStock': out,
                'includeInactive': includeInactive,
                'page': page,
                if (category != null) 'categoryId': category,
                if (warehouse != null) 'warehouseId': warehouse,
                if (shelf != null) 'shelfId': shelf,
              },
            ),
            builder: (raw, reload) {
              final d = asJson(raw);
              final items = asList(d['items']);
              return PageBody(
                children: [
                  Text(
                    '${quantity(d['total'])} ürün bulundu',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (items.isEmpty)
                    const EmptyState(
                      'Ürün bulunamadı',
                      'Aramayı veya filtrelerinizi değiştirebilirsiniz.',
                    ),
                  for (final p in items)
                    ProductTile(
                      p,
                      onTap: () async {
                        await go(context, ProductDetailScreen(id: p.n('id')));
                        await reload();
                      },
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: page > 1
                            ? () => setState(() => page--)
                            : null,
                        child: const Text('Önceki'),
                      ),
                      Text('Sayfa $page'),
                      TextButton(
                        onPressed: page * 40 < d.n('total')
                            ? () => setState(() => page++)
                            : null,
                        child: const Text('Sonraki'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 70),
                ],
              );
            },
          ),
        ),
      ],
    );
    return widget.standalone
        ? Scaffold(
            appBar: AppBar(title: const Text('Stok takibi')),
            body: content,
          )
        : content;
  }
}

class ProductDetailScreen extends StatelessWidget {
  final int id;
  const ProductDetailScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Ürün detayı')),
      body: RemoteView(
        load: () async => await Future.wait([
          app.api.get('/products/$id'),
          app.api.list('/products/$id/batches'),
          if (app.user!.isOperator) app.api.get('/stock/movements/$id'),
        ]),
        builder: (raw, reload) {
          final data = raw as List;
          final p = asJson(data[0]);
          final batches = data[1] as List<Json>;
          final movements = app.user!.isOperator
              ? asList(asJson(data[2])['items'])
              : <Json>[];
          return PageBody(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.s('category').toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p.s('name'),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(p.s('productCode')),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'QR etiketi',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Ürün QR etiketi'),
                        content: SizedBox(
                          width: 240,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              QrImageView(
                                data: p.s('barcode'),
                                backgroundColor: Colors.white,
                                size: 220,
                              ),
                              Text(p.s('barcode')),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Kapat'),
                          ),
                        ],
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_2),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MEVCUT STOK',
                        style: TextStyle(fontSize: 11, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${quantity(p['quantity'])} ${p.s('measureUnit')}',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      StatusPill(
                        p.b('isCritical')
                            ? 'Kritik • Minimum ${p.n('minimumStock')}'
                            : 'Minimum ${p.n('minimumStock')}',
                        alert: p.b('isCritical'),
                      ),
                      if (!p.b('isActive'))
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: StatusPill('Pasif ürün', alert: true),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text('${p.s('warehouse')} / ${p.s('aisle')}'),
                  subtitle: Text('Raf ${p.s('shelf')} • ${p.s('qrValue')}'),
                ),
              ),
              if (p.s('description').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(p.s('description')),
                ),
              if (app.user!.isOperator) ...[
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: p.b('isActive')
                          ? () async {
                              await go(
                                context,
                                StockScreen(inbound: true, productId: id),
                              );
                              await reload();
                            }
                          : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Stok girişi'),
                    ),
                    OutlinedButton.icon(
                      onPressed: p.b('isActive')
                          ? () async {
                              await go(
                                context,
                                StockScreen(inbound: false, productId: id),
                              );
                              await reload();
                            }
                          : null,
                      icon: const Icon(Icons.remove),
                      label: const Text('Stok çıkışı'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await go(context, ProductFormScreen(product: p));
                        await reload();
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Düzenle'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              const SectionTitle(
                'Partiler ve son kullanma',
                subtitle: 'Çıkışta en yakın SKT önce kullanılır (FEFO).',
              ),
              if (batches.isEmpty)
                const Text('Bu ürün için henüz parti girişi yok.'),
              for (final b in batches)
                Card(
                  child: ListTile(
                    title: Text(b.s('batchNumber')),
                    subtitle: Text(dateOnly(b['expiryDate'])),
                    trailing: Text(
                      '${quantity(b['quantity'])} ${p.s('measureUnit')}',
                    ),
                  ),
                ),
              if (app.user!.isOperator) ...[
                const SizedBox(height: 20),
                SectionTitle(
                  'Stok geçmişi',
                  trailing: TextButton(
                    onPressed: () =>
                        go(context, MovementsScreen(productId: id)),
                    child: const Text('Tümü'),
                  ),
                ),
                for (final m in movements.take(6)) MovementTile(m),
              ],
              const SizedBox(height: 20),
              Text(
                'Oluşturma: ${dateTime(p['createdAt'])}\nSon güncelleme: ${dateTime(p['updatedAt'])}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ProductFormScreen extends StatefulWidget {
  final Json? product;
  const ProductFormScreen({super.key, this.product});
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController code,
      barcode,
      name,
      description,
      unit,
      minimum;
  int? category, shelf;
  bool active = true, busy = false;
  @override
  void initState() {
    super.initState();
    final p = widget.product ?? {};
    code = TextEditingController(text: p.s('productCode'));
    barcode = TextEditingController(text: p.s('barcode'));
    name = TextEditingController(text: p.s('name'));
    description = TextEditingController(text: p.s('description'));
    unit = TextEditingController(text: p.s('measureUnit', 'Adet'));
    minimum = TextEditingController(text: p.s('minimumStock', '0'));
    category = p['categoryId'] as int?;
    shelf = p['shelfId'] as int?;
    active = p['isActive'] as bool? ?? true;
  }

  @override
  void dispose() {
    for (final c in [code, barcode, name, description, unit, minimum]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final api = context.read<AppState>().api;
      final d = {
        'productCode': code.text.trim(),
        'barcode': barcode.text.trim(),
        'name': name.text.trim(),
        'description': description.text.trim(),
        'measureUnit': unit.text.trim(),
        'minimumStock': int.parse(minimum.text),
        'categoryId': category,
        'shelfId': shelf,
        'isActive': active,
      };
      if (widget.product == null) {
        await api.post('/products', d);
      } else {
        await api.put('/products/${widget.product!.n('id')}', d);
      }
      if (mounted) {
        toast(context, 'Ürün kaydedildi.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Yeni ürün' : 'Ürünü düzenle'),
      ),
      body: RemoteView(
        load: () =>
            Future.wait([api.list('/categories'), api.list('/shelves')]),
        builder: (raw, reload) {
          final data = raw as List;
          return Form(
            key: form,
            child: PageBody(
              children: [
                const SectionTitle(
                  'Malzeme bilgileri',
                  subtitle: 'Stok miktarı, stok hareketleriyle güncellenir.',
                ),
                _field(name, 'Ürün adı', 160),
                _field(code, 'Ürün kodu', 64),
                _field(barcode, 'Barkod / QR değeri', 128),
                _field(description, 'Açıklama', 2000, optional: true),
                ChoiceField(
                  label: 'Kategori',
                  value: category,
                  items: data[0] as List<Json>,
                  display: (x) => x.s('name'),
                  onChanged: (v) => setState(() => category = v),
                ),
                const SizedBox(height: 16),
                _field(unit, 'Ölçü birimi', 32),
                TextFormField(
                  controller: minimum,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Minimum stok'),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 0 || n > 100000000
                        ? '0–100.000.000 arasında tam sayı girin.'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                ChoiceField(
                  label: 'Depo / Koridor / Raf',
                  value: shelf,
                  items: data[1] as List<Json>,
                  display: (x) =>
                      '${x.s('warehouse')} / ${x.s('aisle')} / ${x.s('code')}',
                  onChanged: (v) => setState(() => shelf = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ürün aktif'),
                  value: active,
                  onChanged: (v) => setState(() => active = v),
                ),
                const SizedBox(height: 16),
                BusyButton(busy: busy, label: 'Ürünü kaydet', action: save),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    int max, {
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: c,
      maxLength: max,
      decoration: InputDecoration(labelText: label, counterText: ''),
      validator: optional
          ? null
          : (v) => v == null || v.trim().length < (c == unit ? 1 : 2)
                ? 'En az ${c == unit ? 1 : 2} karakter girin.'
                : null,
    ),
  );
}
