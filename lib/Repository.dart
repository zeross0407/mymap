import 'dart:convert';

import 'package:http/http.dart' as http;

// Hàm lấy các gợi ý tìm kiếm từ OpenStreetMap
Future<List<Map<String, dynamic>>> getSuggestions(String query) async {
  // URL yêu cầu tìm kiếm từ Nominatim API của OpenStreetMap
  final String url =
      'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=10';

  try {
    // Gửi yêu cầu HTTP GET tới API với URL đã tạo
    final response = await http.get(Uri.parse(url));

    // Kiểm tra mã trạng thái của phản hồi (status code)
    if (response.statusCode == 200) {
      // Phân tích JSON từ phản hồi
      List<dynamic> data = json.decode(response.body);

      // Trả về danh sách các gợi ý tìm kiếm
      return data.map((item) {
        return {
          'name': item['display_name'], // Tên địa điểm từ OpenStreetMap
          'lat': item['lat'], // Vĩ độ của địa điểm
          'lon': item['lon'], // Kinh độ của địa điểm
        };
      }).toList(); // Chuyển đổi danh sách các item thành danh sách Map
    } else {
      // Nếu mã trạng thái không phải 200, ném ngoại lệ
      throw Exception(
          'Failed to fetch suggestions. Status code: ${response.statusCode}');
    }
  } catch (e) {
    // Nếu có lỗi trong quá trình gọi API, in ra lỗi và trả về danh sách rỗng
    print('Error: $e');
    return [];
  }
}
