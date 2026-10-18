import 'dart:convert';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/core/api_client.dart';
import 'package:tanga_acadamie/storage_service.dart';

/// API data fetcher utilities for the app

// ============================================================
// STUDENT ENDPOINTS
// ============================================================

/// Fetch enrolled courses for the current student
Future<Map<String, dynamic>> fetchEnrolled() async {
  final token = await getToken();

  final res = await sharedHttpClient.get(
    Uri.parse('${ApiConfig.baseUrl}/api/enrollment/enrolled-courses'),
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

/// Fetch investment stats for the current student
Future<Map<String, dynamic>> fetchInvestment() async {
  final token = await getToken();

  final res = await sharedHttpClient.get(
    Uri.parse('${ApiConfig.baseUrl}/api/enrollment/investment-stats'),
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

/// Fetch announcements for the current student
Future<Map<String, dynamic>> fetchAnnouncements() async {
  final token = await getToken();

  final res = await sharedHttpClient.get(
    Uri.parse('${ApiConfig.baseUrl}/api/announcements/student/announcements'),
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

/// GETs [url] with the bearer token and returns the decoded JSON body, or
/// `null` if the request fails or returns a non-200 status. Used to fan out
/// independent dashboard requests with `Future.wait`.
Future<dynamic> _fetchJsonOrNull(String url, String token) async {
  try {
    final res = await sharedHttpClient.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
  } catch (_) {
    // Caller falls back to default/empty data.
  }
  return null;
}

/// Fetch complete student dashboard data
Future<Map<String, dynamic>> getStudentDash() async {
  final token = await getToken();
  if (token == null) {
    throw Exception('Not authenticated');
  }

  final user = await getUser();

  // Initialize response data
  Map<String, dynamic> dashboardData = {
    'username': user['username'],
    'enrolledCourses': {'data': {'all': [], 'active': [], 'completed': []}},
    'investment': {'data': {'totalInvestment': 0}},
    'announcements': {'data': []},
  };

  // Fire the three independent requests concurrently instead of sequentially
  // (previously the dashboard waited for the sum of all three round-trips).
  final results = await Future.wait<dynamic>([
    _fetchJsonOrNull('${ApiConfig.baseUrl}/api/enrollment/enrolled-courses', token),
    _fetchJsonOrNull('${ApiConfig.baseUrl}/api/enrollment/investment-stats', token),
    _fetchJsonOrNull('${ApiConfig.baseUrl}/api/announcements/student/announcements', token),
  ]);

  if (results[0] != null) dashboardData['enrolledCourses'] = results[0];
  if (results[1] != null) dashboardData['investment'] = results[1];
  if (results[2] != null) dashboardData['announcements'] = results[2];

  return dashboardData;
}

// ============================================================
// COURSE ENDPOINTS
// ============================================================

/// Fetch a specific course by ID
Future<Map<String, dynamic>> fetchCourse(String courseId) async {
  final token = await getToken();

  final res = await sharedHttpClient.get(
    Uri.parse('${ApiConfig.baseUrl}/api/courses/$courseId'),
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

/// Fetch all published courses (public endpoint)
Future<Map<String, dynamic>> fetchCourses() async {
  final res = await sharedHttpClient.get(
    Uri.parse('${ApiConfig.baseUrl}/api/allcourses'),
    headers: {"Content-Type": "application/json"},
  );

  if (res.statusCode != 200) {
    throw Exception("Failed to fetch Courses: ${res.statusCode}");
  }
  return jsonDecode(res.body) ?? {};
}

// ============================================================
// INSTRUCTOR ENDPOINTS
// ============================================================

/// Fetch instructor dashboard data
Future<Map<String, dynamic>> getInstructorDash() async {
  final token = await getToken();
  if (token == null) {
    throw Exception('Not authenticated');
  }

  final user = await getUser();

  // Initialize response data
  Map<String, dynamic> dashboardData = {
    'username': user['username'],
    'stats': {
      'totalCourses': 0,
      'activeCourses': 0,
      'totalStudents': 0,
      'pendingSubmissions': 0,
      'totalReviews': 0,
    },
    'recentCourses': [],
    'recentAssignments': [],
  };

  // Fire the three independent requests concurrently instead of sequentially.
  final results = await Future.wait<dynamic>([
    _fetchJsonOrNull('${ApiConfig.baseUrl}/api/instructor-courses', token),
    _fetchJsonOrNull('${ApiConfig.baseUrl}/api/courses/instructor/assignments', token),
    _fetchJsonOrNull('${ApiConfig.baseUrl}/api/instructor/reviews', token),
  ]);

  // Instructor courses
  final coursesData = results[0];
  if (coursesData != null) {
    final courses = coursesData['data'] as List? ?? [];

    dashboardData['stats']['totalCourses'] = courses.length;
    dashboardData['stats']['activeCourses'] =
        courses.where((c) => c['status'] == 'published').length;
    dashboardData['stats']['totalStudents'] = courses.fold(
      0,
      (sum, course) => sum + ((course['enrollmentCount'] ?? 0) as int),
    );

    // Get recent 5 courses
    dashboardData['recentCourses'] = courses.take(5).toList();
  }

  // Instructor assignments
  final assignmentsData = results[1];
  if (assignmentsData != null) {
    final assignments = assignmentsData['data'] as List? ?? [];

    dashboardData['stats']['pendingSubmissions'] = assignments.fold(
      0,
      (sum, assignment) => sum + (assignment['submissionCount'] ?? 0) as int,
    );

    // Get recent 5 assignments
    dashboardData['recentAssignments'] = assignments.take(5).toList();
  }

  // Instructor reviews
  final reviewsData = results[2];
  if (reviewsData != null) {
    final reviews = reviewsData['data'] as List? ?? [];
    dashboardData['stats']['totalReviews'] = reviews.length;
  }

  return dashboardData;
}

// ============================================================
// ADMIN ENDPOINTS
// ============================================================

/// Fetch admin dashboard stats
Future<Map<String, dynamic>> getAdminDashboardStats() async {
  final token = await getToken();
  if (token == null) {
    throw Exception('Not authenticated');
  }

  final response = await sharedHttpClient.get(
    Uri.parse('${ApiConfig.baseUrl}/api/admin/dashboard/stats'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  }
  throw Exception('Failed to fetch admin stats: ${response.statusCode}');
}

/// Fetch admin chart data (enrollment trends, course distribution, revenue)
Future<Map<String, dynamic>> getAdminChartData() async {
  final token = await getToken();
  if (token == null) {
    throw Exception('Not authenticated');
  }

  final headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  // Fetch all chart data in parallel
  final results = await Future.wait([
    sharedHttpClient.get(Uri.parse('${ApiConfig.baseUrl}/api/admin/charts/enrollment-trends'), headers: headers),
    sharedHttpClient.get(Uri.parse('${ApiConfig.baseUrl}/api/admin/charts/course-distribution'), headers: headers),
    sharedHttpClient.get(Uri.parse('${ApiConfig.baseUrl}/api/admin/charts/revenue-data'), headers: headers),
  ]);

  return {
    'enrollment': results[0].statusCode == 200 ? jsonDecode(results[0].body)['data'] : null,
    'distribution': results[1].statusCode == 200 ? jsonDecode(results[1].body)['data'] : null,
    'revenue': results[2].statusCode == 200 ? jsonDecode(results[2].body)['data'] : null,
  };
}

/// Fetch all courses for admin (with all statuses)
Future<Map<String, dynamic>> getAdminCourses() async {
  final token = await getToken();
  if (token == null) {
    throw Exception('Not authenticated');
  }

  final response = await sharedHttpClient.get(
    Uri.parse('${ApiConfig.baseUrl}/api/admin/all-courses'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  }
  throw Exception('Failed to fetch admin courses: ${response.statusCode}');
}

/// Fetch top instructors for admin
Future<List<dynamic>> getTopInstructors() async {
  final token = await getToken();
  if (token == null) {
    throw Exception('Not authenticated');
  }

  final response = await sharedHttpClient.get(
    Uri.parse('${ApiConfig.baseUrl}/api/admin/instructors/top'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['data'] ?? [];
  }
  throw Exception('Failed to fetch top instructors: ${response.statusCode}');
}

/// Fetch admin notices
Future<List<dynamic>> getAdminNotices() async {
  final token = await getToken();
  if (token == null) {
    throw Exception('Not authenticated');
  }

  final response = await sharedHttpClient.get(
    Uri.parse('${ApiConfig.baseUrl}/api/admin/notices'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data is List ? data : (data['data'] ?? []);
  }
  throw Exception('Failed to fetch notices: ${response.statusCode}');
}

/// Update course status (approve/reject)
Future<Map<String, dynamic>> updateCourseStatus(String courseId, String status) async {
  final token = await getToken();
  if (token == null) {
    throw Exception('Not authenticated');
  }

  final response = await sharedHttpClient.put(
    Uri.parse('${ApiConfig.baseUrl}/api/courses/$courseId/status'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'status': status}),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  }
  throw Exception('Failed to update course status: ${response.statusCode}');
}

