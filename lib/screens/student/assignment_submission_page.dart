import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:tanga_acadamie/core/utils/app_snackbar.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';

class AssignmentSubmissionPage extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final String courseId;

  const AssignmentSubmissionPage({
    super.key,
    required this.assignment,
    required this.courseId,
  });

  @override
  State<AssignmentSubmissionPage> createState() =>
      _AssignmentSubmissionPageState();
}

class _AssignmentSubmissionPageState extends State<AssignmentSubmissionPage> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<PlatformFile> _selectedFiles = [];
  Map<String, dynamic>? _existingSubmission;
  final TextEditingController _noteController = TextEditingController();

  String get _assignmentId =>
      widget.assignment['_id']?.toString() ??
      widget.assignment['id']?.toString() ??
      '';

  @override
  void initState() {
    super.initState();
    _loadExistingSubmission();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingSubmission() async {
    try {
      final token = await getToken();
      final res = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/submissions/student/course/${widget.courseId}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        // Response: { success, data: [ { assignment, submission } ] }
        final rawList = (data['data'] ?? data['submissions']) as List? ?? [];

        Map<String, dynamic>? matched;
        for (final item in rawList) {
          if (item is! Map) continue;
          final assignment = item['assignment'];
          final assignmentId = assignment is Map
              ? (assignment['_id'] ?? assignment['id'])?.toString()
              : item['assignmentId']?.toString();
          if (assignmentId != _assignmentId) continue;

          final submission = item['submission'];
          matched = submission is Map
              ? Map<String, dynamic>.from(submission)
              : null;
          break;
        }

        setState(() {
          _existingSubmission = matched;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || !mounted) return;

    final newFiles = result.files.where((f) => f.path != null).toList();
    setState(() {
      _selectedFiles = [..._selectedFiles, ...newFiles].take(5).toList();
    });
  }

  Future<void> _submitAssignment() async {
    // Allow a comment-only OR file-only submission (or both).
    if (_selectedFiles.isEmpty && _noteController.text.trim().isEmpty) {
      AppSnackBar.showError(
        context,
        isFr ? 'Ajoutez des fichiers ou une note' : 'Add files or a note first',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final token = await getToken();

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${ApiConfig.baseUrl}/api/submissions/$_assignmentId/submit',
        ),
      );

      request.headers['Authorization'] = 'Bearer $token';

      if (_noteController.text.trim().isNotEmpty) {
        request.fields['comment'] = _noteController.text.trim();
      }

      for (final file in _selectedFiles) {
        if (file.path != null) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'files',
              file.path!,
              contentType: _contentTypeForExtension(file.extension ?? ''),
            ),
          );
        }
      }

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);

      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        AppSnackBar.showSuccess(context, isFr ? 'Devoir soumis !' : 'Assignment submitted!');
        Navigator.pop(context, true);
      } else {
        setState(() => _isSubmitting = false);
        AppSnackBar.showError(context, isFr ? 'Échec de la soumission' : 'Submission failed');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isFr ? 'Soumettre le devoir' : 'Submit Assignment',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _existingSubmission != null
              ? _buildExistingSubmission()
              : _buildSubmissionForm(),
    );
  }

  Widget _buildExistingSubmission() {
    final grade = _existingSubmission?['grade'];
    final feedback = _existingSubmission?['feedback'];
    final status = _existingSubmission?['status'] ?? 'submitted';
    final isGraded = grade != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAssignmentInfo(),
          const SizedBox(height: 16),
          Container(
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
                  children: [
                    Icon(
                      isGraded
                          ? Icons.grade
                          : Icons.check_circle_outline,
                      color: isGraded ? AppColors.warning : AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isGraded
                          ? (isFr ? 'Noté' : 'Graded')
                          : (isFr ? 'Soumis' : 'Submitted'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isGraded ? AppColors.warning : AppColors.success,
                      ),
                    ),
                  ],
                ),
                if (isGraded) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        isFr ? 'Note: ' : 'Grade: ',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$grade',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (feedback != null && feedback.toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    isFr ? 'Retour de l\'instructeur:' : 'Instructor feedback:',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      feedback.toString(),
                      style: TextStyle(
                        color: AppColors.textDark,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${isFr ? 'Statut' : 'Status'}: $status',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAssignmentInfo(),
          const SizedBox(height: 16),

          // Note field
          Container(
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
                Text(
                  isFr ? 'Note (optionnel)' : 'Note (optional)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: isFr
                        ? 'Ajoutez un commentaire...'
                        : 'Add a comment...',
                    hintStyle: TextStyle(color: AppColors.textHint),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Files section
          Container(
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
                  children: [
                    Text(
                      isFr ? 'Fichiers' : 'Files',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${_selectedFiles.length}/5)',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_selectedFiles.isNotEmpty) ...[
                  ..._selectedFiles.asMap().entries.map(
                    (entry) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withAlpha(50),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.attach_file,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry.value.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() =>
                                _selectedFiles.removeAt(entry.key)),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_selectedFiles.length < 5)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(
                        isFr
                            ? 'Ajouter des fichiers'
                            : 'Add Files',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: AppColors.primary.withAlpha(100),
                        ),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitAssignment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
                      isFr ? 'Soumettre' : 'Submit',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAssignmentInfo() {
    final dueDate = widget.assignment['dueDate'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.warning400, AppColors.warning600],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.assignment['title'] ?? 'Assignment',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (widget.assignment['description'] != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.assignment['description'].toString(),
              style: TextStyle(
                color: Colors.white.withAlpha(220),
                fontSize: 14,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (dueDate != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.white.withAlpha(200),
                ),
                const SizedBox(width: 6),
                Text(
                  '${isFr ? 'Échéance' : 'Due'}: ${_formatDate(dueDate)}',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    try {
      final dt =
          date is String ? DateTime.parse(date) : date as DateTime;
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return date.toString();
    }
  }

  /// Returns the correct MIME type for a file extension, or null so the
  /// default (application/octet-stream) is used.
  MediaType? _contentTypeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'doc':
        return MediaType('application', 'msword');
      case 'docx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      case 'ppt':
        return MediaType('application', 'vnd.ms-powerpoint');
      case 'pptx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.presentationml.presentation',
        );
      case 'xls':
        return MediaType('application', 'vnd.ms-excel');
      case 'xlsx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      case 'txt':
        return MediaType('text', 'plain');
      case 'zip':
        return MediaType('application', 'zip');
      case 'mp4':
        return MediaType('video', 'mp4');
      case 'mp3':
        return MediaType('audio', 'mpeg');
      default:
        return null;
    }
  }
}
