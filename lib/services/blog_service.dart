import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tanga_acadamie/models/blog.dart';

/// Service for fetching blog data from the public blog API.
class BlogService {
  static String get _baseUrl {
    final apiUrl = dotenv.env['API_URL'];
    if (apiUrl == null || apiUrl.isEmpty) {
      throw Exception('API_URL not found in .env file');
    }
    return apiUrl;
  }

  /// Fetch the 5 most recent published blogs (for explore page section).
  static Future<List<Blog>> fetchRecentBlogs() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/blogs/recent/list'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch recent blogs: ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to fetch recent blogs');
    }

    final blogsList = data['blogs'] as List<dynamic>? ?? [];
    return blogsList.map((b) => Blog.fromJson(b)).toList();
  }

  /// Fetch a single blog by slug (for detail page).
  static Future<Blog> fetchBlogBySlug(String slug) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/blogs/$slug'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch blog: ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Blog not found');
    }

    return Blog.fromJson(data['blog']);
  }
}
