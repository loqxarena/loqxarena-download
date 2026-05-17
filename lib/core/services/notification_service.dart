import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // 1. Request Permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Setup Local Notifications (Android)
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    
    await _localNotifications.initialize(initSettings);

    // 3. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    // --- NEW: Subscribe EVERY user to the global topic ---
    await _fcm.subscribeToTopic("all_users");
    
    // 4. Print Token (For testing in Firebase Console)
    String? token = await _fcm.getToken();
    debugPrint("🔥 FCM TOKEN: $token");
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel', // id
      'High Importance Notifications', // name
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFFFFD700), // Gold
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      details,
    );
  }

  // Subscribe to Match Updates (e.g. "match_MATCHID")
  static Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
  }
  
  static Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
  }

  // --- NEW: Admin method to trigger Global Push ---
  static Future<void> sendGlobalPush(String title, String message) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      await functions.httpsCallable('sendGlobalNotification').call({
        'title': title,
        'message': message,
      });
    } catch (e) {
      throw Exception("Failed to send notification: $e");
    }
  }
}