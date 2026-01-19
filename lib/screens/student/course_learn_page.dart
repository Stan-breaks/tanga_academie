import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/data_fetcher.dart';
import 'package:tanga_acadamie/screens/home_page.dart';
import 'package:tanga_acadamie/screens/student/lesson_video_player_page.dart';

class CourseLearnPage extends StatefulWidget {
  final String courseId;
  const CourseLearnPage({super.key, required this.courseId});

  @override
  State<CourseLearnPage> createState() => _CourseLearnPageState();
}

class _CourseLearnPageState extends State<CourseLearnPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> downloadAndOpen(String fileName, String url) async {
    final dio = Dio();

    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/$fileName';

    final file = File(filePath);
    if (!await file.exists()) {
      await dio.download(url, filePath);
    }

    await OpenFilex.open(filePath);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: fetchCourse(widget.courseId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        } else {
          final course = snapshot.data?['course'];
          if (course == null) {
            return const Scaffold(
              body: Center(child: Text('Course not found')),
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
                      labelColor: Theme.of(context).primaryColor,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Theme.of(context).primaryColor,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      tabs: const [
                        Tab(text: 'Lessons'),
                        Tab(text: 'Resources'),
                        Tab(text: 'Assignments'),
                        Tab(text: 'About'),
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
      expandedHeight: 200,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.blueGrey),
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage(isLoggedIn: true)),
          );
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: course['bannerImage'] != null
            ? Image.network(
                '${ApiConfig.baseUrl}${course['bannerImage']}',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.blue.shade700,
                    child: const Icon(
                      Icons.school,
                      size: 80,
                      color: Colors.white,
                    ),
                  );
                },
              )
            : Container(
                color: Colors.blue.shade700,
                child: const Icon(Icons.school, size: 80, color: Colors.white),
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
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                Icons.category_outlined,
                course['category'] ?? 'All',
              ),
              _buildInfoChip(Icons.language, course['language'] ?? 'French'),
              _buildInfoChip(
                Icons.people_outline,
                '${course['enrollmentCount'] ?? 0} enrolled',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueLearning(Map<String, dynamic> course) {
    // This would come from progress tracking
    final currentLesson = _getCurrentLesson(course);

    if (currentLesson == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withAlpha(50),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Continue Learning',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentLesson['title'] ?? 'Next Lesson',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Navigate to lesson
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue.shade600,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Resume',
                style: TextStyle(fontWeight: FontWeight.w600),
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
      return const Center(child: Text('No lessons available yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        return _buildChapterCard(chapter, index + 1);
      },
    );
  }

  Widget _buildChapterCard(Map<String, dynamic> chapter, int chapterNumber) {
    final lessons = chapter['lessons'] as List<dynamic>? ?? [];
    final isLocked = chapter['isLockedUntilQuizPass'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isLocked ? Colors.grey : Colors.blue,
          child: isLocked
              ? const Icon(Icons.lock, color: Colors.white, size: 20)
              : Text(
                  '$chapterNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        title: Text(
          chapter['title'] ?? 'Chapter $chapterNumber',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${lessons.length} lessons'),
        children: lessons.asMap().entries.map((entry) {
          return _buildLessonTile(
            entry.value,
            entry.key + 1,
            isLocked,
            chapter,
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
  ) {
    final hasVideo = lesson['video'] != null;
    final hasQuiz = lesson['quiz'] != null;

    return ListTile(
      leading: Icon(
        hasVideo ? Icons.play_circle_outline : Icons.article_outlined,
        color: isChapterLocked ? Colors.grey : Colors.blue,
      ),
      title: Text(lesson['title'] ?? 'Lesson $lessonNumber'),
      subtitle: Row(
        children: [
          if (hasVideo) ...[
            const Icon(Icons.videocam, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              _formatDuration(lesson['video']['duration']),
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (hasQuiz) ...[
            const SizedBox(width: 12),
            const Icon(Icons.quiz, size: 14, color: Colors.orange),
            const SizedBox(width: 4),
            const Text('Quiz', style: TextStyle(fontSize: 12)),
          ],
        ],
      ),
      trailing: isChapterLocked
          ? const Icon(Icons.lock, size: 20, color: Colors.grey)
          : const Icon(Icons.chevron_right),
      onTap: isChapterLocked
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LessonVideoPlayerPage(
                    lesson: lesson,
                    chapter: chapter,
                    courseId: widget.courseId,
                    onComplete: () {
                      // Save progress
                    },
                    onNext: () {
                      // Load next lesson
                    },
                    onPrevious: () {
                      // Load previous lesson
                    },
                  ),
                ),
              );
            },
    );
  }

  Widget _buildResourcesTab(Map<String, dynamic> course) {
    final pdfFiles = course['pdfFiles'] as List<dynamic>? ?? [];
    final certificateFile = course['certificateFile'];

    if (pdfFiles.isEmpty && certificateFile == null) {
      return const Center(child: Text('No resources available'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pdfFiles.isNotEmpty) ...[
          const Text(
            'Course Materials',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...pdfFiles.map(
            (pdf) => _buildResourceCard(
              title: pdf['title'] ?? 'Document',
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
          const SizedBox(height: 20),
          const Text(
            'Certificate',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildResourceCard(
            title: 'Course Certificate',
            icon: Icons.workspace_premium,
            color: Colors.amber,
            onTap: () {
              // View certificate
            },
          ),
        ],
      ],
    );
  }

  Widget _buildResourceCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(50),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: const Icon(Icons.download),
        onTap: onTap,
      ),
    );
  }

  Widget _buildAssignmentsTab(Map<String, dynamic> course) {
    final assignments = course['assignments'] as List<dynamic>? ?? [];

    if (assignments.isEmpty) {
      return const Center(child: Text('No assignments yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: assignments.length,
      itemBuilder: (context, index) {
        final assignment = assignments[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.orange,
              child: Icon(Icons.assignment, color: Colors.white),
            ),
            title: Text(assignment['title'] ?? 'Assignment ${index + 1}'),
            subtitle: const Text('Due: Not submitted'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to assignment
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
        _buildAboutSection('Description', course['description']),
        _buildAboutSection('What you\'ll learn', course['benefits']),
        _buildAboutSection('Requirements', course['requirements']),
        if ((course['tags'] as List?)?.isNotEmpty ?? false) ...[
          const SizedBox(height: 20),
          const Text(
            'Tags',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (course['tags'] as List).map((tag) {
              return Chip(
                label: Text(tag.toString()),
                backgroundColor: Colors.blue.shade50,
                labelStyle: TextStyle(color: Colors.blue.shade700),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildAboutSection(String title, dynamic content) {
    if (content == null || content.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          content.toString(),
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade700,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  bool _hasInProgressContent(Map<String, dynamic> course) {
    // Implement logic to check if user has started the course
    return true; // Placeholder
  }

  Map<String, dynamic>? _getCurrentLesson(Map<String, dynamic> course) {
    // Implement logic to get current lesson from progress
    final chapters = course['chapters'] as List<dynamic>? ?? [];
    if (chapters.isEmpty) return null;

    final firstChapter = chapters[0];
    final lessons = firstChapter['lessons'] as List<dynamic>? ?? [];
    if (lessons.isEmpty) return null;

    return lessons[0]; // Placeholder - return first lesson
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
