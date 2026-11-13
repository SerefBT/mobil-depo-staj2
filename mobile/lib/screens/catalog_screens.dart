import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'products_screen.dart';

class WarehousesScreen extends StatelessWidget {
  const WarehousesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Depolar ve raflar')),
      body: RemoteView(
        load: () => app.api.list('/warehouses'),
        builder: (raw, reload) => PageBody(
          children: [
            SectionTitle(
              'Fiziksel depo ağı',
              subtitle: 'Depo → Koridor → Raf',
              trailing: app.user!.isAdmin
                  ? IconButton.filledTonal(
                      tooltip: 'Depo ekle',
                      onPressed: () async {
                        await go(
                          context,
                          const CatalogCreateScreen(kind: 'warehouses'),
                        );
                        await reload();
                      },
                      icon: const Icon(Icons.add),
                    )
                  : null,
            ),
            for (final w in raw as List<Json>)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    leading: const Icon(Icons.warehouse_outlined, size: 34),
                    title: Text(
                      w.s('name'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    subtitle: Text(
                      '${w.n('aisleCount')} koridor • ${w.n('productCount')} ürün',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => go(context, ShelvesScreen(warehouse: w)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ShelvesScreen extends StatefulWidget {
  final Json warehouse;
  const ShelvesScreen({super.key, required this.warehouse});
  @override
  State<ShelvesScreen> createState() => _ShelvesScreenState();
}

class _ShelvesScreenState extends State<ShelvesScreen> {
  int? aisle;
  int revision = 0;
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final id = widget.warehouse.n('id');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.warehouse.s('name')),
        actions: [
          if (app.user!.isAdmin)
            PopupMenuButton<String>(
              onSelected: (kind) async {
                await go(
                  context,
                  CatalogCreateScreen(kind: kind, warehouseId: id),
                );
                if (mounted) setState(() => revision++);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'aisles', child: Text('Koridor ekle')),
                PopupMenuItem(value: 'shelves', child: Text('Raf ekle')),
              ],
            ),
        ],
      ),
      body: RemoteView(
        key: ValueKey(revision),
        load: () => Future.wait([
          app.api.list('/aisles', query: {'warehouseId': id}),
          app.api.list('/shelves', query: {'warehouseId': id}),
        ]),
        builder: (raw, reload) {
          final data = raw as List;
          final aisles = data[0] as List<Json>;
          final shelves = (data[1] as List<Json>)
              .where((x) => aisle == null || x.n('aisleId') == aisle)
              .toList();
          return PageBody(
            children: [
              const SectionTitle(
                'Raf konumları',
                subtitle: 'Bir rafı seçin veya QR etiketini tarayın.',
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Tüm koridorlar'),
                      selected: aisle == null,
                      onSelected: (_) => setState(() => aisle = null),
                    ),
                    for (final a in aisles)
                      ChoiceChip(
                        label: Text(a.s('name')),
                        selected: aisle == a.n('id'),
                        onSelected: (_) => setState(() => aisle = a.n('id')),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (shelves.isEmpty)
                const EmptyState(
                  'Raf bulunamadı',
                  'Yönetici hesabıyla raf oluşturabilirsiniz.',
                ),
              for (final s in shelves)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: const Icon(Icons.shelves),
                      title: Text('Raf ${s.s('code')}'),
                      subtitle: Text(
                        '${s.s('aisle')} • ${s.n('productCount')} ürün',
                      ),
                      trailing: const Icon(Icons.qr_code_2),
                      onTap: () => go(context, ShelfDetailScreen(shelf: s)),
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

class ShelfDetailScreen extends StatelessWidget {
  final Json shelf;
  const ShelfDetailScreen({super.key, required this.shelf});
  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return Scaffold(
      appBar: AppBar(title: Text('Raf ${shelf.s('code')}')),
      body: RemoteView(
        load: () => api.list('/shelves/${shelf.n('id')}/products'),
        builder: (raw, reload) => PageBody(
          children: [
            Text(
              '${shelf.s('warehouse')} / ${shelf.s('aisle')}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      QrImageView(
                        data: shelf.s('qrValue'),
                        size: 190,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        shelf.s('qrValue'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SectionTitle(
              'Bu raftaki ürünler',
              subtitle: '${(raw as List).length} ürün çeşidi',
            ),
            if (raw.isEmpty)
              const EmptyState(
                'Bu raf boş',
                'Ürün konumunu düzenleyerek bu rafa atama yapabilirsiniz.',
              ),
            for (final p in raw as List<Json>)
              ProductTile(
                p,
                onTap: () => go(context, ProductDetailScreen(id: p.n('id'))),
              ),
          ],
        ),
      ),
    );
  }
}

class CatalogCreateScreen extends StatefulWidget {
  final String kind;
  final int? warehouseId;
  const CatalogCreateScreen({super.key, required this.kind, this.warehouseId});
  @override
  State<CatalogCreateScreen> createState() => _CatalogCreateScreenState();
}

class _CatalogCreateScreenState extends State<CatalogCreateScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      code = TextEditingController(),
      qr = TextEditingController();
  int? warehouse, aisle;
  bool busy = false;
  String get label => switch (widget.kind) {
    'warehouses' => 'Depo',
    'aisles' => 'Koridor',
    'shelves' => 'Raf',
    'units' => 'Birim',
    _ => 'Kategori',
  };
  @override
  void initState() {
    super.initState();
    warehouse = widget.warehouseId;
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    qr.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final data = switch (widget.kind) {
        'warehouses' => {'name': name.text.trim(), 'code': code.text.trim()},
        'aisles' => {'name': name.text.trim(), 'warehouseId': warehouse},
        'shelves' => {
          'aisleId': aisle,
          'code': code.text.trim(),
          'qrValue': qr.text.trim(),
        },
        _ => {'name': name.text.trim()},
      };
      await context.read<AppState>().api.post('/${widget.kind}', data);
      if (mounted) {
        toast(context, '$label oluşturuldu.');
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
      appBar: AppBar(title: Text('$label oluştur')),
      body: RemoteView(
        load: () => Future.wait([api.list('/warehouses'), api.list('/aisles')]),
        builder: (raw, reload) {
          final data = raw as List;
          return Form(
            key: form,
            child: PageBody(
              children: [
                SectionTitle('$label bilgileri'),
                if (['aisles', 'shelves'].contains(widget.kind)) ...[
                  ChoiceField(
                    label: 'Depo',
                    value: warehouse,
                    items: data[0] as List<Json>,
                    display: (x) => x.s('name'),
                    onChanged: (v) => setState(() {
                      warehouse = v;
                      aisle = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                ],
                if (widget.kind == 'shelves') ...[
                  ChoiceField(
                    label: 'Koridor',
                    value: aisle,
                    items: (data[1] as List<Json>)
                        .where(
                          (x) =>
                              warehouse == null ||
                              x.n('warehouseId') == warehouse,
                        )
                        .toList(),
                    display: (x) => '${x.s('warehouse')} / ${x.s('name')}',
                    onChanged: (v) => setState(() => aisle = v),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  TextFormField(
                    controller: name,
                    maxLength: 100,
                    validator: (v) => v == null || v.trim().length < 2
                        ? 'En az 2 karakter girin.'
                        : null,
                    decoration: InputDecoration(labelText: '$label adı'),
                  ),
                  const SizedBox(height: 16),
                ],
                if (['warehouses', 'shelves'].contains(widget.kind)) ...[
                  TextFormField(
                    controller: code,
                    maxLength: widget.kind == 'shelves' ? 64 : 32,
                    validator: requiredText,
                    decoration: InputDecoration(labelText: '$label kodu'),
                  ),
                  const SizedBox(height: 16),
                ],
                if (widget.kind == 'shelves') ...[
                  TextFormField(
                    controller: qr,
                    maxLength: 128,
                    validator: (v) => v == null || v.trim().length < 3
                        ? 'En az 3 karakter girin.'
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Benzersiz QR değeri',
                      hintText: 'DEPO-A-K2-B04',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                BusyButton(busy: busy, label: '$label oluştur', action: save),
              ],
            ),
          );
        },
      ),
    );
  }
}

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Kullanıcı yönetimi')),
      body: RemoteView(
        load: () => app.api.list('/admin/users'),
        builder: (raw, reload) => PageBody(
          children: [
            SectionTitle(
              'Kullanıcılar ve roller',
              trailing: IconButton.filledTonal(
                tooltip: 'Kullanıcı oluştur',
                onPressed: () async {
                  await go(context, const UserFormScreen());
                  await reload();
                },
                icon: const Icon(Icons.person_add_outlined),
              ),
            ),
            for (final u in raw as List<Json>)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      child: Icon(
                        u.b('isActive')
                            ? Icons.person_outline
                            : Icons.person_off_outlined,
                      ),
                    ),
                    title: Text(u.s('fullName')),
                    subtitle: Text(
                      '${u.s('email')}\n${u.s('role')} • ${u.s('unit', 'Birim yok')}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () async {
                      await go(context, UserFormScreen(user: u));
                      await reload();
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class UserFormScreen extends StatefulWidget {
  final Json? user;
  const UserFormScreen({super.key, this.user});
  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, email;
  final password = TextEditingController();
  String role = 'Unit';
  int? unit;
  bool active = true, busy = false;
  @override
  void initState() {
    super.initState();
    final u = widget.user ?? {};
    name = TextEditingController(text: u.s('fullName'));
    email = TextEditingController(text: u.s('email'));
    role = u.s('role', 'Unit');
    unit = u['unitId'] as int?;
    active = u['isActive'] as bool? ?? true;
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final api = context.read<AppState>().api;
      final data = {
        'fullName': name.text.trim(),
        'role': role,
        'unitId': unit,
        'isActive': active,
      };
      if (widget.user == null) {
        await api.post('/admin/users', {
          ...data,
          'email': email.text.trim(),
          'password': password.text,
        });
      } else {
        await api.put('/admin/users/${widget.user!.s('id')}', data);
      }
      if (mounted) {
        toast(context, 'Kullanıcı kaydedildi.');
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
      appBar: AppBar(
        title: Text(
          widget.user == null ? 'Kullanıcı oluştur' : 'Kullanıcı düzenle',
        ),
      ),
      body: RemoteView(
        load: () => app.api.list('/units'),
        builder: (raw, reload) => Form(
          key: form,
          child: PageBody(
            children: [
              const SectionTitle('Hesap bilgileri'),
              TextFormField(
                controller: name,
                maxLength: 100,
                validator: (v) => v == null || v.trim().length < 2
                    ? 'En az 2 karakter girin.'
                    : null,
                decoration: const InputDecoration(labelText: 'Ad / görünen ad'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: email,
                enabled: widget.user == null,
                maxLength: 256,
                validator: (v) =>
                    v == null ||
                        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)
                    ? 'Geçerli bir e-posta girin.'
                    : null,
                decoration: const InputDecoration(labelText: 'E-posta'),
              ),
              if (widget.user == null) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  validator: (v) =>
                      v == null ||
                          v.length < 10 ||
                          !RegExp(r'[A-Z]').hasMatch(v) ||
                          !RegExp(r'[a-z]').hasMatch(v) ||
                          !RegExp(r'\d').hasMatch(v) ||
                          !RegExp(r'[^\w]').hasMatch(v)
                      ? '10 karakter, büyük/küçük harf, rakam ve simge kullanın.'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Başlangıç şifresi',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: const [
                  DropdownMenuItem(value: 'Admin', child: Text('Yönetici')),
                  DropdownMenuItem(
                    value: 'Warehouse',
                    child: Text('Depo personeli'),
                  ),
                  DropdownMenuItem(
                    value: 'Unit',
                    child: Text('Birim yetkilisi'),
                  ),
                ],
                onChanged: (v) => setState(() => role = v!),
              ),
              const SizedBox(height: 16),
              ChoiceField(
                label: 'Birim',
                value: unit,
                required: role == 'Unit',
                items: raw as List<Json>,
                display: (x) => x.s('name'),
                onChanged: (v) => setState(() => unit = v),
              ),
              if (widget.user != null)
                SwitchListTile(
                  title: const Text('Hesap aktif'),
                  value: active,
                  onChanged: (v) => setState(() => active = v),
                ),
              const SizedBox(height: 24),
              BusyButton(busy: busy, label: 'Kullanıcıyı kaydet', action: save),
            ],
          ),
        ),
      ),
    );
  }
}
