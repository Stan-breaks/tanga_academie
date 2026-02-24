import 'package:flutter/material.dart';
import 'package:tanga_acadamie/data_fetcher.dart';
import 'package:tanga_acadamie/screens/shared/course_card.dart';
import 'package:tanga_acadamie/screens/shared/custom_appbar.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

class AdminCoursesPage extends StatefulWidget {
  const AdminCoursesPage({super.key});

  @override
  State<AdminCoursesPage> createState() => _AdminCoursesPageState();
}

class _AdminCoursesPageState extends State<AdminCoursesPage> {
  String _selectedCategory = 'all';
  List<dynamic> _courses = [];
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
      setState(() {
        _courses = result['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredCourses {
    if (_selectedCategory == 'all') return _courses;
    return _courses.where((c) => c['status'] == _selectedCategory).toList();
  }

  int _getCategoryCount(String category) {
    if (category == 'all') return _courses.length;
    return _courses.where((c) => c['status'] == category).toList().length;
  }

  Future<void> _updateStatus(String courseId, String newStatus) async {
    try {
      await updateCourseStatus(courseId, newStatus);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Course ${newStatus == 'published' ? 'approved' : newStatus} successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }

      _fetchCourses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update course: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Scrollable Category Pills
          _buildCategoryScrollBar(),
          
          // Content
          Expanded(
            child: RefreshIndicator(
              color: Colors.blueAccent,
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
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blueAccent : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected ? Colors.blueAccent : Colors.grey.shade300,
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
                          color: isSelected ? Colors.white : Colors.grey.shade700,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Colors.white.withAlpha(50) 
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey.shade700,
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
    Color color = isSelected ? Colors.white : Colors.grey.shade600;
    IconData icon;
    
    switch (category) {
      case 'published':
        icon = Icons.check_circle;
        color = isSelected ? Colors.white : Colors.green;
        break;
      case 'pending':
        icon = Icons.pending;
        color = isSelected ? Colors.white : Colors.orange;
        break;
      case 'rejected':
        icon = Icons.cancel;
        color = isSelected ? Colors.white : Colors.red;
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
            color: Colors.blueAccent,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            isFr ? 'Chargement des cours...' : 'Loading courses...',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
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
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              isFr ? 'Erreur de chargement des cours' : 'Error loading courses',
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
              onPressed: _fetchCourses,
              icon: const Icon(Icons.refresh),
              label: Text(isFr ? 'Réessayer' : 'Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
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
        childAspectRatio: 0.78,
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
        CourseCard(
          course: course,
          onTap: () => _showCourseActions(course),
        ),
        
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
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
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
        color = Colors.green;
        break;
      case 'pending':
        message = isFr ? 'Aucun cours en attente' : 'No courses pending approval';
        icon = Icons.pending_actions;
        color = Colors.orange;
        break;
      case 'rejected':
        message = isFr ? 'Aucun cours rejeté' : 'No rejected courses';
        icon = Icons.cancel_outlined;
        color = Colors.red;
        break;
      default:
        message = isFr ? 'Aucun cours trouvé' : 'No courses found';
        icon = Icons.library_books_outlined;
        color = Colors.blueAccent;
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
              color: Colors.grey.shade700,
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
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            
            // Current Status
            Row(
              children: [
                Text(
                  isFr ? 'Statut actuel : ' : 'Current Status: ',
                  style: const TextStyle(color: Colors.grey),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                color: Colors.grey,
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
                        backgroundColor: Colors.green,
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
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
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
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
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
        title: Text(isFr
            ? '${newStatus == 'published' ? 'Approuver' : newStatus == 'rejected' ? 'Rejeter' : 'Mettre en attente'} le cours'
            : '${newStatus == 'published' ? 'Approve' : newStatus == 'rejected' ? 'Reject' : 'Set to Pending'} Course'),
        content: Text(isFr
            ? 'Êtes-vous sûr de vouloir changer le statut de "$title" ?'
            : 'Are you sure you want to change "$title" status to $newStatus?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isFr ? 'Annuler' : 'Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(courseId, newStatus);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getStatusColor(newStatus),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isFr ? 'Confirmer' : 'Confirm'),
          ),
        ],
      ),
    );
  }
}
