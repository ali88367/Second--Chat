class StreamingOverview {
  StreamingOverview({
    required this.platform,
    required this.live,
    required this.watchUrl,
    required this.chatSocketUrl,
    required this.chatSocketPath,
    this.raw,
  });

  final String platform; // "twitch"
  final bool live;
  final String? watchUrl;
  final String? chatSocketUrl;
  final String? chatSocketPath;
  final Map<String, dynamic>? raw;
}

