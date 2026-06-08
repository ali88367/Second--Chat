import 'package:dio/dio.dart';

import '../../api/http/api_json.dart';
import '../models/platform_publish_config.dart';

/// Fetches RTMP publish credentials and Kick manual stream configuration.
class PlatformPublishService {
  PlatformPublishService(
    this._dio, {
    Future<void> Function()? ensureSession,
  }) : _ensureSession = ensureSession;

  final Dio _dio;
  final Future<void> Function()? _ensureSession;

  static const _allPublishConfigsPath = '/api/v1/platforms/publish-config';
  static const _platformPublishConfigPath =
      '/api/v1/platforms/:platform/publish-config';
  static const _kickManualConfigPath = '/api/v1/kick/stream/manual-config';

  static const _legacyPaths = <String, String>{
    'twitch': '/api/v1/twitch/stream/publish-config',
    'kick': '/api/v1/kick/stream/publish-config',
    'youtube': '/api/v1/youtube/stream/publish-config',
  };

  Future<void> _ensureAuth() async {
    if (_ensureSession != null) {
      await _ensureSession();
    }
  }

  Future<PublishConfigBundle> fetchAllPublishConfigs({
    List<String> platforms = const ['twitch', 'youtube', 'kick'],
  }) async {
    await _ensureAuth();
    final normalized =
        platforms.map((p) => p.trim().toLowerCase()).where((p) => p.isNotEmpty).toList();

    if (normalized.length == 1) {
      final config = await fetchPublishConfig(normalized.first);
      return PublishConfigBundle(byPlatform: {normalized.first: config});
    }

    try {
      final query = normalized.join(',');
      final res = await _dio.get<dynamic>(
        _allPublishConfigsPath,
        queryParameters: {'platforms': query},
      );
      final bundle = _parseBundle(res.data);
      if (bundle.hasAnyRtmpCredentials || bundle.byPlatform.isNotEmpty) {
        return _mergeMissingPlatforms(bundle, normalized);
      }
    } catch (_) {}

    return _fetchPlatformsIndividually(normalized);
  }

  Future<PlatformPublishConfig> fetchPublishConfig(String platform) async {
    await _ensureAuth();
    final key = platform.toLowerCase().trim();

    Object? lastError;
    final path = _platformPublishConfigPath.replaceFirst(':platform', key);
    try {
      final res = await _dio.get<dynamic>(path);
      final bundle = _parseBundle(res.data, fallbackPlatform: key);
      final config = bundle.forPlatform(key);
      if (config != null) return config;
    } catch (e) {
      lastError = e;
    }

    final legacy = _legacyPaths[key];
    if (legacy != null) {
      try {
        final res = await _dio.get<dynamic>(legacy);
        final bundle = _parseBundle(res.data, fallbackPlatform: key);
        final config = bundle.forPlatform(key);
        if (config != null) return config;
      } catch (e) {
        lastError = e;
      }
    }

    throw DioException(
      requestOptions: RequestOptions(path: path),
      message: _humanize(lastError) ?? 'Missing publish config for $key',
    );
  }

