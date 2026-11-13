import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});
  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  String? status;
  bool urgent = false;
  int page = 1, revision = 0;
  int? unit;
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      app.user!.isOperator ? 'Malzeme talepleri' : 'Taleplerim',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (!app.user!.isOperator)
                    IconButton.filledTonal(
                      tooltip: 'Talep oluştur',
                      onPressed: () async {
                        await go(context, const RequestFormScreen());
                        if (mounted) setState(() => revision++);
                      },
                      icon: const Icon(Icons.add),
                    ),
                  if (app.user!.isOperator)
                    IconButton(
                      tooltip: 'Birime göre filtrele',
                      onPressed: () async {
                        try {
                          final units = await app.api.list('/units');
                          if (!context.mounted) return;
                          final value = await showDialog<int>(
                            context: context,
                            builder: (ctx) => SimpleDialog(
                              title: const Text('Birim seçin'),
                              children: [
                                SimpleDialogOption(
                                  onPressed: () => Navigator.pop(ctx, 0),
                                  child: const Text('Tüm birimler'),
                                ),
                                for (final u in units)
                                  SimpleDialogOption(
                                    onPressed: () =>
                                        Navigator.pop(ctx, u.n('id')),
                                    child: Text(u.s('name')),
                                  ),
                              ],
                            ),
                          );
                          if (value != null && mounted) {
                            setState(() {
                              unit = value == 0 ? null : value;
                              page = 1;
                            });
                          }
                        } catch (e) {
                          if (context.mounted) {
                            toast(context, e.toString(), error: true);
                          }
                        }
                      },
                      icon: const Icon(Icons.filter_alt_outlined),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Tümü'),
                      selected: status == null,
                      onSelected: (_) => setState(() {
                        status = null;
                        page = 1;
                      }),
                    ),
                    for (final s in [
                      'Pending',
                      'Approved',
                      'Preparing',
                      'Delivered',
                      'Cancelled',
                    ])
                      ChoiceChip(
                        label: Text(statusLabel(s)),
                        selected: status == s,
                        onSelected: (_) => setState(() {
                          status = s;
                          page = 1;
                        }),
                      ),
                    FilterChip(
                      label: const Text('Acil'),
                      selected: urgent,
                      onSelected: (v) => setState(() {
                        urgent = v;
                        page = 1;
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RemoteView(
            key: ValueKey('$revision:$status:$urgent:$unit:$page'),
            load: () => app.api.get(
              '/requests',
              query: {
                if (status != null) 'status': status,
                if (urgent) 'priority': 'Urgent',
                if (unit != null) 'unitId': unit,
                'page': page,
              },
            ),
            builder: (raw, reload) {
              final d = asJson(raw);
              final requests = asList(d['items']);
              return PageBody(
                children: [
                  Text('${d.n('total')} talep'),
                  const SizedBox(height: 16),
                  if (requests.isEmpty)
                    const EmptyState(
                      'Talep bulunmuyor',
                      'Yeni talepler veya filtreye uygun kayıtlar burada görünür.',
                      icon: Icons.assignment_outlined,
                    ),
                  for (final r in requests)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () async {
                            await go(
                              context,
                              RequestDetailScreen(id: r.n('id')),
                            );
                            await reload();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'TALEP #${r.n('id')}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Spacer(),
                                    StatusPill(
                                      statusLabel(r.s('status')),
                                      alert: r.s('priority') == 'Urgent',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  r.s('unit'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${(r['items'] as List).length} ürün • ${r.s('priority') == 'Urgent' ? 'Acil' : 'Normal'}',
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  dateTime(r['createdAt']),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
                      Text('$page'),
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
  }
}

class RequestDetailScreen extends StatefulWidget {
  final int id;
  const RequestDetailScreen({super.key, required this.id});
  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  bool busy = false;
  Future<void> action(String action, Future<void> Function() reload) async {
    if (action == 'deliver' || action == 'cancel') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            action == 'deliver'
                ? 'Talep teslim edilsin mi?'
                : 'Talep iptal edilsin mi?',
          ),
          content: Text(
            action == 'deliver'
                ? 'Bu talepteki tüm ürünler stoktan düşecek ve hareket geçmişine kaydedilecek.'
                : 'İptal edilen talep tekrar açılamaz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Onayla'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await context.read<AppState>().api.put('/requests/${widget.id}/$action');
      if (mounted) toast(context, 'Talep güncellendi.');
      await reload();
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text('Talep #${widget.id}')),
      body: RemoteView(
        load: () => app.api.get('/requests/${widget.id}'),
        builder: (raw, reload) {
          final r = asJson(raw);
          final status = r.s('status');
          final terminal = ['Delivered', 'Cancelled'].contains(status);
          return PageBody(
            children: [
              Row(
                children: [
                  StatusPill(statusLabel(status)),
                  const SizedBox(width: 8),
                  if (r.s('priority') == 'Urgent')
                    const StatusPill('Acil', alert: true),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                r.s('unit'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text('${r.s('user')} • ${dateTime(r['createdAt'])}'),
              const SizedBox(height: 12),
              if (r.s('description').isNotEmpty) Text(r.s('description')),
              const SizedBox(height: 24),
              const SectionTitle('İstenen malzemeler'),
              for (final i in asList(r['items']))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(i.s('product')),
                      subtitle: Text(
                        'Raf ${i.s('shelf')} • Mevcut ${i.n('available')} ${i.s('measureUnit')}',
                      ),
                      trailing: Text(
                        '${i.n('quantity')}\n${i.s('measureUnit')}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              if (app.user!.isOperator && !terminal) ...[
                if (status == 'Pending')
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => action('approve', reload),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Talebi onayla'),
                  ),
                const SizedBox(height: 10),
                if (['Pending', 'Approved'].contains(status))
                  BusyButton(
                    busy: busy,
                    label: 'Talebi hazırla',
                    icon: Icons.inventory_2_outlined,
                    action: () => action('prepare', reload),
                  ),
                if (status == 'Preparing')
                  BusyButton(
                    busy: busy,
                    label: 'Teslim et ve stoktan düş',
                    icon: Icons.local_shipping_outlined,
                    action: () => action('deliver', reload),
                  ),
              ],
              if (!terminal && (app.user!.isOperator || status == 'Pending'))
                TextButton(
                  onPressed: busy ? null : () => action('cancel', reload),
                  child: const Text('Talebi iptal et'),
                ),
              if (status == 'Delivered')
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.verified_outlined),
                    title: Text('Teslim tamamlandı'),
                    subtitle: Text(
                      'Stok düşümü ve hareket kayıtları oluşturuldu.',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DraftLine {
  int? product;
  final quantity = TextEditingController(text: '1');
  void dispose() => quantity.dispose();
}

class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key});
  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  final form = GlobalKey<FormState>();
  final description = TextEditingController();
  final clientId = const Uuid().v4();
  final lines = [_DraftLine()];
  bool urgent = false, busy = false;
  @override
  void dispose() {
    description.dispose();
    for (final line in lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (lines.map((l) => l.product).toSet().length != lines.length) {
      toast(context, 'Her ürünü yalnızca bir satırda seçin.', error: true);
      return;
    }
    setState(() => busy = true);
    try {
      final result = asJson(
        await context.read<AppState>().api.post('/requests', {
          'clientId': clientId,
          'priority': urgent ? 'Urgent' : 'Normal',
          'description': description.text.trim(),
          'items': lines
              .map(
                (l) => {
                  'productId': l.product,
                  'quantity': int.parse(l.quantity.text),
                },
              )
              .toList(),
        }),
      );
      if (mounted) {
        toast(context, 'Talep #${result.n('id')} oluşturuldu.');
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
    final app = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni malzeme talebi')),
      body: RemoteView(
        load: () => app.api.allProducts(),
        builder: (raw, reload) {
          final products = raw as List<Json>;
          return Form(
            key: form,
            child: PageBody(
              children: [
                SectionTitle(
                  app.user!.unit,
                  subtitle: 'Bir talebe birden fazla malzeme ekleyin.',
                ),
                for (var i = 0; i < lines.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Malzeme ${i + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                if (lines.length > 1)
                                  IconButton(
                                    tooltip: 'Satırı kaldır',
                                    onPressed: () {
                                      final removed = lines[i];
                                      setState(() => lines.removeAt(i));
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            removed.dispose();
                                          });
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ChoiceField(
                              label: 'Ürün',
                              value: lines[i].product,
                              items: products,
                              display: (p) =>
                                  '${p.s('name')} • ${p.n('quantity')} ${p.s('measureUnit')}',
                              onChanged: (v) =>
                                  setState(() => lines[i].product = v),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: lines[i].quantity,
                              validator: positiveNumber,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Talep miktarı',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: lines.length < 100
                      ? () => setState(() => lines.add(_DraftLine()))
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Başka malzeme ekle'),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Acil talep'),
                  subtitle: const Text(
                    'Öncelikli ihtiyaçlar için işaretleyin.',
                  ),
                  value: urgent,
                  onChanged: (v) => setState(() => urgent = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: description,
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Açıklama'),
                ),
                const SizedBox(height: 20),
                BusyButton(
                  busy: busy,
                  label: 'Talebi gönder',
                  icon: Icons.send_outlined,
                  action: save,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
