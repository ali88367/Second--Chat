import 'package:dio/dio.dart';

import '../../api/http/api_json.dart';
import '../models/streaming_overview.dart';

class StreamingService {
  StreamingService(this._dio);

  final Dio _dio;

  String _normalizePlatform(String? raw) {
    final v = (raw ?? '').toLowerCase().trim();
    if (v.isEmpty) return '';
    if (v.contains('twitch')) return 'twitch';
    if (v.contains('kick')) return 'kick';
    if (v.contains('youtube') || v == 'yt' || v.contains('google')) {
      return 'youtube';
    }
    if (v.contains('tiktok')) return 'tiktok';
    return v;
  }

  /// Login/username for chat display from one `platforms[]` entry.
  String? _platformUsernameFromOverviewEntry(Map<String, dynamic> m) {
    var s = extractString(m, const [
      'user_login',
      'login',
      'userLogin',
      'username',
      'user_name',
      'userName',
      'display_name',
      'displayName',
    ]);
    if (s != null && s.trim().isNotEmpty) return s.trim();
    final si = m['streamInfo'];
    if (si is Map) {
      final sm = si.cast<String, dynamic>();
      s = extractString(sm, const [
        'user_login',
        'login',
        'userLogin',
        'username',
        'user_name',
        'display_name',
        'displayName',
      ]);
      if (s != null && s.trim().isNotEmpty) return s.trim();
    }
    return null;
  }

