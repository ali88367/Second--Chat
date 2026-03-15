import 'package:dio/dio.dart';

import '../http/api_json.dart';

class PlatformsApi {
  PlatformsApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> getConnections() async {
    final res = await _dio.get<dynamic>('/api/v1/platforms');
    final json = res.data;
    if (json is List) {
      return json.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    if (json is Map<String, dynamic>) {
      // Common shapes:
      // - { data: [ ... ] }
      // - { data: { platforms: [ ... ] } }
      // - { data: { connections: [ ... ] } }
      // - { data: { twitch: {...}, kick: {...} } }
      final data = json['data'];

      List<Map<String, dynamic>> fromList(List list) {
        return list
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }

      if (data is List) return fromList(data);

      if (data is Map<String, dynamic>) {
        final nested = extractJson(data, const ['platforms', 'connections', 'items']);
        if (nested is List) return fromList(nested);

        // Map keyed by platform name -> details
        final out = <Map<String, dynamic>>[];
        for (final entry in data.entries) {
          if (entry.value is Map) {
            final m = (entry.value as Map).cast<String, dynamic>();
            out.add({'platform': entry.key, ...m});
          }
        }
        if (out.isNotEmpty) return out;
      }
    }
    return const [];
  }
}
