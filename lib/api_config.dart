import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl {
    final apiUrl = dotenv.env["API_URL"];
    if (apiUrl == null || apiUrl.isEmpty) {
      throw Exception("API_URL not found in .env file");
    }
    return apiUrl;
  }

  static String getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }
}
