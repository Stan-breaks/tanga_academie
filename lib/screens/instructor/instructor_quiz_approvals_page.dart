import 'package:flutter/material.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:tanga_acadamie/core/utils/app_snackbar.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';

class InstructorQuizApprovalsPage extends StatefulWidget {
  const InstructorQuizApprovalsPage({super.key});

  @override
  State<InstructorQuizApprovalsPage> createState() =>
      _InstructorQuizApprovalsPageState();
}

class _InstructorQuizApprovalsPageState
    extends State<InstructorQuizApprovalsPage> {
  List<dynamic> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Track which requests are being processed { "userId-courseId-chapterId": true }
  final Map<String, bool> _processing = {};

  @override
  void initState() {
    super.initState();
    _fetchApprovals();
  }

  // ═══════════════════════════════════════════════════════════════════
  // DATA
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _fetchApprovals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/quiz-progress/instructor/approvals'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _requests = data['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = isFr
              ? 'Échec du chargement des demandes d\'approbation'
              : 'Failed to load approval requests';
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

  Future<void> _handleApproval(
    Map<String, dynamic> request,
    String action,
  ) async {
    final userId = request['userId']?.toString() ?? '';
    final courseId = request['courseId']?.toString() ?? '';
    final chapterId = request['chapterId']?.toString() ?? '';
    final key = '$userId-$courseId-$chapterId';

    setState(() => _processing[key] = true);

    try {
      final token = await getToken();
      final path = action == 'approve'
          ? '/api/quiz-progress/grant-instructor-approval'
          : '/api/quiz-progress/deny-instructor-approval';

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'userId': userId,
          'courseId': courseId,
          'chapterId': chapterId,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        AppSnackBar.showSuccess(
          context,
          action == 'approve'
              ? (isFr
                  ? 'Approbation accordée avec succès'
                  : 'Approval granted successfully')
              : (isFr
                  ? 'Approbation refusée'
                  : 'Approval request denied'),
        );
        // Remove the request from the list locally.
        setState(() {
          _requests = _requests.where((r) {
            return !(r['userId']?.toString() == userId &&
                r['courseId']?.toString() == courseId &&
                r['chapterId']?.toString() == chapterId);
          }).toList();
        });
      } else {
        AppSnackBar.showError(
          context,
          isFr
              ? 'Échec du traitement de l\'approbation'
              : 'Failed to process the approval',
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        isFr ? 'Une erreur est survenue' : 'An error occurred',
      );
    } finally {
      if (mounted) setState(() => _processing[key] = false);
    }
  }

  String _formatDate(dynamic dateString) {
    if (dateString == null) return isFr ? 'Non disponible' : 'N/A';
    try {
      final dt = DateTime.parse(dateString.toString());
      return DateFormat('MMM d, yyyy – h:mm a').format(dt);
    } catch (_) {
      return isFr ? 'Non disponible' : 'N/A';
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
          isFr ? 'Approbations de quiz' : 'Quiz Approvals',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _fetchApprovals,
            icon: const Icon(Icons.refresh),
            tooltip: isFr ? 'Actualiser' : 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    isFr
                        ? 'Chargement des demandes...'
                        : 'Loading requests...',
                    style: const TextStyle(color: AppColors.textLight),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _fetchApprovals,
                  child: Column(
                    children: [
                      _buildHeaderBanner(),
                      Expanded(child: _buildList()),
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
            onPressed: _fetchApprovals,
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

  Widget _buildHeaderBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEF5350), Color(0xFFC62828)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withAlpha(50),
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
                  isFr
                      ? 'Demandes d\'approbation de quiz'
                      : 'Quiz Approval Requests',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isFr
                      ? 'Autoriser les étudiants à repasser un quiz après le nombre maximum de tentatives'
                      : 'Allow students to retake a quiz after reaching the maximum number of attempts',
                  style: TextStyle(
                    color: Colors.white.withAlpha(210),
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
                    isFr
                        ? '${_requests.length} en attente'
                        : '${_requests.length} pending',
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
            child: const Icon(Icons.lock_open,
                color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_requests.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: _buildEmptyState(),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        return _buildRequestCard(
          Map<String, dynamic>.from(_requests[index]),
        );
      },
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
                color: AppColors.success.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  size: 64, color: AppColors.success),
            ),
            const SizedBox(height: 24),
            Text(
              isFr ? 'Aucune demande en attente' : 'No Pending Requests',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isFr
                  ? 'Tous les étudiants sont à jour avec leurs tentatives de quiz.'
                  : 'All students are up to date with their quiz attempts.',
              style: const TextStyle(fontSize: 14, color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final userId = request['userId']?.toString() ?? '';
    final courseId = request['courseId']?.toString() ?? '';
    final chapterId = request['chapterId']?.toString() ?? '';
    final key = '$userId-$courseId-$chapterId';
    final isProcessing = _processing[key] == true;

    final userName = request['userName']?.toString() ?? 'Student';
    final userEmail = request['userEmail']?.toString() ?? '';
    final courseName = request['courseName']?.toString() ?? '';
    final totalAttempts = request['totalAttempts'] ?? 0;
    final bestScore = (request['bestScore'] ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
          // ── Student ──
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.error.withAlpha(25),
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'S',
                  style: const TextStyle(
                    color: AppColors.error,
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
                      userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (userEmail.isNotEmpty)
                      Text(
                        userEmail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isFr ? 'En attente' : 'Pending',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB26A00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Details ──
          _buildDetailRow(
            Icons.book_outlined,
            isFr ? 'Cours' : 'Course',
            courseName,
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            Icons.tag,
            isFr ? 'ID du chapitre' : 'Chapter ID',
            chapterId,
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            Icons.repeat,
            isFr ? 'Tentatives' : 'Attempts',
            '$totalAttempts',
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            Icons.stars_outlined,
            isFr ? 'Meilleur score' : 'Best score',
            '${bestScore.toStringAsFixed(0)}%',
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            Icons.schedule,
            isFr ? 'Dernière tentative' : 'Last attempt',
            _formatDate(request['lastAttemptAt']),
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            Icons.outgoing_mail,
            isFr ? 'Demandé' : 'Requested',
            _formatDate(request['requestedAt']),
          ),
          const SizedBox(height: 14),

          // ── Warning note ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.yellow.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.yellow.shade200),
            ),
            child: Text(
              isFr
                  ? 'Cet étudiant a échoué le quiz $totalAttempts fois et nécessite l\'approbation de l\'instructeur pour continuer.'
                  : 'This student failed the quiz $totalAttempts times and needs instructor approval to continue.',
              style: TextStyle(fontSize: 12, color: Colors.yellow.shade900),
            ),
          ),
          const SizedBox(height: 14),

          // ── Actions ──
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      isProcessing ? null : () => _handleApproval(request, 'approve'),
                  icon: isProcessing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(isFr ? 'Approuver' : 'Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      isProcessing ? null : () => _handleApproval(request, 'deny'),
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(isFr ? 'Refuser' : 'Deny'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textLight),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
