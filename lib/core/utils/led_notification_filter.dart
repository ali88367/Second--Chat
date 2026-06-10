import '../../controllers/Main Section Controllers/settings_controller.dart';

/// Decides whether an incoming activity / push should trigger the edge LED bar.
class LedNotificationFilter {
  static bool shouldTrigger({
    required SettingsController settings,
    required String rawActivityType,
    Map<String, dynamic>? event,
  }) {
    if (!settings.notifications.value || !settings.ledNotifications.value) {
      return false;
    }

    final type = _normalizeType(rawActivityType);
    if (type.isEmpty) return false;

    if (_isFollow(type)) {
      return settings.ledNewFollowers.value;
    }

    if (_isSubscribe(type)) {
      if (settings.ledAllSubscribers.value) return true;
      if (!settings.ledMilestoneSubscribers.value) return false;

      final count = _subscriberCount(event);
      final interval = settings.ledMilestoneValue.value.clamp(1, 1000);
      if (count == null) return true;
      return count > 0 && count % interval == 0;
    }

    // Raids, gifts, generic LED socket events, etc.
    return true;
  }

  static String _normalizeType(String? raw) {
    final type = (raw ?? '').toLowerCase().trim().replaceAll(' ', '_');
    switch (type) {
      case 'new_follower':
      case 'new_follow':
        return 'follow';
      case 'new_subscriber':
      case 'new_sub':
      case 'subscription':
        return 'subscribe';
      default:
        return type;
    }
  }

  static bool _isFollow(String type) =>
      type == 'follow' || type.contains('follow');

  static bool _isSubscribe(String type) =>
      type == 'subscribe' ||
      type == 'sub' ||
      type.contains('subscrib');

  static int? _subscriberCount(Map<String, dynamic>? event) {
    if (event == null) return null;

    for (final key in const [
      'subscriberCount',
      'subscriber_count',
      'subCount',
      'sub_count',
      'totalSubs',
      'total_subs',
      'count',
      'milestone',
    ]) {
      final parsed = _asInt(event[key]);
      if (parsed != null) return parsed;
    }

    final metadata = event['metadata'];
    if (metadata is Map) {
      for (final key in const [
        'subscriberCount',
        'subscriber_count',
        'subCount',
        'sub_count',
        'totalSubs',
        'total_subs',
        'count',
        'milestone',
      ]) {
        final parsed = _asInt(metadata[key]);
        if (parsed != null) return parsed;
      }
    }

    return null;
  }

  static int? _asInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }
}
