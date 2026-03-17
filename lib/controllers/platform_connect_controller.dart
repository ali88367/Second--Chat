import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/config/api_config.dart';
import '../api/auth/oauth_provider.dart';
import 'auth_controller.dart';

class PlatformConnectController extends GetxController {
  PlatformConnectController({AuthController? authController})
      : _auth = authController ?? Get.find<AuthController>();

  final AuthController _auth;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  static const _kPrefsAccessToken = 'second_chat.access_token';
  static const _kPrefsRefreshToken = 'second_chat.refresh_token';
  static const _kPrefsPlatformTokens = 'second_chat.platform_tokens';

  final RxBool isLoading = false.obs;
  final Rxn<OAuthProvider> connectingProvider = Rxn<OAuthProvider>();
  final Rxn<OAuthProvider> disconnectingProvider = Rxn<OAuthProvider>();
  final RxMap<OAuthProvider, bool> isConnected = <OAuthProvider, bool>{}.obs;
  final RxSet<OAuthProvider> optimisticLinked = <OAuthProvider>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _startLinkListener();
    ever(_auth.isAuthenticated, (_) {
      refreshConnections();
    });
    refreshConnections();
  }

  Future<void> _startLinkListener() async {
    _linkSub ??= _appLinks.uriLinkStream.listen((uri) {
      _handleOAuthLink(uri, source: 'stream');
    });

    try {
      final initial = await _readInitialLink();
      if (initial != null) _handleOAuthLink(initial, source: 'initial');
    } catch (e) {
      if (kDebugMode) debugPrint('OAUTH LINK init error: $e');
    }
  }

  Future<Uri?> _readInitialLink() async {
    final dynamic al = _appLinks;
    Uri? initial;
    try {
      final v = await al.getInitialAppLink();
      if (v is Uri) initial = v;
    } catch (_) {}
    try {
      final v = await al.getInitialLink();
      if (v is Uri) {
        initial ??= v;
      } else if (v is String && v.isNotEmpty) {
        initial ??= Uri.tryParse(v);
      }
    } catch (_) {}
    return initial;
  }

  Map<String, String> _allParams(Uri uri) {
    final params = <String, String>{...uri.queryParameters};
    final frag = uri.fragment;
    if (frag.isNotEmpty) {
      try {
        params.addAll(Uri.splitQueryString(frag));
      } catch (_) {}
    }
    return params;
  }

  OAuthProvider? _inferProvider(Map<String, String> params) {
    final raw = (params['provider'] ??
            params['platform'] ??
            params['linked'] ??
            params['source'])
        ?.toLowerCase()
        .trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.contains('twitch')) return OAuthProvider.twitch;
    if (raw.contains('kick')) return OAuthProvider.kick;
    if (raw.contains('youtube') || raw.contains('google')) {
      return OAuthProvider.youtube;
    }
    return null;
  }

  Future<void> _handleOAuthLink(Uri uri, {required String source}) async {
    final params = _allParams(uri);
    final accessToken =
        params['token'] ?? params['accessToken'] ?? params['access_token'];
    final refreshToken = params['refreshToken'] ?? params['refresh_token'];

    if (kDebugMode) {
      debugPrint('CONNECT LINK [$source]: $uri');
      debugPrint('CONNECT LINK [$source] params: $params');
    }

    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return;
    }

    if (kDebugMode) {
      debugPrint('CONNECT TOKENS [$source] accessToken=$accessToken');
      debugPrint('CONNECT TOKENS [$source] refreshToken=$refreshToken');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsAccessToken, accessToken);
    await prefs.setString(_kPrefsRefreshToken, refreshToken);

    final provider = _inferProvider(params);
    if (provider == null) {
      if (kDebugMode) {
        debugPrint(
          'CONNECT TOKENS [$source] provider not found in params; stored global keys only.',
        );
      }
      return;
    }

    final raw = prefs.getString(_kPrefsPlatformTokens);
    Map<String, dynamic> map;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        map = decoded is Map<String, dynamic>
            ? decoded
            : Map<String, dynamic>.from(decoded as Map);
      } catch (_) {
        map = <String, dynamic>{};
      }
    } else {
      map = <String, dynamic>{};
    }

    map[provider.name] = {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };
    await prefs.setString(_kPrefsPlatformTokens, jsonEncode(map));

    if (kDebugMode) {
      debugPrint(
        'CONNECT TOKENS STORED(${provider.name}) prefs=$_kPrefsPlatformTokens map=$map',
      );
    }
  }

  Future<void> refreshConnections() async {
    final token = await _readAccessToken();
    if (token == null) {
      isConnected.assignAll({
        OAuthProvider.twitch: false,
        OAuthProvider.kick: false,
        OAuthProvider.youtube: false,
      });
      return;
    }

    isLoading.value = true;
    try {
      final connections = await _fetchPlatformStatus(token);
      if (kDebugMode) {
        debugPrint('PLATFORMS raw count=${connections.length}');
      }
      final map = <OAuthProvider, bool>{
        OAuthProvider.twitch: false,
        OAuthProvider.kick: false,
        OAuthProvider.youtube: false,
      };

      for (final c in connections) {
        final platformRaw = (c['platform'] ?? c['name'] ?? c['type'] ?? '')
            .toString()
            .toLowerCase();
        // Treat "linked/authorized" separately from "enabled" or "currently connected/live".
        final linkedRaw = c['isLinked'] ??
            c['linked'] ??
            c['authorized'] ??
            c['isAuthorized'] ??
            c['hasAuth'] ??
            c['hasTokens'] ??
            c['hasAccessToken'] ??
            c['accessToken'] ??
            c['refreshToken'] ??
            (c['status']?.toString().toLowerCase() == 'linked') ??
            (c['status']?.toString().toLowerCase() == 'authorized');

        final connectedRaw =
            c['isConnected'] ?? c['connected'] ?? c['isLive'] ?? c['live'];

        bool asBool(dynamic v) {
          if (v is bool) return v;
          if (v is num) return v != 0;
          if (v is String) {
            final s = v.toLowerCase().trim();
            return s == 'true' || s == '1' || s == 'yes' || s == 'connected';
          }
          // Non-empty token strings count as linked.
          if (v != null && v is! bool && v is! num) {
            final s = v.toString();
            return s.isNotEmpty;
          }
          return false;
        }

        final linked = asBool(linkedRaw);
        final connected = asBool(connectedRaw);
        final finalConnected = linked || connected;

        if (kDebugMode) {
          debugPrint(
            'PLATFORMS item platform=$platformRaw linkedRaw=$linkedRaw connectedRaw=$connectedRaw => linked=$linked connected=$connected final=$finalConnected',
          );
        }

        if (platformRaw.contains('twitch')) {
          map[OAuthProvider.twitch] = finalConnected;
        }
        if (platformRaw.contains('kick')) map[OAuthProvider.kick] = finalConnected;
        if (platformRaw.contains('youtube') || platformRaw.contains('google')) {
          map[OAuthProvider.youtube] = finalConnected;
        }
      }

      isConnected.assignAll(map);
      // If backend doesn't reflect link state (or uses a different field), keep optimistic state.
      for (final p in optimisticLinked) {
        if (isConnected[p] != true) isConnected[p] = true;
      }
      if (kDebugMode) debugPrint('PLATFORMS mapped=$map');
    } catch (_) {
      // Keep last known state; avoid noisy UI errors in settings.
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPlatformStatus(String token) async {
    final dio = _buildDio();
    final res = await dio.get<dynamic>(
      '/api/v1/platforms/status',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );
    final json = res.data;
    if (kDebugMode) debugPrint('PLATFORMS STATUS RAW: $json');

    dynamic data = json;
    if (data is Map && data['data'] != null) data = data['data'];

    List<Map<String, dynamic>> fromList(List list) {
      return list
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }

    if (data is List) return fromList(data);
    if (data is Map<String, dynamic>) {
      final platforms = data['platforms'];
      if (platforms is List) return fromList(platforms);

      final out = <Map<String, dynamic>>[];
      for (final entry in data.entries) {
        if (entry.value is Map) {
          final m = (entry.value as Map).cast<String, dynamic>();
          out.add({'platform': entry.key, ...m});
        }
      }
      if (out.isNotEmpty) return out;
    }
    return const [];
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
    final token = prefs.getString(_kPrefsAccessToken)?.trim();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  Future<bool> connect(OAuthProvider provider) async {
    if (connectingProvider.value != null) return false;
    connectingProvider.value = provider;
    bool ok = false;
    try {
      ok = await _auth.connectProvider(provider);
      if (ok) {
        optimisticLinked.add(provider);
        isConnected[provider] = true;
      }
    } finally {
      connectingProvider.value = null;
    }
    await refreshConnections();
    // Backend can take a moment to reflect link status; quick retry if still false.
    if (isConnected[provider] != true) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await refreshConnections();
    }
    return ok;
  }

  Future<bool> disconnect(OAuthProvider provider) async {
    if (disconnectingProvider.value != null) return false;
    disconnectingProvider.value = provider;
    bool ok = false;
    try {
      final token = await _readAccessToken();
      if (token == null) {
        if (kDebugMode) {
          debugPrint('PLATFORMS DISCONNECT ERROR: Missing access token');
        }
        return false;
      }

      final dio = _buildDio();
      final res = await dio.delete<dynamic>(
        '/api/v1/platforms/${provider.name.toLowerCase()}',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final data = res.data;
      if (kDebugMode) {
        debugPrint('PLATFORMS DISCONNECT RESPONSE: $data');
      }

      ok = data is Map && data['success'] == true;
      if (ok) {
        isConnected[provider] = false;
        optimisticLinked.remove(provider);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('PLATFORMS DISCONNECT ERROR: $e');
      if (e is DioException && kDebugMode) {
        debugPrint('PLATFORMS DISCONNECT ERROR RESPONSE: ${e.response?.data}');
      }
    } finally {
      disconnectingProvider.value = null;
    }

    await refreshConnections();
    return ok;
  }

  @override
  void onClose() {
    _linkSub?.cancel();
    super.onClose();
  }
}
