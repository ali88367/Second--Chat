import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationPermissionGate {
  const NotificationPermissionGate._();

  static Future<bool> isAllowed() async {
    try {
      final status = await Permission.notification.status;
      if (status.isGranted) return true;
    } catch (_) {}

    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {}

    return false;
  }
}

