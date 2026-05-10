import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:tanga_acadamie/models/blog.dart';
import 'package:tanga_acadamie/storage_service.dart';

/// Authenticated service for admin blog management.
class AdminBlogService {
  static String get _baseUrl {
    final apiUrl = dotenv.env['API_URL'];
    if (apiUrl == null || apiUrl.isEmpty) {
      throw Exception('API_URL not found in .env file');
    }
    return apiUrl;
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Fetch all blogs for admin (with optional filters).
  static Future<Map<String, dynamic>> fetchAllBlogs({
    int page = 1,
    int limit = 10,
    String? status,
    String? category,
    String? search,
  }) async {
    final headers = await _authHeaders();
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final uri = Uri.parse(
      '$_baseUrl/api/admin/blogs',
    ).replace(queryParameters: params);
    final res = await http.get(uri, headers: headers);

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch blogs: ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to fetch blogs');
    }

    final blogs = (data['blogs'] as List<dynamic>? ?? [])
        .map((b) => Blog.fromJson(b))
        .toList();

    return {
      'blogs': blogs,
      'totalPages': data['totalPages'] ?? 1,
      'currentPage': data['currentPage'] ?? 1,
      'total': data['total'] ?? 0,
    };
  }

  /// Fetch single blog by ID for editing.
  static Future<Blog> fetchBlogById(String id) async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$_baseUrl/api/admin/blogs/$id'),
      headers: headers,
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

  /// Create a new blog post (multipart for image upload).
  static Future<Blog> createBlog({
    required String title,
    required String content,
    String excerpt = '',
    String category = '',
    String tags = '',
    String status = 'draft',
    String metaTitle = '',
    String metaDescription = '',
    bool isCommentEnabled = true,
    File? featuredImage,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/admin/blogs'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['title'] = title;
    request.fields['content'] = content;
    request.fields['excerpt'] = excerpt;
    request.fields['category'] = category;
    request.fields['tags'] = tags;
    request.fields['status'] = status;
    request.fields['metaTitle'] = metaTitle;
    request.fields['metaDescription'] = metaDescription;
    request.fields['isCommentEnabled'] = isCommentEnabled.toString();

    if (featuredImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'featuredImage',
          featuredImage.path,
          contentType: _resolveMediaType(featuredImage.path),
        ),
      );
    }

    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);

    if (res.statusCode != 201) {
      throw Exception('Failed to create blog: ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to create blog');
    }

    return Blog.fromJson(data['blog']);
  }

  /// Update an existing blog post (multipart for image upload).
  static Future<Blog> updateBlog({
    required String id,
    required String title,
    required String content,
    String excerpt = '',
    String category = '',
    String tags = '',
    String status = 'draft',
    String metaTitle = '',
    String metaDescription = '',
    bool isCommentEnabled = true,
    File? featuredImage,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$_baseUrl/api/admin/blogs/$id'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['title'] = title;
    request.fields['content'] = content;
    request.fields['excerpt'] = excerpt;
    request.fields['category'] = category;
    request.fields['tags'] = tags;
    request.fields['status'] = status;
    request.fields['metaTitle'] = metaTitle;
    request.fields['metaDescription'] = metaDescription;
    request.fields['isCommentEnabled'] = isCommentEnabled.toString();

    if (featuredImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'featuredImage',
          featuredImage.path,
          contentType: _resolveMediaType(featuredImage.path),
        ),
      );
    }

    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);

    if (res.statusCode != 200) {
      throw Exception('Failed to update blog: ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to update blog');
    }

    return Blog.fromJson(data['blog']);
  }

  /// Delete a blog post by ID.
  static Future<void> deleteBlog(String id) async {
    final headers = await _authHeaders();
    final res = await http.delete(
      Uri.parse('$_baseUrl/api/admin/blogs/$id'),
      headers: headers,
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to delete blog: ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to delete blog');
    }
  }

  /// Resolve the correct MediaType from file extension.
  static MediaType _resolveMediaType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      default:
        return MediaType('image', 'jpeg');
    }
  }
}
