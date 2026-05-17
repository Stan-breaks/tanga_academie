import 'package:flutter/material.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';

class InstructorStudentProgressPage extends StatefulWidget {
  const InstructorStudentProgressPage({super.key});

  @override
  State<InstructorStudentProgressPage> createState() =>
      _InstructorStudentProgressPageState();
}

class _InstructorStudentProgressPageState
    extends State<InstructorStudentProgressPage>
    with SingleTickerProviderStateMixin {
  List<dynamic> _allStudents = [];
  List<dynamic> _filteredStudents = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedCourseId;

  // Track which reset buttons are in progress  { "studentId-courseId-chapterId": true }
  final Map<String, bool> _resetting = {};

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
    _fetchStudentProgress();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════
  // DATA
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _fetchStudentProgress() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/instructor-student'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _allStudents = data['data'] ?? [];
          _applyFilter();
          _isLoading = false;
        });
        _animController.forward(from: 0);
      } else {
        setState(() {
          _errorMessage = 'Failed to load student progress';
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

  void _applyFilter() {
    if (_selectedCourseId == null || _selectedCourseId!.isEmpty) {
      _filteredStudents = List.from(_allStudents);
    } else {
      _filteredStudents = _allStudents.where((student) {
        final courses = student['courses'] as List<dynamic>? ?? [];
        return courses.any((c) => c['courseId'] == _selectedCourseId);
      }).toList();
    }
  }

  /// Collect unique courses from all students for the filter dropdown
  Map<String, String> _getUniqueCourses() {
    final Map<String, String> courses = {};
    for (final student in _allStudents) {
      for (final course in (student['courses'] as List<dynamic>? ?? [])) {
        final id = course['courseId']?.toString() ?? '';
        final name = course['courseName']?.toString() ?? 'Untitled';
        if (id.isNotEmpty) courses[id] = name;
      }
    }
    return courses;
  }

  // ── Reset progress ────────────────────────────────────────────────
  Future<void> _handleResetProgress(
    String studentId,
    String courseId, {
    String? chapterId,
  }) async {
    final resetKey = '$studentId-$courseId-${chapterId ?? "all"}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                chapterId != null ? (isFr ? 'Réinitialiser le chapitre ?' : 'Reset Chapter?') : (isFr ? 'Réinitialiser la progression ?' : 'Reset Course Progress?'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          chapterId != null
              ? (isFr ? 'Cela réinitialisera la progression du quiz de l\'étudiant pour ce chapitre. Cette action est irréversible.' : 'This will reset the student\'s quiz progress for this chapter. This cannot be undone.')
              : (isFr ? 'Cela réinitialisera toute la progression du quiz pour cet étudiant dans ce cours. Cette action est irréversible.' : 'This will reset all quiz progress for this student in this course. This cannot be undone.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isFr ? 'Annuler' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: Text(isFr ? 'Réinitialiser' : 'Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _resetting[resetKey] = true);

    try {
      final token = await getToken();
      final payload = <String, dynamic>{
        'studentId': studentId,
        'courseId': courseId,
      };
      if (chapterId != null) payload['chapterId'] = chapterId;

      final response = await http.post(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/quiz-progress/instructor/reset-progress'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(chapterId != null
                  ? (isFr ? 'Progression du chapitre réinitialisée' : 'Chapter progress reset successfully')
                  : (isFr ? 'Progression du cours réinitialisée' : 'Course progress reset successfully')),
              backgroundColor: AppColors.success,
            ),
          );
        }
        await _fetchStudentProgress();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isFr ? 'Échec de la réinitialisation du progrès' : 'Failed to reset progress'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isFr ? 'Erreur : ' : 'Error: '}${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    setState(() => _resetting[resetKey] = false);
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateString);
      return DateFormat('MMM d, yyyy – h:mm a').format(dt);
    } catch (_) {
      return 'N/A';
    }
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
          isFr ? 'Progression des étudiants' : 'Student Progress',
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
                    'Loading student progress...',
                    style: TextStyle(color: AppColors.textLight),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _fetchStudentProgress,
                  child: Column(
                    children: [
                      _buildHeaderBanner(),
                      _buildCourseFilter(),
                      Expanded(child: _buildStudentList()),
                    ],
                  ),
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
            onPressed: _fetchStudentProgress,
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

  // ── Header banner ─────────────────────────────────────────────────
  Widget _buildHeaderBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.teal.shade400, Colors.teal.shade700],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFr ? 'Progression des étudiants' : 'Student Progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isFr ? 'Suivez la progression individuelle et les performances aux quiz' : 'Track individual student progress and quiz performance',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_filteredStudents.length} student${_filteredStudents.length != 1 ? 's' : ''}',
                    style: const TextStyle(
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.people_outline,
                color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  // ── Course filter ─────────────────────────────────────────────────
  Widget _buildCourseFilter() {
    final uniqueCourses = _getUniqueCourses();

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
              color: Colors.teal.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.filter_list,
                color: Colors.teal, size: 20),
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
                    color: Colors.teal),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'All Courses',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  ...uniqueCourses.entries
                      .map<DropdownMenuItem<String>>((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCourseId = value;
                    _applyFilter();
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Student list ──────────────────────────────────────────────────
  Widget _buildStudentList() {
    if (_filteredStudents.isEmpty) {
      return _buildEmptyState();
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _filteredStudents.length,
        itemBuilder: (context, index) {
          return _buildStudentCard(_filteredStudents[index]);
        },
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
                color: Colors.teal.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline,
                  size: 64, color: Colors.teal),
            ),
            const SizedBox(height: 24),
            Text(
              isFr ? 'Aucun étudiant trouvé' : 'No Students Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isFr ? 'Aucun étudiant ne correspond aux filtres actuels.' : 'No students match the current filters.',
              style: TextStyle(fontSize: 14, color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // STUDENT CARD
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final studentName = student['studentName'] ?? 'Student';
    final studentEmail = student['studentEmail'] ?? '';
    final courses = student['courses'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.teal.withAlpha(25),
            child: Text(
              studentName.isNotEmpty
                  ? studentName[0].toUpperCase()
                  : 'S',
              style: const TextStyle(
                color: Colors.teal,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          title: Text(
            studentName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textDark,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (studentEmail.isNotEmpty)
                Text(
                  studentEmail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.teal.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${courses.length} course${courses.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.teal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          children: courses.map<Widget>((course) {
            return _buildCourseProgressSection(student, course);
          }).toList(),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // COURSE PROGRESS SECTION (inside student card)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCourseProgressSection(
      Map<String, dynamic> student, Map<String, dynamic> course) {
    final courseId = course['courseId'] ?? '';
    final courseName = course['courseName'] ?? 'Untitled';
    final overallProgress = (course['overallProgress'] ?? 0).toDouble();
    final quizProgress = course['quizProgress'] as List<dynamic>? ?? [];
    final studentId = student['studentId'] ?? '';
    final resetKey = '$studentId-$courseId-all';
    final isResettingCourse = _resetting[resetKey] == true;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Course header ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient:
                      LinearGradient(colors: AppColors.primaryGradient),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.book_outlined,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courseName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Overall: ${overallProgress.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              // Reset course button
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: isResettingCourse
                      ? null
                      : () => _handleResetProgress(studentId, courseId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  child: isResettingCourse
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(isFr ? 'Réinitialiser le cours' : 'Reset Course'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Progress bar ──
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: overallProgress / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                overallProgress >= 80
                    ? AppColors.success
                    : overallProgress >= 50
                        ? AppColors.warning
                        : AppColors.error,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 14),

          // ── Quiz progress ──
          if (quizProgress.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  isFr ? 'Aucune tentative de quiz' : 'No quiz attempts yet',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...quizProgress.map<Widget>((quiz) {
              return _buildQuizRow(student, course, quiz);
            }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // QUIZ ROW (single chapter quiz progress)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildQuizRow(Map<String, dynamic> student,
      Map<String, dynamic> course, Map<String, dynamic> quiz) {
    final studentId = student['studentId'] ?? '';
    final courseId = course['courseId'] ?? '';
    final chapterId = quiz['chapterId'] ?? '';
    final resetKey = '$studentId-$courseId-$chapterId';
    final isResettingChapter = _resetting[resetKey] == true;

    final attempts = quiz['attemptsCount'] ??
        (quiz['attempts'] as List?)?.length ??
        quiz['totalAttempts'] ??
        0;
    final bestScore = (quiz['bestScore'] ?? 0).toDouble();
    final passed = quiz['passed'] == true;
    final lastAttempt = quiz['lastAttemptAt']?.toString();
    final restriction = quiz['restrictionStatus'] as Map<String, dynamic>? ??
        {};
    final timeRestricted = restriction['timeRestricted'] == true;
    final videoReWatchRequired =
        restriction['videoReWatchRequired'] == true;
    final instructorApprovalRequired =
        restriction['instructorApprovalRequired'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: passed
              ? AppColors.success.withAlpha(50)
              : AppColors.error.withAlpha(50),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Chapter title + status ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: passed
                      ? AppColors.success.withAlpha(20)
                      : AppColors.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  passed ? Icons.check_circle : Icons.cancel,
                  color: passed ? AppColors.success : AppColors.error,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  chapterId.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: passed
                      ? AppColors.success.withAlpha(20)
                      : AppColors.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  passed ? (isFr ? 'Réussi' : 'Passed') : (isFr ? 'Échoué' : 'Failed'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: passed ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Stats chips ──
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildMiniChip(
                Icons.repeat,
                '$attempts attempt${attempts != 1 ? 's' : ''}',
                AppColors.primary,
              ),
              _buildMiniChip(
                Icons.stars_outlined,
                '${bestScore.toStringAsFixed(0)}%',
                bestScore >= 60 ? AppColors.success : AppColors.error,
              ),
              if (lastAttempt != null)
                _buildMiniChip(
                  Icons.schedule,
                  _formatDate(lastAttempt),
                  AppColors.textLight,
                ),
            ],
          ),

          // ── Restriction badges ──
          if (timeRestricted ||
              videoReWatchRequired ||
              instructorApprovalRequired) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (timeRestricted)
                  _buildRestrictionTag(
                      'Time restricted', Icons.timer_off, AppColors.warning),
                if (videoReWatchRequired)
                  _buildRestrictionTag(
                      'Re-watch video', Icons.replay, AppColors.info),
                if (instructorApprovalRequired)
                  _buildRestrictionTag(
                      'Needs approval', Icons.lock, AppColors.error),
              ],
            ),
          ],

          const SizedBox(height: 10),

          // ── Reset chapter button ──
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 30,
              child: ElevatedButton.icon(
                onPressed: isResettingChapter
                    ? null
                    : () => _handleResetProgress(
                          studentId,
                          courseId,
                          chapterId: chapterId,
                        ),
                icon: isResettingChapter
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh, size: 14),
                label: Text(
                  isResettingChapter ? (isFr ? 'Réinitialisation...' : 'Resetting...') : (isFr ? 'Réinitialiser' : 'Reset'),
                  style: const TextStyle(fontSize: 11),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tiny info chip ────────────────────────────────────────────────
  Widget _buildMiniChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Restriction tag ───────────────────────────────────────────────
  Widget _buildRestrictionTag(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
