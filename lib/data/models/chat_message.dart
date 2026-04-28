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

  String? get canonicalId {
    String? nonEmpty(dynamic value) {
      if (value == null) return null;
      final s = value.toString().trim();
      return s.isEmpty ? null : s;
    }

    final map = raw;
    final metadata = map?['metadata'];
    final metaMap =
        metadata is Map<String, dynamic>
            ? metadata
            : (metadata is Map ? metadata.cast<String, dynamic>() : null);

    return nonEmpty(map?['normalizedId']) ??
        nonEmpty(map?['normalized_id']) ??
        nonEmpty(map?['platform_message_id']) ??
        nonEmpty(map?['platformMessageId']) ??
        nonEmpty(map?['messageId']) ??
        nonEmpty(map?['message_id']) ??
        nonEmpty(metaMap?['messageId']) ??
        nonEmpty(metaMap?['message_id']) ??
        nonEmpty(id);
  }

  String get dedupeKey {
    final t = timestamp.toUtc().millisecondsSinceEpoch;
    return '${platform.toLowerCase()}|${id ?? ''}|$t|$userName|$message';
  }
}

