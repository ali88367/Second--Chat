import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/config/api_config.dart';
import '../../core/constants/constants.dart';
import '../../core/constants/app_colors/app_colors.dart';

class SettingsController extends GetxController {
  static const Map<String, String> _languageNameToCode = {
    'english': 'en',
    'spanish': 'es',
    'arabic': 'ar',
    'portuguese': 'pt',
    'german': 'de',
    'french': 'fr',
  };
  static const Map<String, String> _languageCodeToName = {
    'en': 'English',
    'es': 'Spanish',
    'ar': 'Arabic',
    'pt': 'Portuguese',
    'de': 'German',
    'fr': 'French',
  };

  final Rxn<Map<String, dynamic>> settingsPayload = Rxn<Map<String, dynamic>>();
  final RxBool settingsLoading = false.obs;
  final RxnString settingsError = RxnString();
  bool _settingsRequested = false;

  // General toggles
  RxBool notifications = true.obs;
  RxBool ledNotifications = false.obs;
  RxBool ledNewFollowers = true.obs;
  RxBool ledAllSubscribers = true.obs;
  RxBool ledMilestoneSubscribers = true.obs;
  RxInt ledMilestoneValue = 5.obs;
  RxBool lowPowerMode = false.obs;
  RxBool timeZoneDetection = true.obs;
  RxBool multiScreenPreview = false.obs;
  RxBool animations = true.obs;
  RxBool fullActivityFilters = false.obs;
  RxBool ttsAdvancedSettings = false.obs;

  // Chat / Viewer related toggles
  RxBool viewerCount = true.obs;
  RxBool hideViewerNames = false.obs;
  RxBool showSubscribersOnly = false.obs; // locked in UI
  RxBool showVipsOnly = false.obs; // locked in UI
  RxBool multiChatMergedMode = false.obs; // locked in UI

  // Platform selection (used in CHAT section tabs)
  RxString selectedPlatform = "All".obs; // All, Twitch, Kick, YouTube

  // Optional future settings (placeholders)
  RxString fontSize = "M".obs;
  RxString clockFormat = "12h".obs;
  RxString appLanguage = "English".obs;
  RxString theme = "dark".obs;

  // Premium unlock state
  RxBool isPremiumUnlocked = false.obs;

