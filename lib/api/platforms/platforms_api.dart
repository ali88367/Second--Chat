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

  /// GET `/api/v1/platforms/:platform/categories`
  /// Response: `{ success, data: { items: [{ id, name }] } }` (YouTube may use `title`).
  Future<List<Map<String, String>>> fetchCategories({
    required String platform,
    String? accessToken,
    String? query,
    int? first,
    int? limit,
    String? region,
  }) async {
    final p = platform.toLowerCase().trim();
    if (p.isEmpty) return const [];

    final queryParams = <String, dynamic>{};
    if (query != null && query.trim().isNotEmpty) {
      queryParams['query'] = query.trim();
    }
    if (first != null) queryParams['first'] = first;
    if (limit != null) queryParams['limit'] = limit;
    if (region != null && region.trim().isNotEmpty) {
      queryParams['region'] = region.trim();
    }

    try {
      final headers = <String, String>{};
      final token = accessToken?.trim();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final res = await _dio.get<dynamic>(
        '/api/v1/platforms/$p/categories',
        queryParameters: queryParams.isEmpty ? null : queryParams,
        options: headers.isEmpty ? null : Options(headers: headers),
      );
      return _parseCategoryItems(res.data);
    } on DioException catch (e) {
      assert(() {
        // ignore: avoid_print
        print(
          '[PlatformsApi] categories $p failed '
          '${e.response?.statusCode}: ${e.message}',
        );
        return true;
      }());
      return const [];
    } catch (_) {
      return const [];
    }
  }

  static List<Map<String, String>> _parseCategoryItems(dynamic json) {
    dynamic root = json;
    if (root is Map) {
      final map = root.cast<String, dynamic>();
      root = map['data'] ?? map;
    }

    List<dynamic>? items;
    if (root is Map) {
      final map = root.cast<String, dynamic>();
      final rawItems = map['items'] ?? map['categories'];
      if (rawItems is List) {
        items = rawItems;
      }
    } else if (root is List) {
      items = root;
    }

    if (items == null || items.isEmpty) return const [];

    final out = <Map<String, String>>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final m = raw.cast<String, dynamic>();
      final id = (m['id'] ?? m['category_id'] ?? m['categoryId'] ?? '')
          .toString()
          .trim();
      final name = (m['name'] ?? m['title'] ?? m['label'] ?? '')
          .toString()
          .trim();
      if (id.isEmpty || name.isEmpty) continue;
      out.add(<String, String>{'id': id, 'name': name});
    }
    return out;
  }
}
