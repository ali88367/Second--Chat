import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors/app_colors.dart';

class SettingsController extends GetxController {
  // General toggles
  RxBool notifications = true.obs;
  RxBool ledNotifications = false.obs;
  RxBool lowPowerMode = false.obs;
  RxBool timeZoneDetection = true.obs;

  // Chat / Viewer related toggles
  RxBool viewerCount = true.obs;
  RxBool hideViewerNames = false.obs;
  RxBool showSubscribersOnly = false.obs;   // locked in UI
  RxBool showVipsOnly = false.obs;          // locked in UI
  RxBool multiChatMergedMode = false.obs;   // locked in UI

  // Platform selection (used in CHAT section tabs)
  RxString selectedPlatform = "All".obs;    // All, Twitch, Kick, YouTube

  // Optional future settings (placeholders)
  RxString fontSize = "M".obs;
  RxString clockFormat = "12h".obs;
  RxString appLanguage = "English".obs;

  // Premium unlock state
  RxBool isPremiumUnlocked = false.obs;

  // Platform colors - null means use default
  Rx<Color?> twitchColor = Rx<Color?>(null);
  Rx<Color?> kickColor = Rx<Color?>(null);
  Rx<Color?> youtubeColor = Rx<Color?>(null);

  // Helper methods to get platform colors (with defaults)
  Color getPlatformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'twitch':
        return twitchColor.value ?? twitchPurple;
      case 'kick':
        return kickColor.value ?? kickGreen;
      case 'youtube':
        return youtubeColor.value ?? youtubeRed;
      case 'all':
        return youtubeColor.value ?? Color.fromRGBO(22, 22, 22, 1);

      default:
        return Colors.white;
    }
  }

  void setPlatformColor(String platform, Color color) {
    switch (platform.toLowerCase()) {
      case 'twitch':
        twitchColor.value = color;
        break;
      case 'kick':
        kickColor.value = color;
        break;
      case 'youtube':
        youtubeColor.value = color;
        break;
    }
  }

  // Helper methods
  void toggleNotifications() => notifications.toggle();
  void toggleLedNotifications() => ledNotifications.toggle();
  void toggleLowPowerMode() => lowPowerMode.toggle();
  void toggleTimeZoneDetection() => timeZoneDetection.toggle();
  void toggleViewerCount() => viewerCount.toggle();
  void toggleHideViewerNames() => hideViewerNames.toggle();

  void setPlatform(String platform) {
    selectedPlatform.value = platform;
  }

// You can add persistence later (shared_preferences / hive)
// Example:
// @override
// void onInit() {
//   super.onInit();
//   // load from storage
// }
}