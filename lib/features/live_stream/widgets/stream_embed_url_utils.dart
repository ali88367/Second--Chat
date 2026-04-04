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
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
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
