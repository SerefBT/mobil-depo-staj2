import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';
import 'products_screen.dart';
import 'catalog_screens.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!controller.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed && !busy) {
      controller.start();
    } else {
      controller.stop();
    }
  }

  Future<void> resolve(String code) async {
    if (busy || code.trim().isEmpty) return;
    setState(() => busy = true);
    await controller.stop();
    if (!mounted) return;
    try {
      final api = context.read<AppState>().api;
      Json? shelf;
      try {
        shelf = await api.get(
          '/shelves/qr/${Uri.encodeComponent(code.trim())}',
        );
      } on ApiFailure catch (e) {
        if (e.status != 404) rethrow;
      }
      if (!mounted) return;
      if (shelf != null) {
        await go(context, ShelfDetailScreen(shelf: shelf));
      } else {
        final p = await api.get(
          '/products/barcode/${Uri.encodeComponent(code.trim())}',
        );
        if (mounted) await go(context, ProductDetailScreen(id: p.n('id')));
      }
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    } finally {
      if (mounted) {
        setState(() => busy = false);
        await controller.start();
      }
    }
  }

  Future<void> manual() async {
    final text = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kodu elle girin'),
        content: TextField(
          controller: text,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Barkod, ürün kodu veya raf QR değeri',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, text.text),
            child: const Text('Bul'),
          ),
        ],
      ),
    );
    text.dispose();
    if (code != null) await resolve(code);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF102C35),
    appBar: AppBar(
      title: const Text('QR / Barkod tara'),
      actions: [
        IconButton(
          tooltip: 'Fener',
          onPressed: () => controller.toggleTorch(),
          icon: const Icon(Icons.flashlight_on_outlined),
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  final raw = capture.barcodes.firstOrNull?.rawValue;
                  if (raw != null) resolve(raw);
                },
                errorBuilder: (context, error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.no_photography_outlined,
                          size: 44,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Kamera açılamadı. Kamera iznini uygulama ayarlarından kontrol edin veya kodu elle girin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white),
                        ),
                        TextButton(
                          onPressed: manual,
                          child: const Text('Kodu elle gir'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Container(
                  width: 260,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF68D5BD),
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              if (busy) const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                'Ürün barkodunu veya raf QR kodunu\nçerçevenin içine hizalayın.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: busy ? null : manual,
                icon: const Icon(Icons.keyboard_outlined),
                label: const Text('Kodu elle gir'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
