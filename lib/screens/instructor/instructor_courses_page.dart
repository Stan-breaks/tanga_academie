import 'package:flutter/material.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/screens/instructor/edit_course_page.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tanga_acadamie/core/language/language_provider.dart';

class InstructorCoursesPage extends StatefulWidget {
  const InstructorCoursesPage({super.key});

  @override
  State<InstructorCoursesPage> createState() => _InstructorCoursesPageState();
}

class _InstructorCoursesPageState extends State<InstructorCoursesPage> {
  List<dynamic> _courses = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/instructor-courses'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _courses = data['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load courses';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredCourses {
    if (_selectedFilter == 'all') {
      return _courses;
    }
    return _courses
        .where((course) => course['status'] == _selectedFilter)
        .toList();
  }

  Future<void> _deleteCourse(String courseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 8),
            Text(isFr ? 'Supprimer le cours' : 'Delete Course'),
          ],
        ),
        content: Text(
          isFr ? 'Êtes-vous sûr de vouloir supprimer ce cours ? Cette action est irréversible.' : 'Are you sure you want to delete this course? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isFr ? 'Annuler' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(isFr ? 'Supprimer' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final token = await getToken();
        final response = await http.delete(
          Uri.parse('${ApiConfig.baseUrl}/api/courses/$courseId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Course deleted successfully'),
                backgroundColor: AppColors.success,
              ),
            );
            _fetchCourses();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to delete course'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showZoomDialog(Map<String, dynamic> course) async {
    final courseId = course['_id']?.toString() ?? '';
    final existing = course['zoomLink']?.toString();
    final controller = TextEditingController(text: existing ?? '');

    final result = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.videocam, color: Colors.blue, size: 26),
            const SizedBox(width: 8),
            Text(isFr ? 'Lien Zoom' : 'Zoom Link'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'https://zoom.us/j/...',
                labelText: isFr ? 'URL Zoom' : 'Zoom URL',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () => Navigator.pop(context, '__remove__'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(isFr ? 'Supprimer' : 'Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(isFr ? 'Annuler' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text(isFr ? 'Enregistrer' : 'Save'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (result == null) return;

    try {
      final token = await getToken();
      http.Response res;

      if (result == '__remove__') {
        res = await http.delete(
          Uri.parse('${ApiConfig.baseUrl}/api/courses/$courseId/zoom'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } else {
        if (result.isEmpty) return;
        res = await http.put(
          Uri.parse('${ApiConfig.baseUrl}/api/courses/$courseId/zoom'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'zoomLink': result}),
        );
      }

      if ((res.statusCode == 200 || res.statusCode == 201) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result == '__remove__'
                  ? (isFr ? 'Lien Zoom supprimé' : 'Zoom link removed')
                  : (isFr ? 'Lien Zoom enregistré' : 'Zoom link saved'),
            ),
            backgroundColor:
                result == '__remove__' ? Colors.orange : Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchCourses();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFr ? 'Erreur' : 'Failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (_) {}
  }

  void _navigateToEditCourse(Map<String, dynamic> course) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditCoursePage(course: course)),
    );

    if (result == true) {
      _fetchCourses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFr ? 'Mes cours' : 'My Courses',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryLight, AppColors.primary],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
            onPressed: () async {
              await Navigator.pushNamed(context, '/create-course');
              _fetchCourses();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          if (!_isLoading && _courses.isNotEmpty) _buildStatsSummary(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': isFr ? 'Tous' : 'All', 'icon': Icons.list},
      {'key': 'published', 'label': isFr ? 'Publiés' : 'Published', 'icon': Icons.check_circle},
      {'key': 'pending', 'label': isFr ? 'En attente' : 'Pending', 'icon': Icons.hourglass_empty},
      {'key': 'draft', 'label': isFr ? 'Brouillon' : 'Draft', 'icon': Icons.edit_note},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter['key'];
            final count = filter['key'] == 'all'
                ? _courses.length
                : _courses.where((c) => c['status'] == filter['key']).length;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      filter['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : AppColors.textLight,
                    ),
                    const SizedBox(width: 6),
                    Text(filter['label'] as String),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textLight,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surfaceLight,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textDark,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = filter['key'] as String;
                  });
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    final totalStudents = _courses.fold<int>(
      0,
      (sum, course) => sum + ((course['enrollmentCount'] ?? 0) as int),
    );
    final totalReviews = _courses.fold<int>(
      0,
      (sum, course) => sum + ((course['totalReviews'] ?? 0) as int),
    );
    final avgRating = _courses.isNotEmpty
        ? _courses.fold<double>(
                0,
                (sum, course) =>
                    sum + ((course['rating'] ?? 0) as num).toDouble(),
              ) /
              _courses.length
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primaryLight.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('📚', '${_courses.length}', isFr ? 'Cours' : 'Courses'),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          _buildStatItem('👥', '$totalStudents', isFr ? 'Étudiants' : 'Students'),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          _buildStatItem('⭐', avgRating.toStringAsFixed(1), isFr ? 'Moy.' : 'Avg Rating'),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          _buildStatItem('💬', '$totalReviews', isFr ? 'Avis' : 'Reviews'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.textLight, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Loading your courses...',
              style: TextStyle(color: AppColors.textLight),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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
      );
    }

    if (_courses.isEmpty) {
      return _buildEmptyState();
    }

    if (_filteredCourses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              isFr ? 'Aucun cours $_selectedFilter' : 'No $_selectedFilter courses',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedFilter = 'all';
                });
              },
              child: Text(
                isFr ? 'Afficher tous les cours' : 'Show all courses',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      );
    }

    // Grid View like student section
    return RefreshIndicator(
      onRefresh: _fetchCourses,
      color: AppColors.primary,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.95,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: _filteredCourses.length,
        itemBuilder: (context, index) {
          return _buildCourseGridCard(_filteredCourses[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school_outlined,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isFr ? 'Aucun cours' : 'No Courses Yet',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isFr ? 'Partagez vos connaissances en créant votre premier cours !' : 'Start sharing your knowledge by creating your first course!',
              style: const TextStyle(fontSize: 16, color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.pushNamed(context, '/create-course');
                _fetchCourses();
              },
              icon: const Icon(Icons.add),
              label: Text(isFr ? 'Créer votre premier cours' : 'Create Your First Course'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseGridCard(Map<String, dynamic> course) {
    final status = course['status'] ?? 'draft';
    final statusColors = {
      'published': AppColors.success,
      'pending': AppColors.warning,
      'draft': AppColors.textLight,
      'rejected': AppColors.error,
    };
    final statusColor = statusColors[status] ?? AppColors.textLight;
    final rating = (course['rating'] ?? 0.0) as num;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToEditCourse(course),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Image
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child:
                        course['bannerImage'] != null &&
                            course['bannerImage'].toString().isNotEmpty
                        ? Image.network(
                            ApiConfig.getImageUrl(course['bannerImage']),
                            height: 90,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaceholderBanner();
                            },
                          )
                        : _buildPlaceholderBanner(),
                  ),
                  // Gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 35,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(80),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Status Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toString().toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Price Badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '\$${course['price'] ?? 0}',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Course Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        course['title'] ?? 'Untitled Course',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      // Stats Row
                      Row(
                        children: [
                          Icon(Icons.people_outline, size: 12, color: Colors.grey.shade600),
                          const SizedBox(width: 3),
                          Text(
                            '${course['enrollmentCount'] ?? 0}',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.star, size: 12, color: AppColors.warning),
                          const SizedBox(width: 3),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Action Buttons Row
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 30,
                              child: OutlinedButton(
                                onPressed: () => _navigateToEditCourse(course),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary, width: 1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.edit, size: 12),
                                    const SizedBox(width: 3),
                                    Text(isFr ? 'Modifier' : 'Edit', style: const TextStyle(fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            height: 30,
                            width: 30,
                            child: IconButton(
                              onPressed: () =>
                                  _showZoomDialog(course),
                              padding: EdgeInsets.zero,
                              tooltip: 'Zoom',
                              icon: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: const EdgeInsets.all(5),
                                child: Icon(
                                  course['zoomLink'] != null
                                      ? Icons.videocam
                                      : Icons.videocam_off,
                                  color: course['zoomLink'] != null
                                      ? Colors.blue
                                      : Colors.grey.shade500,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            height: 30,
                            width: 30,
                            child: IconButton(
                              onPressed: () => _deleteCourse(course['_id']),
                              padding: EdgeInsets.zero,
                              icon: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: const EdgeInsets.all(5),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.error,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderBanner() {
    return Container(
      height: 90,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryLight, AppColors.primary],
        ),
      ),
      child: const Center(
        child: Icon(Icons.school_outlined, size: 36, color: Colors.white),
      ),
    );
  }
}
