import 'package:dio/dio.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/config/api_config.dart';
import '../../core/constants/app_colors/app_colors.dart';

class SettingsController extends GetxController {
  final Rxn<Map<String, dynamic>> settingsPayload = Rxn<Map<String, dynamic>>();
  final RxBool settingsLoading = false.obs;
  final RxnString settingsError = RxnString();
  bool _settingsRequested = false;

  // General toggles
  RxBool notifications = true.obs;
  RxBool ledNotifications = false.obs;
  RxBool lowPowerMode = false.obs;
  RxBool timeZoneDetection = true.obs;

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
        return youtubeColor.value ?? const Color.fromRGBO(22, 22, 22, 1);
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
        settingsError.value = 'Missing access token';
        print('SETTINGS ERROR: Missing access token in SharedPreferences');
        return;
      }
      final dio = _buildDio();
      final res = await dio.get<dynamic>(
        '/api/v1/settings',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final data = res.data;
      if (data is Map && data['data'] is Map) {
        settingsPayload.value = Map<String, dynamic>.from(data['data'] as Map);
        _applySettingsFromApi(settingsPayload.value!);
      } else {
        settingsError.value = 'Unexpected response format';
      }

      print('SETTINGS RESPONSE RAW: $data');
      if (data is Map) {
        print('SETTINGS RESPONSE DATA: ${data['data']}');
      }
    } catch (e) {
      settingsError.value = 'Failed to load settings';
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
        settingsError.value = 'Missing access token';
        print('SETTINGS PATCH ERROR: Missing access token in SharedPreferences');
        return false;
      }
      final dio = _buildDio();
      print('SETTINGS PATCH REQUEST: $patch');
      final res = await dio.patch<dynamic>(
        '/api/v1/settings',
        data: patch,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
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
    Map<String, dynamic>? patch;

    switch (key) {
      case 'notifications':
        target = notifications;
        patch = {
          'settings': {
            'notifications': {'enabled': value}
          }
        };
        break;
      case 'ledNotifications':
        target = ledNotifications;
        patch = {
          'settings': {
            'notifications': {'ledNotifications': value}
          }
        };
        break;
      case 'viewerCount':
        target = viewerCount;
        patch = {
          'settings': {
            'chat': {'viewerCount': value}
          }
        };
        break;
      case 'hideViewerNames':
        target = hideViewerNames;
        patch = {
          'settings': {
            'chat': {'hideViewerNames': value}
          }
        };
        break;
      case 'showSubscribersOnly':
        target = showSubscribersOnly;
        patch = {
          'settings': {
            'chat': {'showSubscribersOnly': value}
          }
        };
        break;
      case 'showVipsOnly':
        target = showVipsOnly;
        patch = {
          'settings': {
            'chat': {'showVipModsOnly': value}
          }
        };
        break;
      case 'multiChatMergedMode':
        target = multiChatMergedMode;
        patch = {
          'settings': {
            'chat': {'multiChatMergedMode': value}
          }
        };
        break;
      case 'lowPowerMode':
        target = lowPowerMode;
        patch = {
          'settings': {
            'other': {'lowPowerMode': value}
          }
        };
        break;
      case 'timeZoneDetection':
        target = timeZoneDetection;
        patch = {
          'settings': {
            'language': {'timeZoneDetection': value}
          }
        };
        break;
    }

    if (target == null || patch == null) return;
    final prev = target.value;
    target.value = value;
    final ok = await _patchSettings(patch);
    if (!ok) target.value = prev;
  }

  Future<void> updateFontSize(String value) async {
    final prev = fontSize.value;
    fontSize.value = value;
    final ok = await _patchSettings({
      'settings': {
        'chat': {'fontSize': value}
      }
    });
    if (!ok) fontSize.value = prev;
  }

  Future<void> updateAppLanguage(String value) async {
    final prev = appLanguage.value;
    appLanguage.value = value;
    final ok = await _patchSettings({
      'settings': {
        'language': {'appLanguage': value}
      }
    });
    if (!ok) appLanguage.value = prev;
  }

  Future<void> updateClockFormat(String value) async {
    final prev = clockFormat.value;
    clockFormat.value = value;
    final ok = await _patchSettings({
      'settings': {
        'language': {'clock': value}
      }
    });
    if (!ok) clockFormat.value = prev;
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
      ledNotifications.value =
          _asBool(notif['ledNotifications'], ledNotifications.value);
    }

    final chat = settings['chat'];
    if (chat is Map) {
      viewerCount.value = _asBool(chat['viewerCount'], viewerCount.value);
      hideViewerNames.value =
          _asBool(chat['hideViewerNames'], hideViewerNames.value);
      showSubscribersOnly.value =
          _asBool(chat['showSubscribersOnly'], showSubscribersOnly.value);
      showVipsOnly.value = _asBool(chat['showVipModsOnly'], showVipsOnly.value);
      multiChatMergedMode.value =
          _asBool(chat['multiChatMergedMode'], multiChatMergedMode.value);
      fontSize.value = _asString(chat['fontSize'], fontSize.value);

      final platforms = chat['selectedPlatforms'];
      if (platforms is List && platforms.isNotEmpty) {
        final normalized = platforms
            .map((e) => e.toString().toLowerCase())
            .toList();
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
      final platformColours = appearance['platformColours'];
      if (platformColours is Map) {
        final twitch = platformColours['twitch'];
        final kick = platformColours['kick'];
        final youtube = platformColours['youtube'];
        final twitchHex = twitch is Map ? twitch['color']?.toString() : null;
        final kickHex = kick is Map ? kick['color']?.toString() : null;
        final youtubeHex =
            youtube is Map ? youtube['color']?.toString() : null;
        final tColor = _parseHexColor(twitchHex);
        final kColor = _parseHexColor(kickHex);
        final yColor = _parseHexColor(youtubeHex);
        if (tColor != null) twitchColor.value = tColor;
        if (kColor != null) kickColor.value = kColor;
        if (yColor != null) youtubeColor.value = yColor;
      }
    }

    final language = settings['language'];
    if (language is Map) {
      appLanguage.value = _asString(language['appLanguage'], appLanguage.value);
      clockFormat.value = _asString(language['clock'], clockFormat.value);
      timeZoneDetection.value =
          _asBool(language['timeZoneDetection'], timeZoneDetection.value);
    }

    final other = settings['other'];
    if (other is Map) {
      lowPowerMode.value = _asBool(other['lowPowerMode'], lowPowerMode.value);
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
}
