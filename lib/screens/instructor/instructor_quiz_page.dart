import 'package:flutter/material.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class InstructorQuizPage extends StatefulWidget {
  const InstructorQuizPage({super.key});

  @override
  State<InstructorQuizPage> createState() => _InstructorQuizPageState();
}

class _InstructorQuizPageState extends State<InstructorQuizPage>
    with SingleTickerProviderStateMixin {
  // ── Filter state ──────────────────────────────────────────────────
  List<dynamic> _courses = [];
  bool _isLoadingCourses = true;
  String? _selectedCourseId;
  String? _selectedLessonId;

  // Course detail (chapters + lessons)
  Map<String, dynamic>? _courseDetail;
  bool _isLoadingCourseDetail = false;

  // ── Quiz state ────────────────────────────────────────────────────
  List<_QuizQuestion> _questions = [];
  bool _isLoadingQuiz = false;
  bool _isSaving = false;
  bool _existingQuiz = false;

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

  // ═══════════════════════════════════════════════════════════════════
  // DATA FETCHING
  // ═══════════════════════════════════════════════════════════════════

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
          _isLoadingCourses = false;
        });
      } else {
        setState(() => _isLoadingCourses = false);
      }
    } catch (e) {
      setState(() => _isLoadingCourses = false);
    }
  }

  Future<void> _fetchCourseDetail(String courseId) async {
    setState(() {
      _isLoadingCourseDetail = true;
      _courseDetail = null;
      _selectedLessonId = null;
      _questions = [];
      _existingQuiz = false;
    });

    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/courses/$courseId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _courseDetail = data['data'] ?? data;
          _isLoadingCourseDetail = false;
        });
      } else {
        setState(() => _isLoadingCourseDetail = false);
      }
    } catch (e) {
      setState(() => _isLoadingCourseDetail = false);
    }
  }

  Future<void> _fetchExistingQuiz(String lessonId) async {
    setState(() {
      _isLoadingQuiz = true;
      _questions = [];
      _existingQuiz = false;
    });

    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/courses/$_selectedCourseId/lessons/$lessonId/quiz'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final quizData = data['data'];

        if (quizData != null && quizData['questions'] != null) {
          final questions = quizData['questions'] as List;
          setState(() {
            _existingQuiz = questions.isNotEmpty;
            _questions = questions.map((q) {
              final options = (q['options'] as List?)
                      ?.map((o) => o.toString())
                      .toList() ??
                  ['', '', '', ''];
              return _QuizQuestion(
                question: q['question'] ?? '',
                options: options,
                correctAnswer: q['correctAnswer'] ?? 0,
              );
            }).toList();
          });
        }
      }
      // If 404 or no quiz, we start fresh — that's fine
    } catch (e) {
      // Start fresh
    }

    setState(() => _isLoadingQuiz = false);

    if (_questions.isEmpty) {
      _addQuestion();
    }

    _animController.forward(from: 0);
  }

  // ═══════════════════════════════════════════════════════════════════
  // QUIZ CRUD
  // ═══════════════════════════════════════════════════════════════════

  void _addQuestion() {
    setState(() {
      _questions.add(_QuizQuestion(
        question: '',
        options: ['', '', '', ''],
        correctAnswer: 0,
      ));
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFr ? 'Un quiz doit avoir au moins une question' : 'A quiz must have at least one question'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    setState(() {
      _questions.removeAt(index);
    });
  }

  Future<void> _saveQuiz() async {
    // Validate
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.question.trim().isEmpty) {
        _showError('Question ${i + 1} is empty');
        return;
      }
      bool hasEmptyOption = false;
      for (final opt in q.options) {
        if (opt.trim().isEmpty) {
          hasEmptyOption = true;
          break;
        }
      }
      if (hasEmptyOption) {
        _showError('Question ${i + 1} has empty options');
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final token = await getToken();
      final questionsPayload = _questions.map((q) {
        return {
          'question': q.question,
          'options': q.options,
          'correctAnswer': q.correctAnswer,
        };
      }).toList();

      final method = _existingQuiz ? 'PUT' : 'POST';
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}/api/courses/$_selectedCourseId/lessons/$_selectedLessonId/quiz');

      http.Response response;
      if (method == 'PUT') {
        response = await http.put(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'questions': questionsPayload}),
        );
      } else {
        response = await http.post(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'questions': questionsPayload}),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() => _existingQuiz = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  _existingQuiz ? (isFr ? 'Quiz mis à jour avec succès' : 'Quiz updated successfully') : (isFr ? 'Quiz créé avec succès' : 'Quiz created successfully')),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        _showError('Failed to save quiz');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    }

    setState(() => _isSaving = false);
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPER: Get all lessons flat from course
  // ═══════════════════════════════════════════════════════════════════

  List<Map<String, dynamic>> _getAllLessons() {
    if (_courseDetail == null) return [];
    final chapters = _courseDetail!['chapters'] as List<dynamic>? ?? [];
    final List<Map<String, dynamic>> allLessons = [];

    for (final chapter in chapters) {
      final chapterTitle = chapter['title'] ?? 'Chapter';
      final lessons = chapter['lessons'] as List<dynamic>? ?? [];
      for (final lesson in lessons) {
        allLessons.add({
          ...Map<String, dynamic>.from(lesson),
          '_chapterTitle': chapterTitle,
        });
      }
    }
    return allLessons;
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
          isFr ? 'Créer un quiz' : 'Create Quiz',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      body: _isLoadingCourses
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    isFr ? 'Chargement des cours...' : 'Loading courses...',
                    style: TextStyle(color: AppColors.textLight),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                _buildCourseSelector(),
                _buildLessonSelector(),
                if (_selectedCourseId != null &&
                    _selectedLessonId != null)
                  _buildQuizBuilderHeader(),
                Expanded(child: _buildQuizContent()),
              ],
            ),
    );
  }

  // ── Course selector ───────────────────────────────────────────────
  Widget _buildCourseSelector() {
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
            child: const Icon(Icons.book_outlined,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCourseId,
                hint: Text(
                  isFr ? 'Sélectionner un cours' : 'Select a Course',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: AppColors.primary),
                isExpanded: true,
                items: _courses.map<DropdownMenuItem<String>>((course) {
                  return DropdownMenuItem<String>(
                    value: course['_id'],
                    child: Text(
                      course['title'] ?? 'Untitled',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCourseId = value;
                    _selectedLessonId = null;
                    _questions = [];
                    _existingQuiz = false;
                  });
                  if (value != null) {
                    _fetchCourseDetail(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Lesson selector ───────────────────────────────────────────────
  Widget _buildLessonSelector() {
    if (_selectedCourseId == null) return const SizedBox.shrink();

    if (_isLoadingCourseDetail) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2),
          ),
        ),
      );
    }

    final allLessons = _getAllLessons();

    if (allLessons.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withAlpha(15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withAlpha(60)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.warning, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                isFr ? 'Ce cours n\'a pas encore de leçons. Ajoutez-en d\'abord.' : 'This course has no lessons yet. Add lessons first.',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

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
            child: const Icon(Icons.article_outlined,
                color: Colors.teal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLessonId,
                hint: Text(
                  isFr ? 'Sélectionner une leçon' : 'Select a Lesson',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: Colors.teal),
                isExpanded: true,
                items: allLessons.map<DropdownMenuItem<String>>((lesson) {
                  return DropdownMenuItem<String>(
                    value: lesson['_id'],
                    child: Text(
                      '${lesson['_chapterTitle']} › ${lesson['title'] ?? 'Untitled'}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedLessonId = value);
                  if (value != null) {
                    _fetchExistingQuiz(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quiz builder header ───────────────────────────────────────────
  Widget _buildQuizBuilderHeader() {
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
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: AppColors.primaryGradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _existingQuiz ? Icons.edit_note : Icons.quiz_outlined,
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
                  _existingQuiz ? (isFr ? 'Modifier le quiz' : 'Edit Quiz') : (isFr ? 'Créer un quiz' : 'Create Quiz'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  '${_questions.length} question${_questions.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          // Add question button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _addQuestion,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.success.withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline,
                        color: AppColors.success, size: 18),
                    SizedBox(width: 4),
                    Text(
                      isFr ? 'Ajouter' : 'Add',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quiz content area ─────────────────────────────────────────────
  Widget _buildQuizContent() {
    // No course selected
    if (_selectedCourseId == null) {
      return _buildPlaceholder(
        icon: Icons.school_outlined,
        title: isFr ? 'Sélectionnez un cours' : 'Select a Course',
        subtitle: isFr ? 'Choisissez un cours dans le menu ci-dessus pour commencer.' : 'Choose a course from the dropdown above to get started.',
      );
    }

    // Course selected but no lesson
    if (_selectedLessonId == null) {
      if (_isLoadingCourseDetail) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }
      return _buildPlaceholder(
        icon: Icons.article_outlined,
        title: isFr ? 'Sélectionnez une leçon' : 'Select a Lesson',
        subtitle: isFr ? 'Choisissez une leçon pour créer ou modifier son quiz.' : 'Choose a lesson to create or edit its quiz.',
      );
    }

    // Loading quiz
    if (_isLoadingQuiz) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(isFr ? 'Chargement du quiz...' : 'Loading quiz...', style: const TextStyle(color: AppColors.textLight)),
          ],
        ),
      );
    }

    // Quiz builder
    if (_questions.isEmpty) {
      return _buildPlaceholder(
        icon: Icons.quiz_outlined,
        title: isFr ? 'Aucune question' : 'No Questions',
        subtitle: isFr ? 'Appuyez sur le bouton ajouter ci-dessus pour créer votre première question.' : 'Tap the add button above to create your first question.',
      );
    }

    return Column(
      children: [
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                return _buildQuestionCard(index);
              },
            ),
          ),
        ),
        _buildSaveBar(),
      ],
    );
  }

  // ── Placeholder widget ────────────────────────────────────────────
  Widget _buildPlaceholder({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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
              child: Icon(icon, size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Single question card ──────────────────────────────────────────
  Widget _buildQuestionCard(int index) {
    final question = _questions[index];

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Question header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withAlpha(10),
                  AppColors.primaryLight.withAlpha(10),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient:
                        LinearGradient(colors: AppColors.primaryGradient),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isFr ? 'Question ${index + 1}' : 'Question ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                ),
                const Spacer(),
                // Delete question button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _removeQuestion(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: AppColors.error, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Question text field ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextFormField(
              initialValue: question.question,
              onChanged: (value) {
                question.question = value;
              },
              decoration: InputDecoration(
                hintText: isFr ? 'Tapez votre question ici...' : 'Type your question here...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.help_outline,
                    color: AppColors.primary, size: 20),
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
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Options ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFr ? 'Options' : 'Options',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(question.options.length, (optIndex) {
                  final isCorrect = question.correctAnswer == optIndex;
                  final labels = ['A', 'B', 'C', 'D'];
                  final label =
                      optIndex < labels.length ? labels[optIndex] : '${optIndex + 1}';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        // Radio-style correct answer selector
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              question.correctAnswer = optIndex;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isCorrect
                                  ? AppColors.success
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isCorrect
                                    ? AppColors.success
                                    : Colors.grey.shade300,
                                width: isCorrect ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: isCorrect
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 18)
                                  : Text(
                                      label,
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Option text field
                        Expanded(
                          child: TextFormField(
                            initialValue: question.options[optIndex],
                            onChanged: (value) {
                              question.options[optIndex] = value;
                            },
                            decoration: InputDecoration(
                              hintText: 'Option $label',
                              hintStyle:
                                  TextStyle(color: Colors.grey.shade400),
                              filled: true,
                              fillColor: isCorrect
                                  ? AppColors.success.withAlpha(10)
                                  : AppColors.surfaceLight,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: isCorrect
                                      ? AppColors.success.withAlpha(80)
                                      : Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: isCorrect
                                      ? AppColors.success.withAlpha(80)
                                      : Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: isCorrect
                                      ? AppColors.success
                                      : AppColors.primary,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          // ── Correct answer hint ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Text(
                  isFr ? 'Appuyez sur la lettre pour marquer la bonne réponse' : 'Tap the letter to mark the correct answer',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Save bar ──────────────────────────────────────────────────────
  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addQuestion,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: Text(isFr ? 'Ajouter une question' : 'Add Question'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveQuiz,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(
                  _isSaving
                      ? (isFr ? 'Enregistrement...' : 'Saving...')
                      : _existingQuiz
                          ? (isFr ? 'Mettre à jour le quiz' : 'Update Quiz')
                          : (isFr ? 'Enregistrer le quiz' : 'Save Quiz'),
                  style: const TextStyle(
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
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// QUIZ QUESTION MODEL
// ═════════════════════════════════════════════════════════════════════

class _QuizQuestion {
  String question;
  List<String> options;
  int correctAnswer;

  _QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
  });
}
