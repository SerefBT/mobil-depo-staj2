import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

Future<void> serverSettings(BuildContext context) async {
  final app = context.read<AppState>();
  final controller = TextEditingController(text: app.baseUrl);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sunucu bağlantısı'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Emülatör: 10.0.2.2:5080\nUSB bağlı telefon: 127.0.0.1:5080\nSunucu adresinin sonunda /api bulunmalı.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'API adresi'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await app.setBaseUrl(controller.text);
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              if (ctx.mounted) toast(ctx, e.toString(), error: true);
            }
          },
          child: const Text('Kaydet'),
        ),
      ],
    ),
  );
  controller.dispose();
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final login = TextEditingController(), password = TextEditingController();
  bool busy = false, hidden = true;
  @override
  void dispose() {
    login.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await context.read<AppState>().login(login.text.trim(), password.text);
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Her malzeme,\ndoğru yerde.',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'MOBİL DEPO',
                  style: TextStyle(
                    letterSpacing: 3,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 30),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Form(
                      key: form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Hesabınıza giriş yapın',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Depo operasyonlarınıza güvenle devam edin.',
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: login,
                            validator: requiredText,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: 'E-posta veya kullanıcı adı',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: password,
                            validator: requiredText,
                            obscureText: hidden,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => busy ? null : submit(),
                            decoration: InputDecoration(
                              labelText: 'Şifre',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => hidden = !hidden),
                                icon: Icon(
                                  hidden
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          BusyButton(
                            busy: busy,
                            label: 'Giriş yap',
                            icon: Icons.arrow_forward,
                            action: submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'Demo hesapları',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Yalnızca örnek kurum verileri',
                    style: TextStyle(fontSize: 11),
                  ),
                  children: [
                    for (final data in [
                      ('Yönetici', 'admin', 'Admin12345!'),
                      ('Depo personeli', 'depo', 'Depo12345!'),
                      ('Birim yetkilisi', 'birim', 'Birim12345!'),
                    ])
                      ListTile(
                        dense: true,
                        title: Text(data.$1),
                        subtitle: Text('${data.$2}@demo.local'),
                        trailing: const Icon(Icons.north_west, size: 18),
                        onTap: () {
                          login.text = '${data.$2}@demo.local';
                          password.text = data.$3;
                        },
                      ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => serverSettings(context),
                  icon: const Icon(Icons.dns_outlined, size: 17),
                  label: const Text('Sunucu bağlantısını ayarla'),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Mobil Depo, Raf ve Stok Yönetim Sistemi',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
