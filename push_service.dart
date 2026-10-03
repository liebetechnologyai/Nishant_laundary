import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_client.dart';

class PushService {
  static bool _available = false;
  static bool _started = false;

  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  // Must match the channelId the backend sends for Android pushes.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'order_updates',
    'Order updates',
    description: 'Status updates for your laundry orders',
    importance: Importance.high,
  );

  /// Initialises Firebase. If native Firebase config files are missing the app keeps working without push.
  static Future<void> bootstrap() async {
    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (e) {
      debugPrint('Push disabled (Firebase not configured): $e');
    }
  }

  /// Requests permission, registers the device token with the backend and wires tap handling.
  static Future<void> start(void Function(String orderId) onOrderTap) async {
    if (!_available || _started) return;
    _started = true;

    try {
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();
      await fm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (r) {
          final id = r.payload;
          if (id != null && id.isNotEmpty) onOrderTap(id);
        },
      );
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // Foreground messages are not shown by Android automatically, so show them locally.
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n == null || defaultTargetPlatform != TargetPlatform.android) return;
        _local.show(
          m.hashCode,
          n.title,
          n.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          payload: m.data['order_id'] as String?,
        );
      });

      FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m, onOrderTap));
      final initial = await fm.getInitialMessage();
      if (initial != null) _open(initial, onOrderTap);

      final token = await fm.getToken();
      if (token != null) await api.registerDevice(token);
      fm.onTokenRefresh.listen((t) async {
        try {
          await api.registerDevice(t);
        } catch (e) {
          debugPrint('Token refresh registration failed: $e');
        }
      });
    } catch (e) {
      debugPrint('Push setup failed: $e');
    }
  }

  static void _open(RemoteMessage m, void Function(String orderId) onOrderTap) {
    final id = m.data['order_id'];
    if (id is String && id.isNotEmpty) onOrderTap(id);
  }
}
