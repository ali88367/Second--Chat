import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';

class ChatService {
  ChatService(this._dio);

  final Dio _dio;

  Future<void> sendMessage({
    required String platform,
    required String accessToken,
    required String message,
  }) async {
    try {
      await _dio.post<dynamic>(
        '/api/v1/chat/send',
        data: {
          'platform': platform,
          'message': message,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );
    } catch (_) {
      // silent by requirement
    }
  }

  /// GET /api/v1/chat/history?platform=twitch&limit=100&offset=0
  Future<List<ChatMessage>> loadHistory({
    required String platform,
    required String accessToken,
    int limit = 100,
    int offset = 0,
  }) async {
    final platformKey = platform.trim().toLowerCase();
    final kickDebug = platformKey == 'kick' && kDebugMode;

    if (kickDebug) {
      debugPrint(
        '[SC_CHAT_HISTORY_KICK] → GET /api/v1/chat/history '
        'platform=$platform limit=$limit offset=$offset '
        '(auth present=${accessToken.trim().isNotEmpty})',
      );
    }

    try {
      final res = await _dio.get<dynamic>(
        '/api/v1/chat/history',
        queryParameters: {
          'platform': platform,
          'limit': limit,
          'offset': offset,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            // Ensure intermediaries/browsers do not cache chat history responses.
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0',
          },
        ),
      );

      final json = res.data;
      if (kickDebug) {
        final top = json is Map ? json.keys.join(',') : json.runtimeType.toString();
        debugPrint(
          '[SC_CHAT_HISTORY_KICK] ← HTTP ${res.statusCode} bodyTop=$top',
        );
      }

      dynamic data = json;
      if (data is Map && data['data'] != null) data = data['data'];
      if (data is Map && data['messages'] != null) data = data['messages'];

      if (data is! List) {
        if (kickDebug) {
          debugPrint(
            '[SC_CHAT_HISTORY_KICK] ⚠ no List in response (got ${data.runtimeType}), returning 0',
          );
        }
        return const [];
      }

      if (kickDebug) {
        debugPrint(
          '[SC_CHAT_HISTORY_KICK] raw rows=${data.length} before parse',
        );
      }

      final out = <ChatMessage>[];
      for (final item in data) {
        if (item is! Map) continue;
        final m = item.cast<String, dynamic>();
        final user = (m['sender_username'] ??
                m['senderUsername'] ??
                m['user'] ??
                m['username'] ??
                m['name'] ??
                'Unknown')
            .toString();
        final text = (m['message'] ?? m['text'] ?? '').toString();
        if (text.trim().isEmpty) continue;
        final metadata = m['metadata'];
        final tsRaw = (metadata is Map
                ? (metadata['timestamp'] ?? metadata['ts'] ?? metadata['time'])
                : null) ??
            m['timestamp'] ??
            m['created_at'] ??
            m['createdAt'] ??
            m['ts'] ??
            m['time'];
        final ts = _parseTimestamp(tsRaw) ?? DateTime.now().toUtc();
        final id = (m['platform_message_id'] ??
                m['platformMessageId'] ??
                m['id'] ??
                m['_id'] ??
                m['messageId'])
            ?.toString();
        final p = (m['platform'] ?? platform).toString().trim().toLowerCase();
        out.add(
          ChatMessage(
            platform: p,
            userName: user,
            message: text,
            timestamp: ts,
            id: id,
            raw: m,
          ),
        );
      }

      if (kickDebug) {
        debugPrint(
          '[SC_CHAT_HISTORY_KICK] ✓ parsed=${out.length} ChatMessage(s)',
        );
        final n = out.length < 3 ? out.length : 3;
        for (var i = 0; i < n; i++) {
          final msg = out[i];
          final preview = msg.message.length > 48
              ? '${msg.message.substring(0, 48)}…'
              : msg.message;
          debugPrint(
            '[SC_CHAT_HISTORY_KICK]   [$i] user=${msg.userName} '
            'platformField=${msg.platform} id=${msg.id ?? '(none)'} '
            'ts=${msg.timestamp.toIso8601String()} msg="$preview"',
          );
        }
      }

      return out;
    } catch (e, st) {
      if (kickDebug) {
        debugPrint('[SC_CHAT_HISTORY_KICK] ✗ error: $e');
        debugPrint('[SC_CHAT_HISTORY_KICK] stack: $st');
      }
      return const [];
    }
  }

  DateTime? _parseTimestamp(dynamic tsRaw) {
    if (tsRaw == null) return null;
    if (tsRaw is int) {
      // assume ms since epoch
      if (tsRaw > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(tsRaw, isUtc: true);
      }
      // seconds since epoch
      return DateTime.fromMillisecondsSinceEpoch(tsRaw * 1000, isUtc: true);
    }
    if (tsRaw is String) {
      return DateTime.tryParse(tsRaw);
    }
    return null;
  }
}

