import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../controllers/edge_glow_notification_controller.dart';
import '../controllers/Main Section Controllers/settings_controller.dart';
import '../core/utils/led_notification_filter.dart';

String _safeJson(Map<String, dynamic> map) {
  try {
    return jsonEncode(map);
  } catch (_) {
    return map.toString();
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    debugPrint(
      '[PUSH_BG] id=${message.messageId} '
      'from=${message.from} '
      'notificationTitle=${message.notification?.title} '
      'notificationBody=${message.notification?.body} '
      'data=${_safeJson(message.data)}',
    );
  }
}

class PushNotificationService {
  static bool _initialized = false;
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static StreamSubscription<RemoteMessage>? _onOpenSub;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      if (kDebugMode) {
        debugPrint(
          '[PUSH_FG] id=${message.messageId} '
          'title=${message.notification?.title} '
          'body=${message.notification?.body} '
          'data=${_safeJson(message.data)}',
        );
      }
      unawaited(_maybeTriggerEdgeLedForPush(message.data));
    });

    _onOpenSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (kDebugMode) {
        debugPrint(
          '[PUSH_OPENED_APP] id=${message.messageId} '
          'title=${message.notification?.title} '
          'data=${_safeJson(message.data)}',
        );
      }
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null && kDebugMode) {
      debugPrint(
        '[PUSH_INITIAL_MESSAGE] id=${initial.messageId} '
        'title=${initial.notification?.title} '
        'data=${_safeJson(initial.data)}',
      );
    }

    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      token,
    ) async {
      if (kDebugMode) {
        debugPrint('[PUSH_TOKEN_REFRESH] tokenLen=${token.length}');
      }
      if (!Get.isRegistered<AuthController>()) return;
      final auth = Get.find<AuthController>();
      if (!auth.isAuthenticated.value) return;
      await auth.registerCurrentDevicePushToken();
    });
  }

  static Future<void> _maybeTriggerEdgeLedForPush(
    Map<String, dynamic> data,
  ) async {
    if (!Get.isRegistered<SettingsController>() ||
        !Get.isRegistered<EdgeGlowNotificationController>()) {
      return;
    }

    final settings = Get.find<SettingsController>();
    final activityType =
        (data['type'] ??
                data['eventType'] ??
                data['kind'] ??
                data['event'] ??
                '')
            .toString();

    if (!LedNotificationFilter.shouldTrigger(
      settings: settings,
      rawActivityType: activityType,
      event: data,
    )) {
      return;
    }

    final platform =
        (data['platform'] ?? data['platformName'] ?? data['source'] ?? '')
            .toString();
    if (platform.trim().isEmpty) return;

    Get.find<EdgeGlowNotificationController>().triggerForPlatform(platform);
  }

  static Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _onMessageSub?.cancel();
    await _onOpenSub?.cancel();
    _tokenRefreshSub = null;
    _onMessageSub = null;
    _onOpenSub = null;
    _initialized = false;
  }
}

