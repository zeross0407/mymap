import 'dart:convert';

import 'package:http/http.dart' as http;

Future<List<Map<String, dynamic>>> getSuggestions(String query) async {
  final String url =
      'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=10';

  try {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);

      // Trả về danh sách gợi ý
      return data.map((item) {
        return {
          'name': item['display_name'],
          'lat': item['lat'],
          'lon': item['lon'],
        };
      }).toList();
    } else {
      throw Exception(
          'Failed to fetch suggestions. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
    return [];
  }
}






