import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../main.dart';
import '../screen/expense_detail_screen.dart';
import '../screen/groups/group_detail_screen.dart';

/// Push notifications: a phone subscribes itself to its own FCM topic,
/// `user_<id>`, right after login, and the server sends every expense/
/// settlement/new-member event straight to that topic — no device tokens
/// are ever registered or stored. Same pattern already proven out in the
/// DM Bhatt Classes app, adapted here to actually navigate on tap instead
/// of leaving that as a stub.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channel = AndroidNotificationChannel(
    'expense_updates_channel',
    'Expense & group updates',
    description: 'New expenses, settlements and group activity.',
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  /// The user currently subscribed to their topic, so [syncSubscription] is
  /// a no-op when called again with the same id (it runs on every
  /// StateManager change, most of which have nothing to do with auth).
  String? _subscribedUserId;

  /// Payload of a notification tapped while the app was terminated. Consumed
  /// once by [consumePendingTap] after the first screen is ready to route.
  Map<String, dynamic>? _pendingTap;

  FirebaseMessaging? get _fcm {
    try {
      if (Firebase.apps.isNotEmpty) return FirebaseMessaging.instance;
    } catch (_) {
      // Firebase never initialized (no native config dropped in yet) —
      // every push feature is simply unavailable, not a crash.
    }
    return null;
  }

  Future<void> initialize() async {
    final fcm = _fcm;
    if (fcm == null) {
      if (kDebugMode) {
        print('[push] Firebase not initialized — push notifications disabled.');
      }
      return;
    }

    await fcm.requestPermission(alert: true, badge: true, sound: true);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          _handleTap(Map<String, dynamic>.from(jsonDecode(payload) as Map));
        } catch (e) {
          if (kDebugMode) print('[push] Bad local-notification payload: $e');
        }
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Foreground: FCM does not show a system banner on its own while the
    // app is open, so this shows one via flutter_local_notifications.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;

      _local.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: jsonEncode(message.data),
      );
    });

    // Tapped while backgrounded (app still alive in memory).
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleTap(message.data));

    // Tapped from a fully terminated state — no stream fires for this, so
    // it's only ever available from this one-shot call. Stashed until a
    // navigator/session exists to route with.
    final initialMessage = await fcm.getInitialMessage();
    if (initialMessage != null) _pendingTap = initialMessage.data;
  }

  /// Keeps this device's topic subscription in step with who is signed in.
  /// Safe to call repeatedly — only actually (un)subscribes when the
  /// signed-in user id has changed since the last call.
  Future<void> syncSubscription(String? userId) async {
    final normalized = (userId == null || userId.isEmpty) ? null : userId;
    if (normalized == _subscribedUserId) return;

    final fcm = _fcm;
    if (fcm == null) {
      _subscribedUserId = normalized;
      return;
    }

    final previous = _subscribedUserId;
    _subscribedUserId = normalized;

    try {
      if (previous != null) await fcm.unsubscribeFromTopic('user_$previous');
      if (normalized != null) await fcm.subscribeToTopic('user_$normalized');
    } catch (e) {
      if (kDebugMode) print('[push] Topic (un)subscribe failed: $e');
    }
  }

  /// A tap that launched the app from terminated — call once the app's
  /// first screen is ready to navigate, then it is cleared so it never
  /// re-fires on a later rebuild.
  void consumePendingTap() {
    final tap = _pendingTap;
    _pendingTap = null;
    if (tap != null) _handleTap(tap);
  }

  void _handleTap(Map<String, dynamic> data) {
    final type = data['type'];
    final groupId = data['groupId'];
    final expenseId = data['expenseId'];
    if (groupId == null || groupId is! String || groupId.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;

      if (type == 'expense' && expenseId is String && expenseId.isNotEmpty) {
        navigator.push(MaterialPageRoute(
          builder: (_) => ExpenseDetailScreen(expenseId: expenseId, groupId: groupId),
        ));
      } else {
        navigator.push(MaterialPageRoute(
          builder: (_) => GroupDetailScreen(groupId: groupId),
        ));
      }
    });
  }
}
