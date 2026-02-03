import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';

/// API data fetcher utilities for the app

// ============================================================
// STUDENT ENDPOINTS
// ============================================================

/// Fetch enrolled courses for the current student
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

/// Fetch investment stats for the current student
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

/// Fetch announcements for the current student
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

/// Fetch complete student dashboard data
Future<Map<String, dynamic>> getStudentDash() async {
  try {
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

    // Fetch enrolled courses
    try {
      final enrolledResponse = await get(
        Uri.parse('${ApiConfig.baseUrl}/api/enrollment/enrolled-courses'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (enrolledResponse.statusCode == 200) {
        dashboardData['enrolledCourses'] = jsonDecode(enrolledResponse.body);
      }
    } catch (e) {
      // Keep default empty data
    }

    // Fetch investment
    try {
      final investmentResponse = await get(
        Uri.parse('${ApiConfig.baseUrl}/api/enrollment/investment-stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (investmentResponse.statusCode == 200) {
        dashboardData['investment'] = jsonDecode(investmentResponse.body);
      }
    } catch (e) {
      // Keep default empty data
    }

    // Fetch announcements
    try {
      final announcementsResponse = await get(
        Uri.parse('${ApiConfig.baseUrl}/api/announcements/student/announcements'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (announcementsResponse.statusCode == 200) {
        dashboardData['announcements'] = jsonDecode(announcementsResponse.body);
      }
    } catch (e) {
      // Keep default empty data
    }

    return dashboardData;
  } catch (e) {
    rethrow;
  }
}

// ============================================================
// COURSE ENDPOINTS
// ============================================================

/// Fetch a specific course by ID
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

/// Fetch all published courses (public endpoint)
Future<Map<String, dynamic>> fetchCourses() async {
  final apiUrl = dotenv.env['API_URL'];
  if (apiUrl == null) {
    throw Exception("API_URL not found in .env file");
  }

  final res = await get(
    Uri.parse('$apiUrl/api/allcourses'),
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
  try {
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

    // Fetch instructor courses
    try {
      final coursesResponse = await get(
        Uri.parse('${ApiConfig.baseUrl}/api/instructor-courses'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (coursesResponse.statusCode == 200) {
        final coursesData = jsonDecode(coursesResponse.body);
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
    } catch (e) {
      // Keep default empty data
    }

    // Fetch instructor assignments
    try {
      final assignmentsResponse = await get(
        Uri.parse('${ApiConfig.baseUrl}/api/courses/instructor/assignments'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (assignmentsResponse.statusCode == 200) {
        final assignmentsData = jsonDecode(assignmentsResponse.body);
        final assignments = assignmentsData['data'] as List? ?? [];

        dashboardData['stats']['pendingSubmissions'] = assignments.fold(
          0,
          (sum, assignment) =>
              sum + (assignment['submissionCount'] ?? 0) as int,
        );

        // Get recent 5 assignments
        dashboardData['recentAssignments'] = assignments.take(5).toList();
      }
    } catch (e) {
      // Keep default empty data
    }

    // Fetch instructor reviews
    try {
      final reviewsResponse = await get(
        Uri.parse('${ApiConfig.baseUrl}/api/instructor/reviews'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (reviewsResponse.statusCode == 200) {
        final reviewsData = jsonDecode(reviewsResponse.body);
        final reviews = reviewsData['data'] as List? ?? [];
        dashboardData['stats']['totalReviews'] = reviews.length;
      }
    } catch (e) {
      // Keep default empty data
    }

    return dashboardData;
  } catch (e) {
    rethrow;
  }
}

// ============================================================
// ADMIN ENDPOINTS
// ============================================================

/// Fetch admin dashboard stats
Future<Map<String, dynamic>> getAdminDashboardStats() async {
  try {
    final token = await getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await get(
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
  } catch (e) {
    rethrow;
  }
}

/// Fetch admin chart data (enrollment trends, course distribution, revenue)
Future<Map<String, dynamic>> getAdminChartData() async {
  try {
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
      get(Uri.parse('${ApiConfig.baseUrl}/api/admin/charts/enrollment-trends'), headers: headers),
      get(Uri.parse('${ApiConfig.baseUrl}/api/admin/charts/course-distribution'), headers: headers),
      get(Uri.parse('${ApiConfig.baseUrl}/api/admin/charts/revenue-data'), headers: headers),
    ]);

    return {
      'enrollment': results[0].statusCode == 200 ? jsonDecode(results[0].body)['data'] : null,
      'distribution': results[1].statusCode == 200 ? jsonDecode(results[1].body)['data'] : null,
      'revenue': results[2].statusCode == 200 ? jsonDecode(results[2].body)['data'] : null,
    };
  } catch (e) {
    rethrow;
  }
}

/// Fetch all courses for admin (with all statuses)
Future<Map<String, dynamic>> getAdminCourses() async {
  try {
    final token = await getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await get(
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
  } catch (e) {
    rethrow;
  }
}

/// Fetch top instructors for admin
Future<List<dynamic>> getTopInstructors() async {
  try {
    final token = await getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await get(
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
  } catch (e) {
    rethrow;
  }
}

/// Fetch admin notices
Future<List<dynamic>> getAdminNotices() async {
  try {
    final token = await getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await get(
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
  } catch (e) {
    rethrow;
  }
}

/// Update course status (approve/reject)
Future<Map<String, dynamic>> updateCourseStatus(String courseId, String status) async {
  try {
    final token = await getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await put(
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
  } catch (e) {
    rethrow;
  }
}

