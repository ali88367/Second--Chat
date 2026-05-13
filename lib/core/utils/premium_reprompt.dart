import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls how often the Premium paywall flow is shown to non-subscribers.
///
/// Requirement: re-show every 3–5 days when the user opens the app.
class PremiumReprompt {
  PremiumReprompt._();

  static const String _kNextEligibleAtMs = 'second_chat.premium.next_eligible_at_ms';
  static const String _kLastShownAtMs = 'second_chat.premium.last_shown_at_ms';

  static Future<DateTime?> readNextEligibleAt() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_kNextEligibleAtMs);
    if (v == null || v <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true).toLocal();
  }

  static Future<void> markShownNowAndScheduleNext({Random? random}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final rng = random ?? Random();
    // 3–5 days (inclusive).
    final days = 3 + rng.nextInt(3);
    final next = now.add(Duration(days: days));
    await prefs.setInt(_kLastShownAtMs, now.toUtc().millisecondsSinceEpoch);
    await prefs.setInt(_kNextEligibleAtMs, next.toUtc().millisecondsSinceEpoch);
    if (kDebugMode) {
      debugPrint('[PremiumReprompt] shown=$now nextEligible=$next (days=$days)');
    }
  }

  static Future<bool> isEligibleNow() async {
    final prefs = await SharedPreferences.getInstance();
    final nextMs = prefs.getInt(_kNextEligibleAtMs);
    if (nextMs == null || nextMs <= 0) return true; // never shown before
    final next = DateTime.fromMillisecondsSinceEpoch(nextMs, isUtc: true);
    return DateTime.now().toUtc().isAfter(next) || DateTime.now().toUtc().isAtSameMomentAs(next);
  }
}

