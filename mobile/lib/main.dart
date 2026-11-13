import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..initialize(),
      child: const DepoApp(),
    ),
  );
}

class DepoApp extends StatelessWidget {
  const DepoApp({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return MaterialApp(
      key: ValueKey(app.user?.id ?? 'signed-out'),
      title: 'Mobil Depo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.create(false),
      darkTheme: AppTheme.create(true),
      themeMode: app.dark ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: app.starting
          ? const SplashScreen()
          : app.restoreError != null
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(app.restoreError!, textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: app.retryRestore,
                        child: const Text('Bağlantıyı tekrar dene'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await app.clearSession();
                          app.restoreError = null;
                          app.retryRestore();
                        },
                        child: const Text('Giriş ekranına dön'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : app.user == null
          ? const LoginScreen()
          : const ShellScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xFF12333C),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, color: Color(0xFF68D5BD), size: 64),
          SizedBox(height: 20),
          Text(
            'MOBİL DEPO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Her malzeme, doğru yerde.',
            style: TextStyle(color: Colors.white70),
          ),
          SizedBox(height: 36),
          CircularProgressIndicator(color: Color(0xFF68D5BD)),
        ],
      ),
    ),
  );
}
