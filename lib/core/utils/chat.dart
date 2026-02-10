import 'dart:convert';

import 'package:http/http.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';

/// Result wrapper for chat API calls
class ChatResult {
  final dynamic data;
  final String? error;

  ChatResult({this.data, this.error});

  bool get isSuccess => error == null && data != null;
}

/// Fetch user chats from API
Future<ChatResult> fetchUserChats() async {
  try {
    final token = await getToken();
    if (token == null) {
      return ChatResult(error: 'Not authenticated');
    }

    final response = await get(
      Uri.parse('${ApiConfig.baseUrl}/api/chats/user-chats'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      // Handle both direct array and {data: [...]} formats
      final chats = body is List ? body : (body['data'] ?? []);
      return ChatResult(data: chats);
    } else {
      return ChatResult(error: 'Failed to load chats: ${response.statusCode}');
    }
  } catch (e) {
    return ChatResult(error: 'Error loading chats: $e');
  }
}

/// Start a new chat with a participant
Future<ChatResult> startChat({
  required String participantId,
  String? courseId,
  String? userType,
}) async {
  try {
    final token = await getToken();
    if (token == null) {
      return ChatResult(error: 'Not authenticated');
    }

    String url;
    Map<String, dynamic> body;

    // Different endpoints based on user type
    if (userType == 'Student' && courseId != null) {
      url = '${ApiConfig.baseUrl}/api/chats/course-chat';
      body = {
        'studentId': participantId,
        'userType': 'Instructor',
        'courseId': courseId,
      };
    } else {
      url = '${ApiConfig.baseUrl}/api/chats';
      body = {'participantId': participantId};
    }

    final response = await post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return ChatResult(data: data['data'] ?? data);
    } else {
      final errorData = json.decode(response.body);
      String errorMessage = 'Failed to start chat';

      if (response.statusCode == 403) {
        if (errorData['message']?.contains('not enrolled') == true) {
          errorMessage = 'You need to enroll in this course first';
        } else if (errorData['message']?.contains('unpublished') == true) {
          errorMessage = 'This course is not yet available';
        } else {
          errorMessage = errorData['message'] ?? errorMessage;
        }
      }

      return ChatResult(error: errorMessage);
    }
  } catch (e) {
    return ChatResult(error: 'Error starting chat: $e');
  }
}

/// Fetch admin contacts (all users except current)
Future<ChatResult> fetchAdminContacts() async {
  try {
    final token = await getToken();
    if (token == null) {
      return ChatResult(error: 'Not authenticated');
    }

    final response = await get(
      Uri.parse('${ApiConfig.baseUrl}/api/chats/admin/contacts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final users = data is List ? data : (data['data'] ?? []);
      return ChatResult(data: users);
    } else {
      return ChatResult(error: 'Failed to load contacts');
    }
  } catch (e) {
    return ChatResult(error: 'Error loading contacts: $e');
  }
}

/// Fetch instructor's student contacts (grouped by course)
Future<ChatResult> fetchStudentContacts() async {
  try {
    final token = await getToken();
    if (token == null) {
      return ChatResult(error: 'Not authenticated');
    }

    final response = await get(
      Uri.parse('${ApiConfig.baseUrl}/api/chats/instructor/students'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final courses = data is List ? data : (data['data'] ?? []);
      return ChatResult(data: courses);
    } else {
      return ChatResult(error: 'Failed to load students');
    }
  } catch (e) {
    return ChatResult(error: 'Error loading students: $e');
  }
}

/// Fetch admin contacts for instructor
Future<ChatResult> fetchAdminsForInstructor() async {
  try {
    final token = await getToken();
    if (token == null) {
      return ChatResult(error: 'Not authenticated');
    }

    final response = await get(
      Uri.parse('${ApiConfig.baseUrl}/api/chats/admins'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final admins = data is List ? data : (data['data'] ?? []);
      return ChatResult(data: admins);
    } else {
      return ChatResult(error: 'Failed to load admins');
    }
  } catch (e) {
    return ChatResult(error: 'Error loading admins: $e');
  }
}

/// Fetch instructor contacts for student
Future<ChatResult> fetchInstructorContacts() async {
  try {
    final token = await getToken();
    if (token == null) {
      return ChatResult(error: 'Not authenticated');
    }

    final response = await get(
      Uri.parse('${ApiConfig.baseUrl}/api/chats/student/instructors'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final instructors = data is List ? data : (data['data'] ?? []);
      return ChatResult(data: instructors);
    } else {
      return ChatResult(error: 'Failed to load instructors');
    }
  } catch (e) {
    return ChatResult(error: 'Error loading instructors: $e');
  }
}

/// Get current user ID from token
Future<String?> getCurrentUserId() async {
  try {
    final token = await getToken();
    if (token != null) {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = json.decode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        );
        return payload['id'] ?? payload['userId'];
      }
    }
    return null;
  } catch (e) {
    return null;
  }
}
