import 'package:intl/intl.dart';

/// True when settings / API use 24-hour clock (`24h`, `24`, etc.).
bool appClockUses24Hour(String? clockFormat) {
  final v = (clockFormat ?? '').toLowerCase().trim();
  return v == '24' || v == '24h';
}

/// Formats a local [DateTime] using the app clock preference (`12h` vs `24h`).
String formatAppClockTime(DateTime local, {required String clockFormat}) {
  if (appClockUses24Hour(clockFormat)) {
    return DateFormat.Hm().format(local);
  }
  return DateFormat.jm().format(local);
}

/// Parses socket/API timestamp values and formats for display in local time.
String formatAppClockTimeFromRaw(
  dynamic tsRaw, {
  required String clockFormat,
}) {
  DateTime? ts;
  if (tsRaw is DateTime) ts = tsRaw;
  if (tsRaw is String) ts = DateTime.tryParse(tsRaw);
  if (tsRaw is int) {
    ts = tsRaw > 1000000000000
        ? DateTime.fromMillisecondsSinceEpoch(tsRaw, isUtc: true)
        : DateTime.fromMillisecondsSinceEpoch(tsRaw * 1000, isUtc: true);
  }
  ts ??= DateTime.now().toUtc();
  return formatAppClockTime(ts.toLocal(), clockFormat: clockFormat);
}
