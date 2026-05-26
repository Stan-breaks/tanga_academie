import 'dart:convert';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/data_fetcher.dart';
import 'package:tanga_acadamie/screens/student/assignment_submission_page.dart';
import 'package:tanga_acadamie/screens/student/lesson_video_player_page.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

class CourseLearnPage extends StatefulWidget {
  final String courseId;
  const CourseLearnPage({super.key, required this.courseId});

  @override
  State<CourseLearnPage> createState() => _CourseLearnPageState();
}

class _CourseLearnPageState extends State<CourseLearnPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<Map<String, dynamic>> _courseFuture;
  Set<String> _completedVideoIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _courseFuture = fetchCourse(widget.courseId);
    _loadProgress();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    try {
      final token = await getToken();
      final res = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/progress/course/${widget.courseId}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final videos =
            data['completedVideos'] ??
            data['data']?['completedVideos'] ??
            [];
        setState(() {
          _completedVideoIds = Set<String>.from(
            (videos as List).map((v) => v.toString()),
          );
        });
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _buildFlatLessonList(
    Map<String, dynamic> course,
  ) {
    final chapters = course['chapters'] as List? ?? [];
    final result = <Map<String, dynamic>>[];
    for (final chapter in chapters) {
      final lessons = chapter['lessons'] as List? ?? [];
      for (final lesson in lessons) {
        result.add({
          'chapter': chapter as Map<String, dynamic>,
          'lesson': lesson as Map<String, dynamic>,
        });
      }
    }
    return result;
  }

  void _openLesson(
    Map<String, dynamic> course,
    Map<String, dynamic> chapter,
    Map<String, dynamic> lesson,
  ) {
    final flat = _buildFlatLessonList(course);
    final lessonId =
        lesson['_id']?.toString() ?? lesson['id']?.toString() ?? '';
    final idx = flat.indexWhere((e) {
      final l = e['lesson'] as Map<String, dynamic>;
      return l['_id']?.toString() == lessonId ||
          l['id']?.toString() == lessonId;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonVideoPlayerPage(
          lesson: lesson,
          chapter: chapter,
          courseId: widget.courseId,
          onComplete: () {
            _loadProgress();
          },
          onNext: idx >= 0 && idx < flat.length - 1
              ? () {
                  Navigator.pop(context);
                  _openLesson(
                    course,
                    flat[idx + 1]['chapter'] as Map<String, dynamic>,
                    flat[idx + 1]['lesson'] as Map<String, dynamic>,
                  );
                }
              : null,
          onPrevious: idx > 0
              ? () {
                  Navigator.pop(context);
                  _openLesson(
                    course,
                    flat[idx - 1]['chapter'] as Map<String, dynamic>,
                    flat[idx - 1]['lesson'] as Map<String, dynamic>,
                  );
                }
              : null,
        ),
      ),
    );
  }

  Future<void> downloadAndOpen(String fileName, String url) async {
    final dio = Dio();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';

      final file = File(filePath);
      if (!await file.exists()) {
        await dio.download(url, filePath);
      }

      await OpenFilex.open(filePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFr
                  ? 'Erreur de téléchargement. Vérifiez votre connexion.'
                  : 'Download failed. Check your connection.',
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _courseFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Colors.blueAccent,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isFr ? 'Chargement du cours...' : 'Loading course...',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isFr
                        ? 'Erreur de chargement du cours'
                        : 'Error loading course',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        } else {
          final course = snapshot.data?['course'];
          if (course == null) {
            return Scaffold(
              backgroundColor: Colors.grey.shade50,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isFr ? 'Cours introuvable' : 'Course not found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            body: CustomScrollView(
              slivers: [
                // App Bar with Course Banner
                _buildAppBar(course),

                // Course Title and Info
                SliverToBoxAdapter(child: _buildCourseHeader(course)),

                // Continue Learning Section
                if (_hasInProgressContent(course))
                  SliverToBoxAdapter(child: _buildContinueLearning(course)),

                // Tab Bar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      isScrollable: false,
                      labelColor: Colors.blueAccent,
                      unselectedLabelColor: Colors.grey.shade600,
                      indicatorColor: Colors.blueAccent,
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      tabs: [
                        Tab(text: isFr ? 'Leçons' : 'Lessons'),
                        Tab(text: isFr ? 'Ressources' : 'Resources'),
                        Tab(text: isFr ? 'Tâches' : 'Tasks'),
                        Tab(text: isFr ? 'À propos' : 'About'),
                      ],
                    ),
                  ),
                ),

                // Tab Content
                SliverFillRemaining(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLessonsTab(course),
                      _buildResourcesTab(course),
                      _buildAssignmentsTab(course),
                      _buildAboutTab(course),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildAppBar(Map<String, dynamic> course) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: Colors.blueAccent,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(60),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            course['bannerImage'] != null
                ? Image.network(
                    '${ApiConfig.baseUrl}${course['bannerImage']}',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.blueAccent.shade400,
                              Colors.blue.shade800,
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.school,
                          size: 80,
                          color: Colors.white38,
                        ),
                      );
                    },
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blueAccent.shade400,
                          Colors.blue.shade800,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.school,
                      size: 80,
                      color: Colors.white38,
                    ),
                  ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withAlpha(80)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseHeader(Map<String, dynamic> course) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            course['title'] ?? 'Untitled Course',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildInfoChip(
                Icons.category_outlined,
                course['category'] ?? 'All',
                Colors.blueAccent,
              ),
              _buildInfoChip(
                Icons.language,
                course['language'] ?? 'French',
                Colors.green,
              ),
              _buildInfoChip(
                Icons.people_outline,
                '${course['enrollmentCount'] ?? 0} ${isFr ? 'inscrits' : 'enrolled'}',
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueLearning(Map<String, dynamic> course) {
    final current = _getCurrentLessonWithChapter(course);
    final currentLesson = current?['lesson'] as Map<String, dynamic>?;

    if (currentLesson == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blueAccent.shade400, Colors.blueAccent.shade700],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isFr ? 'Continuer l\'apprentissage' : 'Continue Learning',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            currentLesson['title'] ?? 'Next Lesson',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final current = _getCurrentLessonWithChapter(course);
                if (current != null) {
                  _openLesson(
                    course,
                    current['chapter'] as Map<String, dynamic>,
                    current['lesson'] as Map<String, dynamic>,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow, size: 20),
                  SizedBox(width: 8),
                  Text(
                    isFr ? 'Reprendre' : 'Resume',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonsTab(Map<String, dynamic> course) {
    final chapters = course['chapters'] as List<dynamic>? ?? [];

    if (chapters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isFr ? 'Aucune leçon' : 'No lessons yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFr
                  ? 'Les leçons apparaîtront bientôt'
                  : 'Lessons will appear here soon',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        return _buildChapterCard(chapter, index + 1, course);
      },
    );
  }

  Widget _buildChapterCard(
    Map<String, dynamic> chapter,
    int chapterNumber,
    Map<String, dynamic> course,
  ) {
    final lessons = chapter['lessons'] as List<dynamic>? ?? [];
    final isLocked = chapter['isLockedUntilQuizPass'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isLocked
                  ? [Colors.grey.shade400, Colors.grey.shade600]
                  : [Colors.blueAccent.shade200, Colors.blueAccent.shade700],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: isLocked
                ? const Icon(Icons.lock, color: Colors.white, size: 22)
                : Text(
                    '$chapterNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
          ),
        ),
        title: Text(
          chapter['title'] ?? 'Chapter $chapterNumber',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${lessons.length} ${isFr ? (lessons.length == 1 ? 'leçon' : 'leçons') : (lessons.length == 1 ? 'lesson' : 'lessons')}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
        children: lessons.asMap().entries.map((entry) {
          return _buildLessonTile(
            entry.value,
            entry.key + 1,
            isLocked,
            chapter,
            course,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLessonTile(
    Map<String, dynamic> lesson,
    int lessonNumber,
    bool isChapterLocked,
    Map<String, dynamic> chapter,
    Map<String, dynamic> course,
  ) {
    final hasVideo = lesson['video'] != null;
    final hasQuiz = lesson['quiz'] != null;
    final videoId =
        lesson['video']?['_id']?.toString() ??
        lesson['video']?['id']?.toString();
    final isCompleted =
        videoId != null && _completedVideoIds.contains(videoId);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isChapterLocked
            ? null
            : () => _openLesson(course, chapter, lesson),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isChapterLocked
                      ? Colors.grey.shade200
                      : Colors.blueAccent.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasVideo ? Icons.play_circle_outline : Icons.article_outlined,
                  color: isChapterLocked
                      ? Colors.grey.shade400
                      : Colors.blueAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson['title'] ?? 'Lesson $lessonNumber',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isChapterLocked
                            ? Colors.grey.shade500
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (hasVideo) ...[
                          Icon(
                            Icons.videocam,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(lesson['video']['duration']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                        if (hasQuiz) ...[
                          if (hasVideo) const SizedBox(width: 12),
                          Icon(
                            Icons.quiz,
                            size: 14,
                            color: Colors.orange.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Quiz',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                isChapterLocked
                    ? Icons.lock_outline
                    : isCompleted
                        ? Icons.check_circle
                        : Icons.chevron_right,
                size: 22,
                color: isChapterLocked
                    ? Colors.grey.shade400
                    : isCompleted
                        ? Colors.green
                        : Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isCourseComplete(Map<String, dynamic> course) {
    final chapters = course['chapters'] as List? ?? [];
    if (chapters.isEmpty) return false;
    for (final chapter in chapters) {
      for (final lesson in (chapter['lessons'] as List? ?? [])) {
        final videoId =
            lesson['video']?['_id']?.toString() ??
            lesson['video']?['id']?.toString();
        if (videoId != null && !_completedVideoIds.contains(videoId)) {
          return false;
        }
      }
    }
    return true;
  }

  Widget _buildResourcesTab(Map<String, dynamic> course) {
    final pdfFiles = course['pdfFiles'] as List<dynamic>? ?? [];
    final certificateFile = course['certificateFile'];
    final zoomLink = course['zoomLink']?.toString();
    final hasContent =
        pdfFiles.isNotEmpty || certificateFile != null || zoomLink != null;

    if (!hasContent) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              isFr ? 'Aucune ressource disponible' : 'No resources available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFr
                  ? 'Les ressources seront ajoutées par l\'instructeur'
                  : 'Resources will be added by the instructor',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Zoom live session
        if (zoomLink != null) ...[
          _buildResourcesHeader(
            isFr ? 'Session en direct' : 'Live Session',
            Icons.videocam,
          ),
          const SizedBox(height: 12),
          _buildZoomCard(zoomLink),
          const SizedBox(height: 8),
        ],

        if (pdfFiles.isNotEmpty) ...[
          if (zoomLink != null) const SizedBox(height: 16),
          _buildResourcesHeader(
            isFr ? 'Matériels de cours' : 'Course Materials',
            Icons.description,
          ),
          const SizedBox(height: 12),
          ...pdfFiles.map(
            (pdf) => _buildResourceCard(
              title: pdf['title'] ?? 'Document',
              subtitle: isFr ? 'Document PDF' : 'PDF Document',
              icon: Icons.picture_as_pdf,
              color: Colors.red,
              onTap: () {
                downloadAndOpen(
                  pdf['title'],
                  "${ApiConfig.baseUrl}${pdf['url']}",
                );
              },
            ),
          ),
        ],

        if (certificateFile != null) ...[
          const SizedBox(height: 24),
          _buildResourcesHeader(
            isFr ? 'Certificat' : 'Certificate',
            Icons.workspace_premium,
          ),
          const SizedBox(height: 12),
          _buildCertificateCard(course, certificateFile),
        ],
      ],
    );
  }

  Widget _buildZoomCard(String zoomLink) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade700, Colors.blue.shade900],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withAlpha(60),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => launchUrl(
            Uri.parse(zoomLink),
            mode: LaunchMode.externalApplication,
          ),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.videocam,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFr ? 'Rejoindre la session Zoom' : 'Join Zoom Session',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isFr
                            ? 'Cliquez pour rejoindre la classe en direct'
                            : 'Tap to join the live class',
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new,
                  color: Colors.white.withAlpha(200),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCertificateCard(
    Map<String, dynamic> course,
    String certificateFile,
  ) {
    final complete = _isCourseComplete(course);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (!complete) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.lock, color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isFr
                              ? 'Terminez toutes les leçons pour débloquer le certificat'
                              : 'Complete all lessons to unlock the certificate',
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.orange.shade700,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
              return;
            }
            downloadAndOpen(
              'Course Certificate',
              "${ApiConfig.baseUrl}$certificateFile",
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: complete
                        ? Colors.amber.withAlpha(30)
                        : Colors.grey.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    complete
                        ? Icons.workspace_premium
                        : Icons.lock_outline,
                    color: complete ? Colors.amber : Colors.grey.shade500,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFr ? 'Certificat du cours' : 'Course Certificate',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        complete
                            ? (isFr ? 'Disponible — Télécharger' : 'Available — Tap to download')
                            : (isFr
                                ? 'Terminez le cours pour débloquer'
                                : 'Complete the course to unlock'),
                        style: TextStyle(
                          fontSize: 13,
                          color: complete
                              ? Colors.green.shade600
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: complete
                        ? Colors.blueAccent.withAlpha(25)
                        : Colors.grey.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    complete ? Icons.download : Icons.lock,
                    color: complete ? Colors.blueAccent : Colors.grey.shade400,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResourcesHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.blueAccent, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildResourceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.download,
                    color: Colors.blueAccent,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentsTab(Map<String, dynamic> course) {
    final assignments = course['assignments'] as List<dynamic>? ?? [];

    if (assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isFr ? 'Aucun devoir' : 'No assignments yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFr
                  ? 'Les devoirs seront ajoutés bientôt'
                  : 'Assignments will appear here when added',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: assignments.length,
      itemBuilder: (context, index) {
        final assignment = assignments[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.assignment, color: Colors.white),
            ),
            title: Text(
              assignment['title'] ?? 'Assignment ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isFr ? 'En attente' : 'Pending',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AssignmentSubmissionPage(
                    assignment: assignment,
                    courseId: widget.courseId,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAboutTab(Map<String, dynamic> course) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAboutSection(
          isFr ? 'Description' : 'Description',
          course['description'],
          Icons.info_outline,
        ),
        _buildAboutSection(
          isFr ? 'Ce que vous apprendrez' : 'What you\'ll learn',
          course['benefits'],
          Icons.lightbulb_outline,
        ),
        _buildAboutSection(
          isFr ? 'Prérequis' : 'Requirements',
          course['requirements'],
          Icons.checklist,
        ),
        if ((course['tags'] as List?)?.isNotEmpty ?? false) ...[
          const SizedBox(height: 24),
          _buildResourcesHeader(
            isFr ? 'Étiquettes' : 'Tags',
            Icons.local_offer,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (course['tags'] as List).map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blueAccent.withAlpha(50)),
                ),
                child: Text(
                  tag.toString(),
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildAboutSection(String title, dynamic content, IconData icon) {
    if (content == null || content.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.blueAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content.toString(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  bool _hasInProgressContent(Map<String, dynamic> course) {
    final chapters = course['chapters'] as List? ?? [];
    if (chapters.isEmpty) return false;
    for (final chapter in chapters) {
      final lessons = chapter['lessons'] as List? ?? [];
      for (final lesson in lessons) {
        final videoId =
            lesson['video']?['_id']?.toString() ??
            lesson['video']?['id']?.toString();
        if (videoId == null || !_completedVideoIds.contains(videoId)) {
          return true;
        }
      }
    }
    return false;
  }

  Map<String, dynamic>? _getCurrentLessonWithChapter(
    Map<String, dynamic> course,
  ) {
    final chapters = course['chapters'] as List? ?? [];
    if (chapters.isEmpty) return null;

    for (final chapter in chapters) {
      final lessons = chapter['lessons'] as List? ?? [];
      for (final lesson in lessons) {
        final videoId =
            lesson['video']?['_id']?.toString() ??
            lesson['video']?['id']?.toString();
        if (videoId == null || !_completedVideoIds.contains(videoId)) {
          return {
            'chapter': chapter as Map<String, dynamic>,
            'lesson': lesson as Map<String, dynamic>,
          };
        }
      }
    }

    // All complete — return last lesson
    final lastChapter = chapters.last as Map<String, dynamic>;
    final lessons = lastChapter['lessons'] as List? ?? [];
    if (lessons.isEmpty) return null;
    return {
      'chapter': lastChapter,
      'lesson': lessons.last as Map<String, dynamic>,
    };
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return '';
    final minutes = (duration / 60).floor();
    return '${minutes}min';
  }
}

// Sticky Tab Bar Delegate
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return false;
  }
}
