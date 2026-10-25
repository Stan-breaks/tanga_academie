import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/data_fetcher.dart';
import 'package:tanga_acadamie/screens/admin/admin_analytics_page.dart';
import 'package:tanga_acadamie/screens/admin/admin_courses_page.dart';
import 'package:tanga_acadamie/screens/admin/admin_users_list.dart';
import 'package:tanga_acadamie/screens/admin/admin_blogs_page.dart';
import 'package:tanga_acadamie/screens/shared/_stat_card.dart';
import 'package:tanga_acadamie/screens/shared/course_card.dart';
import 'package:tanga_acadamie/screens/shared/course_details_page.dart';
import 'package:tanga_acadamie/screens/shared/settings_page.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? _stats;
  List<dynamic> _topInstructors = [];
  List<dynamic> _notices = [];
  List<dynamic> _recentCourses = [];
  bool _isLoading = true;
  String? _error;
  String _username = 'Admin';

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get username
      final user = await getUser();
      if (!mounted) return;
      _username = user['username'] ?? user['firstName'] ?? 'Admin';

      // Run all requests concurrently — one failing (e.g. 401) won't crash the
      // whole dashboard. Previously these were four serial round-trips.
      final List<dynamic> results = await Future.wait<dynamic>([
        getAdminDashboardStats().catchError((_) => <String, dynamic>{}),
        getTopInstructors().catchError((_) => <dynamic>[]),
        getAdminNotices().catchError((_) => <dynamic>[]),
        getAdminCourses().catchError((_) => <String, dynamic>{}),
      ]);

      final statsResult = results[0] as Map<String, dynamic>;
      final instructorsResult = results[1] as List;
      final noticesResult = results[2] as List;
      final coursesResult = results[3] as Map<String, dynamic>;

      // Normalize the {success, data:{...}} envelope defensively.
      final statsData = statsResult['data'];
      final normalizedStats = (statsData is Map<String, dynamic> ? statsData : statsResult);
      final coursesData = coursesResult['data'] ?? coursesResult['courses'];
      final normalizedCourses = coursesData is List ? coursesData : const [];

      if (!mounted) return;
      setState(() {
        _stats = normalizedStats.isNotEmpty ? normalizedStats : null;
        _topInstructors = instructorsResult.take(5).toList();
        _notices = noticesResult.take(5).toList();
        _recentCourses = normalizedCourses.take(6).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatMoney(dynamic amount) {
    if (amount == null) return '\$0';
    final value = (amount is num)
        ? amount.toDouble()
        : double.tryParse(amount.toString()) ?? 0.0;
    return NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(value);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return _buildDashboard();
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              isFr
                  ? 'Chargement du tableau de bord admin...'
                  : 'Loading admin dashboard...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error300),
              const SizedBox(height: 16),
              Text(
                isFr ? 'Quelque chose a mal tourné' : 'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Unknown error',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchDashboardData,
                icon: const Icon(Icons.refresh),
                label: Text(isFr ? 'Réessayer' : 'Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    // Accept both {stats:[...]} and the raw {data:{stats:[...]}} envelope.
    final statsMap = _stats?['data'] is Map ? _stats!['data'] as Map : _stats;
    final statsList = statsMap?['stats'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _fetchDashboardData,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Welcome Section
            _buildWelcomeSection(),
            const SizedBox(height: 24),

            // Stats Grid
            _buildStatsGrid(statsList),
            const SizedBox(height: 32),

            // Quick Actions Section
            _buildSectionHeader(
              context,
              isFr ? 'Actions rapides' : 'Quick Actions',
              Icons.flash_on,
              0,
            ),
            const SizedBox(height: 16),
            _buildQuickActions(),
            const SizedBox(height: 32),

            // Recent Courses Section
            _buildSectionHeader(
              context,
              isFr ? 'Cours récents' : 'Recent Courses',
              Icons.library_books,
              _recentCourses.length,
            ),
            const SizedBox(height: 16),
            _buildRecentCourses(),
            const SizedBox(height: 32),

            // Popular Instructors Section
            _buildSectionHeader(
              context,
              isFr ? 'Instructeurs populaires' : 'Popular Instructors',
              Icons.star,
              _topInstructors.length,
            ),
            const SizedBox(height: 16),
            _buildPopularInstructors(),
            const SizedBox(height: 32),

            // Notice Board Section
            _buildSectionHeader(
              context,
              isFr ? 'Tableau d\'affichage' : 'Notice Board',
              Icons.notifications,
              _notices.length,
            ),
            const SizedBox(height: 16),
            _buildNoticeBoard(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
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
          colors: [AppColors.primary400, AppColors.primary700],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(80),
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
                  _username,
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
                    isFr ? '👑 Tableau de bord admin' : '👑 Admin Dashboard',
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
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(List<dynamic> statsList) {
    // Map stats from API response
    final statsMap = <String, dynamic>{};
    for (var stat in statsList) {
      final title = stat['title'] as String? ?? '';
      final value = stat['value'];
      if (title.toLowerCase().contains('total courses')) {
        statsMap['totalCourses'] = value;
      } else if (title.toLowerCase().contains('active')) {
        statsMap['activeCourses'] = value;
      } else if (title.toLowerCase().contains('pending')) {
        statsMap['pendingCourses'] = value;
      } else if (title.toLowerCase().contains('student')) {
        statsMap['totalStudents'] = value;
      } else if (title.toLowerCase().contains('instructor')) {
        statsMap['totalInstructors'] = value;
      } else if (title.toLowerCase().contains('revenue')) {
        statsMap['totalRevenue'] = value;
      } else if (title.toLowerCase().contains('purchase')) {
        statsMap['totalPurchases'] = value;
      }
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      children: [
        StatCard(
          title: isFr ? 'Total des cours' : 'Total Courses',
          value: '${statsMap['totalCourses'] ?? 0}',
          icon: Icons.library_books,
          gradientColors: [
            AppColors.primary200,
            AppColors.primary700,
          ],
        ),
        StatCard(
          title: isFr ? 'Cours actifs' : 'Active Courses',
          value: '${statsMap['activeCourses'] ?? 0}',
          icon: Icons.play_circle_fill,
          gradientColors: [AppColors.success400, AppColors.success700],
        ),
        StatCard(
          title: isFr ? 'Cours en attente' : 'Pending Courses',
          value: '${statsMap['pendingCourses'] ?? 0}',
          icon: Icons.pending_actions,
          gradientColors: [AppColors.warning400, AppColors.warning600],
        ),
        StatCard(
          title: isFr ? 'Total des étudiants' : 'Total Students',
          value: '${statsMap['totalStudents'] ?? 0}',
          icon: Icons.people,
          gradientColors: [AppColors.secondary400, AppColors.secondary800],
        ),
        StatCard(
          title: isFr ? 'Total des instructeurs' : 'Total Instructors',
          value: '${statsMap['totalInstructors'] ?? 0}',
          icon: Icons.school,
          gradientColors: [AppColors.success400, AppColors.success700],
        ),
        StatCard(
          title: isFr ? 'Revenus de la plateforme' : 'Platform Revenue',
          value: _formatMoney(statsMap['totalRevenue']),
          icon: Icons.payments,
          gradientColors: [AppColors.warning400, AppColors.warning700],
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
            color: AppColors.primary.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
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
                  color: AppColors.textDark,
                ),
              ),
              if (count > 0)
                Text(
                  '$count ${count == 1 ? (isFr ? 'élément' : 'item') : (isFr ? 'éléments' : 'items')}',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickActionItem(
        title: isFr ? 'Gérer les cours' : 'Manage Courses',
        icon: Icons.library_books,
        color: AppColors.primary,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminCoursesPage()),
          );
        },
      ),
      _QuickActionItem(
        title: isFr ? 'Analytiques' : 'Analytics',
        icon: Icons.bar_chart,
        color: AppColors.secondary,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminAnalyticsPage()),
          );
        },
      ),
      _QuickActionItem(
        title: isFr ? 'Utilisateurs' : 'Users',
        icon: Icons.people,
        color: AppColors.success,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminUsersList()),
          );
        },
      ),
      _QuickActionItem(
        title: isFr ? 'Articles' : 'Blogs',
        icon: Icons.article,
        color: AppColors.success,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminBlogsPage()),
          );
        },
      ),
      _QuickActionItem(
        title: isFr ? 'Paramètres' : 'Settings',
        icon: Icons.settings,
        color: AppColors.warning,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          );
        },
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.9,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: action.color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(action.icon, color: action.color, size: 26),
              ),
              const SizedBox(height: 8),
              Text(
                action.title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentCourses() {
    if (_recentCourses.isEmpty) {
      return _buildEmptyState(
        isFr ? 'Aucun cours' : 'No courses yet',
        isFr
            ? 'Les cours apparaîtront ici'
            : 'Courses will appear here as they are created',
        Icons.library_books_outlined,
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.82,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: _recentCourses.length > 4 ? 4 : _recentCourses.length,
      itemBuilder: (context, index) {
        return CourseCard(
          course: _recentCourses[index],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    CourseDetailsPage(course: _recentCourses[index]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPopularInstructors() {
    if (_topInstructors.isEmpty) {
      return _buildEmptyState(
        isFr ? 'Aucun instructeur' : 'No instructors yet',
        isFr
            ? 'Les instructeurs apparaîtront ici'
            : 'Instructors will appear here once they create courses',
        Icons.school_outlined,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _topInstructors.length > 5 ? 5 : _topInstructors.length,
        separatorBuilder: (_, _) =>
            Divider(color: AppColors.borderLight, height: 1),
        itemBuilder: (context, index) {
          final instructor = _topInstructors[index];
          return _buildInstructorTile(instructor);
        },
      ),
    );
  }

  Widget _buildInstructorTile(Map<String, dynamic> instructor) {
    final firstName = instructor['firstName'] ?? '';
    final lastName = instructor['lastName'] ?? '';
    final name = '$firstName $lastName'.trim();
    final profile = instructor['profile'];
    final studentCount = instructor['studentCount'] ?? 0;
    final courseCount = instructor['courseCount'] ?? 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: profile != null && profile.isNotEmpty
            ? NetworkImage('${ApiConfig.baseUrl}$profile')
            : null,
        backgroundColor: AppColors.primary100,
        child: profile == null || profile.isEmpty
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.primary,
                ),
              )
            : null,
      ),
      title: Text(
        name.isEmpty ? 'Unknown Instructor' : name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Row(
        children: [
          Icon(Icons.people, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            '$studentCount',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Icon(Icons.book, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            '$courseCount',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBoard() {
    if (_notices.isEmpty) {
      return _buildEmptyState(
        isFr ? 'Aucune notification' : 'No notices',
        isFr
            ? 'Les notifications apparaîtront ici'
            : 'Important notices will appear here',
        Icons.notifications_none,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _notices.length,
        separatorBuilder: (context, index) =>
            Divider(color: AppColors.borderLight, height: 1),
        itemBuilder: (context, index) {
          final notice = _notices[index];
          return _buildNoticeTile(notice);
        },
      ),
    );
  }

  Widget _buildNoticeTile(Map<String, dynamic> notice) {
    final title = notice['title'] ?? 'Untitled';
    final priority = notice['priority'] ?? 'low';
    final type = notice['type'] ?? 'system';
    final createdAt = notice['createdAt'];
    final isRead = notice['isRead'] ?? false;

    Color priorityColor;
    switch (priority) {
      case 'high':
        priorityColor = AppColors.error;
        break;
      case 'medium':
        priorityColor = AppColors.warning;
        break;
      default:
        priorityColor = AppColors.success;
    }

    String typeIcon;
    switch (type) {
      case 'enrollment':
        typeIcon = '👥';
        break;
      case 'financial':
        typeIcon = '💰';
        break;
      case 'course':
        typeIcon = '📚';
        break;
      default:
        typeIcon = '⚠️';
    }

    String dateStr = '';
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        dateStr = DateFormat('MMM d, yyyy').format(date);
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: priorityColor, width: 4)),
        color: isRead ? Colors.white : AppColors.primary50,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Text(typeIcon, style: const TextStyle(fontSize: 24)),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          dateStr,
          style: TextStyle(fontSize: 12, color: AppColors.textLight),
        ),
        trailing: !isRead
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isFr ? 'NOUVEAU' : 'NEW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _QuickActionItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
