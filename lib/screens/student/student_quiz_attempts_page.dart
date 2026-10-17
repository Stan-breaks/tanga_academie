import 'package:flutter/material.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';

class StudentQuizAttemptsPage extends StatefulWidget {
  const StudentQuizAttemptsPage({super.key});

  @override
  State<StudentQuizAttemptsPage> createState() =>
      _StudentQuizAttemptsPageState();
}

class _StudentQuizAttemptsPageState extends State<StudentQuizAttemptsPage> {
  List<dynamic> _attempts = [];
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await getToken();
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final results = await Future.wait([
        http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/quizes/attempts-all'),
          headers: headers,
        ),
        http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/quizes/summary'),
          headers: headers,
        ),
      ]);

      final attemptsRes = results[0];
      final summaryRes = results[1];

      if (attemptsRes.statusCode == 200) {
        final data = json.decode(attemptsRes.body);
        _attempts = data['data'] ?? [];
      } else {
        throw Exception(
          isFr
              ? 'Échec du chargement des tentatives'
              : 'Failed to load quiz attempts',
        );
      }

      if (summaryRes.statusCode == 200) {
        final data = json.decode(summaryRes.body);
        _summary = data['data'] is Map
            ? Map<String, dynamic>.from(data['data'])
            : null;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(dynamic dateString) {
    if (dateString == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateString.toString());
      return DateFormat('MMM d, yyyy – h:mm a').format(dt);
    } catch (_) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isFr ? 'Mes tentatives de quiz' : 'My Quiz Attempts',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _fetchData,
            icon: const Icon(Icons.refresh),
            tooltip: isFr ? 'Actualiser' : 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _fetchData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      _buildSummarySection(),
                      const SizedBox(height: 16),
                      if (_attempts.isEmpty)
                        _buildEmptyState()
                      else
                        ..._attempts.map((a) => _buildAttemptCard(
                              Map<String, dynamic>.from(a),
                            )),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchData,
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

  Widget _buildSummarySection() {
    if (_summary == null) return const SizedBox.shrink();

    final totalQuizzes = _summary!['totalQuizzes'] ?? 0;
    final passedQuizzes = _summary!['passedQuizzes'] ?? 0;
    final failedQuizzes = _summary!['failedQuizzes'] ?? 0;
    final averageScore = _summary!['averageScore'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.primaryGradient),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(50),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFr ? 'Résumé des quiz' : 'Quiz Summary',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildSummaryStat(
                isFr ? 'Quiz' : 'Quizzes',
                '$totalQuizzes',
                Icons.quiz_outlined,
              ),
              _buildSummaryStat(
                isFr ? 'Réussis' : 'Passed',
                '$passedQuizzes',
                Icons.check_circle_outline,
              ),
              _buildSummaryStat(
                isFr ? 'Échoués' : 'Failed',
                '$failedQuizzes',
                Icons.cancel_outlined,
              ),
              _buildSummaryStat(
                isFr ? 'Moyenne' : 'Average',
                '$averageScore%',
                Icons.insights,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withAlpha(220), size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.quiz_outlined,
                size: 56, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text(
            isFr ? 'Aucune tentative de quiz' : 'No Quiz Attempts',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isFr
                ? 'Vous n\'avez encore tenté aucun quiz. Commencez à apprendre et passez votre premier quiz !'
                : 'You haven\'t attempted any quiz yet. Start learning and take your first quiz!',
            style: const TextStyle(fontSize: 13, color: AppColors.textLight),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAttemptCard(Map<String, dynamic> attempt) {
    final courseName = attempt['courseName']?.toString() ?? '';
    final chapterTitle = attempt['chapterTitle']?.toString() ?? '';
    final score = (attempt['score'] ?? 0).toDouble();
    final passed = attempt['passed'] == true;
    final answers = attempt['answers'] as List?;
    final totalAttempts = attempt['totalAttempts'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: passed
              ? AppColors.success.withAlpha(50)
              : AppColors.error.withAlpha(50),
        ),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: passed
                  ? AppColors.success.withAlpha(20)
                  : AppColors.error.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              passed ? Icons.check_circle : Icons.cancel,
              color: passed ? AppColors.success : AppColors.error,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  chapterTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildMiniChip(
                      Icons.schedule,
                      _formatDate(attempt['attemptedAt']),
                      AppColors.textLight,
                    ),
                    if (totalAttempts != 0)
                      _buildMiniChip(
                        Icons.repeat,
                        isFr
                            ? '$totalAttempts tentatives'
                            : '$totalAttempts attempts',
                        AppColors.primary,
                      ),
                    if (answers != null)
                      _buildMiniChip(
                        Icons.help_outline,
                        '${answers.length} ${isFr ? 'questions' : 'questions'}',
                        AppColors.info,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${score.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: passed ? AppColors.success : AppColors.error,
                ),
              ),
              Text(
                passed ? (isFr ? 'Réussi' : 'Passed') : (isFr ? 'Échoué' : 'Failed'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: passed ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
