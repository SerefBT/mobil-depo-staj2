import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final ApiService api = ApiService();
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  final DeviceNotifications notifications = DeviceNotifications();
  UserProfile? user;
  String baseUrl = const String.fromEnvironment('API_BASE_URL');
  bool starting = true, dark = false;
  String? restoreError;
  Timer? _timer;
  int unread = 0;
  bool _polling = false;
  AppState() {
    if (baseUrl.isEmpty) {
      baseUrl = kIsWeb
          ? Uri.base.resolve('/api').toString()
          : 'http://10.0.2.2:5080/api';
    }
    WidgetsBinding.instance.addObserver(this);
    api.onUnauthorized = () => unawaited(clearSession());
  }
  Future<void> initialize() async {
    try {
      baseUrl = await storage.read(key: 'api_url') ?? baseUrl;
      dark = await storage.read(key: 'dark') == 'true';
      api.configure(baseUrl);
      await notifications.initialize();
      api.token = await storage.read(key: 'token');
      if (api.token != null) {
        try {
          user = UserProfile.fromJson(await api.get('/auth/me'));
          _startPolling();
        } on ApiFailure catch (e) {
          if (e.status == 401) {
            await clearSession();
          } else {
            restoreError = e.message;
          }
        }
      }
    } catch (e) {
      restoreError = 'Oturum bilgileri okunamadı. Uygulamayı yeniden başlatın.';
    }
    starting = false;
    notifyListeners();
  }

  Future<void> retryRestore() async {
    starting = true;
    restoreError = null;
    notifyListeners();
    await initialize();
  }

  Future<void> login(String login, String password) async {
    final data = asJson(
      await api.post('/auth/login', {'login': login, 'password': password}),
    );
    await storage.write(key: 'token', value: data.s('token'));
    api.token = data.s('token');
    user = UserProfile.fromJson(asJson(data['user']));
    restoreError = null;
    await notifications.requestPermission();
    _startPolling();
    notifyListeners();
  }

  Future<void> setBaseUrl(String raw) async {
    var url = raw.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const ApiFailure(
        'Geçerli bir API adresi girin. Örnek: http://10.0.2.2:5080/api',
      );
    }
    final privateHttp = [
      'localhost',
      '10.0.2.2',
      '127.0.0.1',
    ].contains(uri.host);
    if (uri.scheme == 'http' && !privateHttp) {
      throw const ApiFailure(
        'İnternet üzerindeki sunucular için HTTPS kullanın.',
      );
    }
    if (!url.endsWith('/api')) url = '$url/api';
    if (user != null) await clearSession();
    await storage.write(key: 'api_url', value: url);
    baseUrl = url;
    api.configure(url);
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await api.post('/auth/logout', null);
    } finally {
      await clearSession();
    }
  }

  Future<void> clearSession() async {
    _timer?.cancel();
    api.token = null;
    user = null;
    unread = 0;
    await storage.delete(key: 'token');
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    dark = value;
    await storage.write(key: 'dark', value: '$value');
    notifyListeners();
  }

  void _startPolling() {
    _timer?.cancel();
    unawaited(poll());
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(poll()),
    );
  }

  Future<void> poll() async {
    if (user == null || _polling) return;
    _polling = true;
    try {
      final data = await api.get('/notifications');
      unread = data.n('unread');
      final key = 'notification_${user!.id}';
      final last = int.tryParse(await storage.read(key: key) ?? '0') ?? 0;
      final items = asList(data['items']);
      for (final item
          in items.reversed
              .where((n) => n.n('id') > last && !n.b('isRead'))
              .take(5)) {
        await notifications.show(
          item.n('id'),
          item.s('title'),
          item.s('message'),
        );
      }
      if (items.isNotEmpty) {
        await storage.write(key: key, value: items.first.s('id'));
      }
      notifyListeners();
    } catch (_) {
      /* Connection errors are shown in the active screen; polling resumes automatically. */
    } finally {
      _polling = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && user != null) {
      _startPolling();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
