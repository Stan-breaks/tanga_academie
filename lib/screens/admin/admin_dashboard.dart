import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/data_fetcher.dart';
import 'package:tanga_acadamie/screens/shared/_stat_card.dart';
import 'package:tanga_acadamie/screens/shared/course_card.dart';
import 'package:tanga_acadamie/storage_service.dart';

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
      _username = user['username'] ?? user['firstName'] ?? 'Admin';

      final results = await Future.wait([
        getAdminDashboardStats(),
        getTopInstructors(),
        getAdminNotices(),
        getAdminCourses(),
      ]);

      setState(() {
        _stats = results[0] as Map<String, dynamic>?;
        _topInstructors = (results[1] as List<dynamic>).take(5).toList();
        _notices = (results[2] as List<dynamic>).take(5).toList();
        final coursesData = results[3] as Map<String, dynamic>;
        _recentCourses = (coursesData['data'] as List<dynamic>? ?? []).take(6).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatMoney(dynamic amount) {
    if (amount == null) return '\$0';
    final value = amount is int ? amount.toDouble() : (amount as double);
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
              'Loading admin dashboard...',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
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
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Unknown error',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchDashboardData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
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
    final statsList = _stats?['data']?['stats'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        color: Colors.blueAccent,
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
              'Quick Actions',
              Icons.flash_on,
              0,
            ),
            const SizedBox(height: 16),
            _buildQuickActions(),
            const SizedBox(height: 32),

            // Recent Courses Section
            _buildSectionHeader(
              context,
              'Recent Courses',
              Icons.library_books,
              _recentCourses.length,
            ),
            const SizedBox(height: 16),
            _buildRecentCourses(),
            const SizedBox(height: 32),

            // Popular Instructors Section
            _buildSectionHeader(
              context,
              'Popular Instructors',
              Icons.star,
              _topInstructors.length,
            ),
            const SizedBox(height: 16),
            _buildPopularInstructors(),
            const SizedBox(height: 32),

            // Notice Board Section
            _buildSectionHeader(
              context,
              'Notice Board',
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
                  child: const Text(
                    '👑 Admin Dashboard',
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
            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 36),
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
          title: 'Total Courses',
          value: '${statsMap['totalCourses'] ?? 0}',
          icon: Icons.library_books,
          gradientColors: [
            Colors.blueAccent.shade200,
            Colors.blueAccent.shade700,
          ],
        ),
        StatCard(
          title: 'Active Courses',
          value: '${statsMap['activeCourses'] ?? 0}',
          icon: Icons.play_circle_fill,
          gradientColors: [Colors.green.shade400, Colors.green.shade700],
        ),
        StatCard(
          title: 'Pending Courses',
          value: '${statsMap['pendingCourses'] ?? 0}',
          icon: Icons.pending_actions,
          gradientColors: [Colors.orange.shade400, Colors.deepOrange.shade600],
        ),
        StatCard(
          title: 'Total Students',
          value: '${statsMap['totalStudents'] ?? 0}',
          icon: Icons.people,
          gradientColors: [Colors.purple.shade400, Colors.purple.shade800],
        ),
        StatCard(
          title: 'Total Instructors',
          value: '${statsMap['totalInstructors'] ?? 0}',
          icon: Icons.school,
          gradientColors: [Colors.teal.shade400, Colors.teal.shade700],
        ),
        StatCard(
          title: 'Platform Revenue',
          value: _formatMoney(statsMap['totalRevenue']),
          icon: Icons.payments,
          gradientColors: [Colors.amber.shade400, Colors.amber.shade700],
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
          child: Icon(icon, color: Colors.blueAccent, size: 22),
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
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
        title: 'Manage Courses',
        icon: Icons.library_books,
        color: Colors.blue,
        onTap: () {
          // Handled by bottom navigation
        },
      ),
      _QuickActionItem(
        title: 'User Management',
        icon: Icons.people,
        color: Colors.green,
        onTap: () => Navigator.pushNamed(context, '/admin-users'),
      ),
      _QuickActionItem(
        title: 'Analytics',
        icon: Icons.bar_chart,
        color: Colors.orange,
        onTap: () => Navigator.pushNamed(context, '/admin-analytics'),
      ),
      _QuickActionItem(
        title: 'Settings',
        icon: Icons.settings,
        color: Colors.purple,
        onTap: () => Navigator.pushNamed(context, '/admin-settings'),
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
        'No courses yet',
        'Courses will appear here as they are created',
        Icons.library_books_outlined,
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.95,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: _recentCourses.length > 4 ? 4 : _recentCourses.length,
      itemBuilder: (context, index) {
        return CourseCard(
          course: _recentCourses[index],
          onTap: () {
            // Navigate to course details
          },
        );
      },
    );
  }

  Widget _buildPopularInstructors() {
    if (_topInstructors.isEmpty) {
      return _buildEmptyState(
        'No instructors yet',
        'Instructors will appear here once they create courses',
        Icons.school_outlined,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _topInstructors.length > 5 ? 5 : _topInstructors.length,
        separatorBuilder: (_, __) => Divider(color: Colors.grey.shade200, height: 1),
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
        backgroundColor: Colors.blueAccent.shade100,
        child: profile == null || profile.isEmpty
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blueAccent,
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
          Icon(Icons.people, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            '$studentCount',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          Icon(Icons.book, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            '$courseCount',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }

  Widget _buildNoticeBoard() {
    if (_notices.isEmpty) {
      return _buildEmptyState(
        'No notices',
        'Important notices will appear here',
        Icons.notifications_none,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _notices.length,
        separatorBuilder: (_, __) => Divider(color: Colors.grey.shade200, height: 1),
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
        priorityColor = Colors.red;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        break;
      default:
        priorityColor = Colors.green;
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
        color: isRead ? Colors.white : Colors.blue.shade50,
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
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        trailing: !isRead
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
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
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
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
