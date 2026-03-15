String? extractString(dynamic json, List<String> keys) {
  if (json is Map<String, dynamic>) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.isNotEmpty) return value;
    }
    final data = json['data'];
    if (data != null) return extractString(data, keys);
  }
  return null;
}

dynamic extractJson(dynamic json, List<String> keys) {
  if (json is Map<String, dynamic>) {
    for (final key in keys) {
      if (json.containsKey(key)) return json[key];
    }
    final data = json['data'];
    if (data != null) return extractJson(data, keys);
  }
  return null;
}

