import 'package:flutter/material.dart';
import 'package:tanga_acadamie/screens/admin_home/admin_home_page.dart';
import 'package:tanga_acadamie/screens/instructor/instructor_home_page.dart';
import 'package:tanga_acadamie/screens/student/student_home.dart';

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
      return InstructorHomePage(isLoggedIn: isLoggedIn, user: user);
    } else {
      return StudentHome(isLoggedIn: isLoggedIn, user: user);
    }
  }
}
