class ChatMessage {
  ChatMessage({
    required this.platform,
    required this.userName,
    required this.message,
    required this.timestamp,
    this.id,
    this.raw,
  });

  final String platform; // e.g. "twitch"
  final String userName;
  final String message;
  final DateTime timestamp;
  final String? id;
  final Map<String, dynamic>? raw;

  String get dedupeKey {
    final t = timestamp.toUtc().millisecondsSinceEpoch;
    return '${platform.toLowerCase()}|${id ?? ''}|$t|$userName|$message';
  }
}

