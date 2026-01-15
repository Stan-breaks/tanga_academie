import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart';
import 'package:tanga_acadamie/storage_service.dart';

Future<Map<String, dynamic>> fetchEnrolled() async {
  final apiUrl = dotenv.env['API_URL'];
  if (apiUrl == null) {
    throw Exception("API_URL not found in .env file");
  }
  final token = await getToken();

  final res = await get(
    Uri.parse('$apiUrl/api/enrollment/enrolled-courses'),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
  );

  if (res.statusCode != 200) {
    throw Exception("Failed to fetch enrolled courses: ${res.statusCode}");
  }
  return jsonDecode(res.body) ?? {};
}

Future<Map<String, dynamic>> fetchInvestment() async {
  final apiUrl = dotenv.env['API_URL'];
  if (apiUrl == null) {
    throw Exception("API_URL not found in .env file");
  }
  final token = await getToken();

  final res = await get(
    Uri.parse('$apiUrl/api/enrollment/investment-stats'),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
  );

  if (res.statusCode != 200) {
    throw Exception("Failed to fetch investments: ${res.statusCode}");
  }
  return jsonDecode(res.body) ?? {};
}

Future<Map<String, dynamic>> fetchAnnouncements() async {
  final apiUrl = dotenv.env['API_URL'];
  if (apiUrl == null) {
    throw Exception("API_URL not found in .env file");
  }
  final token = await getToken();

  final res = await get(
    Uri.parse('$apiUrl/api/announcements/student/announcements'),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
  );

  if (res.statusCode != 200) {
    throw Exception("Failed to fetch announcements: ${res.statusCode}");
  }
  return jsonDecode(res.body) ?? {};
}

Future<Map<String, dynamic>> fetchCourse(String courseId) async {
  final apiUrl = dotenv.env['API_URL'];
  if (apiUrl == null) {
    throw Exception("API_URL not found in .env file");
  }
  final token = await getToken();

  final res = await get(
    Uri.parse('$apiUrl/api/courses/$courseId'),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    },
  );

  if (res.statusCode != 200) {
    throw Exception("Failed to fetch course: ${res.statusCode}");
  }
  return jsonDecode(res.body) ?? {};
}


Future<Map<String, dynamic>> fetchCourses() async {
  final apiUrl = dotenv.env['API_URL'];
  if (apiUrl == null) {
    throw Exception("API_URL not found in .env file");
  }

  final res = await get(
    Uri.parse('$apiUrl/api/allcourses'),
    headers: {
      "Content-Type": "application/json",
    },
  );

  if (res.statusCode != 200) {
    throw Exception("Failed to fetch Courses: ${res.statusCode}");
  }
  return jsonDecode(res.body) ?? {};
}
