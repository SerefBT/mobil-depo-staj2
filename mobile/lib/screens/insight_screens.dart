import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'products_screen.dart';

Future<void> exportCsv(BuildContext context, DateTime from, DateTime to) async {
  try {
    final api = context.read<AppState>().api;
    final bytes = await api.request(
      'GET',
      '/reports/stock-movements.csv',
      query: {
        'from': from.toIso8601String().split('T').first,
        'to': to.toIso8601String().split('T').first,
      },
      responseType: ResponseType.bytes,
    );
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        title: 'Stok hareketleri',
        files: [
          XFile.fromData(
            Uint8List.fromList(List<int>.from(bytes as List)),
            mimeType: 'text/csv',
            name: 'stok-hareketleri.csv',
          ),
        ],
        fileNameOverrides: ['stok-hareketleri.csv'],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  } catch (e) {
    if (context.mounted) toast(context, e.toString(), error: true);
  }
}

class MovementsScreen extends StatefulWidget {
  final int? productId;
  const MovementsScreen({super.key, this.productId});
  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen> {
  int page = 1;
  DateTime from = DateTime.now().subtract(const Duration(days: 30)),
      to = DateTime.now();
  Future<void> dates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: from, end: to),
    );
    if (range != null && mounted) {
      setState(() {
        from = range.start;
        to = range.end;
        page = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok hareket geçmişi'),
        actions: [
          if (widget.productId == null) ...[
            IconButton(
              tooltip: 'Tarih aralığı',
              onPressed: dates,
              icon: const Icon(Icons.date_range_outlined),
            ),
            IconButton(
              tooltip: 'CSV paylaş',
              onPressed: () => exportCsv(context, from, to),
              icon: const Icon(Icons.ios_share),
            ),
          ],
        ],
      ),
      body: RemoteView(
        key: ValueKey('$page:$from:$to'),
        load: () => api.get(
          widget.productId == null
              ? '/reports/stock-movements'
              : '/stock/movements/${widget.productId}',
          query: {
            'page': page,
            if (widget.productId == null) ...{
              'from': from.toIso8601String().split('T').first,
              'to': to.toIso8601String().split('T').first,
            },
          },
        ),
        builder: (raw, reload) {
          final data = asJson(raw);
          final items = asList(data['items']);
          return PageBody(
            children: [
              SectionTitle(
                '${data.n('total')} stok hareketi',
                subtitle: widget.productId == null
                    ? '${dateOnly(from.toIso8601String())} – ${dateOnly(to.toIso8601String())}'
                    : 'Ürünün tüm stok hareketleri',
              ),
              if (items.isEmpty)
                const EmptyState(
                  'Hareket bulunamadı',
                  'Seçilen aralıkta stok işlemi yapılmamış.',
                ),
              for (final m in items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MovementTile(m),
                        Text(
                          '${movementLabel(m.s('type'))} • ${m.n('previousStock')} → ${m.n('nextStock')} • ${m.s('user')}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        if (m['requestId'] != null)
                          Text(
                            'Talep #${m.n('requestId')}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: page > 1 ? () => setState(() => page--) : null,
                    child: const Text('Önceki'),
                  ),
                  Text('Sayfa $page'),
                  TextButton(
                    onPressed: page * 50 < data.n('total')
                        ? () => setState(() => page++)
                        : null,
                    child: const Text('Sonraki'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime from = DateTime.now().subtract(const Duration(days: 30)),
      to = DateTime.now();
  bool exporting = false;
  Future<void> dates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: from, end: to),
    );
    if (range != null && mounted) {
      setState(() {
        from = range.start;
        to = range.end;
      });
    }
  }

  Future<void> export() async {
    setState(() => exporting = true);
    await exportCsv(context, from, to);
    if (mounted) setState(() => exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlar ve analiz'),
        actions: [
          IconButton(
            tooltip: 'Tarih aralığı',
            onPressed: dates,
            icon: const Icon(Icons.date_range_outlined),
          ),
        ],
      ),
      body: RemoteView(
        key: ValueKey('$from:$to'),
        load: () => api.get(
          '/reports/summary',
          query: {
            'from': from.toIso8601String().split('T').first,
            'to': to.toIso8601String().split('T').first,
          },
        ),
        builder: (raw, reload) {
          final d = asJson(raw);
          final top = asList(d['topProducts']),
              daily = asList(d['daily']),
              units = asList(d['byUnit']),
              expiring = asList(d['expiring']);
          final max = top.isEmpty ? 1 : top.first.n('quantity');
          return PageBody(
            children: [
              SectionTitle(
                'Operasyon raporu',
                subtitle:
                    '${dateOnly(from.toIso8601String())} – ${dateOnly(to.toIso8601String())}',
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: exporting ? null : export,
                    icon: exporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    label: const Text('CSV dışa aktar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => go(
                      context,
                      const ProductsScreen(
                        criticalOnly: true,
                        standalone: true,
                      ),
                    ),
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: const Text('Kritik stoklar'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SectionTitle(
                'Günlük stok akışı',
                subtitle: 'Giriş / çıkış miktarları',
              ),
              if (daily.isEmpty) const Text('Bu tarih aralığında hareket yok.'),
              for (final day in daily)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      title: Text(dateOnly(day['date'])),
                      subtitle: Text('+${quantity(day['in'])} giriş'),
                      trailing: Text(
                        '−${quantity(day['out'])} çıkış',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              const SectionTitle('En çok kullanılan malzemeler'),
              if (top.isEmpty) const Text('Çıkış kaydı bulunamadı.'),
              for (final p in top)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(p.s('name'))),
                          Text(
                            quantity(p['quantity']),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (p.n('quantity') / (max == 0 ? 1 : max)).clamp(
                          0.0,
                          1.0,
                        ),
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              const SectionTitle('Birimlere göre talepler'),
              for (final u in units)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.apartment_outlined),
                  title: Text(u.s('unit')),
                  subtitle: Text('${u.n('pending')} aktif talep'),
                  trailing: Text('${u.n('count')} toplam'),
                ),
              const SizedBox(height: 20),
              const SectionTitle(
                'Yaklaşan son kullanma tarihleri',
                subtitle: '30 / 15 / 7 gün uyarıları ve süresi geçen partiler',
              ),
              if (expiring.isEmpty)
                const EmptyState(
                  'Yaklaşan SKT yok',
                  'Önümüzdeki 30 günde süresi dolacak parti bulunmuyor.',
                  icon: Icons.event_available_outlined,
                ),
              for (final b in expiring)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.event_busy_outlined,
                        color: Colors.deepOrange,
                      ),
                      title: Text(b.s('product')),
                      subtitle: Text(
                        '${b.s('batchNumber')} • ${dateOnly(b['expiryDate'])}\n${b.n('quantity')} adet',
                      ),
                      trailing: StatusPill(
                        b.n('daysLeft') < 0
                            ? 'Süresi geçti'
                            : '${b.n('daysLeft')} gün',
                        alert: b.n('daysLeft') <= 7,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => go(context, const MovementsScreen()),
                icon: const Icon(Icons.history),
                label: const Text('Tüm hareket geçmişini aç'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: RemoteView(
        load: () => app.api.get('/notifications'),
        builder: (raw, reload) {
          final d = asJson(raw);
          final items = asList(d['items']);
          return PageBody(
            children: [
              SectionTitle(
                '${d.n('unread')} okunmamış bildirim',
                trailing: TextButton(
                  onPressed: () async {
                    try {
                      await app.api.put('/notifications/read-all');
                      await app.poll();
                      await reload();
                    } catch (e) {
                      if (context.mounted) {
                        toast(context, e.toString(), error: true);
                      }
                    }
                  },
                  child: const Text('Tümünü oku'),
                ),
              ),
              if (items.isEmpty)
                const EmptyState(
                  'Bildirim bulunmuyor',
                  'Stok, talep ve SKT uyarıları burada görünecek.',
                  icon: Icons.notifications_none,
                ),
              for (final n in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    color: n.b('isRead')
                        ? null
                        : Theme.of(context).colorScheme.primaryContainer
                              .withValues(alpha: .35),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Icon(
                        n.b('isRead')
                            ? Icons.notifications_none
                            : Icons.notifications_active_outlined,
                      ),
                      title: Text(
                        n.s('title'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${n.s('message')}\n${dateTime(n['createdAt'])}',
                        ),
                      ),
                      onTap: () async {
                        try {
                          await app.api.put('/notifications/${n.n('id')}/read');
                          await app.poll();
                          await reload();
                        } catch (e) {
                          if (context.mounted) {
                            toast(context, e.toString(), error: true);
                          }
                        }
                      },
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
