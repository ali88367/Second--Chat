import 'package:dio/dio.dart';

import '../../api/http/api_json.dart';
import '../models/platform_publish_config.dart';
import '../models/twitch_publish_config.dart';

/// Fetches Twitch RTMP publish credentials from the backend.
/// Prefer [PlatformPublishService] for multi-platform publishing.
class TwitchPublishService {
  TwitchPublishService(this._dio);

  final Dio _dio;

  static const String _publishConfigPath =
      '/api/v1/twitch/stream/publish-config';

  Future<TwitchPublishConfig> fetchPublishConfig() async {
    final res = await _dio.get<dynamic>(_publishConfigPath);
    final root = res.data;
    if (root is! Map) {
      throw DioException(
        requestOptions: res.requestOptions,
        message: 'Invalid publish-config response',
      );
    }
    final map = Map<String, dynamic>.from(root);
    if (map['success'] == false) {
      final msg = extractString(map, const ['message', 'error']) ??
          'Failed to load Twitch publish config';
      throw DioException(
        requestOptions: res.requestOptions,
        message: msg,
      );
    }
    final data = map['data'];
    if (data is! Map) {
      throw DioException(
        requestOptions: res.requestOptions,
        message: 'Missing publish-config data',
      );
    }
    final platformConfig = PlatformPublishConfig.fromJson(
      'twitch',
      Map<String, dynamic>.from(data),
    );
  final config = _toTwitchConfig(platformConfig);
    if (config.serverUrl.isEmpty || config.streamKey.isEmpty) {
      throw DioException(
        requestOptions: res.requestOptions,
        message: 'Incomplete RTMP credentials from server',
      );
    }
    return config;
  }

  static TwitchPublishConfig _toTwitchConfig(PlatformPublishConfig config) {
    return TwitchPublishConfig(
      broadcasterId: config.broadcasterId,
      channel: config.channel,
      streamKey: config.streamKey,
      serverUrl: config.serverUrl,
      fullRtmpUrl: config.fullRtmpUrl,
      watchUrl: config.watchUrl,
      canStartBroadcastViaApi: config.canStartBroadcastViaApi,
      requiresClientEncoder: config.requiresClientEncoder,
    );
  }
}
