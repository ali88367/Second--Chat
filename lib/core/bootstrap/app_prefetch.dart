import 'dart:async';

import 'package:get/get.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/settings_controller.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/streak_controller.dart';
import 'package:second_chat/controllers/auth_controller.dart';
import 'package:second_chat/controllers/chat_controller.dart';
import 'package:second_chat/features/Invite/Invite_screen.dart';

class AppPrefetch {
  static Future<bool> prefetchAfterAuth({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (!Get.isRegistered<AuthController>()) return false;
    final auth = Get.find<AuthController>();
    if (!auth.isAuthenticated.value) return false;

    final futures = <Future<void>>[];

    if (Get.isRegistered<SettingsController>()) {
      futures.add(Get.find<SettingsController>().loadSettings(force: true));
    }
    if (Get.isRegistered<StreamStreaksController>()) {
      futures.add(
        Get.find<StreamStreaksController>()
            .fetchCurrentStreak(force: true, silent: true)
            .then((_) {}),
      );
    }
    if (Get.isRegistered<InviteController>()) {
      futures.add(Get.find<InviteController>().loadInvites());
    }
    if (Get.isRegistered<ChatController>()) {
      futures.add(Get.find<ChatController>().ensureStreamRealtimeBootstrap());
    }

    try {
      await Future.wait(futures).timeout(timeout);
    } catch (_) {
      return false;
    }

    if (Get.isRegistered<SettingsController>()) {
      final settings = Get.find<SettingsController>();
      if (settings.settingsPayload.value == null &&
          settings.settingsError.value != null) {
        return false;
      }
    }

    return true;
  }
}

