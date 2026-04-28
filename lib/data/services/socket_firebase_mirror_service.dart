import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';

/// Mirrors selected socket/platform runtime stats to Firestore for testing.
///
/// Default: disabled (set `--dart-define=ENABLE_FIREBASE_SOCKET_MIRROR=true`).
/// When disabled, all calls are no-ops and add effectively zero overhead.
class SocketFirebaseMirrorService extends GetxService {
  static const bool _enabledByConfig = bool.fromEnvironment(
    'ENABLE_FIREBASE_SOCKET_MIRROR',
    defaultValue: true,
  );

  bool _runtimeEnabled = _enabledByConfig;
  bool get enabled => _runtimeEnabled;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, Map<String, dynamic>> _platformData =
      <String, Map<String, dynamic>>{
        'twitch': <String, dynamic>{},
        'kick': <String, dynamic>{},
        'youtube': <String, dynamic>{},
      };
  String? _latestApiAccessToken;
  String? _latestApiTokenSource;
  String? _latestApiTokenPlatform;
  DateTime? _latestApiTokenAt;

  Timer? _flushTimer;
  bool _flushing = false;
  static const Duration _flushDebounce = Duration(milliseconds: 350);

  void setEnabled(bool value) {
    _runtimeEnabled = value;
  }

  void updatePlatformSnapshot({
    required String platform,
    bool? live,
    int? viewerCount,
    String? title,
    String? category,
    bool? socketConnectedInApp,
    bool? accountConnected,
    String? latestEvent,
    DateTime? socketReceivedAt,
  }) {
    if (!enabled) return;
    final p = _normalizePlatform(platform);
    if (p == null) return;

    final target = _platformData[p] ?? <String, dynamic>{};
    if (live != null) target['live'] = live;
    if (viewerCount != null) target['viewerCount'] = viewerCount;
    if (title != null) target['title'] = title;
    if (category != null) target['category'] = category;
    if (socketConnectedInApp != null) {
      target['socketConnectedInApp'] = socketConnectedInApp;
    }
    if (accountConnected != null) {
      target['accountConnected'] = accountConnected;
    }
    if (latestEvent != null) target['latestSocketEvent'] = latestEvent;

    final ts = (socketReceivedAt ?? DateTime.now()).toLocal();
    target['latestSocketTimestamp'] = _formatTs(ts);
    target['latestSocketEpochMs'] = ts.millisecondsSinceEpoch;

    _platformData[p] = target;
    _scheduleFlush();
  }

  void updateLatestApiAccessToken({
    required String token,
    String? source,
    String? platform,
  }) {
    if (!enabled) return;
    final t = token.trim();
    if (t.isEmpty) return;
    _latestApiAccessToken = t;
    _latestApiTokenSource = source?.trim().isNotEmpty == true
        ? source!.trim()
        : null;
    _latestApiTokenPlatform = platform?.trim().isNotEmpty == true
        ? platform!.trim().toLowerCase()
        : null;
    _latestApiTokenAt = DateTime.now().toLocal();
    _scheduleFlush();
  }

  Future<void> flushNow() async {
    if (!enabled || _flushing) return;
    _flushing = true;
    try {
      final docId = _resolveGoogleUsernameDocId();
      if (docId == null) return;
      final now = DateTime.now().toLocal();
      final payload = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'latestSocketTimestamp': _formatTs(now),
        'latestSocketEpochMs': now.millisecondsSinceEpoch,
        if (_latestApiAccessToken != null) 'latestApiAccessToken': _latestApiAccessToken,
        if (_latestApiTokenSource != null) 'latestApiAccessTokenSource': _latestApiTokenSource,
        if (_latestApiTokenPlatform != null) 'latestApiAccessTokenPlatform': _latestApiTokenPlatform,
        if (_latestApiTokenAt != null) 'latestApiAccessTokenTimestamp': _formatTs(_latestApiTokenAt!),
        if (_latestApiTokenAt != null)
          'latestApiAccessTokenEpochMs': _latestApiTokenAt!.millisecondsSinceEpoch,
        'twitch': Map<String, dynamic>.from(
          _platformData['twitch'] ?? const {},
        ),
        'kick': Map<String, dynamic>.from(_platformData['kick'] ?? const {}),
        'youtube': Map<String, dynamic>.from(
          _platformData['youtube'] ?? const {},
        ),
      };
      unawaited(
        _firestore
            .collection('users')
            .doc(docId)
            .set(payload, SetOptions(merge: true)),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SocketFirebaseMirrorService] flush error: $e');
      }
    } finally {
      _flushing = false;
    }
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(_flushDebounce, () {
      unawaited(flushNow());
    });
  }

  String? _resolveGoogleUsernameDocId() {
    try {
      if (!Get.isRegistered<AuthController>()) return null;
      final me = Get.find<AuthController>().me.value;
      final username = (me?['username'] ?? '').toString().trim();
      if (username.isNotEmpty) return username;
      final email = (me?['email'] ?? '').toString().trim();
      if (email.isNotEmpty && email.contains('@')) {
        return email.split('@').first;
      }
    } catch (_) {}
    return null;
  }

  static String? _normalizePlatform(String? raw) {
    final v = (raw ?? '').toLowerCase().trim();
    if (v.isEmpty) return null;
    if (v.contains('twitch')) return 'twitch';
    if (v.contains('kick')) return 'kick';
    if (v.contains('youtube') || v == 'yt' || v.contains('google')) {
      return 'youtube';
    }
    return null;
  }

  static String _formatTs(DateTime dt) {
    final yyyy = dt.year.toString().padLeft(4, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$mi:$ss';
  }

  @override
  void onClose() {
    _flushTimer?.cancel();
    super.onClose();
  }
}
