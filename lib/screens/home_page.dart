import 'package:flutter/material.dart';
import 'package:tanga_acadamie/screens/admin_home/admin_home_page.dart';
import 'package:tanga_acadamie/screens/instructor_home/instructor_dashboard.dart';
import 'package:tanga_acadamie/screens/student/student_home.dart';
import 'package:tanga_acadamie/storage_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: getUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        } else {
          final user = snapshot.data!;
          if (user['role'] == "Admin") {
            return const AdminHomePage();
          } else if (user['role'] == "instructor") {
            return const InstructorDashboard();
          } else {
            return StudentHome();
          }
        }
      },
    );
  }
}
