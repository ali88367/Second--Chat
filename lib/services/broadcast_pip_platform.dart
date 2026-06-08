import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native picture-in-picture entry (Android) while RTMP broadcast is active.
class BroadcastPipPlatform {
  BroadcastPipPlatform._();

  static const MethodChannel _channel =
      MethodChannel('com.secondchat/broadcast_pip');

  static Future<void> setBroadcastActive(bool active) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('setBroadcastActive', active);
    } catch (e) {
      if (kDebugMode) debugPrint('BroadcastPipPlatform.setBroadcastActive: $e');
    }
  }

  static Future<bool> enterPipIfSupported() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('enterPip');
      return result == true;
    } catch (e) {
      if (kDebugMode) debugPrint('BroadcastPipPlatform.enterPip: $e');
      return false;
    }
  }
}
