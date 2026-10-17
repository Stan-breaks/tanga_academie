import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:tanga_acadamie/core/utils/app_snackbar.dart';

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
  String? _restrictionReason;
  Map<String, dynamic> _restrictions = {};
  bool _showResults = false;
  bool _requestingApproval = false;
  List<Map<String, dynamic>> _questions = [];
  List<int?> _selectedAnswers = [];
  Map<String, dynamic>? _result;

  String get _lessonId =>
      widget.lesson['_id']?.toString() ??
      widget.lesson['id']?.toString() ??
      '';

  String get _chapterId =>
      widget.chapter['_id']?.toString() ??
      widget.chapter['id']?.toString() ??
      '';

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  // Ask the backend whether a new attempt is allowed. The endpoint is
  // chapter-keyed, so we must send the chapter id (not the lesson id).
  Future<Map<String, dynamic>> _fetchRestrictions() async {
    final token = await getToken();
    final result = <String, dynamic>{
      'allowed': true,
      'reason': null,
      'restrictions': <String, dynamic>{},
    };
    try {
      final res = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/quiz-progress/attempt-allowed/${widget.courseId}/$_chapterId',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final inner = data['data'] is Map
            ? Map<String, dynamic>.from(data['data'])
            : <String, dynamic>{};
        result['allowed'] = inner['allowed'] ?? data['allowed'] ?? true;
        result['reason'] = inner['reason'] ?? data['reason'];
        result['restrictions'] = inner['restrictions'] is Map
            ? Map<String, dynamic>.from(inner['restrictions'])
            : <String, dynamic>{};
      }
    } catch (_) {}
    return result;
  }

  Future<Map<String, dynamic>?> _fetchStatus() async {
    final token = await getToken();
    try {
      final res = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/quiz-progress/status/${widget.courseId}/$_chapterId',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final d = data['data'] is Map
            ? Map<String, dynamic>.from(data['data'])
            : <String, dynamic>{};
        final attempts = (d['attempts'] ?? 0) as num;
        if (attempts > 0) {
          return {
            'score': d['bestScore'] ?? d['score'] ?? 0,
            'passed': d['passed'] ?? false,
            'attempts': attempts,
          };
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadQuiz() async {
    // Quiz questions are embedded in the lesson under `quiz.questions`
    final quizData = widget.lesson['quiz'];
    final rawQuestions = quizData is Map ? quizData['questions'] : null;
    final questions = rawQuestions is List
        ? rawQuestions
              .whereType<Map>()
              .map((q) => Map<String, dynamic>.from(q))
              .toList()
        : <Map<String, dynamic>>[];

    final restrictions = await _fetchRestrictions();
    final attemptAllowed = restrictions['allowed'] == true;
    final priorResult = attemptAllowed ? await _fetchStatus() : null;

    if (!mounted) return;

    setState(() {
      _attemptAllowed = attemptAllowed;
      _restrictionReason = restrictions['reason'] as String?;
      _restrictions = Map<String, dynamic>.from(
        restrictions['restrictions'] ?? {},
      );
      _questions = questions;
      _selectedAnswers = List.filled(questions.length, null);
      if (priorResult != null) {
        _result = priorResult;
        _showResults = true;
      }
      _isLoading = false;
    });
  }

  Future<void> _retakeQuiz() async {
    final restrictions = await _fetchRestrictions();
    if (!mounted) return;

    if (restrictions['allowed'] == true) {
      setState(() {
        _result = null;
        _showResults = false;
        _attemptAllowed = true;
        _restrictionReason = null;
        _restrictions = {};
        _selectedAnswers = List.filled(_questions.length, null);
      });
    } else {
      setState(() {
        _showResults = false;
        _attemptAllowed = false;
        _restrictionReason = restrictions['reason'] as String?;
        _restrictions = Map<String, dynamic>.from(
          restrictions['restrictions'] ?? {},
        );
      });
    }
  }

  Future<void> _requestApproval() async {
    setState(() => _requestingApproval = true);
    final token = await getToken();
    try {
      final res = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/quiz-progress/request-instructor-approval',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'courseId': widget.courseId,
          'chapterId': _chapterId,
        }),
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        AppSnackBar.showSuccess(
          context,
          isFr
              ? 'Demande envoyée à votre instructeur'
              : 'Request sent to your instructor',
        );
        // Refresh so the "pending" state is reflected.
        final restrictions = await _fetchRestrictions();
        if (!mounted) return;
        setState(() {
          _restrictions = Map<String, dynamic>.from(
            restrictions['restrictions'] ?? {},
          );
        });
      } else {
        AppSnackBar.showError(
          context,
          isFr
              ? 'Échec de l\'envoi de la demande'
              : 'Failed to send request',
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        isFr ? 'Une erreur est survenue' : 'An error occurred',
      );
    } finally {
      if (mounted) setState(() => _requestingApproval = false);
    }
  }

  Future<void> _submitQuiz() async {
    if (_questions.isEmpty) return;
    if (_selectedAnswers.any((a) => a == null)) {
      AppSnackBar.showError(
        context,
        isFr ? 'Répondez à toutes les questions' : 'Answer all questions first',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final token = await getToken();

    // The backend grades server-side and expects the selected option strings.
    final answers = _selectedAnswers.asMap().entries.map((entry) {
      final options = (_questions[entry.key]['options'] as List?) ?? [];
      final index = entry.value;
      if (index != null && index >= 0 && index < options.length) {
        return options[index].toString();
      }
      return '';
    }).toList();

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/quiz-progress/submit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'courseId': widget.courseId,
          'chapterId': _chapterId,
          'lessonId': _lessonId,
          'answers': answers,
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        setState(() {
          _result = data['data'] ?? data;
          _showResults = true;
          _isSubmitting = false;
        });
        widget.onCompleted?.call();
      } else if (res.statusCode == 403) {
        // The server rejected the attempt due to a restriction (e.g. the last
        // attempt unlocked a cooldown or an instructor-approval gate).
        String? reason;
        try {
          reason = (jsonDecode(res.body) as Map)['reason']?.toString();
        } catch (_) {}
        setState(() => _isSubmitting = false);
        AppSnackBar.showError(
          context,
          reason == 'instructor_approval'
              ? (isFr
                  ? 'Approbation de l\'instructeur requise'
                  : 'Instructor approval required')
              : reason == 'time_restriction'
                  ? (isFr
                      ? 'Veuillez patienter avant de réessayer'
                      : 'Please wait before retrying')
                  : (isFr
                      ? 'Tentative non autorisée'
                      : 'Attempt not allowed'),
        );
        final restrictions = await _fetchRestrictions();
        if (!mounted) return;
        setState(() {
          _showResults = false;
          _attemptAllowed = restrictions['allowed'] == true;
          _restrictionReason = restrictions['reason'] as String?;
          _restrictions = Map<String, dynamic>.from(
            restrictions['restrictions'] ?? {},
          );
        });
      } else {
        setState(() => _isSubmitting = false);
        AppSnackBar.showError(
          context,
          isFr ? 'Erreur lors de la soumission' : 'Submission failed',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppSnackBar.showError(
        context,
        isFr ? 'Une erreur est survenue' : 'An error occurred',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Quiz',
          style: TextStyle(fontWeight: FontWeight.w600),
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
                  ? _buildRestrictionScreen()
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
    final score = _result?['score'] ?? _result?['percentage'] ?? 0;
    final passed = _result?['passed'] ?? (score >= 60);
    final correct = _result?['correct'] ?? _result?['correctAnswers'];
    final total = _questions.length;

    return Center(
      child: SingleChildScrollView(
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
            const SizedBox(height: 8),
            Text(
              passed
                  ? (isFr
                      ? 'Vous pouvez passer au chapitre suivant.'
                      : 'You can now proceed to the next chapter.')
                  : (isFr
                      ? 'Vous devez obtenir 60 % pour réussir.'
                      : 'You need 60% to pass.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            if (!passed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _retakeQuiz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isFr ? 'Repasser le quiz' : 'Retake Quiz',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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

  // ── Restriction screens ────────────────────────────────────────────
  Widget _buildRestrictionScreen() {
    final reason = _restrictionReason;
    final attempts = _restrictions['totalAttempts'];

    if (reason == 'time_restriction') {
      final hours = _restrictions['timeRemaining'];
      return _buildInfoScreen(
        icon: Icons.lock_clock,
        color: Colors.orange,
        title: isFr
            ? 'Quiz temporairement verrouillé'
            : 'Quiz temporarily locked',
        subtitle: isFr
            ? 'Vous devez attendre $hours heure(s) avant votre prochaine tentative.'
            : 'You must wait $hours hour(s) before your next attempt.',
        footer: attempts != null
            ? (isFr ? 'Tentatives : $attempts' : 'Attempts: $attempts')
            : null,
      );
    }

    if (reason == 'video_rewatch') {
      return _buildInfoScreen(
        icon: Icons.replay_circle_filled,
        color: Colors.blue,
        title: isFr ? 'Re-visionnage requis' : 'Video re-watch required',
        subtitle: isFr
            ? 'Vous devez revoir entièrement la vidéo du chapitre avant votre prochaine tentative.'
            : 'You must re-watch the chapter video before your next attempt.',
        footer: attempts != null
            ? (isFr ? 'Tentatives : $attempts' : 'Attempts: $attempts')
            : null,
      );
    }

    if (reason == 'instructor_approval' || reason == null) {
      final requested = _restrictions['instructorApprovalRequestedAt'] != null;
      return _buildInfoScreen(
        icon: Icons.school,
        color: Colors.red,
        title: isFr
            ? 'Approbation de l\'instructeur requise'
            : 'Instructor approval required',
        subtitle: isFr
            ? 'Vous avez atteint le nombre maximum de tentatives. Demandez l\'autorisation à votre instructeur pour continuer.'
            : 'You have reached the maximum number of attempts. Request permission from your instructor to continue.',
        footer: attempts != null
            ? (isFr ? 'Tentatives : $attempts' : 'Attempts: $attempts')
            : null,
        extra: requested
            ? Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  isFr
                      ? 'Demande envoyée - en attente d\'approbation'
                      : 'Request sent - awaiting approval',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(top: 20),
                child: ElevatedButton(
                  onPressed: _requestingApproval ? null : _requestApproval,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _requestingApproval
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(isFr
                          ? 'Demander l\'approbation'
                          : 'Request Approval'),
                ),
              ),
      );
    }

    return _buildInfoScreen(
      icon: Icons.lock_outline,
      color: Colors.red,
      title: isFr ? 'Tentative non autorisée' : 'Attempt not allowed',
      subtitle: isFr
          ? 'Vous ne pouvez pas repasser ce quiz pour le moment.'
          : 'You cannot retake this quiz right now.',
    );
  }

  Widget _buildInfoScreen({
    required IconData icon,
    required String title,
    required String subtitle,
    Color color = Colors.grey,
    String? footer,
    Widget? extra,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            if (footer != null) ...[
              const SizedBox(height: 12),
              Text(
                footer,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            ?extra,
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isFr ? 'Retour' : 'Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoQuizScreen() => _buildInfoScreen(
        icon: Icons.quiz_outlined,
        title: isFr ? 'Aucun quiz disponible' : 'No Quiz Available',
        subtitle: isFr
            ? 'Ce cours n\'a pas encore de quiz.'
            : 'This lesson has no quiz yet.',
      );
}
