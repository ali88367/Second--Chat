import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Call once (e.g. from main) to print all stored tokens in full (no truncation).
Future<void> debugPrintTokensOnce() async {
  if (!kDebugMode) return;
  try {
    const accessKey = 'second_chat.access_token';
    const refreshKey = 'second_chat.refresh_token';
    const platformKey = 'second_chat.platform_tokens';

    final storage = const FlutterSecureStorage();
    final accessToken = await storage.read(key: accessKey);
    final refreshToken = await storage.read(key: refreshKey);

    final prefs = await SharedPreferences.getInstance();
    final platformRaw = prefs.getString(platformKey);
    final prefsAccess = prefs.getString(accessKey);
    final prefsRefresh = prefs.getString(refreshKey);

    // Use print() so long tokens are not truncated (debugPrint may truncate).
    print('TOKENS: secure_access=${accessToken ?? "null"}');
    print('TOKENS: secure_refresh=${refreshToken ?? "null"}');
    print('TOKENS: prefs_access=${prefsAccess ?? "null"}');
    print('TOKENS: prefs_refresh=${prefsRefresh ?? "null"}');
    print('TOKENS: platform_tokens=${platformRaw ?? "null"}');
  } catch (_) {}
}
