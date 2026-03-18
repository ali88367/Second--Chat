class StreamingOverview {
  StreamingOverview({
    required this.platform,
    required this.live,
    required this.watchUrl,
    required this.chatSocketUrl,
    required this.chatSocketPath,
    this.viewerCount,
    Map<String, int>? viewerCountsByPlatform,
    Map<String, bool>? liveByPlatform,
    Map<String, String?>? embedUrlByPlatform,
    this.raw,
  })  : viewerCountsByPlatform = viewerCountsByPlatform ?? const {},
        liveByPlatform = liveByPlatform ?? const {},
        embedUrlByPlatform = embedUrlByPlatform ?? const {};

  final String platform; // "twitch"
  final bool live;
  final String? watchUrl;
  final String? chatSocketUrl;
  final String? chatSocketPath;
  final int? viewerCount;
  final Map<String, int> viewerCountsByPlatform;
  final Map<String, bool> liveByPlatform;
  /// Per-platform preferred playback URL (embedUrl if present, else watchUrl).
  final Map<String, String?> embedUrlByPlatform;
  final Map<String, dynamic>? raw;
}
