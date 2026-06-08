class TwitchPublishConfig {
  const TwitchPublishConfig({
    required this.broadcasterId,
    required this.channel,
    required this.streamKey,
    required this.serverUrl,
    required this.fullRtmpUrl,
    this.watchUrl,
    this.canStartBroadcastViaApi = false,
    this.requiresClientEncoder = true,
  });

  final String broadcasterId;
  final String channel;
  final String streamKey;
  final String serverUrl;
  final String fullRtmpUrl;
  final String? watchUrl;
  final bool canStartBroadcastViaApi;
  final bool requiresClientEncoder;

  factory TwitchPublishConfig.fromJson(Map<String, dynamic> json) {
    final rtmp = json['rtmp'];
    final playback = json['playback'];
    final capabilities = json['capabilities'];

    String serverUrl = '';
    String streamKey = '';
    String fullUrl = '';

    if (rtmp is Map) {
      final m = Map<String, dynamic>.from(rtmp);
      serverUrl = (m['serverUrl'] ?? '').toString().trim();
      streamKey = (m['streamKey'] ?? '').toString().trim();
      fullUrl = (m['fullUrl'] ?? '').toString().trim();
    }

    streamKey = streamKey.isNotEmpty
        ? streamKey
        : (json['streamKey'] ?? '').toString().trim();
    serverUrl = serverUrl.isNotEmpty ? serverUrl : '';

    return TwitchPublishConfig(
      broadcasterId: (json['broadcasterId'] ?? '').toString(),
      channel: (json['channel'] ?? '').toString(),
      streamKey: streamKey,
      serverUrl: serverUrl,
      fullRtmpUrl: fullUrl,
      watchUrl: playback is Map
          ? (playback['watchUrl'] ?? '').toString().trim()
          : null,
      canStartBroadcastViaApi: capabilities is Map
          ? capabilities['canStartBroadcastViaApi'] == true
          : false,
      requiresClientEncoder: capabilities is Map
          ? capabilities['requiresClientEncoder'] != false
          : true,
    );
  }
}