  // Platform colors - null means use default
  Rx<Color?> twitchColor = Rx<Color?>(null);
  Rx<Color?> kickColor = Rx<Color?>(null);
  Rx<Color?> youtubeColor = Rx<Color?>(null);
  Timer? _patchTimer;
  static const String _prefTwitchColor = 'second_chat.platform_color.twitch';
  static const String _prefKickColor = 'second_chat.platform_color.kick';
  static const String _prefYoutubeColor = 'second_chat.platform_color.youtube';

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
        return youtubeColor.value ?? const Color.fromRGBO(22, 22, 22, 1);
      default:
        return Colors.white;
    }
  }

  void setPlatformColor(String platform, Color color) {
    switch (platform.toLowerCase()) {
      case 'twitch':
        twitchColor.value = color;
        unawaited(_savePlatformColorToPrefs(_prefTwitchColor, color));
        break;
      case 'kick':
        kickColor.value = color;
        unawaited(_savePlatformColorToPrefs(_prefKickColor, color));
        break;
      case 'youtube':
        youtubeColor.value = color;
        unawaited(_savePlatformColorToPrefs(_prefYoutubeColor, color));
        break;
    }
    _scheduleFullSettingsPatch();
  }

  void setPlatform(String platform) {
    selectedPlatform.value = platform;
  }

  void loadSettingsIfNeeded() {
    if (_settingsRequested) return;
    _settingsRequested = true;
    loadSettings(force: true);
  }

  Future<void> loadSettings({bool force = false}) async {
    if (_settingsRequested && !force) return;
    _settingsRequested = true;
    settingsLoading.value = true;
    settingsError.value = null;

    try {
      final token = await _readAccessToken();
      if (token == null) {
        settingsError.value = 'missingAccessToken';
        print('SETTINGS ERROR: Missing access token in SharedPreferences');
        return;
      }
      final dio = _buildDio();
      final res = await dio.get<dynamic>(
        '/api/v1/settings',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = res.data;
      if (data is Map && data['data'] is Map) {
        settingsPayload.value = Map<String, dynamic>.from(data['data'] as Map);
        _applySettingsFromApi(settingsPayload.value!);
      } else {
        settingsError.value = 'unexpectedResponseFormat';
      }

      print('SETTINGS RESPONSE RAW: $data');
      if (data is Map) {
        print('SETTINGS RESPONSE DATA: ${data['data']}');
      }
    } catch (e) {
      settingsError.value = 'failedToLoadSettings';
      print('SETTINGS ERROR: $e');
      if (e is DioException) {
        print('SETTINGS ERROR RESPONSE: ${e.response?.data}');
      }
    } finally {
      settingsLoading.value = false;
    }
  }

  Future<bool> _patchSettings(Map<String, dynamic> patch) async {
    try {
      final token = await _readAccessToken();
      if (token == null) {
        settingsError.value = 'missingAccessToken';
        print(
          'SETTINGS PATCH ERROR: Missing access token in SharedPreferences',
        );
        return false;
      }
      final dio = _buildDio();
      print('SETTINGS PATCH REQUEST: $patch');
      final res = await dio.patch<dynamic>(
        '/api/v1/settings',
        data: patch,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      print('SETTINGS PATCH RESPONSE: ${res.data}');
      return true;
    } catch (e) {
      print('SETTINGS PATCH ERROR: $e');
      if (e is DioException) {
        print('SETTINGS PATCH ERROR RESPONSE: ${e.response?.data}');
      }
      return false;
    }
  }

  Future<void> updateToggle(String key, bool value) async {
    RxBool? target;

    switch (key) {
      case 'notifications':
        target = notifications;
        break;
      case 'ledNotifications':
        target = ledNotifications;
        break;
      case 'viewerCount':
        target = viewerCount;
        break;
      case 'hideViewerNames':
        target = hideViewerNames;
        break;
      case 'showSubscribersOnly':
        target = showSubscribersOnly;
        break;
      case 'showVipsOnly':
        target = showVipsOnly;
        break;
      case 'multiChatMergedMode':
        target = multiChatMergedMode;
        break;
      case 'lowPowerMode':
        target = lowPowerMode;
        break;
      case 'timeZoneDetection':
        target = timeZoneDetection;
        break;
      case 'multiScreenPreview':
        target = multiScreenPreview;
        break;
      case 'animations':
        target = animations;
        break;
      case 'fullActivityFilters':
        target = fullActivityFilters;
        break;
      case 'ttsAdvancedSettings':
        target = ttsAdvancedSettings;
        break;
    }

    if (target == null) return;
    final prev = target.value;
    target.value = value;
    final ok = await _patchSettings(_buildFullSettingsPatch());
    if (!ok) target.value = prev;
  }

  Future<void> updateFontSize(String value) async {
    final prev = fontSize.value;
    fontSize.value = value;
    final ok = await _patchSettings(_buildFullSettingsPatch());
    if (!ok) {
      fontSize.value = prev;
      return;
    }
    await _persistFontSizeToPrefs();
  }

  Future<void> updateAppLanguage(String value) async {
    final prev = appLanguage.value;
    appLanguage.value = value;
    final ok = await _patchSettings(_buildFullSettingsPatch());
    if (!ok) {
      appLanguage.value = prev;
      return;
    }
    await _persistAndApplyLocaleFromAppLanguage();
  }

  Future<void> _persistAndApplyLocaleFromAppLanguage() async {
    final normalized = appLanguage.value.toLowerCase().trim();
    final code = _languageNameToCode[normalized];
    if (code == null || code.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyLanguage, code);
    } catch (_) {}

    try {
      Get.updateLocale(Locale(code));
    } catch (_) {}
  }

  Future<void> _persistFontSizeToPrefs() async {
    final value = fontSize.value.trim();
    if (value.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyFontSize, value);
    } catch (_) {}
  }

  Future<void> _loadUiPrefsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(AppConstants.keyLanguage)?.trim();
      if (code != null && code.isNotEmpty) {
        appLanguage.value = _languageCodeToName[code.toLowerCase()] ?? appLanguage.value;
      }
      final fs = prefs.getString(AppConstants.keyFontSize)?.trim();
      if (fs != null && fs.isNotEmpty) {
        fontSize.value = fs.toUpperCase();
      }
    } catch (_) {}
  }

  double get textScaleFactor {
    switch (fontSize.value.trim().toUpperCase()) {
      case 'S':
        return 0.90;
      case 'M':
        return 1.00;
      case 'L':
        return 1.12;
      case 'XL':
        return 1.25;
      default:
        return 1.00;
    }
  }

  Future<void> updateClockFormat(String value) async {
    final prev = clockFormat.value;
    clockFormat.value = value;
    final ok = await _patchSettings(_buildFullSettingsPatch());
    if (!ok) clockFormat.value = prev;
  }

  Future<void> updateLedSetting(String key, bool value) async {
    RxBool? target;
    switch (key) {
      case 'newFollowers':
        target = ledNewFollowers;
        break;
      case 'allSubscribers':
        target = ledAllSubscribers;
        break;
      case 'milestoneSubscribers':
        target = ledMilestoneSubscribers;
        break;
    }
    if (target == null) return;
    final prev = target.value;
    target.value = value;
    final ok = await _patchSettings(_buildFullSettingsPatch());
    if (!ok) target.value = prev;
  }

  Future<void> updateLedMilestoneValue(int value) async {
    final prevValue = ledMilestoneValue.value;
    final prevEnabled = ledMilestoneSubscribers.value;
    ledMilestoneValue.value = value;
    if (!ledMilestoneSubscribers.value) {
      ledMilestoneSubscribers.value = true;
    }
    final ok = await _patchSettings(_buildFullSettingsPatch());
    if (!ok) {
      ledMilestoneValue.value = prevValue;
      ledMilestoneSubscribers.value = prevEnabled;
    }
  }

  Dio _buildDio() {
    return Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  Future<String?> _readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('second_chat.access_token')?.trim();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  void _applySettingsFromApi(Map<String, dynamic> payload) {
    final settings = payload['settings'];
    if (settings is! Map) return;

    final notif = settings['notifications'];
    if (notif is Map) {
      notifications.value = _asBool(notif['enabled'], notifications.value);
      ledNotifications.value = _asBool(
        notif['ledNotifications'],
        ledNotifications.value,
      );
      final ledSettings = notif['ledSettings'];
      if (ledSettings is Map) {
        ledNewFollowers.value = _asBool(
          ledSettings['newFollowers'],
          ledNewFollowers.value,
        );
        ledAllSubscribers.value = _asBool(
          ledSettings['allSubscribers'],
          ledAllSubscribers.value,
        );
        ledMilestoneSubscribers.value = _asBool(
          ledSettings['milestoneSubscribers'],
          ledMilestoneSubscribers.value,
        );
        ledMilestoneValue.value = _asInt(
          ledSettings['milestoneValue'],
          ledMilestoneValue.value,
        );
      }
    }

    final chat = settings['chat'];
    if (chat is Map) {
      viewerCount.value = _asBool(chat['viewerCount'], viewerCount.value);
      hideViewerNames.value = _asBool(
        chat['hideViewerNames'],
        hideViewerNames.value,
      );
      showSubscribersOnly.value = _asBool(
        chat['showSubscribersOnly'],
        showSubscribersOnly.value,
      );
      showVipsOnly.value = _asBool(chat['showVipModsOnly'], showVipsOnly.value);
      multiChatMergedMode.value = _asBool(
        chat['multiChatMergedMode'],
        multiChatMergedMode.value,
      );
      fontSize.value = _asString(chat['fontSize'], fontSize.value);
      unawaited(_persistFontSizeToPrefs());

      final platforms = chat['selectedPlatforms'];
      if (platforms is List && platforms.isNotEmpty) {
        final normalized =
            platforms.map((e) => e.toString().toLowerCase()).toList();
        if (normalized.contains('all')) {
          selectedPlatform.value = 'All';
        } else {
          final first = normalized.first;
          selectedPlatform.value = _titleCase(first);
        }
      }
    }

    final appearance = settings['appearance'];
    if (appearance is Map) {
      theme.value = _asString(appearance['theme'], theme.value);
      final platformColours = appearance['platformColours'];
      if (platformColours is Map) {
        final twitch = platformColours['twitch'];
        final kick = platformColours['kick'];
        final youtube = platformColours['youtube'];
        final twitchHex = twitch is Map ? twitch['color']?.toString() : null;
        final kickHex = kick is Map ? kick['color']?.toString() : null;
        final youtubeHex = youtube is Map ? youtube['color']?.toString() : null;
        final tColor = _parseHexColor(twitchHex);
        final kColor = _parseHexColor(kickHex);
        final yColor = _parseHexColor(youtubeHex);
        if (tColor != null) {
          twitchColor.value = tColor;
          unawaited(_savePlatformColorToPrefs(_prefTwitchColor, tColor));
        }
        if (kColor != null) {
          kickColor.value = kColor;
          unawaited(_savePlatformColorToPrefs(_prefKickColor, kColor));
        }
        if (yColor != null) {
          youtubeColor.value = yColor;
          unawaited(_savePlatformColorToPrefs(_prefYoutubeColor, yColor));
        }
      }
    }

    final language = settings['language'];
    if (language is Map) {
      appLanguage.value = _asString(language['appLanguage'], appLanguage.value);
      clockFormat.value = _asString(language['clock'], clockFormat.value);
      timeZoneDetection.value = _asBool(
        language['timeZoneDetection'],
        timeZoneDetection.value,
      );
      _persistAndApplyLocaleFromAppLanguage();
    }

    final other = settings['other'];
    if (other is Map) {
      multiScreenPreview.value = _asBool(
        other['multiScreenPreview'],
        multiScreenPreview.value,
      );
      animations.value = _asBool(other['animations'], animations.value);
      lowPowerMode.value = _asBool(other['lowPowerMode'], lowPowerMode.value);
      fullActivityFilters.value = _asBool(
        other['fullActivityFilters'],
        fullActivityFilters.value,
      );
      ttsAdvancedSettings.value = _asBool(
        other['ttsAdvancedSettings'],
        ttsAdvancedSettings.value,
      );
    }

    final account = payload['account'];
    if (account is Map) {
      isPremiumUnlocked.value = _asBool(account['isPremium'], false);
    }
  }

  bool _asBool(dynamic value, bool fallback) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase().trim();
      if (v == 'true' || v == '1' || v == 'yes') return true;
      if (v == 'false' || v == '0' || v == 'no') return false;
    }
    return fallback;
  }

  String _asString(dynamic value, String fallback) {
    if (value == null) return fallback;
    final s = value.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  Color? _parseHexColor(String? hex) {
    if (hex == null) return null;
    var cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) cleaned = 'FF$cleaned';
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(value);
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  Map<String, dynamic> _buildFullSettingsPatch() {
    final settingsBase = settingsPayload.value?['settings'];
    final settingsMap = _copyMap(settingsBase);

    final notificationsMap = _copyMap(settingsMap['notifications']);
    notificationsMap['enabled'] = notifications.value;
    notificationsMap['ledNotifications'] = ledNotifications.value;
    final ledSettingsMap = _copyMap(notificationsMap['ledSettings']);
    ledSettingsMap['newFollowers'] = ledNewFollowers.value;
    ledSettingsMap['allSubscribers'] = ledAllSubscribers.value;
    ledSettingsMap['milestoneSubscribers'] = ledMilestoneSubscribers.value;
    ledSettingsMap['milestoneValue'] = ledMilestoneValue.value;
    notificationsMap['ledSettings'] = ledSettingsMap;
    settingsMap['notifications'] = notificationsMap;

    final chatMap = _copyMap(settingsMap['chat']);
    chatMap['fontSize'] = fontSize.value;
    chatMap['showSubscribersOnly'] = showSubscribersOnly.value;
    chatMap['showVipModsOnly'] = showVipsOnly.value;
    chatMap['viewerCount'] = viewerCount.value;
    chatMap['hideViewerNames'] = hideViewerNames.value;
    chatMap['multiChatMergedMode'] = multiChatMergedMode.value;
    settingsMap['chat'] = chatMap;

    final appearanceMap = _copyMap(settingsMap['appearance']);
    final fallbackTheme =
        appearanceMap['theme']?.toString().trim().isNotEmpty == true
            ? appearanceMap['theme']
            : 'dark';
    appearanceMap['theme'] =
        theme.value.trim().isEmpty ? fallbackTheme : theme.value;
    final platformColoursMap = _copyMap(appearanceMap['platformColours']);
    platformColoursMap['twitch'] = _mergePlatformColor(
      platformColoursMap['twitch'],
      twitchColor.value,
      '#9146FF',
    );
    platformColoursMap['kick'] = _mergePlatformColor(
      platformColoursMap['kick'],
      kickColor.value,
      '#53FC18',
    );
    platformColoursMap['youtube'] = _mergePlatformColor(
      platformColoursMap['youtube'],
      youtubeColor.value,
      '#FF0000',
    );
    appearanceMap['platformColours'] = platformColoursMap;
    settingsMap['appearance'] = appearanceMap;

    final languageMap = _copyMap(settingsMap['language']);
    languageMap['appLanguage'] = appLanguage.value;
    languageMap['timeZoneDetection'] = timeZoneDetection.value;
    languageMap['clock'] = clockFormat.value;
    settingsMap['language'] = languageMap;

    final otherMap = _copyMap(settingsMap['other']);
    otherMap['multiScreenPreview'] = multiScreenPreview.value;
    otherMap['animations'] = animations.value;
    otherMap['lowPowerMode'] = lowPowerMode.value;
    otherMap['fullActivityFilters'] = fullActivityFilters.value;
    otherMap['ttsAdvancedSettings'] = ttsAdvancedSettings.value;
    settingsMap['other'] = otherMap;

    return {'settings': settingsMap};
  }

  Map<String, dynamic> _copyMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _mergePlatformColor(
    dynamic existing,
    Color? color,
    String fallbackHex,
  ) {
    final map = _copyMap(existing);
    final existingHex = map['color']?.toString().trim();
    final resolvedHex =
        color != null ? _toHexColor(color) : (existingHex ?? fallbackHex);
    map['color'] = resolvedHex;
    map['mode'] = map['mode'] ?? 'grid';
    map['opacity'] = map['opacity'] ?? 100;
    return map;
  }

  String _toHexColor(Color color) {
    final value = color.value & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  void _scheduleFullSettingsPatch() {
    _patchTimer?.cancel();
    _patchTimer = Timer(const Duration(milliseconds: 450), () async {
      await _patchSettings(_buildFullSettingsPatch());
    });
  }

  Future<void> _savePlatformColorToPrefs(String key, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    final hex = _toHexColor(color);
    await prefs.setString(key, hex);
    print('PLATFORM COLOR PREF SAVED: $key=$hex');
  }

  Future<void> _loadPlatformColorsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final tHex = prefs.getString(_prefTwitchColor);
    final kHex = prefs.getString(_prefKickColor);
    final yHex = prefs.getString(_prefYoutubeColor);
    final tColor = _parseHexColor(tHex);
    final kColor = _parseHexColor(kHex);
    final yColor = _parseHexColor(yHex);
    if (tColor != null) twitchColor.value = tColor;
    if (kColor != null) kickColor.value = kColor;
    if (yColor != null) youtubeColor.value = yColor;
    print('PLATFORM COLOR PREF LOADED: twitch=$tHex kick=$kHex youtube=$yHex');
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(_loadUiPrefsFromPrefs());
    unawaited(_loadPlatformColorsFromPrefs());
  }

  @override
  void onClose() {
    _patchTimer?.cancel();
    super.onClose();
  }
}
