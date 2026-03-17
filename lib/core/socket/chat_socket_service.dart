import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../data/models/chat_message.dart';

class ChatSocketService extends GetxService {
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxInt viewerCount = 0.obs;
  final RxBool isConnected = false.obs;

  io.Socket? _socket;
  Timer? _reconnectTimer;
  bool _manuallyDisconnected = false;

  // Prevent duplicate messages (bounded memory).
  final Map<String, DateTime> _seen = <String, DateTime>{};
  static const int _seenMax = 600;
  static const Duration _seenTtl = Duration(minutes: 10);

  Future<void> connect({
    required String baseUrl,
    required String path,
    required String accessToken,
  }) async {
    try {
      _manuallyDisconnected = false;
      await disconnect(); // ensures clean slate

      final socket = io.io(
        baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setPath(path)
            .setAuth({'token': accessToken})
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(999999)
            .setReconnectionDelay(700)
            .setReconnectionDelayMax(4000)
            .build(),
      );

      _socket = socket;

      socket.on('connect', (_) {
        isConnected.value = true;
        _emitStart();
      });

      socket.on('disconnect', (_) {
        isConnected.value = false;
        if (!_manuallyDisconnected) {
          _scheduleReconnect();
        }
      });

      socket.on('connect_error', (_) {
        isConnected.value = false;
        if (!_manuallyDisconnected) {
          _scheduleReconnect();
        }
      });

      socket.on('chat:message', (payload) {
        final msg = _parseChatMessage(payload);
        if (msg == null) return;
        if (_dedupe(msg)) return;
        messages.add(msg);
      });

      socket.on('viewer_count:update', (payload) {
        final v = _parseViewerCount(payload);
        if (v != null) viewerCount.value = v;
      });

      socket.connect();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _manuallyDisconnected = true;
    try {
      _emitStop();
    } catch (_) {}
    try {
      _socket?.dispose();
    } catch (_) {
      try {
        _socket?.disconnect();
      } catch (_) {}
    }
    _socket = null;
    isConnected.value = false;
  }

  Future<void> reconnect({
    required String baseUrl,
    required String path,
    required String accessToken,
  }) async {
    await connect(baseUrl: baseUrl, path: path, accessToken: accessToken);
  }

  void _emitStart() {
    try {
      _socket?.emit('chat:start');
    } catch (_) {}
  }

  void _emitStop() {
    try {
      _socket?.emit('chat:stop');
    } catch (_) {}
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      // Actual reconnect is driven by Socket.IO's internal reconnection too.
      // This timer is a guard to ensure we attempt connect if something got stuck.
      try {
        _socket?.connect();
      } catch (_) {}
    });
  }

  bool _dedupe(ChatMessage msg) {
    final now = DateTime.now().toUtc();
    // purge
    final cutoff = now.subtract(_seenTtl);
    _seen.removeWhere((_, t) => t.isBefore(cutoff));

    final key = msg.dedupeKey;
    if (_seen.containsKey(key)) return true;
    _seen[key] = now;

    // cap
    if (_seen.length > _seenMax) {
      final keys = _seen.keys.toList(growable: false);
      // remove roughly oldest half (map iteration order is insertion order in Dart)
      final removeCount = (_seen.length - _seenMax) + 50;
      for (var i = 0; i < removeCount && i < keys.length; i++) {
        _seen.remove(keys[i]);
      }
    }
    return false;
  }

  ChatMessage? _parseChatMessage(dynamic payload) {
    try {
      Map<String, dynamic>? map;
      if (payload is Map) {
        map = payload.cast<String, dynamic>();
      } else if (payload is String) {
        final decoded = jsonDecode(payload);
        if (decoded is Map) map = decoded.cast<String, dynamic>();
      }
      if (map == null) return null;

      final platform =
          (map['platform'] ?? map['source'] ?? 'twitch').toString();
      final user = (map['sender_username'] ??
              map['senderUsername'] ??
              map['user'] ??
              map['username'] ??
              map['name'] ??
              map['displayName'] ??
              'Unknown')
          .toString();
      final message = (map['message'] ?? map['text'] ?? '').toString();
      if (message.trim().isEmpty) return null;

      final id = (map['platform_message_id'] ??
              map['platformMessageId'] ??
              map['id'] ??
              map['_id'] ??
              map['messageId'])
          ?.toString();
      final metadata = map['metadata'];
      final tsRaw = (metadata is Map
              ? (metadata['timestamp'] ?? metadata['ts'] ?? metadata['time'])
              : null) ??
          map['timestamp'] ??
          map['created_at'] ??
          map['createdAt'] ??
          map['ts'] ??
          map['time'];
      final ts = _parseTimestamp(tsRaw) ?? DateTime.now().toUtc();

      return ChatMessage(
        platform: platform,
        userName: user,
        message: message,
        timestamp: ts,
        id: id,
        raw: map,
      );
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseTimestamp(dynamic tsRaw) {
    if (tsRaw == null) return null;
    if (tsRaw is int) {
      if (tsRaw > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(tsRaw, isUtc: true);
      }
      return DateTime.fromMillisecondsSinceEpoch(tsRaw * 1000, isUtc: true);
    }
    if (tsRaw is String) return DateTime.tryParse(tsRaw);
    return null;
  }

  int? _parseViewerCount(dynamic payload) {
    try {
      if (payload is int) return payload;
      if (payload is num) return payload.toInt();
      if (payload is String) return int.tryParse(payload.trim());
      if (payload is Map) {
        final m = payload.cast<String, dynamic>();
        final v = m['viewerCount'] ?? m['viewer_count'] ?? m['count'];
        if (v is num) return v.toInt();
        if (v is String) return int.tryParse(v.trim());
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

