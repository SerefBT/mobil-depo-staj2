import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'products_screen.dart';
import 'stock_screen.dart';
import 'requests_screen.dart';
import 'catalog_screens.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return RemoteView(
      load: () => app.api.get('/dashboard'),
      builder: (raw, reload) {
        final d = asJson(raw);
        final user = app.user!;
        final critical = asList(d['criticalProducts']);
        final movements = asList(d['recentMovements']);
        return PageBody(
          children: [
            const SizedBox(height: 8),
            Text(
              'Merhaba, ${user.fullName.replaceFirst('Demo ', '')}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Deponuz bir bakışta.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF123B44), Color(0xFF087F78)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ANLIK STOK DURUMU',
                          style: TextStyle(
                            color: Color(0xFFAADED5),
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          quantity(d['totalStock']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'kayıtlı toplam stok miktarı',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 18),
                        StatusPill('${d.n('totalProducts')} ürün çeşidi'),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.warehouse_outlined,
                    color: Color(0xFF89C7BE),
                    size: 74,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (ctx, c) => GridView.count(
                crossAxisCount: c.maxWidth > 650 ? 4 : 2,
                childAspectRatio: 1.65,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _metric(
                    context,
                    'Kritik stok',
                    d.n('criticalStock'),
                    Icons.warning_amber_rounded,
                    alert: true,
                  ),
                  _metric(
                    context,
                    'Aktif talep',
                    d.n('pendingRequests'),
                    Icons.assignment_outlined,
                  ),
                  if (user.isOperator) ...[
                    _metric(
                      context,
                      'Bugünkü giriş',
                      d.n('todayIn'),
                      Icons.south_west,
                    ),
                    _metric(
                      context,
                      'Bugünkü çıkış',
                      d.n('todayOut'),
                      Icons.north_east,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionTitle('Hızlı işlemler'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (user.isOperator) ...[
                  FilledButton.icon(
                    onPressed: () async {
                      await go(context, const StockScreen(inbound: true));
                      await reload();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Stok girişi'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await go(context, const StockScreen(inbound: false));
                      await reload();
                    },
                    icon: const Icon(Icons.remove),
                    label: const Text('Stok çıkışı'),
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: () async {
                      await go(context, const RequestFormScreen());
                      await reload();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Malzeme talep et'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => go(context, const WarehousesScreen()),
                  icon: const Icon(Icons.location_on_outlined),
                  label: const Text('Raf konumları'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SectionTitle(
              'İlgilenmeniz gerekenler',
              subtitle: 'Minimum seviyenin altındaki malzemeler',
              trailing: TextButton(
                onPressed: () => go(
                  context,
                  const ProductsScreen(criticalOnly: true, standalone: true),
                ),
                child: const Text('Tümü'),
              ),
            ),
            if (critical.isEmpty)
              const EmptyState(
                'Stok seviyeleri uygun',
                'Kritik stok seviyesinde ürün bulunmuyor.',
                icon: Icons.verified_outlined,
              ),
            for (final p in critical)
              ProductTile(
                p,
                onTap: () async {
                  await go(context, ProductDetailScreen(id: p.n('id')));
                  await reload();
                },
              ),
            if (user.isOperator) ...[
              const SizedBox(height: 16),
              const SectionTitle('Son stok hareketleri'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Column(
                    children: [
                      if (movements.isEmpty)
                        const EmptyState(
                          'Henüz hareket yok',
                          'İlk stok işlemi burada görünecek.',
                        ),
                      for (final m in movements) MovementTile(m),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 60),
          ],
        );
      },
    );
  }

  Widget _metric(
    BuildContext context,
    String label,
    int value,
    IconData icon, {
    bool alert = false,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: alert
                    ? const Color(0xFFBB6B37)
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            quantity(value),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}
