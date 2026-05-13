import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/chat_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/constants.dart';
import '../../features/live_stream/live_stream_screen.dart';
import '../../features/main_section/main/HomeScreen2.dart';
import '../../core/utils/premium_reprompt.dart';

class PremiumFlow {
  PremiumFlow._();

  /// Dismisses the paywall flow and sends the user into the app.
  /// Also schedules the next time the paywall can be shown (3–5 days).
  static Future<void> dismissToApp() async {
    unawaited(_markIntroOnboardingComplete());
    unawaited(PremiumReprompt.markShownNowAndScheduleNext());

    final chat = Get.isRegistered<ChatController>() ? Get.find<ChatController>() : null;
    final anyLive =
        chat != null &&
            (chat.platformLive.values.any((v) => v == true) ||
                (chat.overview.value?.live == true));

    if (anyLive) {
      Get.offAll(
        () => const Livestreaming(),
        transition: Transition.cupertino,
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
      );
      return;
    }

    Get.offAll(
      () => const HomeScreen2(),
      transition: Transition.cupertino,
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
    );
  }

  static Future<void> _markIntroOnboardingComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.keyIntroOnboardingComplete, true);
      try {
        if (Get.isRegistered<AuthController>()) {
          await Get.find<AuthController>()
              .rememberIntroOnboardingCompletedForCurrentUser();
        }
      } catch (_) {}
    } catch (e) {
      if (kDebugMode) debugPrint('[PremiumFlow] markIntroComplete failed: $e');
    }
  }
}
