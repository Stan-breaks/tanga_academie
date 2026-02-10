// Contact models for chat functionality
import 'package:tanga_acadamie/api_config.dart';

/// Generic user contact for admin to message any user
class UserContact {
  final String id;
  final String name;
  final String profile;
  final String email;
  final String role;

  UserContact({
    required this.id,
    required this.name,
    required this.profile,
    required this.email,
    required this.role,
  });

  factory UserContact.fromJson(Map<String, dynamic> json) {
    final firstName = json['firstName']?.toString() ?? '';
    final lastName = json['lastName']?.toString() ?? '';
    final name = json['name']?.toString() ?? '$firstName $lastName'.trim();
    final profilePath = json['profile']?.toString() ?? json['avatar']?.toString();

    return UserContact(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: name.isEmpty ? 'Unknown User' : name,
      profile: profilePath != null && profilePath.isNotEmpty
          ? (profilePath.startsWith('http') ? profilePath : '${ApiConfig.baseUrl}$profilePath')
          : '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
    );
  }

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

/// Instructor contact for students to message
class InstructorContact {
  final String id;
  final String name;
  final String profile;
  final List<Course> courses;

  InstructorContact({
    required this.id,
    required this.name,
    required this.profile,
    this.courses = const [],
  });

  factory InstructorContact.fromJson(Map<String, dynamic> json) {
    final firstName = json['firstName']?.toString() ?? '';
    final lastName = json['lastName']?.toString() ?? '';
    final name = json['username']?.toString() ?? 
                 json['name']?.toString() ?? 
                 '$firstName $lastName'.trim();
    final profilePath = json['profile']?.toString() ?? json['avatar']?.toString();

    return InstructorContact(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: name.isEmpty ? 'Unknown' : name,
      profile: profilePath != null && profilePath.isNotEmpty
          ? (profilePath.startsWith('http') ? profilePath : '${ApiConfig.baseUrl}$profilePath')
          : '',
      courses: (json['courses'] as List<dynamic>?)
              ?.map((c) => Course.fromJson(c))
              .toList() ??
          [],
    );
  }

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

/// Student contact for instructors to message
class StudentContact {
  final String id;
  final String name;
  final String profile;
  final String email;

  StudentContact({
    required this.id,
    required this.name,
    required this.profile,
    required this.email,
  });

  factory StudentContact.fromJson(Map<String, dynamic> json) {
    final firstName = json['firstName']?.toString() ?? '';
    final lastName = json['lastName']?.toString() ?? '';
    final name = json['username']?.toString() ?? 
                 json['name']?.toString() ?? 
                 '$firstName $lastName'.trim();
    final profilePath = json['profile']?.toString() ?? json['avatar']?.toString();

    return StudentContact(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: name.isEmpty ? 'Unknown' : name,
      profile: profilePath != null && profilePath.isNotEmpty
          ? (profilePath.startsWith('http') ? profilePath : '${ApiConfig.baseUrl}$profilePath')
          : '',
      email: json['email']?.toString() ?? '',
    );
  }

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

/// Admin contact
class AdminContact {
  final String id;
  final String name;
  final String profile;
  final String email;

  AdminContact({
    required this.id,
    required this.name,
    required this.profile,
    required this.email,
  });

  factory AdminContact.fromJson(Map<String, dynamic> json) {
    final firstName = json['firstName']?.toString() ?? '';
    final lastName = json['lastName']?.toString() ?? '';
    final name = json['fullName']?.toString() ??
                 json['username']?.toString() ?? 
                 json['name']?.toString() ?? 
                 '$firstName $lastName'.trim();
    final profilePath = json['profile']?.toString() ?? json['avatar']?.toString();

    return AdminContact(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: name.isEmpty ? 'Unknown' : name,
      profile: profilePath != null && profilePath.isNotEmpty
          ? (profilePath.startsWith('http') ? profilePath : '${ApiConfig.baseUrl}$profilePath')
          : '',
      email: json['email']?.toString() ?? '',
    );
  }

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

/// Course with enrolled students (for instructor chat list)
class CourseWithStudents {
  final String courseId;
  final String courseTitle;
  final String courseBanner;
  final List<StudentContact> students;

  CourseWithStudents({
    required this.courseId,
    required this.courseTitle,
    required this.courseBanner,
    required this.students,
  });

  factory CourseWithStudents.fromJson(Map<String, dynamic> json) {
    // Handle both nested course object and direct fields
    final course = json['course'] ?? json;
    final courseIdValue = course['id']?.toString() ?? 
                          course['_id']?.toString() ?? 
                          json['courseId']?.toString() ?? '';
    final bannerPath = course['bannerImage']?.toString() ?? 
                       course['thumbnail']?.toString() ?? '';
    
    return CourseWithStudents(
      courseId: courseIdValue,
      courseTitle: course['title']?.toString() ?? 'Untitled Course',
      courseBanner: bannerPath.isNotEmpty && !bannerPath.startsWith('http')
          ? '${ApiConfig.baseUrl}$bannerPath'
          : bannerPath,
      students: (json['students'] as List<dynamic>?)
              ?.map((s) => StudentContact.fromJson(s))
              .toList() ??
          [],
    );
  }
}

/// Basic course info
class Course {
  final String id;
  final String title;

  Course({
    required this.id,
    required this.title,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
    );
  }
}
