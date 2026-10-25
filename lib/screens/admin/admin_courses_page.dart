import 'package:flutter/material.dart';
import 'package:tanga_acadamie/data_fetcher.dart';
import 'package:tanga_acadamie/screens/shared/course_card.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:tanga_acadamie/core/utils/app_snackbar.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';

class AdminCoursesPage extends StatefulWidget {
  const AdminCoursesPage({super.key});

  @override
  State<AdminCoursesPage> createState() => _AdminCoursesPageState();
}

class _AdminCoursesPageState extends State<AdminCoursesPage> {
  String _selectedCategory = 'all';
  List<Map<String, dynamic>> _courses = [];
  bool _isLoading = true;
  String? _error;

  List<Map<String, String>> get _categories => [
    {'id': 'all', 'label': isFr ? 'Tous les cours' : 'All Courses'},
    {'id': 'published', 'label': isFr ? 'Publiés' : 'Published'},
    {'id': 'pending', 'label': isFr ? 'En attente' : 'Pending'},
    {'id': 'rejected', 'label': isFr ? 'Rejetés' : 'Rejected'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await getAdminCourses();
      if (!mounted) return;
      // Normalize {success, data:[...]} / {success, courses:[...]} envelopes.
      final raw = result['data'] ?? result['courses'];
      setState(() {
        _courses = raw is List
            ? raw
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
            : <Map<String, dynamic>>[];
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

  List<Map<String, dynamic>> get _filteredCourses {
    if (_selectedCategory == 'all') return _courses;
    return _courses.where((c) => c['status'] == _selectedCategory).toList();
  }

  int _getCategoryCount(String category) {
    if (category == 'all') return _courses.length;
    return _courses.where((c) => c['status'] == category).length;
  }

  Future<void> _updateStatus(String courseId, String newStatus) async {
    try {
      await updateCourseStatus(courseId, newStatus);

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          isFr
              ? 'Cours ${newStatus == 'published' ? 'approuvé' : newStatus} avec succès !'
              : 'Course ${newStatus == 'published' ? 'approved' : newStatus} successfully!',
        );
      }

      _fetchCourses();
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          '${isFr ? 'Échec de la mise à jour du cours : ' : 'Failed to update course: '}$e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Scrollable Category Pills
          _buildCategoryScrollBar(),

          // Content
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _fetchCourses,
              child: _isLoading
                  ? _buildLoadingState()
                  : _error != null
                  ? _buildErrorState()
                  : _buildCourseGrid(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryScrollBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _categories.map((category) {
            final isSelected = _selectedCategory == category['id'];
            final count = _getCategoryCount(category['id']!);

            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = category['id']!;
                  });
                },
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _getCategoryIcon(category['id']!, isSelected),
                      const SizedBox(width: 6),
                      Text(
                        category['label']!,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textDark,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withAlpha(50)
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _getCategoryIcon(String category, bool isSelected) {
    Color color = isSelected ? Colors.white : AppColors.textSecondary;
    IconData icon;

    switch (category) {
      case 'published':
        icon = Icons.check_circle;
        color = isSelected ? Colors.white : AppColors.success;
        break;
      case 'pending':
        icon = Icons.pending;
        color = isSelected ? Colors.white : AppColors.warning;
        break;
      case 'rejected':
        icon = Icons.cancel;
        color = isSelected ? Colors.white : AppColors.error;
        break;
      default:
        icon = Icons.library_books;
    }

    return Icon(icon, size: 16, color: color);
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            isFr ? 'Chargement des cours...' : 'Loading courses...',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error300),
            const SizedBox(height: 16),
            Text(
              isFr ? 'Erreur de chargement des cours' : 'Error loading courses',
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
              onPressed: _fetchCourses,
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
    );
  }

  Widget _buildCourseGrid() {
    final courses = _filteredCourses;

    if (courses.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.82,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final course = courses[index];
        return _buildAdminCourseCard(course);
      },
    );
  }

  Widget _buildAdminCourseCard(Map<String, dynamic> course) {
    final status = course['status'] ?? 'pending';

    return Stack(
      children: [
        // Reuse the CourseCard widget
        CourseCard(course: course, onTap: () => _showCourseActions(course)),

        // Status badge overlay
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(status),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              status.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'published':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;
    Color color;

    switch (_selectedCategory) {
      case 'published':
        message = isFr ? 'Aucun cours publié' : 'No published courses';
        icon = Icons.check_circle_outline;
        color = AppColors.success;
        break;
      case 'pending':
        message = isFr
            ? 'Aucun cours en attente'
            : 'No courses pending approval';
        icon = Icons.pending_actions;
        color = AppColors.warning;
        break;
      case 'rejected':
        message = isFr ? 'Aucun cours rejeté' : 'No rejected courses';
        icon = Icons.cancel_outlined;
        color = AppColors.error;
        break;
      default:
        message = isFr ? 'Aucun cours trouvé' : 'No courses found';
        icon = Icons.library_books_outlined;
        color = AppColors.primary;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: color),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  void _showCourseActions(Map<String, dynamic> course) {
    final courseId = course['_id'];
    final currentStatus = course['status'] ?? 'pending';
    final title = course['title'] ?? 'Untitled Course';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Current Status
            Row(
              children: [
                Text(
                  isFr ? 'Statut actuel : ' : 'Current Status: ',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(currentStatus),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    currentStatus.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Text(
              isFr ? 'Changer le statut' : 'Change Status',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                if (currentStatus != 'published')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmStatusChange(courseId, 'published', title);
                      },
                      icon: const Icon(Icons.check),
                      label: Text(isFr ? 'Approuver' : 'Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (currentStatus != 'published') const SizedBox(width: 8),

                if (currentStatus != 'pending')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmStatusChange(courseId, 'pending', title);
                      },
                      icon: const Icon(Icons.pending),
                      label: Text(isFr ? 'En attente' : 'Pending'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        side: const BorderSide(color: AppColors.warning),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (currentStatus != 'pending') const SizedBox(width: 8),

                if (currentStatus != 'rejected')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmStatusChange(courseId, 'rejected', title);
                      },
                      icon: const Icon(Icons.close),
                      label: Text(isFr ? 'Rejeter' : 'Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmStatusChange(String courseId, String newStatus, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isFr
              ? '${newStatus == 'published'
                    ? 'Approuver'
                    : newStatus == 'rejected'
                    ? 'Rejeter'
                    : 'Mettre en attente'} le cours'
              : '${newStatus == 'published'
                    ? 'Approve'
                    : newStatus == 'rejected'
                    ? 'Reject'
                    : 'Set to Pending'} Course',
        ),
        content: Text(
          isFr
              ? 'Êtes-vous sûr de vouloir changer le statut de "$title" ?'
              : 'Are you sure you want to change "$title" status to $newStatus?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              isFr ? 'Annuler' : 'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(courseId, newStatus);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getStatusColor(newStatus),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(isFr ? 'Confirmer' : 'Confirm'),
          ),
        ],
      ),
    );
  }
}
