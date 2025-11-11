// lib/domain/services/notification_service.dart
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService I = NotificationService._();

  final _fcm = FirebaseMessaging.instance;
  final _fln = FlutterLocalNotificationsPlugin();
  final _sb = Supabase.instance.client;

  Future<void> init() async {
    // iOS: permiso
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Android: canal local
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _fln.initialize(const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onTap);

    // Token FCM
    final token = await _fcm.getToken();
    if (token != null) {
      await _saveToken(token);
    }

    // Suscribirse a cambios de token
    FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);

    // Handlers
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);

    // Background (necesita top-level handler en main.dart)
  }

  Future<void> _saveToken(String token) async {
    final user = _sb.auth.currentUser;
    if (user == null) return;
    final platform = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web');
    await _sb.from('device_tokens').upsert({
      'user_id': user.id,
      'fcm_token': token,
      'platform': platform,
    }, onConflict: 'user_id,fcm_token');
  }

  void _onForegroundMessage(RemoteMessage msg) async {
    final n = msg.notification;
    if (n != null) {
      await _fln.show(
        n.hashCode,
        n.title,
        n.body,
        const NotificationDetails(
          android: AndroidNotificationDetails('nearby_events', 'Eventos Cercanos',
              importance: Importance.max, priority: Priority.high),
          iOS: DarwinNotificationDetails(),
        ),
        payload: msg.data['eventId'],
      );
    }
  }

  void _onOpened(RemoteMessage msg) {
    // TODO: navegar a view_activity_screen.dart con msg.data['eventId']
  }

  void _onTap(NotificationResponse r) {
    final eventId = r.payload; 
    // TODO: navegación
  }
}