  int? _extractInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  Future<StreamingOverview?> fetchOverview({
    required String platform,
    required String accessToken,
  }) async {
    final normalizedPlatform = _normalizePlatform(platform).isEmpty
        ? platform.toLowerCase().trim()
        : _normalizePlatform(platform);
    try {
      final res = await _dio.get<dynamic>(
        '/api/v1/streaming/overview',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
        queryParameters: {'platform': normalizedPlatform},
      );

      final json = res.data;
      final parsed = _parseOverview(json, platform: normalizedPlatform);
      if (parsed != null) return parsed;

      // Some deployments may not accept the `platform` query param.
      final res2 = await _dio.get<dynamic>(
        '/api/v1/streaming/overview',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      return _parseOverview(res2.data, platform: normalizedPlatform);
    } catch (_) {
      return null;
    }
  }

  /// Parses GET /api/v1/streaming/overview response.
  /// Expects: { "success": true, "data": { "chatSocketUrl", "chatSocketPath", "platforms": [ { "platform", "live", "player": { "watchUrl", "embedUrl", "chatUrl" } } ] } }
  /// Picks the requested platform from data.platforms and uses top-level socket fields.
  ///
  /// IMPORTANT: For WebView playback we prefer `player.embedUrl` over `player.watchUrl`.
  StreamingOverview? _parseOverview(dynamic json, {required String platform}) {
    final data = _unwrapData(json);
    if (data is! Map) return null;
    final map = data.cast<String, dynamic>();

    final socketUrl =
        extractString(map, const ['chatSocketUrl', 'chat_socket_url']);
    final socketPath =
        extractString(map, const ['chatSocketPath', 'chat_socket_path']);

    final platformsList = map['platforms'];
    if (platformsList is List) {
      final viewerCountsByPlatform = <String, int>{};
      final liveByPlatform = <String, bool>{};
      final embedUrlByPlatform = <String, String?>{};
      final usernamesByPlatform = <String, String?>{};
      for (final p in platformsList) {
        if (p is! Map) continue;
        final m = p.cast<String, dynamic>();
        final pNameRaw = (m['platform'] ?? m['name'] ?? '').toString().trim();
        if (pNameRaw.isEmpty) continue;
        final pKey = _normalizePlatform(pNameRaw);
        if (pKey.isEmpty) continue;

        final uname = _platformUsernameFromOverviewEntry(m);
        if (uname != null && uname.isNotEmpty) {
          usernamesByPlatform[pKey] = uname;
        }

        final liveRaw = m['live'];
        final live = liveRaw is bool
            ? liveRaw
            : (liveRaw?.toString().toLowerCase() == 'true');
        liveByPlatform[pKey] = live;

        // API field name varies across deployments.
        final count = _extractInt(m, const [
          'viewerCount',
          'viewer_count',
          'viewers',
          'viewer_count_live',
          'liveViewerCount',
          'live_viewer_count',
          'views',
          'viewCount',
          'view_count',
        ]);
        if (count != null) viewerCountsByPlatform[pKey] = count;

        final playerAny = m['player'];
        if (playerAny is Map) {
          final embedUrl =
              extractString(playerAny, const ['embedUrl', 'embed_url']);
          final watchUrl =
              extractString(playerAny, const ['watchUrl', 'watch_url', 'url']);
          embedUrlByPlatform[pKey] =
              (embedUrl != null && embedUrl.trim().isNotEmpty)
                  ? embedUrl
                  : watchUrl;
        }
      }

      final key = _normalizePlatform(platform);
      for (final p in platformsList) {
        if (p is! Map) continue;
        final m = p.cast<String, dynamic>();
        final pName = _normalizePlatform(
          (m['platform'] ?? m['name'] ?? '').toString(),
        );
        if (pName != key) continue;

        final liveRaw = m['live'];
        final live = liveRaw is bool
            ? liveRaw
            : (liveRaw?.toString().toLowerCase() == 'true');

        final player = m['player'];
        String? embedUrl;
        String? watchUrl;
        if (player is Map) {
          embedUrl = extractString(player, const ['embedUrl', 'embed_url']);
          watchUrl =
              extractString(player, const ['watchUrl', 'watch_url', 'url']);
        }
        embedUrl ??= extractString(m, const ['embedUrl', 'embed_url']);
        watchUrl ??= extractString(m, const ['watchUrl', 'watch_url']);

        final viewerCount = viewerCountsByPlatform[key] ??
            _extractInt(m, const [
              'viewerCount',
              'viewer_count',
              'viewers',
              'viewer_count_live',
              'liveViewerCount',
              'live_viewer_count',
              'views',
              'viewCount',
              'view_count',
            ]);

        return StreamingOverview(
          platform: platform,
          live: live,
          watchUrl: (embedUrl != null && embedUrl.trim().isNotEmpty)
              ? embedUrl
              : watchUrl,
          chatSocketUrl: socketUrl,
          chatSocketPath: socketPath,
          viewerCount: viewerCount,
          viewerCountsByPlatform: viewerCountsByPlatform,
          liveByPlatform: liveByPlatform,
          embedUrlByPlatform: embedUrlByPlatform,
          usernamesByPlatform: usernamesByPlatform,
          raw: map,
        );
      }
    }

    // Fallback: treat data as single platform object (legacy shape).
    final liveRaw = map['live'];
    final live = liveRaw is bool
        ? liveRaw
        : (liveRaw?.toString().toLowerCase() == 'true');
    final player = map['player'];
    String? embedUrl;
    String? watchUrl;
    if (player is Map) {
      embedUrl = extractString(player, const ['embedUrl', 'embed_url']);
      watchUrl = extractString(player, const ['watchUrl', 'watch_url', 'url']);
    }
    embedUrl ??= extractString(map, const ['embedUrl', 'embed_url']);
    watchUrl ??= extractString(map, const ['watchUrl', 'watch_url']);

    final viewerCount = _extractInt(map, const [
      'viewerCount',
      'viewer_count',
      'viewers',
      'viewer_count_live',
      'liveViewerCount',
      'live_viewer_count',
      'views',
      'viewCount',
      'view_count',
    ]);
    final pNorm = _normalizePlatform(platform);
    final legacyUser = _platformUsernameFromOverviewEntry(map);
    final usernamesLegacy = (legacyUser != null && legacyUser.isNotEmpty)
        ? <String, String?>{pNorm: legacyUser}
        : const <String, String?>{};
    return StreamingOverview(
      platform: platform,
      live: live,
      watchUrl: (embedUrl != null && embedUrl.trim().isNotEmpty)
          ? embedUrl
          : watchUrl,
      chatSocketUrl: socketUrl,
      chatSocketPath: socketPath,
      viewerCount: viewerCount,
      viewerCountsByPlatform: viewerCount == null
          ? const {}
          : {pNorm: viewerCount},
      liveByPlatform: {pNorm: live},
      embedUrlByPlatform: {
        pNorm: (embedUrl != null && embedUrl.trim().isNotEmpty)
            ? embedUrl
            : watchUrl
      },
      usernamesByPlatform: usernamesLegacy,
      raw: map,
    );
  }

  dynamic _unwrapData(dynamic json) {
    if (json is Map && json['data'] != null) return json['data'];
    return json;
  }
}
