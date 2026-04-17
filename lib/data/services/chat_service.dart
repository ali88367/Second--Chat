import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';

String? _historyNonEmpty(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

const int _kHistoryResponseLogMaxChars = 12000;
const Duration _kHistoryConnectTimeout = Duration(seconds: 45);
const Duration _kHistoryReceiveTimeout = Duration(seconds: 45);
const int _kHistoryTimeoutRetryAttempts = 1;

dynamic _jsonSafeForHistoryLog(dynamic v) {
  if (v == null || v is num || v is String || v is bool) return v;
  if (v is DateTime) return v.toIso8601String();
  if (v is Map) {
    final out = <String, dynamic>{};
    for (final e in v.entries) {
      out[e.key.toString()] = _jsonSafeForHistoryLog(e.value);
    }
    return out;
  }
  if (v is Iterable) {
    return v.map(_jsonSafeForHistoryLog).toList();
  }
  return v.toString();
}

/// Full HTTP body as JSON text for the live log UI (truncated).
String _responseBodyJsonForLog(dynamic data) {
  try {
    final s = jsonEncode(_jsonSafeForHistoryLog(data));
    if (s.length <= _kHistoryResponseLogMaxChars) return s;
    return '${s.substring(0, _kHistoryResponseLogMaxChars)}…';
  } catch (_) {
    final s = data?.toString() ?? 'null';
    if (s.length <= _kHistoryResponseLogMaxChars) return s;
    return '${s.substring(0, _kHistoryResponseLogMaxChars)}…';
  }
}

/// Per [API_SOCKET_DETAILS.md] GET `/chat/history`: `{ success, data: [...], activities, timeline, context }` — log only [data] for readability.
dynamic _chatHistoryEnvelopeDataOnly(dynamic root) {
  if (root is Map && root['data'] != null) return root['data'];
  return root;
}

List<Map<String, dynamic>> _parseHistoryActivities(dynamic root) {
  if (root is! Map) return const [];
  final act = root['activities'];
  if (act is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final item in act) {
    if (item is Map<String, dynamic>) {
      out.add(Map<String, dynamic>.from(item));
    } else if (item is Map) {
      out.add(Map<String, dynamic>.from(item.cast<String, dynamic>()));
    }
  }
  return out;
}

/// Result of GET `/api/v1/chat/history` including optional [activities] (follow, unfollow, …).
class ChatHistoryLoadResult {
  const ChatHistoryLoadResult({
    required this.messages,
    this.activities = const [],
  });

  final List<ChatMessage> messages;
  final List<Map<String, dynamic>> activities;
}

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
  Future<ChatHistoryLoadResult> loadHistory({
    required String platform,
    required String accessToken,
    int limit = 100,
    int offset = 0,
    void Function(String eventName, String payloadText)? onLogLine,
  }) async {
    final platformKey = platform.trim().toLowerCase();
    final kickDebug = platformKey == 'kick' && kDebugMode;

    void log(String event, Map<String, dynamic> fields) {
      try {
        onLogLine?.call(event, jsonEncode(fields));
      } catch (_) {}
    }

    log('api:chat/history', {
      'phase': 'request',
      'method': 'GET',
      'path': '/api/v1/chat/history',
      'platform': platform,
      'limit': limit,
      'offset': offset,
    });

    if (kickDebug) {
      debugPrint(
        '[SC_CHAT_HISTORY_KICK] → GET /api/v1/chat/history '
        'platform=$platform limit=$limit offset=$offset '
        '(auth present=${accessToken.trim().isNotEmpty})',
      );
    }

    bool isRetryableTimeout(DioException e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return true;
      }
      final msg = (e.message ?? '').toLowerCase();
      return msg.contains('timeout');
    }

    for (var attempt = 0; attempt <= _kHistoryTimeoutRetryAttempts; attempt++) {
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
            // History is not latency-critical; allow slower networks.
            connectTimeout: _kHistoryConnectTimeout,
            receiveTimeout: _kHistoryReceiveTimeout,
          ),
        );

        final json = res.data;
        final historyActivities = _parseHistoryActivities(json);
        if (kickDebug) {
          final top =
              json is Map ? json.keys.join(',') : json.runtimeType.toString();
          debugPrint(
            '[SC_CHAT_HISTORY_KICK] ← HTTP ${res.statusCode} bodyTop=$top',
          );
        }

        dynamic data = json;
        if (data is Map && data['data'] != null) data = data['data'];
        if (data is Map && data['messages'] != null) data = data['messages'];

        if (data is! List) {
          log('api:chat/history', {
            'phase': 'response',
            'http': res.statusCode,
            'platform': platformKey,
            'parsedCount': 0,
            'activityCount': historyActivities.length,
            'issue': 'body_not_a_message_list',
            'bodyKind': data.runtimeType.toString(),
            'data': _responseBodyJsonForLog(_chatHistoryEnvelopeDataOnly(json)),
          });
          if (kickDebug) {
            debugPrint(
              '[SC_CHAT_HISTORY_KICK] ⚠ no List in response (got ${data.runtimeType}), returning 0',
            );
          }
          return ChatHistoryLoadResult(
            messages: const [],
            activities: historyActivities,
          );
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
          final metadata = m['metadata'];
          // Align with socket `chat:message`: prefer top-level `username`.
          final user = _historyNonEmpty(m['username']) ??
              _historyNonEmpty(m['sender_username']) ??
              _historyNonEmpty(m['senderUsername']) ??
              _historyNonEmpty(m['login']) ??
              _historyNonEmpty(m['user_login']) ??
              _historyNonEmpty(m['userLogin']) ??
              _historyNonEmpty(m['user']) ??
              _historyNonEmpty(m['name']) ??
              (metadata is Map
                  ? (_historyNonEmpty(metadata['login']) ??
                      _historyNonEmpty(metadata['user_login']) ??
                      _historyNonEmpty(metadata['userLogin']) ??
                      _historyNonEmpty(metadata['sender_username']) ??
                      _historyNonEmpty(metadata['username']) ??
                      _historyNonEmpty(metadata['user']) ??
                      _historyNonEmpty(metadata['display_name']) ??
                      _historyNonEmpty(metadata['displayName']))
                  : null) ??
              'Unknown';
          var text =
              (m['message'] ?? m['text'] ?? m['body'] ?? m['content'] ?? '')
              .toString();
          if (text.trim().isEmpty && metadata is Map) {
            final mm = metadata.cast<String, dynamic>();
            text =
                (mm['message'] ??
                        mm['text'] ??
                        mm['body'] ??
                        mm['content'] ??
                        '')
                    .toString();
          }
          if (text.trim().isEmpty) continue;
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

        log('api:chat/history', {
          'phase': 'response',
          'http': res.statusCode,
          'platform': platformKey,
          'rawRowCount': data.length,
          'parsedCount': out.length,
          'activityCount': historyActivities.length,
          'data': _responseBodyJsonForLog(_chatHistoryEnvelopeDataOnly(json)),
        });

        return ChatHistoryLoadResult(
          messages: out,
          activities: historyActivities,
        );
      } on DioException catch (e, st) {
        final errRoot = e.response?.data;
        final shouldRetry =
            attempt < _kHistoryTimeoutRetryAttempts && isRetryableTimeout(e);
        log('api:chat/history', {
          'phase': 'error',
          'platform': platformKey,
          'type': 'dio',
          'message': e.message ?? e.toString(),
          'http': e.response?.statusCode,
          'attempt': attempt + 1,
          'willRetry': shouldRetry,
          'data': _responseBodyJsonForLog(_chatHistoryEnvelopeDataOnly(errRoot)),
        });
        if (kickDebug) {
          debugPrint(
            '[SC_CHAT_HISTORY_KICK] ✗ dio (attempt ${attempt + 1}/${_kHistoryTimeoutRetryAttempts + 1}): $e',
          );
          if (!shouldRetry) {
            debugPrint('[SC_CHAT_HISTORY_KICK] stack: $st');
          }
        }
        if (shouldRetry) {
          await Future<void>.delayed(const Duration(milliseconds: 600));
          continue;
        }
        return const ChatHistoryLoadResult(messages: []);
      } catch (e, st) {
        log('api:chat/history', {
          'phase': 'error',
          'platform': platformKey,
          'type': 'other',
          'message': e.toString(),
          'attempt': attempt + 1,
        });
        if (kickDebug) {
          debugPrint('[SC_CHAT_HISTORY_KICK] ✗ error: $e');
          debugPrint('[SC_CHAT_HISTORY_KICK] stack: $st');
        }
        return const ChatHistoryLoadResult(messages: []);
      }
    }
    return const ChatHistoryLoadResult(messages: []);
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

