/// Extracts a YouTube video id from watch, embed, Shorts, Live, or youtu.be URLs.
String? extractYoutubeVideoId(Uri uri) {
  final host = uri.host.toLowerCase();
  if (host == 'youtu.be') {
    if (uri.pathSegments.isEmpty) return null;
    final id = uri.pathSegments.first.trim();
    return id.isEmpty ? null : id;
  }
  if (!host.contains('youtube.com') && !host.contains('youtube-nocookie.com')) {
    return null;
  }

  final segments = uri.pathSegments;
  if (segments.isEmpty) {
    return uri.queryParameters['v']?.trim();
  }

  final lowerSegments = segments.map((s) => s.toLowerCase()).toList();
  final embedIdx = lowerSegments.indexOf('embed');
  if (embedIdx != -1 && embedIdx + 1 < segments.length) {
    final id = segments[embedIdx + 1].trim();
    return id.isEmpty ? null : id;
  }
  if (lowerSegments.contains('shorts') || lowerSegments.contains('live')) {
    final id = segments.last.trim();
    return id.isEmpty ? null : id;
  }
  if (uri.path.toLowerCase().startsWith('/watch')) {
    final id = uri.queryParameters['v']?.trim();
    return (id == null || id.isEmpty) ? null : id;
  }
  return uri.queryParameters['v']?.trim();
}

bool _isYoutubeHost(Uri uri) {
  final host = uri.host.toLowerCase();
  return host == 'youtu.be' ||
      host.contains('youtube.com') ||
      host.contains('youtube-nocookie.com');
}

/// Normalizes any YouTube playback URL to a WebView-safe nocookie embed.
String normalizeYoutubeEmbedUrl(
  String raw, {
  String? origin,
  bool suppressFullscreen = false,
}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !_isYoutubeHost(uri)) return trimmed;

  final videoId = extractYoutubeVideoId(uri);
  if (videoId == null || videoId.isEmpty) return trimmed;

  final originHost = origin?.trim();
  final qp = <String, String>{
    'autoplay': '1',
    'mute': '1',
    'playsinline': '1',
    'enablejsapi': '1',
    'rel': '0',
    'modestbranding': '1',
  };
  if (originHost != null && originHost.isNotEmpty) {
    qp['origin'] = originHost;
  }
  if (suppressFullscreen) {
    qp['fs'] = '0';
  }
  return Uri.https('www.youtube-nocookie.com', '/embed/$videoId', qp).toString();
}

/// Twitch parent fix aligned with [StreamWebView._sanitizeUrl].
Uri? _uriAfterTwitchParentFix(String trimmed) {
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (uri.host.toLowerCase().contains('player.twitch.tv')) {
    final qp = Map<String, String>.from(uri.queryParameters);
    final parent = qp['parent'];
    if (parent == null || parent.isEmpty || parent == 'localhost') {
      qp['parent'] = 'cafe7bygasco.com';
    }
    return uri.replace(queryParameters: qp);
  }
  return uri;
}

String _normalizedPath(String path) {
  if (path.isEmpty) return '/';
  if (path.length > 1 && path.endsWith('/')) {
    return path.substring(0, path.length - 1);
  }
  return path;
}

/// Stable fingerprint for the same logical embed (query order / harmless rewrites ignored).
String canonicalStreamEmbedIdentity(String raw) {
  var trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final uriProbe = Uri.tryParse(trimmed);
  if (uriProbe != null && _isYoutubeHost(uriProbe)) {
    final normalized = normalizeYoutubeEmbedUrl(trimmed);
    if (normalized.isNotEmpty) {
      trimmed = normalized;
    }
  }
  final uri = _uriAfterTwitchParentFix(trimmed);
  if (uri == null) return trimmed;

  final path = _normalizedPath(uri.path.isEmpty ? '/' : uri.path);
  final port = uri.hasPort ? ':${uri.port}' : '';
  final host = uri.host.toLowerCase();

  final keys = uri.queryParameters.keys.toList()..sort();
  if (keys.isEmpty) {
    return '${uri.scheme}://$host$port$path';
  }
  final pairs = <String>[];
  for (final k in keys) {
    final v = uri.queryParameters[k];
    if (v == null) continue;
    pairs.add(
      '${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(v)}',
    );
  }
  final q = pairs.join('&');
  return '${uri.scheme}://$host$port$path?$q';
}

/// True when two embed URLs refer to the same player document for dedupe / latch purposes.
bool streamEmbedUrlsCanonicallyEqual(String a, String b) {
  final ta = a.trim();
  final tb = b.trim();
  if (ta.isEmpty && tb.isEmpty) return true;
  if (ta.isEmpty || tb.isEmpty) return false;
  if (ta == tb) return true;
  return canonicalStreamEmbedIdentity(ta) == canonicalStreamEmbedIdentity(tb);
}
