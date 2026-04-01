import 'dart:async';

import 'package:get/get.dart';

import 'Main Section Controllers/settings_controller.dart';

class EdgeGlowNotificationController extends GetxController {
  EdgeGlowNotificationController({SettingsController? settingsController})
      : _settings = settingsController ?? Get.find<SettingsController>();

  final SettingsController _settings;

  final RxBool isVisible = false.obs;
  final RxString activePlatform = 'twitch'.obs;
  final RxInt sequence = 0.obs;

  Timer? _hideTimer;
  Worker? _notificationsWorker;
  Worker? _ledNotificationsWorker;

  static const Duration _defaultDuration = Duration(seconds: 4);

  bool get _isEnabled =>
      _settings.notifications.value == true &&
      _settings.ledNotifications.value == true;

  void triggerForPlatform(
    String rawPlatform, {
    Duration duration = _defaultDuration,
  }) {
    if (!_isEnabled) return;
    final platform = _normalizePlatform(rawPlatform);
    if (platform.isEmpty) return;

    activePlatform.value = platform;
    sequence.value = sequence.value + 1;
    isVisible.value = true;

    _hideTimer?.cancel();
    _hideTimer = Timer(duration, () {
      isVisible.value = false;
    });
  }

  void hideNow() {
    _hideTimer?.cancel();
    _hideTimer = null;
    isVisible.value = false;
  }

  @override
  void onInit() {
    super.onInit();
    _notificationsWorker = ever<bool>(_settings.notifications, (_) {
      if (!_isEnabled) hideNow();
    });
    _ledNotificationsWorker = ever<bool>(_settings.ledNotifications, (_) {
      if (!_isEnabled) hideNow();
    });
  }

  @override
  void onClose() {
    _notificationsWorker?.dispose();
    _ledNotificationsWorker?.dispose();
    _hideTimer?.cancel();
    super.onClose();
  }

  String _normalizePlatform(String raw) {
    final value = raw.toLowerCase().trim();
    if (value.isEmpty) return '';
    if (value.contains('youtube') || value == 'yt' || value == 'google') {
      return 'youtube';
    }
    if (value.contains('twitch')) return 'twitch';
    if (value.contains('kick')) return 'kick';
    if (value.contains('tiktok')) return 'tiktok';
    return value;
  }
}
