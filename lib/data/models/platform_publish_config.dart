/// RTMP publish credentials for one streaming platform.
class PlatformPublishConfig {
  const PlatformPublishConfig({
    required this.platform,
    required this.broadcasterId,
    required this.channel,
    required this.streamKey,
    required this.serverUrl,
    required this.fullRtmpUrl,
    this.backupServerUrl = '',
    this.broadcastId,
    this.youtubeStreamId,
    this.watchUrl,
    this.canStartBroadcastViaApi = false,
    this.requiresClientEncoder = true,
    this.hasManualConfig = false,
  });

  final String platform;
  final String broadcasterId;
  final String channel;
  final String streamKey;
  final String serverUrl;
  final String backupServerUrl;
  final String? broadcastId;
  final String? youtubeStreamId;
  final String fullRtmpUrl;
  final String? watchUrl;
  final bool canStartBroadcastViaApi;
  final bool requiresClientEncoder;
  final bool hasManualConfig;

  bool get hasRtmpCredentials =>
      ingestServerUrls.isNotEmpty && streamKey.trim().isNotEmpty;

  /// Primary then backup RTMP ingest URLs (plain `rtmp://`, never RTMPS).
  List<String> get ingestServerUrls {
    final urls = <String>[];
    for (final raw in [serverUrl, backupServerUrl]) {
      final normalized = _normalizeIngestServer(raw);
      if (normalized.isEmpty) continue;
      if (!urls.contains(normalized)) urls.add(normalized);
    }
    return urls;
  }

  static String _rtmpsToRtmp(String url) {
    var out = url.trim();
    if (out.isEmpty) return '';
    if (out.toLowerCase().startsWith('rtmps://')) {
      out = 'rtmp://${out.substring('rtmps://'.length)}';
    }
    return out;
  }

  /// Builds a full RTMP publish URL with the stream key embedded.
  static String buildFullRtmpPublishUrl(String serverUrl, String streamKey) {
    final key = streamKey.trim();
    var base = _rtmpsToRtmp(serverUrl.trim());
    if (base.isEmpty || key.isEmpty) return '';

    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }

    final queryIndex = base.indexOf('?');
    if (queryIndex >= 0) {
      final path = base.substring(0, queryIndex);
      final query = base.substring(queryIndex);
      return '$path/$key$query';
    }

