import 'dart:async';

import 'package:get/get.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/settings_controller.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/streak_controller.dart';
import 'package:second_chat/controllers/auth_controller.dart';
import 'package:second_chat/features/Invite/Invite_screen.dart';

class AppPrefetch {
  static Future<bool>? _inFlight;

  static Future<bool> prefetchAfterAuth({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_inFlight != null) return _inFlight!;
    _inFlight = _prefetchAfterAuthInternal(timeout: timeout).whenComplete(() {
      _inFlight = null;
    });
    return _inFlight!;
  }

  static Future<bool> _prefetchAfterAuthInternal({
    required Duration timeout,
  }) async {
    if (!Get.isRegistered<AuthController>()) return false;
    final auth = Get.find<AuthController>();
    if (!auth.isAuthenticated.value) return false;

    SettingsController? settings;

    if (Get.isRegistered<SettingsController>()) {
      settings = Get.find<SettingsController>();
    }

    final blockingTasks = <Future<void>>[];

    // Run blocking warmups in parallel.
    if (settings != null) {
      // Avoid forcing a network refresh on splash/login. If cached settings are
      // already hydrated, this becomes a fast no-op.
      blockingTasks.add(
        settings.loadSettings(force: false).catchError((_) {}),
      );
    }

    if (Get.isRegistered<StreamStreaksController>()) {
      final streakCtrl = Get.find<StreamStreaksController>();
      blockingTasks.add(
        streakCtrl.fetchCurrentStreak(force: false, silent: true).then((_) {}),
      );
    }

    if (Get.isRegistered<InviteController>()) {
      unawaited(Get.find<InviteController>().loadInvites().catchError((_) {}));
    }

    if (blockingTasks.isNotEmpty) {
      try {
        await Future.wait(
          blockingTasks.map((f) => f.timeout(timeout, onTimeout: () {})),
          eagerError: false,
        );
      } catch (_) {
        // Soft-fail: individual tasks already handle errors/timeouts.
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
