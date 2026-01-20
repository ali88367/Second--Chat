import 'package:get/get.dart';

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