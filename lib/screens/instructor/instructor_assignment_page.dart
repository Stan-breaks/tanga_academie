import 'package:flutter/material.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';

class InstructorAssignmentPage extends StatefulWidget {
  const InstructorAssignmentPage({super.key});

  @override
  State<InstructorAssignmentPage> createState() =>
      _InstructorAssignmentPageState();
}

class _InstructorAssignmentPageState extends State<InstructorAssignmentPage>
    with SingleTickerProviderStateMixin {
  List<dynamic> _courses = [];
  List<dynamic> _assignments = [];
  bool _isLoading = true;
  bool _isLoadingAssignments = false;
  String? _errorMessage;
  String? _selectedCourseId;
  String _selectedCourseName = '';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _fetchCourses();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Fetch instructor courses for the filter dropdown ──────────────
  Future<void> _fetchCourses() async {
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
        // If no course selected yet, fetch all instructor assignments
        _fetchAllAssignments();
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

  // ── Fetch ALL assignments across instructor's courses ─────────────
  Future<void> _fetchAllAssignments() async {
    setState(() => _isLoadingAssignments = true);
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/courses/instructor/assignments'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _assignments = data['data'] ?? [];
          _isLoadingAssignments = false;
        });
        _animController.forward(from: 0);
      } else {
        setState(() {
          _assignments = [];
          _isLoadingAssignments = false;
        });
      }
    } catch (e) {
      setState(() {
        _assignments = [];
        _isLoadingAssignments = false;
      });
    }
  }

  // ── Fetch assignments for a specific course ───────────────────────
  Future<void> _fetchCourseAssignments(String courseId) async {
    setState(() => _isLoadingAssignments = true);
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/courses/$courseId/assignments'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _assignments = data['data'] ?? [];
          _isLoadingAssignments = false;
        });
        _animController.forward(from: 0);
      } else {
        setState(() {
          _assignments = [];
          _isLoadingAssignments = false;
        });
      }
    } catch (e) {
      setState(() {
        _assignments = [];
        _isLoadingAssignments = false;
      });
    }
  }

  // ── Delete assignment ─────────────────────────────────────────────
  Future<void> _deleteAssignment(String assignmentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: 28),
            SizedBox(width: 8),
            Text(isFr ? 'Supprimer le devoir' : 'Delete Assignment'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this assignment? This action cannot be undone.',
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
          Uri.parse(
              '${ApiConfig.baseUrl}/api/courses/assignments/$assignmentId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          setState(() {
            _assignments
                .removeWhere((a) => a['_id'] == assignmentId);
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isFr ? 'Devoir supprimé avec succès' : 'Assignment deleted successfully'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to delete assignment'),
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

  // ── Update assignment ─────────────────────────────────────────────
  Future<void> _updateAssignment(
      String assignmentId, Map<String, dynamic> formData) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/courses/assignments/$assignmentId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(formData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          final index =
              _assignments.indexWhere((a) => a['_id'] == assignmentId);
          if (index != -1) {
            _assignments[index] = data['data'];
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isFr ? 'Devoir mis à jour avec succès' : 'Assignment updated successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update assignment'),
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

  // ── Open edit bottom sheet ────────────────────────────────────────
  void _openEditSheet(Map<String, dynamic> assignment) {
    final titleController =
        TextEditingController(text: assignment['title'] ?? '');
    final descController =
        TextEditingController(text: assignment['description'] ?? '');
    final maxPointsController = TextEditingController(
        text: (assignment['maxPoints'] ?? 100).toString());
    DateTime selectedDate = assignment['dueDate'] != null
        ? DateTime.parse(assignment['dueDate'])
        : DateTime.now().add(const Duration(days: 7));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
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
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: AppColors.primaryGradient,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.edit_note,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Edit Assignment',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Title field
                    _buildInputLabel('Title'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: titleController,
                      hint: 'Assignment title',
                      icon: Icons.title,
                    ),
                    const SizedBox(height: 16),

                    // Description field
                    _buildInputLabel('Description'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: descController,
                      hint: 'Assignment description',
                      icon: Icons.description_outlined,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Due Date
                    _buildInputLabel('Due Date'),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.primary,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: AppColors.textDark,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setBottomState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('MMM d, yyyy').format(selectedDate),
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.textDark,
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.arrow_drop_down,
                                color: Colors.grey.shade500),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Max Points
                    _buildInputLabel('Max Points'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: maxPointsController,
                      hint: '100',
                      icon: Icons.stars_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 28),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              final formData = {
                                'title': titleController.text,
                                'description': descController.text,
                                'dueDate': selectedDate.toIso8601String(),
                                'maxPoints':
                                    int.tryParse(maxPointsController.text) ??
                                        100,
                              };
                              Navigator.pop(context);
                              await _updateAssignment(
                                  assignment['_id'], formData);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Open submissions view ─────────────────────────────────────────
  void _openSubmissionsView(Map<String, dynamic> assignment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AssignmentSubmissionsPage(
          assignmentId: assignment['_id'],
          assignmentTitle: assignment['title'] ?? 'Assignment',
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isFr ? 'Devoirs' : 'Assignments',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Loading assignments...',
                    style: TextStyle(color: AppColors.textLight),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildCourseFilter(),
                    if (!_isLoadingAssignments && _assignments.isNotEmpty)
                      _buildStatsBanner(),
                    Expanded(child: _buildAssignmentsList()),
                  ],
                ),
    );
  }

  // ── Error state ──────────────────────────────────────────────────
  Widget _buildErrorState() {
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

  // ── Course filter dropdown ────────────────────────────────────────
  Widget _buildCourseFilter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.filter_list,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCourseId,
                hint: const Text(
                  'All Courses',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: AppColors.primary),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'All Courses',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  ..._courses.map<DropdownMenuItem<String>>((course) {
                    return DropdownMenuItem<String>(
                      value: course['_id'],
                      child: Text(
                        course['title'] ?? 'Untitled',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCourseId = value;
                    _selectedCourseName = value != null
                        ? (_courses.firstWhere(
                            (c) => c['_id'] == value,
                            orElse: () => {'title': ''},
                          )['title'] ?? '')
                        : '';
                  });
                  if (value == null) {
                    _fetchAllAssignments();
                  } else {
                    _fetchCourseAssignments(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats banner ──────────────────────────────────────────────────
  Widget _buildStatsBanner() {
    final totalAssignments = _assignments.length;
    final totalSubmissions = _assignments.fold<int>(
      0,
      (sum, a) => sum + ((a['submissionCount'] ?? 0) as int),
    );
    final overdueCount = _assignments.where((a) {
      if (a['dueDate'] == null) return false;
      return DateTime.parse(a['dueDate']).isBefore(DateTime.now());
    }).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withAlpha(20),
            AppColors.primaryLight.withAlpha(20),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('📝', '$totalAssignments', isFr ? 'Devoirs' : 'Assignments'),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          _buildStatItem('📤', '$totalSubmissions', isFr ? 'Soumissions' : 'Submissions'),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          _buildStatItem('⏰', '$overdueCount', isFr ? 'En retard' : 'Overdue'),
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

  // ── Assignments list ──────────────────────────────────────────────
  Widget _buildAssignmentsList() {
    if (_isLoadingAssignments) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_assignments.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        if (_selectedCourseId != null) {
          await _fetchCourseAssignments(_selectedCourseId!);
        } else {
          await _fetchAllAssignments();
        }
      },
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: _assignments.length,
          itemBuilder: (context, index) {
            return _buildAssignmentCard(_assignments[index], index);
          },
        ),
      ),
    );
  }

  // ── Single assignment card ────────────────────────────────────────
  Widget _buildAssignmentCard(Map<String, dynamic> assignment, int index) {
    final dueDate = assignment['dueDate'] != null
        ? DateTime.parse(assignment['dueDate'])
        : null;
    final isOverdue =
        dueDate != null && dueDate.isBefore(DateTime.now());
    final dueDateStr =
        dueDate != null ? DateFormat('MMM d, yyyy').format(dueDate) : 'No date';
    final submissionCount = assignment['submissionCount'] ?? 0;
    final maxPoints = assignment['maxPoints'] ?? 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue
              ? AppColors.error.withAlpha(60)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openSubmissionsView(assignment),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isOverdue
                              ? [
                                  AppColors.error.withAlpha(180),
                                  AppColors.error,
                                ]
                              : AppColors.primaryGradient,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isOverdue
                            ? Icons.assignment_late
                            : Icons.assignment_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assignment['title'] ?? 'Untitled',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textDark,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (assignment['courseTitle'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                assignment['courseTitle'],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isOverdue
                            ? AppColors.error.withAlpha(25)
                            : AppColors.success.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isOverdue
                              ? AppColors.error.withAlpha(60)
                              : AppColors.success.withAlpha(60),
                        ),
                      ),
                      child: Text(
                        isOverdue ? (isFr ? 'En retard' : 'Overdue') : (isFr ? 'Actif' : 'Active'),
                        style: TextStyle(
                          color: isOverdue ? AppColors.error : AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Info chips ──
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(
                      Icons.calendar_today,
                      dueDateStr,
                      isOverdue ? AppColors.error : AppColors.primary,
                    ),
                    _buildInfoChip(
                      Icons.stars_outlined,
                      '$maxPoints pts',
                      AppColors.warning,
                    ),
                    _buildInfoChip(
                      Icons.people_outline,
                      '$submissionCount submissions',
                      Colors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Action buttons ──
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () => _openSubmissionsView(assignment),
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: Text(isFr ? 'Soumissions' : 'Submissions',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.info,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        onPressed: () => _openEditSheet(assignment),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label:
                            Text(isFr ? 'Modifier' : 'Edit', style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 36,
                      width: 36,
                      child: IconButton(
                        onPressed: () =>
                            _deleteAssignment(assignment['_id']),
                        padding: EdgeInsets.zero,
                        icon: Container(
                          decoration: BoxDecoration(
                            color: AppColors.error.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                            size: 16,
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
      ),
    );
  }

  // ── Info chip widget ──────────────────────────────────────────────
  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────
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
                color: AppColors.primary.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _selectedCourseId != null
                  ? (isFr ? 'Aucun devoir pour ce cours' : 'No Assignments for this Course')
                  : (isFr ? 'Aucun devoir' : 'No Assignments Yet'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedCourseId != null
                  ? (isFr ? 'Ce cours n\'a pas encore de devoirs.' : 'This course doesn\'t have any assignments yet.')
                  : (isFr ? 'Créez des devoirs pour vos cours !' : 'Create assignments for your courses to get started!'),
              style: const TextStyle(fontSize: 14, color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper: Input label ───────────────────────────────────────────
  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: AppColors.textDark,
      ),
    );
  }

  // ── Helper: Text field ────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// ASSIGNMENT SUBMISSIONS PAGE
// ═════════════════════════════════════════════════════════════════════

class _AssignmentSubmissionsPage extends StatefulWidget {
  final String assignmentId;
  final String assignmentTitle;

  const _AssignmentSubmissionsPage({
    required this.assignmentId,
    required this.assignmentTitle,
  });

  @override
  State<_AssignmentSubmissionsPage> createState() =>
      _AssignmentSubmissionsPageState();
}

class _AssignmentSubmissionsPageState
    extends State<_AssignmentSubmissionsPage> {
  List<dynamic> _submissions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSubmissions();
  }

  Future<void> _fetchSubmissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/courses/assignments/${widget.assignmentId}/submissions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _submissions = data['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load submissions';
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

  // ── Grade submission ──────────────────────────────────────────────
  Future<void> _gradeSubmission(
      String submissionId, int grade, String feedback) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/courses/assignments/submissions/$submissionId/grade'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'grade': grade,
          'feedback': feedback,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Submission graded successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        _fetchSubmissions();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to grade submission'),
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

  // ── Open grading sheet ────────────────────────────────────────────
  void _openGradingSheet(Map<String, dynamic> submission) {
    final gradeController = TextEditingController(
      text: submission['grade']?.toString() ?? '',
    );
    final feedbackController = TextEditingController(
      text: submission['feedback'] ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
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
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppColors.successGradient,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.grading,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Grade Submission',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            submission['studentName'] ?? 'Student',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Student's answer / file
                if (submission['content'] != null &&
                    submission['content'].toString().isNotEmpty) ...[
                  const Text(
                    'Student\'s Answer',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      submission['content'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textDark,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Grade field
                const Text(
                  'Grade',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: gradeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter grade',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.stars_outlined,
                        color: AppColors.warning, size: 20),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Feedback field
                const Text(
                  'Feedback',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: feedbackController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Write feedback for the student...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 48),
                      child: Icon(Icons.comment_outlined,
                          color: AppColors.primary, size: 20),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final grade =
                              int.tryParse(gradeController.text) ?? 0;
                          final feedback = feedbackController.text;
                          Navigator.pop(context);
                          _gradeSubmission(
                              submission['_id'], grade, feedback);
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text(
                          'Submit Grade',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.assignmentTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _fetchSubmissions,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : _submissions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'No Submissions Yet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Students haven\'t submitted their work yet.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _fetchSubmissions,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _submissions.length,
                        itemBuilder: (context, index) {
                          return _buildSubmissionCard(_submissions[index]);
                        },
                      ),
                    ),
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic> submission) {
    final isGraded = submission['grade'] != null;
    final submittedAt = submission['submittedAt'] != null
        ? DateFormat('MMM d, yyyy – h:mm a')
            .format(DateTime.parse(submission['submittedAt']))
        : 'Unknown date';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGraded
              ? AppColors.success.withAlpha(60)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openGradingSheet(submission),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Student avatar
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primary.withAlpha(25),
                      child: Text(
                        (submission['studentName'] ?? 'S')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            submission['studentName'] ?? 'Student',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            submittedAt,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isGraded
                            ? AppColors.success.withAlpha(25)
                            : AppColors.warning.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isGraded
                              ? AppColors.success.withAlpha(60)
                              : AppColors.warning.withAlpha(60),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isGraded
                                ? Icons.check_circle
                                : Icons.hourglass_empty,
                            size: 14,
                            color: isGraded
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isGraded
                                ? '${submission['grade']} pts'
                                : 'Pending',
                            style: TextStyle(
                              color: isGraded
                                  ? AppColors.success
                                  : AppColors.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Content preview
                if (submission['content'] != null &&
                    submission['content'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      submission['content'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textDark,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                // File attachment indicator
                if (submission['fileUrl'] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.attach_file, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        'File attached',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],

                // Feedback preview
                if (submission['feedback'] != null &&
                    submission['feedback'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.comment_outlined,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          submission['feedback'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                // Grade button
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () => _openGradingSheet(submission),
                    icon: Icon(
                      isGraded ? Icons.edit_outlined : Icons.grading,
                      size: 16,
                    ),
                    label: Text(
                      isGraded ? 'Update Grade' : 'Grade Now',
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isGraded ? AppColors.primary : AppColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