  /// Saves Kick stream URL/key (one-time manual setup).
  Future<void> saveKickManualConfig({
    required String streamKey,
    String? streamId,
    String? streamUrl,
  }) async {
    await _ensureAuth();
    final payload = <String, dynamic>{};
    final key = streamKey.trim();
    final id = streamId?.trim() ?? '';
    final url = streamUrl?.trim() ?? '';
    if (key.isNotEmpty) payload['streamKey'] = key;
    if (id.isNotEmpty) payload['streamId'] = id;
    if (url.isNotEmpty) payload['streamUrl'] = url;
    if (payload.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: _kickManualConfigPath),
        message: 'Kick stream key is required',
      );
    }

    await _dio.patch<dynamic>(_kickManualConfigPath, data: payload);
  }

  Future<PublishConfigBundle> _fetchPlatformsIndividually(
    List<String> platforms,
  ) async {
    final byPlatform = <String, PlatformPublishConfig>{};
    Object? lastError;

    for (final platform in platforms) {
      try {
        byPlatform[platform] = await fetchPublishConfig(platform);
      } catch (e) {
        lastError = e;
      }
    }

    if (byPlatform.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: _allPublishConfigsPath),
        message: _humanize(lastError) ?? 'No publish configs available',
      );
    }

    return PublishConfigBundle(byPlatform: byPlatform);
  }

  Future<PublishConfigBundle> _mergeMissingPlatforms(
    PublishConfigBundle bundle,
    List<String> platforms,
  ) async {
    final merged = Map<String, PlatformPublishConfig>.from(bundle.byPlatform);
    for (final platform in platforms) {
      if (merged.containsKey(platform)) continue;
      try {
        merged[platform] = await fetchPublishConfig(platform);
      } catch (_) {}
    }
    return PublishConfigBundle(
      byPlatform: merged,
      unifiedIngest: bundle.unifiedIngest,
    );
  }

  PublishConfigBundle _parseBundle(
    dynamic root, {
    String? fallbackPlatform,
  }) {
    if (root is! Map) {
      throw DioException(
        requestOptions: RequestOptions(path: _allPublishConfigsPath),
        message: 'Invalid publish-config response',
      );
    }

    final map = Map<String, dynamic>.from(root);
    if (map['success'] == false) {
      final msg = extractString(map, const ['message', 'error']) ??
          'Failed to load publish config';
      throw DioException(
        requestOptions: RequestOptions(path: _allPublishConfigsPath),
        message: msg,
      );
    }

    final data = map['data'];
    if (data is! Map) {
      if (fallbackPlatform != null) {
        return PublishConfigBundle(
          byPlatform: {
            fallbackPlatform: PlatformPublishConfig.fromJson(
              fallbackPlatform,
              map,
            ),
          },
        );
      }
      throw DioException(
        requestOptions: RequestOptions(path: _allPublishConfigsPath),
        message: 'Missing publish-config data',
      );
    }

    final dataMap = Map<String, dynamic>.from(data);
    final byPlatform = <String, PlatformPublishConfig>{};

    PlatformPublishConfig? unifiedIngest;
    for (final key in const [
      'unifiedRtmp',
      'unifiedIngest',
      'ingest',
      'restream',
      'primaryRtmp',
      'combinedIngest',
    ]) {
      final node = dataMap[key];
      if (node is Map) {
        final config = PlatformPublishConfig.fromJson(
          'restream',
          Map<String, dynamic>.from(node),
        );
        if (config.hasRtmpCredentials) {
          unifiedIngest = config;
          break;
        }
      }
    }

    final platformsNode = dataMap['platforms'] ?? dataMap['configs'];
    if (platformsNode is Map) {
      for (final entry in platformsNode.entries) {
        final platformKey = entry.key.toString().toLowerCase().trim();
        if (entry.value is! Map) continue;
        byPlatform[platformKey] = PlatformPublishConfig.fromJson(
          platformKey,
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }

    for (final key in const ['twitch', 'kick', 'youtube']) {
      if (byPlatform.containsKey(key)) continue;
      final node = dataMap[key];
      if (node is Map) {
        byPlatform[key] = PlatformPublishConfig.fromJson(
          key,
          Map<String, dynamic>.from(node),
        );
      }
    }

    if (_looksLikeSinglePlatformConfig(dataMap)) {
      final platform = fallbackPlatform ??
          _detectPlatformKey(dataMap) ??
          'twitch';
      byPlatform.putIfAbsent(
        platform,
        () => PlatformPublishConfig.fromJson(platform, dataMap),
      );
    } else if (byPlatform.isEmpty && fallbackPlatform != null) {
      byPlatform[fallbackPlatform] = PlatformPublishConfig.fromJson(
        fallbackPlatform,
        dataMap,
      );
    }

    if (byPlatform.isEmpty && unifiedIngest == null) {
      throw DioException(
        requestOptions: RequestOptions(path: _allPublishConfigsPath),
        message: 'No publish configs in response',
      );
    }

    return PublishConfigBundle(
      byPlatform: byPlatform,
      unifiedIngest: unifiedIngest,
    );
  }

  bool _looksLikeSinglePlatformConfig(Map<String, dynamic> dataMap) {
    return dataMap.containsKey('rtmp') ||
        dataMap.containsKey('streamKey') ||
        dataMap.containsKey('ingestServers') ||
        dataMap.containsKey('manualSetup') ||
        dataMap.containsKey('broadcastId');
  }

  String? _detectPlatformKey(Map<String, dynamic> dataMap) {
    if (dataMap.containsKey('ingestServers') ||
        dataMap.containsKey('preferredIngestServer')) {
      return 'twitch';
    }
    if (dataMap.containsKey('broadcastId') ||
        (dataMap['ingestionType']?.toString() == 'rtmp' &&
            dataMap.containsKey('channelId'))) {
      return 'youtube';
    }
    if (dataMap.containsKey('manualSetup') ||
        dataMap.containsKey('broadcasterUserId')) {
      return 'kick';
    }
    return null;
  }

  String? _humanize(Object? error) {
    if (error == null) return null;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final msg = data['message'] ?? data['error'];
        if (msg != null && msg.toString().trim().isNotEmpty) {
          return msg.toString();
        }
      }
      return error.message;
    }
    return error.toString();
  }
}
