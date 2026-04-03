Map<String, dynamic>? _asStringKeyedMap(dynamic json) {
  if (json is Map<String, dynamic>) return json;
  if (json is Map) {
    return json.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}

String? extractString(dynamic json, List<String> keys) {
  final m = _asStringKeyedMap(json);
  if (m == null) return null;
  for (final key in keys) {
    final value = m[key];
    if (value is String && value.isNotEmpty) return value;
  }
  final data = m['data'];
  if (data != null) return extractString(data, keys);
  return null;
}

dynamic extractJson(dynamic json, List<String> keys) {
  final m = _asStringKeyedMap(json);
  if (m == null) return null;
  for (final key in keys) {
    if (m.containsKey(key)) return m[key];
  }
  final data = m['data'];
  if (data != null) return extractJson(data, keys);
  return null;
}

