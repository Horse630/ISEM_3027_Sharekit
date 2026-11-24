import 'dart:convert';

import 'package:http/http.dart' as http;

class RemoteApi {
  static const root =
      'https://crudcrud.com/api/ca79774c90ee43e8bd32fdd71190db70';

  Future<List<Map<String, dynamic>>> list(String collection) async {
    final response = await http
        .get(Uri.parse('$root/$collection'))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode == 404) return const [];
    if (response.statusCode != 200) {
      throw StateError('共用資料庫讀取失敗');
    }
    final data = jsonDecode(response.body);
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  Future<Map<String, dynamic>> create(
    String collection,
    Map<String, Object?> body,
  ) async {
    final response = await http
        .post(
          Uri.parse('$root/$collection'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw StateError('共用資料庫寫入失敗');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<void> replace(
    String collection,
    String id,
    Map<String, Object?> body,
  ) async {
    final payload = Map<String, Object?>.from(body)..remove('_id');
    final response = await http
        .put(
          Uri.parse('$root/$collection/$id'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('共用資料庫寫入失敗');
    }
  }
}