    return '$base/$key';
  }

  /// Primary then backup full RTMP URLs (`rtmp://host/app/key`).
  List<String> get fullRtmpPublishUrls {
    final urls = <String>[];
    for (final server in ingestServerUrls) {
      final full = buildFullRtmpPublishUrl(server, streamKey);
      if (full.isNotEmpty && !urls.contains(full)) urls.add(full);
    }
    return urls;
  }

  String _normalizeIngestServer(String raw) {
    var url = _rtmpsToRtmp(raw);
    if (url.isEmpty) return '';
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  factory PlatformPublishConfig.fromJson(
    String platformKey,
    Map<String, dynamic> json,
  ) {
    final platform = platformKey.toLowerCase().trim();
    final rtmp = json['rtmp'];
    final playback = json['playback'];
    final capabilities = json['capabilities'];
    final manual = json['manualConfig'] ??
        json['manual'] ??
        json['manualSetup'];

    String serverUrl = '';
    String backupServerUrl = '';
    String streamKey = '';
    String fullUrl = '';

    if (rtmp is Map) {
      final m = Map<String, dynamic>.from(rtmp);
      streamKey = _firstNonEmpty([
        m['streamKey'],
        m['key'],
      ]);

      if (platform == 'youtube') {
        // apivideo_live_stream / StreamPack: plain RTMP only (no RTMPS/TLS).
        serverUrl = _rtmpsToRtmp(_firstNonEmpty([
          m['ingestionAddress'],
          m['serverUrl'],
          m['url'],
        ]));
        backupServerUrl = _rtmpsToRtmp(_firstNonEmpty([
          m['backupIngestionAddress'],
          m['backupServerUrl'],
        ]));

        fullUrl = _firstNonEmpty([
          m['primaryFullUrl'],
          m['fullUrl'],
          m['fullRtmpUrl'],
        ]);

        if (serverUrl.isEmpty) {
          serverUrl = _rtmpsToRtmp(_firstNonEmpty([
            m['rtmpsIngestionAddress'],
          ]));
        }
        if (backupServerUrl.isEmpty) {
          backupServerUrl = _rtmpsToRtmp(_firstNonEmpty([
            m['rtmpsBackupIngestionAddress'],
          ]));
        }

        if (streamKey.isEmpty && fullUrl.isNotEmpty) {
          final parsed = _splitRtmpFullUrl(fullUrl);
          streamKey = parsed.$2;
          if (serverUrl.isEmpty) serverUrl = parsed.$1;
        }
      } else {
        serverUrl = _firstNonEmpty([
          m['serverUrl'],
          m['ingestionAddress'],
          m['streamUrl'],
          m['url'],
        ]);
        fullUrl = _firstNonEmpty([
          m['fullUrl'],
          m['fullRtmpUrl'],
          m['primaryFullUrl'],
        ]);
      }
    }

    streamKey = streamKey.isNotEmpty
        ? streamKey
        : _firstNonEmpty([json['streamKey'], json['key']]);

    serverUrl = serverUrl.isNotEmpty
        ? serverUrl
        : _firstNonEmpty([
            json['serverUrl'],
            json['rtmpUrl'],
            json['streamUrl'],
          ]);

    if (fullUrl.isEmpty) {
      final preferred = json['preferredIngestServer'];
      if (preferred is Map && streamKey.isNotEmpty) {
        final template =
            (preferred['urlTemplate'] ?? '').toString().trim();
        if (template.isNotEmpty) {
          fullUrl = template.replaceAll('{stream_key}', streamKey);
          if (serverUrl.isEmpty && fullUrl.contains('/')) {
            serverUrl = fullUrl.substring(0, fullUrl.lastIndexOf('/'));
          }
        }
      }
    }

    if (manual is Map) {
      final manualMap = Map<String, dynamic>.from(manual);
      streamKey = streamKey.isNotEmpty
          ? streamKey
          : _firstNonEmpty([
              manualMap['streamKey'],
              manualMap['key'],
            ]);
      serverUrl = serverUrl.isNotEmpty
          ? serverUrl
          : _firstNonEmpty([
              manualMap['streamUrl'],
              manualMap['serverUrl'],
              manualMap['url'],
            ]);
    }

    if (fullUrl.isEmpty && serverUrl.isNotEmpty && streamKey.isNotEmpty) {
      final base = serverUrl.endsWith('/') ? serverUrl : '$serverUrl/';
      fullUrl = '$base$streamKey';
    }

    if (serverUrl.isEmpty && fullUrl.isNotEmpty) {
      final parsed = _splitRtmpFullUrl(fullUrl);
      if (parsed.$1.isNotEmpty) {
        serverUrl = _rtmpsToRtmp(parsed.$1);
      } else {
        final slash = fullUrl.lastIndexOf('/');
        if (slash > 'rtmp://'.length) {
          serverUrl = _rtmpsToRtmp(fullUrl.substring(0, slash));
        }
      }
    }

    final hasManual = manual is Map
        ? _firstNonEmpty([
              manual['streamKey'],
              manual['key'],
              manual['streamUrl'],
              manual['serverUrl'],
            ]).isNotEmpty ||
            manual['configured'] == true ||
            manual['hasStreamKey'] == true
        : json['hasManualConfig'] == true ||
            json['manualConfigured'] == true;

    return PlatformPublishConfig(
      platform: platform,
      broadcasterId: _firstNonEmpty([
        json['broadcasterId'],
        json['broadcasterUserId'],
        json['channelId'],
      ]),
      channel: _firstNonEmpty([
        json['channel'],
        json['username'],
      ]),
      streamKey: streamKey,
      serverUrl: serverUrl,
      backupServerUrl: backupServerUrl,
      broadcastId: _firstNonEmpty([json['broadcastId']]).isEmpty
          ? null
          : _firstNonEmpty([json['broadcastId']]),
      youtubeStreamId: _firstNonEmpty([json['streamId']]).isEmpty
          ? null
          : _firstNonEmpty([json['streamId']]),
      fullRtmpUrl: fullUrl,
      watchUrl: playback is Map
          ? _firstNonEmpty([
              playback['watchUrl'],
              playback['url'],
            ])
          : null,
      canStartBroadcastViaApi: capabilities is Map
          ? capabilities['canStartBroadcastViaApi'] == true ||
              capabilities['canFetchCredentialsViaApi'] == true
          : json['canStartBroadcastViaApi'] == true,
      requiresClientEncoder: capabilities is Map
          ? capabilities['requiresClientEncoder'] != false
          : json['requiresClientEncoder'] != false,
      hasManualConfig: hasManual && streamKey.isNotEmpty,
    );
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  /// Splits `rtmp(s)://host/app/streamKey` into server URL + key.
  static (String, String) _splitRtmpFullUrl(String fullUrl) {
    var url = _rtmpsToRtmp(fullUrl.trim());
    if (url.isEmpty) return ('', '');

    final schemeEnd = url.indexOf('://');
    if (schemeEnd < 0) return ('', '');

    final pathStart = url.indexOf('/', schemeEnd + 3);
    if (pathStart < 0) return (url, '');

    final keyStart = url.lastIndexOf('/');
    if (keyStart <= pathStart) return (url.substring(0, keyStart), '');

  final key = url.substring(keyStart + 1);
    final server = url.substring(0, keyStart);
    return (server, key);
  }
}

/// Combined publish-config payload (bulk or multi-platform).
class PublishConfigBundle {
  const PublishConfigBundle({
    required this.byPlatform,
    this.unifiedIngest,
  });

  final Map<String, PlatformPublishConfig> byPlatform;
  final PlatformPublishConfig? unifiedIngest;

  PlatformPublishConfig? forPlatform(String platform) =>
      byPlatform[platform.toLowerCase().trim()];

  bool get hasAnyRtmpCredentials =>
      unifiedIngest?.hasRtmpCredentials == true ||
      byPlatform.values.any((c) => c.hasRtmpCredentials);

  /// Best RTMP ingest for the selected platform(s).
  PlatformPublishConfig? resolveIngestForPlatforms(
    Iterable<String> platformKeys,
  ) {
    final normalized = platformKeys.map((p) => p.toLowerCase().trim()).toList();

    // Prefer platform-specific credentials (YouTube/Twitch/Kick ingest URLs).
    for (final key in normalized) {
      final config = forPlatform(key);
      if (config != null && config.hasRtmpCredentials) return config;
    }

    if (unifiedIngest != null && unifiedIngest!.hasRtmpCredentials) {
      return unifiedIngest;
    }

    for (final entry in byPlatform.entries) {
      if (entry.value.hasRtmpCredentials) return entry.value;
    }
    return null;
  }

  PlatformPublishConfig? ingestForPlatform(String platform) {
    final config = forPlatform(platform);
    if (config != null && config.hasRtmpCredentials) return config;
    return null;
  }
}
