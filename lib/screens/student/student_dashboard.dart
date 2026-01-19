import 'package:flutter/material.dart';
import 'package:tanga_acadamie/screens/shared/_stat_card.dart';
import 'package:tanga_acadamie/screens/shared/annoucment_card.dart';
import 'package:tanga_acadamie/screens/shared/course_card.dart';
import 'package:tanga_acadamie/storage_service.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getStudentDash(),
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
          final data = snapshot.data!;
          final List activeCourses =
              data['enrolledCourses']?['data']?['active'] ?? [];
          final List announcements = data['announcements']?['data'] ?? [];
          
          return Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  "Hi, ${data['username'] ?? 'guest'} 👋",
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    StatCard(
                      title: 'Enrolled',
                      value:
                          "${data['enrolledCourses']?['data']?['all']?.length ?? 0}",
                    ),
                    StatCard(
                      title: 'Completed',
                      value:
                          "${data['enrolledCourses']?['data']?['completed']?.length ?? 0}",
                    ),
                    StatCard(
                      title: 'Active',
                      value:
                          "${data['enrolledCourses']?['data']?['active']?.length ?? 0}",
                    ),
                    StatCard(
                      title: 'Investissement',
                      value:
                          "${data['investment']?['data']?['totalInvestment'] ?? 0}",
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Continue Learning',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (activeCourses.isEmpty)
                  const Text(
                    "No active courses yet",
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: activeCourses.length,
                    itemBuilder: (context, index) {
                      return CourseCard(course: activeCourses[index]);
                    },
                  ),
                const SizedBox(height: 24),
                Text(
                  "Annonces du Cours (${announcements.length})",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (announcements.isEmpty)
                  const Text(
                    "No announcements yet",
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  Column(
                    children: announcements
                        .map(
                          (announcement) =>
                              AnnouncementCard(announcement: announcement),
                        )
                        .toList(),
                  ),
              ],
            ),
          );
        }
      },
    );
  }
}
