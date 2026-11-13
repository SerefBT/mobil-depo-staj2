import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/common.dart';
import 'login_screen.dart';
import 'catalog_screens.dart';
import 'insight_screens.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final u = app.user!;
    return PageBody(
      children: [
        const SectionTitle('Hesabım'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  child: const Icon(Icons.person_outline, size: 36),
                ),
                const SizedBox(height: 14),
                Text(u.fullName, style: Theme.of(context).textTheme.titleLarge),
                Text(u.email),
                const SizedBox(height: 12),
                StatusPill(u.roleLabel),
                if (u.unit.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(u.unit),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Koyu görünüm'),
                value: app.dark,
                onChanged: app.setDark,
              ),
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: const Text('Sunucu bağlantısı'),
                subtitle: Text(app.baseUrl),
                onTap: () => serverSettings(context),
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Şifremi değiştir'),
                onTap: () => go(context, const PasswordScreen()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (u.isOperator) ...[
          ListTile(
            leading: const Icon(Icons.analytics_outlined),
            title: const Text('Raporlar ve son kullanma tarihleri'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => go(context, const ReportsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.swap_vert),
            title: const Text('Tüm stok hareketleri'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => go(context, const MovementsScreen()),
          ),
        ],
        ListTile(
          leading: const Icon(Icons.warehouse_outlined),
          title: const Text('Depolar ve raflar'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => go(context, const WarehousesScreen()),
        ),
        if (u.isAdmin) ...[
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Kullanıcı yönetimi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => go(context, const UsersScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.apartment_outlined),
            title: const Text('Birim oluştur'),
            onTap: () => go(context, const CatalogCreateScreen(kind: 'units')),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Kategori oluştur'),
            onTap: () =>
                go(context, const CatalogCreateScreen(kind: 'categories')),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            try {
              await app.logout();
            } catch (_) {
              if (context.mounted) {
                toast(context, 'Cihazdaki oturum kapatıldı.');
              }
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Güvenli çıkış yap'),
        ),
        const SizedBox(height: 20),
        const Text(
          'Mobil Depo 1.0.0\nBu ortamda yalnızca kurmaca demo verileri kullanılır.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11),
        ),
      ],
    );
  }
}

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});
  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final form = GlobalKey<FormState>();
  final current = TextEditingController(), next = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final app = context.read<AppState>();
      await app.api.put('/auth/password', {
        'currentPassword': current.text,
        'newPassword': next.text,
      });
      if (mounted) {
        toast(context, 'Şifre değişti. Yeni şifrenizle giriş yapın.');
        Navigator.pop(context);
      }
      await app.clearSession();
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Şifre değiştir')),
    body: Form(
      key: form,
      child: PageBody(
        children: [
          const SectionTitle(
            'Hesap güvenliği',
            subtitle: '10 karakter, büyük/küçük harf, rakam ve simge kullanın.',
          ),
          TextFormField(
            controller: current,
            obscureText: true,
            validator: (v) =>
                v == null || v.isEmpty ? 'Mevcut şifrenizi girin.' : null,
            decoration: const InputDecoration(labelText: 'Mevcut şifre'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: next,
            obscureText: true,
            validator: (v) =>
                v == null || v.length < 10 ? 'En az 10 karakter girin.' : null,
            decoration: const InputDecoration(labelText: 'Yeni şifre'),
          ),
          const SizedBox(height: 24),
          BusyButton(busy: busy, label: 'Şifreyi güncelle', action: save),
        ],
      ),
    ),
  );
}
