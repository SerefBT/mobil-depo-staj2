import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DeviceNotifications {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
    );
    _ready = true;
  }

  Future<void> requestPermission() async {
    if (_ready) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> show(int id, String title, String body) async {
    if (!_ready) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'depo_updates',
          'Depo bildirimleri',
          channelDescription: 'Stok, talep ve son kullanma tarihi uyarıları',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
