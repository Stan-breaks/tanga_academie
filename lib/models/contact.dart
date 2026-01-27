// Contact models for chat functionality

/// Instructor contact for students to message
class InstructorContact {
  final String id;
  final String name;
  final String? avatar;
  final List<Course> courses;

  InstructorContact({
    required this.id,
    required this.name,
    this.avatar,
    this.courses = const [],
  });

  factory InstructorContact.fromJson(Map<String, dynamic> json) {
    return InstructorContact(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['username']?.toString() ?? json['name']?.toString() ?? 'Unknown',
      avatar: json['avatar']?.toString(),
      courses: (json['courses'] as List<dynamic>?)
              ?.map((c) => Course.fromJson(c))
              .toList() ??
          [],
    );
  }
}

/// Student contact for instructors to message
class StudentContact {
  final String id;
  final String name;
  final String? avatar;
  final String? email;

  StudentContact({
    required this.id,
    required this.name,
    this.avatar,
    this.email,
  });

  factory StudentContact.fromJson(Map<String, dynamic> json) {
    return StudentContact(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['username']?.toString() ?? json['name']?.toString() ?? 'Unknown',
      avatar: json['avatar']?.toString(),
      email: json['email']?.toString(),
    );
  }
}

/// Admin contact
class AdminContact {
  final String id;
  final String name;
  final String? avatar;
  final String? email;

  AdminContact({
    required this.id,
    required this.name,
    this.avatar,
    this.email,
  });

  factory AdminContact.fromJson(Map<String, dynamic> json) {
    return AdminContact(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['username']?.toString() ?? json['name']?.toString() ?? 'Unknown',
      avatar: json['avatar']?.toString(),
      email: json['email']?.toString(),
    );
  }
}

/// Course with enrolled students
class CourseWithStudents {
  final String id;
  final String title;
  final String? thumbnail;
  final List<StudentContact> students;

  CourseWithStudents({
    required this.id,
    required this.title,
    this.thumbnail,
    this.students = const [],
  });

  factory CourseWithStudents.fromJson(Map<String, dynamic> json) {
    return CourseWithStudents(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Course',
      thumbnail: json['thumbnail']?.toString() ?? json['bannerImage']?.toString(),
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
