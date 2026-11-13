import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart';
import 'products_screen.dart';
import 'requests_screen.dart';
import 'scanner_screen.dart';
import 'catalog_screens.dart';
import 'insight_screens.dart';
import 'profile_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});
  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int tab = 0;
  static const labels = ['Genel bakış', 'Ürünler', 'Talepler', 'Hesabım'];
  static const icons = [
    Icons.grid_view_outlined,
    Icons.inventory_2_outlined,
    Icons.assignment_outlined,
    Icons.person_outline,
  ];
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.user!;
    final wide = MediaQuery.sizeOf(context).width >= 1050;
    final pages = [
      const DashboardScreen(),
      const ProductsScreen(),
      const RequestsScreen(),
      const ProfileScreen(),
    ];
    Widget extra(String label, IconData icon, Widget page) => ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        if (!wide) Navigator.pop(context);
        go(context, page);
      },
    );
    Widget menu() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                user.roleLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (wide) ...[
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: ListTile(
                selected: tab == i,
                selectedTileColor: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Icon(icons[i], size: 21),
                title: Text(
                  labels[i],
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => setState(() => tab = i),
              ),
            ),
          const SizedBox(height: 12),
          const Divider(),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 0, 8),
          child: Text(
            'DEPO OPERASYONLARI',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        extra(
          'Depolar ve raflar',
          Icons.warehouse_outlined,
          const WarehousesScreen(),
        ),
        if (user.isOperator) ...[
          extra(
            'Kritik stoklar',
            Icons.warning_amber_rounded,
            const ProductsScreen(criticalOnly: true, standalone: true),
          ),
          extra('Stok hareketleri', Icons.swap_vert, const MovementsScreen()),
          extra(
            'Raporlar ve SKT',
            Icons.analytics_outlined,
            const ReportsScreen(),
          ),
          if (wide)
            extra(
              'QR / barkod tara',
              Icons.qr_code_scanner,
              const ScannerScreen(),
            ),
        ],
        if (user.isAdmin) ...[
          const Divider(),
          extra(
            'Kullanıcı yönetimi',
            Icons.manage_accounts_outlined,
            const UsersScreen(),
          ),
          extra(
            'Birim oluştur',
            Icons.apartment_outlined,
            const CatalogCreateScreen(kind: 'units'),
          ),
          extra(
            'Kategori oluştur',
            Icons.category_outlined,
            const CatalogCreateScreen(kind: 'categories'),
          ),
        ],
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'MOBİL DEPO 1.0\nWeb ve Android yönetim sistemi',
            style: TextStyle(fontSize: 10, height: 1.7),
          ),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            const Text(
              'MOBİL DEPO',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
            if (wide) ...[
              const SizedBox(width: 24),
              Text(
                'Merkezi stok yönetimi',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Bildirimler',
            onPressed: () async {
              await go(context, const NotificationsScreen());
              await app.poll();
            },
            icon: Badge(
              isLabelVisible: app.unread > 0,
              label: Text('${app.unread}'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [menu()],
                ),
              ),
            ),
      body: Row(
        children: [
          if (wide)
            Container(
              width: 248,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant
                        .withValues(alpha: .5),
                  ),
                ),
              ),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [menu()],
                ),
              ),
            ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: user.isOperator && !wide
          ? FloatingActionButton(
              onPressed: () => go(context, const ScannerScreen()),
              tooltip: 'QR / barkod tara',
              child: const Icon(Icons.qr_code_scanner),
            )
          : null,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (value) => setState(() => tab = value),
              destinations: [
                for (var i = 0; i < labels.length; i++)
                  NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
              ],
            ),
    );
  }
}
