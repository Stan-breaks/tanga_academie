import 'package:flutter/material.dart';
import 'package:tanga_acadamie/screens/admin_home/admin_home_page.dart';
import 'package:tanga_acadamie/screens/instructor_home/instructor_dashboard.dart';
import 'package:tanga_acadamie/screens/student/student_home.dart';
import 'package:tanga_acadamie/storage_service.dart';

class HomePage extends StatelessWidget {
  final bool isLoggedIn;
  final Map<String, dynamic> user;

  const HomePage({
    super.key,
    required this.isLoggedIn,
    this.user = const {"role": "guest"},
  });
  @override
  Widget build(BuildContext context) {
    if (user['role'] == "Admin") {
      return const AdminHomePage();
    } else if (user['role'] == "instructor") {
      return const InstructorDashboard();
    } else {
      return StudentHome(isLoggedIn: isLoggedIn, user: user);
    }
  }
}
