import 'dart:async';

import 'package:get/get.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/settings_controller.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/streak_controller.dart';
import 'package:second_chat/controllers/auth_controller.dart';
import 'package:second_chat/features/Invite/Invite_screen.dart';

class AppPrefetch {
  static Future<bool> prefetchAfterAuth({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!Get.isRegistered<AuthController>()) return false;
    final auth = Get.find<AuthController>();
    if (!auth.isAuthenticated.value) return false;

    SettingsController? settings;
    Future<void>? settingsFuture;

    if (Get.isRegistered<SettingsController>()) {
      settings = Get.find<SettingsController>();
      // Avoid forcing a network refresh on splash/login. If cached settings are
      // already hydrated, this becomes a fast no-op.
      settingsFuture = settings.loadSettings(force: false);
    }

    final optionalFutures = <Future<void>>[];

    if (Get.isRegistered<StreamStreaksController>()) {
      optionalFutures.add(
        Get.find<StreamStreaksController>()
            .fetchCurrentStreak(force: false, silent: true)
            .then((_) {}),
      );
    }
    if (Get.isRegistered<InviteController>()) {
      optionalFutures.add(Get.find<InviteController>().loadInvites());
    }

    // Fire optional prefetches in the background; they should not block app
    // startup or cause "Check your connection" errors on partial failures.
    if (optionalFutures.isNotEmpty) {
      unawaited(
        Future.wait(
          optionalFutures.map((f) => f.catchError((_) {})),
          eagerError: false,
        ),
      );
    }

    if (settingsFuture != null) {
      // Only block on settings briefly if we don't already have cached settings.
      final alreadyHydrated = settings?.settingsPayload.value != null;
      if (!alreadyHydrated) {
        try {
          await settingsFuture.timeout(timeout);
        } catch (_) {
          // Treat as a soft timeout; settings may still finish in background.
        }
      }
    }

    if (settings != null) {
      // Fail only when settings are truly unavailable (no cached payload) and an
      // error is present. If settings are still loading, allow the app to
      // continue and let the controller finish fetching in the background.
      final payload = settings.settingsPayload.value;
      final err = settings.settingsError.value;
      if (payload == null && err != null && err.isNotEmpty) return false;
    }

    return true;
  }
}
