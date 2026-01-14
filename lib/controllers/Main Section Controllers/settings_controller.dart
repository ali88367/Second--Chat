// controllers/settings_controller.dart
import 'package:get/get.dart';

class SettingsController extends GetxController {
  // Switch states (based on your screenshot)
  var notifications = true.obs;
  var ledNotifications = true.obs;
  var connectOtherPlatforms = false.obs;
  var showSubscribersOnly = false.obs;
  var showVipsOnly = false.obs;
  var viewerCount = true.obs;
  var hideViewerNames = false.obs;
  var multiChatMergedMode = false.obs;
  var lowPowerMode = false.obs;

  // You can add methods to toggle if needed
  void toggleLedNotifications() => ledNotifications.toggle();
  void toggleConnectPlatforms() => connectOtherPlatforms.toggle();
// ... add others as needed
}