class StreamingOverview {
  StreamingOverview({
    required this.platform,
    required this.live,
    required this.watchUrl,
    required this.chatSocketUrl,
    required this.chatSocketPath,
    this.viewerCount,
    Map<String, int>? viewerCountsByPlatform,
    this.raw,
  }) : viewerCountsByPlatform = viewerCountsByPlatform ?? const {};

  final String platform; // "twitch"
  final bool live;
  final String? watchUrl;
  final String? chatSocketUrl;
  final String? chatSocketPath;
  final int? viewerCount;
  final Map<String, int> viewerCountsByPlatform;
  final Map<String, dynamic>? raw;
}
