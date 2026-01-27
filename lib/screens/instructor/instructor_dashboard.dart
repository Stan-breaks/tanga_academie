import 'package:flutter/material.dart';
import 'package:tanga_acadamie/data_fetcher.dart';
import 'package:tanga_acadamie/screens/shared/_stat_card.dart';
import 'package:intl/intl.dart';

class InstructorDashboard extends StatelessWidget {
  const InstructorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getInstructorDash(),
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
          final stats = data['stats'] ?? {};
          final List recentCourses = data['recentCourses'] ?? [];
          final List recentAssignments = data['recentAssignments'] ?? [];

          return Scaffold(
            body: RefreshIndicator(
              onRefresh: () async {
                // Trigger a rebuild by returning a future
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Welcome Header
                  Text(
                    "Hi, ${data['username'] ?? 'Instructor'} 👋",
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Welcome to your instructor dashboard",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stats Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      StatCard(
                        title: 'Total Courses',
                        value: "${stats['totalCourses'] ?? 0}",
                      ),
                      StatCard(
                        title: 'Active Courses',
                        value: "${stats['activeCourses'] ?? 0}",
                      ),
                      StatCard(
                        title: 'Total Students',
                        value: "${stats['totalStudents'] ?? 0}",
                      ),
                      StatCard(
                        title: 'Pending Submissions',
                        value: "${stats['pendingSubmissions'] ?? 0}",
                      ),
                      StatCard(
                        title: 'Total Reviews',
                        value: "${stats['totalReviews'] ?? 0}",
                      ),
                      StatCard(
                        title: 'Course Rating',
                        value: "4.5 ⭐",
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Quick Actions Section
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildQuickActions(context),
                  const SizedBox(height: 32),

                  // Recent Courses Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Courses',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (recentCourses.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            // Navigate to all courses
                            Navigator.pushNamed(context, '/instructor-courses');
                          },
                          child: const Text('View All'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (recentCourses.isEmpty)
                    _buildEmptyState(
                      'No courses yet',
                      'Create your first course to get started!',
                      Icons.book_outlined,
                    )
                  else
                    _buildRecentCourses(recentCourses, context),
                  const SizedBox(height: 32),

                  // Recent Assignment Activity Section
                  const Text(
                    'Assignment Activity',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (recentAssignments.isEmpty)
                    _buildEmptyState(
                      'No assignments yet',
                      'Create assignments to track student submissions!',
                      Icons.assignment_outlined,
                    )
                  else
                    _buildRecentAssignments(recentAssignments, context),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      QuickAction(
        title: 'Create New Course',
        description: 'Start creating your next course',
        icon: '📚',
        color: Colors.blue.shade400,
        route: '/create-course',
      ),
      QuickAction(
        title: 'Manage Courses',
        description: 'Edit and update existing courses',
        icon: '⚙️',
        color: Colors.green.shade500,
        route: '/instructor-courses',
      ),
      QuickAction(
        title: 'Grade Assignments',
        description: 'Review and grade student submissions',
        icon: '📝',
        color: Colors.orange.shade400,
        route: '/instructor-assignments',
      ),
      QuickAction(
        title: 'Quiz Analytics',
        description: 'Track student quiz performance',
        icon: '📊',
        color: Colors.purple.shade500,
        route: '/instructor-quiz-analytics',
      ),
      QuickAction(
        title: 'Student Progress',
        description: 'Monitor student learning progress',
        icon: '👥',
        color: Colors.teal.shade500,
        route: '/instructor-student-progress',
      ),
      QuickAction(
        title: 'Messages',
        description: 'Communicate with your students',
        icon: '💬',
        color: Colors.pink.shade500,
        route: '/instructor-messages',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return _buildQuickActionCard(action, context);
      },
    );
  }

  Widget _buildQuickActionCard(QuickAction action, BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, action.route);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              action.color,
              action.color.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: action.color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                action.icon,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(height: 8),
              Text(
                action.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                action.description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentCourses(List courses, BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: courses.length > 5 ? 5 : courses.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final course = courses[index];
        return _buildCourseCard(course, context);
      },
    );
  }

  Widget _buildCourseCard(Map course, BuildContext context) {
    final status = course['status'] ?? 'draft';
    final statusColor = status == 'published'
        ? Colors.green
        : status == 'pending'
            ? Colors.orange
            : Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    course['title'] ?? 'Untitled Course',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildCourseInfo(
                  Icons.people_outline,
                  'Students: ${course['enrollmentCount'] ?? 0}',
                ),
                const SizedBox(width: 16),
                _buildCourseInfo(
                  Icons.attach_money,
                  'Price: \$${course['price'] ?? 0}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentAssignments(List assignments, BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: assignments.length > 5 ? 5 : assignments.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final assignment = assignments[index];
        return _buildAssignmentCard(assignment, context);
      },
    );
  }

  Widget _buildAssignmentCard(Map assignment, BuildContext context) {
    final dueDate = assignment['dueDate'];
    final dueDateStr = dueDate != null
        ? DateFormat('MMM d, yyyy').format(DateTime.parse(dueDate))
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              assignment['title'] ?? 'Untitled Assignment',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildAssignmentInfo(
                  Icons.assignment_outlined,
                  'Submissions: ${assignment['submissionCount'] ?? 0}',
                ),
                _buildAssignmentInfo(
                  Icons.stars_outlined,
                  'Max Points: ${assignment['maxPoints'] ?? 'Not set'}',
                ),
                if (dueDateStr != null)
                  _buildAssignmentInfo(
                    Icons.calendar_today_outlined,
                    'Due: $dueDateStr',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Helper class for quick actions
class QuickAction {
  final String title;
  final String description;
  final String icon;
  final Color color;
  final String route;

  QuickAction({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.route,
  });
}
