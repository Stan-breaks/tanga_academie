import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

class StudentQuizPage extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final Map<String, dynamic> chapter;
  final String courseId;
  final VoidCallback? onCompleted;

  const StudentQuizPage({
    super.key,
    required this.lesson,
    required this.chapter,
    required this.courseId,
    this.onCompleted,
  });

  @override
  State<StudentQuizPage> createState() => _StudentQuizPageState();
}

class _StudentQuizPageState extends State<StudentQuizPage> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _attemptAllowed = true;
  bool _showResults = false;
  List<Map<String, dynamic>> _questions = [];
  List<int?> _selectedAnswers = [];
  Map<String, dynamic>? _result;

  String get _lessonId =>
      widget.lesson['_id']?.toString() ??
      widget.lesson['id']?.toString() ??
      '';

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    final token = await getToken();

    // Check if attempt allowed
    try {
      final res = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/quiz-progress/attempt-allowed/${widget.courseId}/$_lessonId',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _attemptAllowed =
            data['allowed'] ?? data['attemptAllowed'] ?? true;
      }
    } catch (_) {}

    // Quiz questions are embedded in lesson data
    final quizData = widget.lesson['quiz'];
    if (quizData != null && quizData['questions'] != null) {
      final questions =
          (quizData['questions'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _questions = questions;
        _selectedAnswers = List.filled(questions.length, null);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitQuiz() async {
    if (_selectedAnswers.any((a) => a == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFr
                ? 'Répondez à toutes les questions'
                : 'Answer all questions first',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final token = await getToken();

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/quiz-progress/submit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'answers': _selectedAnswers,
          'courseId': widget.courseId,
          'chapterId': _lessonId,
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        setState(() {
          _result = data['data'] ?? data;
          _showResults = true;
          _isSubmitting = false;
        });
        widget.onCompleted?.call();
      } else {
        setState(() => _isSubmitting = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFr ? 'Erreur lors de la soumission' : 'Submission failed',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          isFr ? 'Quiz' : 'Quiz',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : _showResults
              ? _buildResults()
              : !_attemptAllowed
                  ? _buildNoAttemptScreen()
                  : _questions.isEmpty
                      ? _buildNoQuizScreen()
                      : _buildQuizContent(),
    );
  }

  Widget _buildQuizContent() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _questions.length,
            itemBuilder: (context, i) => _buildQuestionCard(i),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 8,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitQuiz,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isFr ? 'Soumettre le quiz' : 'Submit Quiz',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(int index) {
    final q = _questions[index];
    final options = (q['options'] as List?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  q['question'] ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...options.asMap().entries.map((entry) {
            final isSelected = _selectedAnswers[index] == entry.key;
            return GestureDetector(
              onTap: () =>
                  setState(() => _selectedAnswers[index] = entry.key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blueAccent.withAlpha(25)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Colors.blueAccent
                        : Colors.grey.shade200,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? Colors.blueAccent
                          : Colors.grey.shade400,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected
                              ? Colors.blueAccent
                              : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final score =
        _result?['score'] ?? _result?['percentage'] ?? 0;
    final passed = _result?['passed'] ?? (score >= 70);
    final correct =
        _result?['correct'] ?? _result?['correctAnswers'];
    final total = _questions.length;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: passed
                    ? Colors.green.withAlpha(25)
                    : Colors.red.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                passed
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
                size: 60,
                color: passed ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              passed
                  ? (isFr ? 'Félicitations !' : 'Congratulations!')
                  : (isFr ? 'Essayez encore' : 'Try Again'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: passed ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$score%',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: passed ? Colors.green : Colors.orange,
              ),
            ),
            if (correct != null) ...[
              const SizedBox(height: 8),
              Text(
                '${isFr ? 'Réponses correctes' : 'Correct answers'}: $correct/$total',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isFr ? 'Retour à la leçon' : 'Back to Lesson',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAttemptScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_clock, size: 72, color: Colors.orange.shade400),
            const SizedBox(height: 24),
            Text(
              isFr
                  ? 'Tentative non autorisée'
                  : 'No More Attempts Allowed',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isFr
                  ? 'Vous avez épuisé vos tentatives pour ce quiz.'
                  : 'You have used all your attempts for this quiz.',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(isFr ? 'Retour' : 'Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoQuizScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.quiz_outlined, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 24),
          Text(
            isFr ? 'Aucun quiz disponible' : 'No Quiz Available',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFr
                ? 'Ce cours n\'a pas encore de quiz.'
                : 'This lesson has no quiz yet.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(isFr ? 'Retour' : 'Go Back'),
          ),
        ],
      ),
    );
  }
}
