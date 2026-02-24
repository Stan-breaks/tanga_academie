import 'package:flutter/material.dart';
import 'package:tanga_acadamie/data_fetcher.dart';
import 'package:tanga_acadamie/screens/shared/_stat_card.dart';
import 'package:intl/intl.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

class InstructorDashboard extends StatelessWidget {
  const InstructorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getInstructorDash(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
                    isFr ? 'Chargement du tableau de bord...' : 'Loading your dashboard...',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text(
                      isFr ? 'Quelque chose a mal tourné' : 'Something went wrong',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          final data = snapshot.data!;
          final stats = data['stats'] ?? {};
          final List recentCourses = data['recentCourses'] ?? [];
          final List recentAssignments = data['recentAssignments'] ?? [];

          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            body: RefreshIndicator(
              color: Colors.blueAccent,
              onRefresh: () async {
                // Trigger a rebuild by returning a future
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Welcome Section
                  _buildWelcomeSection(data['username'] ?? 'Instructor'),
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
                        title: isFr ? 'Total des cours' : 'Total Courses',
                        value: "${stats['totalCourses'] ?? 0}",
                        icon: Icons.library_books,
                        gradientColors: [
                          Colors.blueAccent.shade200,
                          Colors.blueAccent.shade700,
                        ],
                      ),
                      StatCard(
                        title: isFr ? 'Cours actifs' : 'Active Courses',
                        value: "${stats['activeCourses'] ?? 0}",
                        icon: Icons.play_circle_fill,
                        gradientColors: [
                          Colors.green.shade400,
                          Colors.green.shade700,
                        ],
                      ),
                      StatCard(
                        title: isFr ? 'Total des étudiants' : 'Total Students',
                        value: "${stats['totalStudents'] ?? 0}",
                        icon: Icons.people,
                        gradientColors: [
                          Colors.orange.shade400,
                          Colors.deepOrange.shade600,
                        ],
                      ),
                      StatCard(
                        title: isFr ? 'Soumissions en attente' : 'Pending Submissions',
                        value: "${stats['pendingSubmissions'] ?? 0}",
                        icon: Icons.assignment_late,
                        gradientColors: [
                          Colors.purple.shade400,
                          Colors.purple.shade800,
                        ],
                      ),
                      StatCard(
                        title: isFr ? 'Total des avis' : 'Total Reviews',
                        value: "${stats['totalReviews'] ?? 0}",
                        icon: Icons.rate_review,
                        gradientColors: [
                          Colors.teal.shade400,
                          Colors.teal.shade700,
                        ],
                      ),
                      StatCard(
                        title: isFr ? 'Note des cours' : 'Course Rating',
                        value: "4.5 ⭐",
                        icon: Icons.star,
                        gradientColors: [
                          Colors.amber.shade400,
                          Colors.amber.shade700,
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Quick Actions Section
                  _buildSectionHeader(isFr ? 'Actions rapides' : 'Quick Actions', Icons.flash_on),
                  const SizedBox(height: 16),
                  _buildQuickActions(context),
                  const SizedBox(height: 32),

                  // Recent Courses Section
                  _buildSectionHeader(isFr ? 'Cours récents' : 'Recent Courses', Icons.library_books),
                  const SizedBox(height: 16),
                  if (recentCourses.isEmpty)
                    _buildEmptyState(
                      isFr ? 'Aucun cours' : 'No courses yet',
                      isFr ? 'Créez votre premier cours pour commencer !' : 'Create your first course to get started!',
                      Icons.book_outlined,
                    )
                  else
                    _buildRecentCourses(recentCourses, context),
                  const SizedBox(height: 32),

                  // Recent Assignment Activity Section
                  _buildSectionHeader(isFr ? 'Activité des devoirs' : 'Assignment Activity', Icons.assignment),
                  const SizedBox(height: 16),
                  if (recentAssignments.isEmpty)
                    _buildEmptyState(
                      isFr ? 'Aucun devoir' : 'No assignments yet',
                      isFr ? 'Créez des devoirs pour suivre les soumissions !' : 'Create assignments to track student submissions!',
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

  Widget _buildWelcomeSection(String username) {
    final hour = DateTime.now().hour;
    String greeting;
    IconData greetingIcon;

    if (hour < 12) {
      greeting = isFr ? 'Bonjour' : 'Good morning';
      greetingIcon = Icons.wb_sunny_outlined;
    } else if (hour < 17) {
      greeting = isFr ? 'Bon après-midi' : 'Good afternoon';
      greetingIcon = Icons.wb_sunny;
    } else {
      greeting = isFr ? 'Bonsoir' : 'Good evening';
      greetingIcon = Icons.nights_stay_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blueAccent.shade400, Colors.blue.shade700],
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
                    Icon(greetingIcon, color: Colors.white70, size: 18),
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
                  child: Text(
                    isFr ? '\u{1F393} Tableau de bord instructeur' : '\u{1F393} Instructor Dashboard',
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(20),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.blueAccent, size: 22),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      QuickAction(
        title: isFr ? 'Créer un cours' : 'Create New Course',
        description: isFr ? 'Commencez à créer votre prochain cours' : 'Start creating your next course',
        icon: '📚',
        color: Colors.blue.shade400,
        route: '/create-course',
      ),
      QuickAction(
        title: isFr ? 'Gérer les cours' : 'Manage Courses',
        description: isFr ? 'Modifier et mettre à jour les cours' : 'Edit and update existing courses',
        icon: '⚙️',
        color: Colors.green.shade500,
        route: '/instructor-courses',
      ),
      QuickAction(
        title: isFr ? 'Noter les devoirs' : 'Grade Assignments',
        description: isFr ? 'Vérifier et noter les soumissions' : 'Review and grade student submissions',
        icon: '📝',
        color: Colors.orange.shade400,
        route: '/instructor-assignments',
      ),
      QuickAction(
        title: isFr ? 'Créer un quiz' : 'Create Quiz',
        description: isFr ? 'Créer et gérer les quiz' : 'Create & manage lesson quizzes',
        icon: '📊',
        color: Colors.purple.shade500,
        route: '/instructor-quiz',
      ),
      QuickAction(
        title: isFr ? 'Progrès des étudiants' : 'Student Progress',
        description: isFr ? 'Suivre les progrès d\'apprentissage' : 'Monitor student learning progress',
        icon: '👥',
        color: Colors.teal.shade500,
        route: '/instructor-student-progress',
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
