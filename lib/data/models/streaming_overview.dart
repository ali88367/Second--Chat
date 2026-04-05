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
    Map<String, String?>? usernamesByPlatform,
    this.raw,
  })  : viewerCountsByPlatform = viewerCountsByPlatform ?? const {},
        liveByPlatform = liveByPlatform ?? const {},
        embedUrlByPlatform = embedUrlByPlatform ?? const {},
        usernamesByPlatform = usernamesByPlatform ?? const {};

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
  /// Linked account login per platform from overview `platforms[]` (chat display).
  final Map<String, String?> usernamesByPlatform;
  final Map<String, dynamic>? raw;
}
