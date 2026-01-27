import 'package:flutter/material.dart';
import 'package:tanga_acadamie/screens/shared/_stat_card.dart';
import 'package:tanga_acadamie/screens/shared/annoucment_card.dart';
import 'package:tanga_acadamie/screens/shared/course_card.dart';
import 'package:tanga_acadamie/screens/student/course_learn_page.dart';
import 'package:tanga_acadamie/screens/login_page.dart';
import 'package:tanga_acadamie/storage_service.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getStudentDash(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        } else if (snapshot.hasError) {
          // Check if it's an authentication error
          final errorString = snapshot.error.toString().toLowerCase();
          if (errorString.contains('unauthorized') || 
              errorString.contains('401') ||
              errorString.contains('token') ||
              errorString.contains('not logged')) {
            return _buildNotLoggedInState(context);
          }
          return _buildErrorState(snapshot.error.toString());
        } else if (snapshot.data == null) {
          return _buildNotLoggedInState(context);
        } else {
          final data = snapshot.data!;
          final List activeCourses =
              data['enrolledCourses']?['data']?['active'] ?? [];
          final List announcements = data['announcements']?['data'] ?? [];

          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            body: RefreshIndicator(
              color: Colors.blueAccent,
              onRefresh: () async {
                // Trigger refresh
              },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Welcome Section
                  _buildWelcomeSection(data['username'] ?? 'Guest'),
                  const SizedBox(height: 24),
                  
                  // Stats Grid
                  _buildStatsGrid(data),
                  const SizedBox(height: 32),
                  
                  // Continue Learning Section
                  _buildSectionHeader(
                    context,
                    'Continue Learning',
                    Icons.play_circle_fill,
                    activeCourses.length,
                  ),
                  const SizedBox(height: 16),
                  _buildActiveCourses(context, activeCourses),
                  const SizedBox(height: 32),
                  
                  // Announcements Section
                  _buildSectionHeader(
                    context,
                    'Course Announcements',
                    Icons.campaign,
                    announcements.length,
                  ),
                  const SizedBox(height: 16),
                  _buildAnnouncements(announcements),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Colors.blueAccent,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              'Loading your dashboard...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotLoggedInState(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Icon Container
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blueAccent.shade100,
                      Colors.blueAccent.shade400,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withAlpha(60),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              
              // Welcome Text
              const Text(
                'Welcome to Tanga Academie',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Subtitle
              Text(
                'Your personalized learning dashboard awaits! Sign in to access your enrolled courses, track your progress, and continue your learning journey.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // Feature Cards
              Row(
                children: [
                  Expanded(
                    child: _buildFeatureCard(
                      Icons.library_books_rounded,
                      'My Courses',
                      'Access enrolled courses',
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFeatureCard(
                      Icons.trending_up_rounded,
                      'Progress',
                      'Track your learning',
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildFeatureCard(
                      Icons.workspace_premium_rounded,
                      'Certificates',
                      'Earn achievements',
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFeatureCard(
                      Icons.chat_rounded,
                      'Connect',
                      'Chat with instructors',
                      Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              
              // Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login_rounded, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Sign In to Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Signup Text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(String username) {
    final hour = DateTime.now().hour;
    String greeting;
    IconData greetingIcon;
    
    if (hour < 12) {
      greeting = 'Good morning';
      greetingIcon = Icons.wb_sunny_outlined;
    } else if (hour < 17) {
      greeting = 'Good afternoon';
      greetingIcon = Icons.wb_sunny;
    } else {
      greeting = 'Good evening';
      greetingIcon = Icons.nights_stay_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blueAccent.shade400,
            Colors.blue.shade700,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      greetingIcon,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      greeting,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '🎓 Keep learning!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(50),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.school,
              color: Colors.white,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> data) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      children: [
        StatCard(
          title: 'Enrolled Courses',
          value: "${data['enrolledCourses']?['data']?['all']?.length ?? 0}",
          icon: Icons.library_books,
          gradientColors: [
            Colors.blueAccent.shade200,
            Colors.blueAccent.shade700,
          ],
        ),
        StatCard(
          title: 'Completed',
          value: "${data['enrolledCourses']?['data']?['completed']?.length ?? 0}",
          icon: Icons.check_circle,
          gradientColors: [
            Colors.green.shade400,
            Colors.green.shade700,
          ],
        ),
        StatCard(
          title: 'In Progress',
          value: "${data['enrolledCourses']?['data']?['active']?.length ?? 0}",
          icon: Icons.trending_up,
          gradientColors: [
            Colors.orange.shade400,
            Colors.deepOrange.shade600,
          ],
        ),
        StatCard(
          title: 'Investment',
          value: "${data['investment']?['data']?['totalInvestment'] ?? 0}",
          icon: Icons.payments,
          gradientColors: [
            Colors.purple.shade400,
            Colors.purple.shade800,
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
    int count,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.blueAccent,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (count > 0)
                Text(
                  '$count ${count == 1 ? 'item' : 'items'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveCourses(BuildContext context, List activeCourses) {
    if (activeCourses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No active courses',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start exploring courses to begin your learning journey!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: activeCourses.length,
      itemBuilder: (context, index) {
        return CourseCard(
          course: activeCourses[index],
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => CourseLearnPage(
                  courseId: activeCourses[index]['_id'],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnnouncements(List announcements) {
    if (announcements.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No announcements yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Instructors will post updates here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: announcements
          .map((announcement) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AnnouncementCard(announcement: announcement),
              ))
          .toList(),
    );
  }
}
