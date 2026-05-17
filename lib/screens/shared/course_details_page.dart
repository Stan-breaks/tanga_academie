import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/screens/login_page.dart';
import 'package:tanga_acadamie/screens/student/course_learn_page.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

class CourseDetailsPage extends StatefulWidget {
  final Map<String, dynamic>? course;

  const CourseDetailsPage({super.key, required this.course});

  @override
  State<CourseDetailsPage> createState() => _CourseDetailsPageState();
}

class _CourseDetailsPageState extends State<CourseDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasAccess = false;
  bool _loading = false;
  bool _checkingAccess = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkCourseAccess();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkCourseAccess() async {
    try {
      final token = await getToken();

      if (token!.isEmpty) {
        setState(() => _checkingAccess = false);
        return;
      }

      final dio = Dio();
      final response = await dio.get(
        '${ApiConfig.baseUrl}/api/payments/check-access/${widget.course!["_id"]}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.data['success'] == true) {
        setState(() => _hasAccess = response.data['hasAccess'] ?? false);
      }
    } catch (error) {
      debugPrint('Error checking course access: $error');
    } finally {
      setState(() => _checkingAccess = false);
    }
  }

  bool _isFree(Map<String, dynamic> course) {
    final offerType = course['offerType'];
    return offerType == 'free' || offerType == 'freemium';
  }

  bool _isFreemium(Map<String, dynamic> course) {
    return course['offerType'] == 'freemium';
  }

  double _getCurrentPrice(Map<String, dynamic> course) {
    return (course['discountedPrice'] ?? course['price'] ?? 0.0).toDouble();
  }

  Future<void> _handleFreeCourseEnrollment(Map<String, dynamic> course) async {
    setState(() => _loading = true);
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        setState(() => _loading = false);
        _navigateToLogin(
          isFr
              ? 'Connectez-vous pour vous inscrire à ce cours'
              : 'Sign in to enroll in this course',
        );
        return;
      }

      final dio = Dio();
      final url = _isFreemium(course)
          ? '${ApiConfig.baseUrl}/api/payments/enroll-freemium'
          : '${ApiConfig.baseUrl}/api/payments/enroll-free';

      final response = await dio.post(
        url,
        data: {'courseId': course['_id']},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.data['success'] == true) {
        _showSnackBar(
          isFr
              ? 'Inscription au cours gratuit réussie !'
              : 'Successfully enrolled in free course!',
        );
        setState(() => _hasAccess = true);

        await Future.delayed(const Duration(milliseconds: 1500));
        setState(() {
          _hasAccess = true;
        });
      }
    } catch (error) {
      _showSnackBar('${isFr ? 'Échec de l\'inscription' : 'Failed to enroll'}: ${error.toString()}');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _handlePremiumCoursePayment(Map<String, dynamic> course) async {
    setState(() => _loading = true);
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        setState(() => _loading = false);
        _navigateToLogin(
          isFr
              ? 'Connectez-vous pour acheter ce cours'
              : 'Sign in to purchase this course',
        );
        return;
      }

      final dio = Dio();
      final response = await dio.post(
        '${ApiConfig.baseUrl}/api/payments/create-session',
        data: {'courseId': course['_id']},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.data['success'] == true) {
        await _launchPaymentGateway(response.data);
      }
    } catch (error) {
      _showSnackBar('${isFr ? 'Paiement échoué' : 'Payment failed'}: ${error.toString()}');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _launchPaymentGateway(Map<String, dynamic> paymentData) async {
    final gatewayUrl = paymentData['gatewayUrl'];
    final params = paymentData['paymentData'] as Map<String, dynamic>;

    final uri = Uri.parse(gatewayUrl).replace(
      queryParameters: params.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('Could not launch payment gateway');
    }
  }

  void _handleStartLearning() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CourseLearnPage(courseId: widget.course!["_id"]),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _navigateToLogin(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.login, color: Colors.blueAccent),
            ),
            const SizedBox(width: 12),
            Text(isFr ? 'Connexion requise' : 'Sign In Required'),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isFr ? 'Annuler' : 'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(isFr ? 'Se connecter' : 'Sign In'),
          ),
        ],
      ),
    );
  }

  String _getTotalDuration(int? totalSeconds) {
    if (totalSeconds == null) return 'N/A';
    final hrs = totalSeconds ~/ 3600;
    final mins = (totalSeconds % 3600) ~/ 60;
    return '${hrs > 0 ? '${hrs}h ' : ''}${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // App Bar with Course Banner
          _buildAppBar(widget.course!),

          // Course Details Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildCourseHeader(widget.course!),
                _buildPriceAndEnrollment(widget.course!),
              ],
            ),
          ),

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
                tabs: [
                  Tab(text: isFr ? 'Aperçu' : 'Overview'),
                  Tab(text: isFr ? 'Programme' : 'Curriculum'),
                  Tab(text: isFr ? 'Avis' : 'Reviews'),
                ],
              ),
            ),
          ),

          // Tab Content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(widget.course!),
                _buildCurriculumTab(widget.course!),
                _buildReviewsTab(widget.course!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(Map<String, dynamic> course) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
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
    final instructor = course['instructor'];
    final instructorName = instructor != null
        ? '${instructor['firstName'] ?? ''} ${instructor['lastName'] ?? ''}'
        : (isFr ? 'Inconnu' : 'Unknown');

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category and Featured Tags
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip(isFr ? 'En vedette' : 'Featured', Colors.blue),
              _buildChip(course['category'] ?? 'All', Colors.indigo),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            course['title'] ?? (isFr ? 'Cours sans titre' : 'Untitled Course'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            course['description'] ?? '',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Instructor and Meta Info
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  (instructor?['firstName']?[0] ?? 'U').toUpperCase(),
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      instructorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      isFr ? 'Instructeur' : 'Instructor',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Course Stats
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildStat(Icons.language, course['language'] ?? 'French'),
              _buildStat(
                Icons.timer_outlined,
                _getTotalDuration(course['totalDuration']),
              ),
              _buildStat(
                Icons.book_outlined,
                '${(course['chapters'] as List?)?.length ?? 0} ${isFr ? 'Leçons' : 'Lessons'}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildPriceAndEnrollment(Map<String, dynamic> course) {
    final isFree = _isFree(course);
    final currentPrice = _getCurrentPrice(course);
    final originalPrice = course['price']?.toDouble();
    final discountPercent =
        originalPrice != null &&
            originalPrice > 0 &&
            course['discountedPrice'] != null
        ? (((originalPrice - course['discountedPrice']) / originalPrice) * 100)
              .round()
        : 0;

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Price Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isFree)
                Text(
                  isFr ? 'Gratuit' : 'Free',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${currentPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    if (originalPrice != null &&
                        course['discountedPrice'] != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '\$${originalPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              if (discountPercent > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$discountPercent% OFF',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Enrollment Button
          if (_checkingAccess)
            const Center(child: CircularProgressIndicator())
          else
            _buildEnrollmentButton(course, isFree),

          const SizedBox(height: 8),

          // Helper Text
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                isFr
                    ? (isFree
                          ? 'Accès gratuit à vie'
                          : 'Paiement sécurisé via MaxiCash')
                    : (isFree
                          ? 'Free lifetime access'
                          : 'Secure payment via MaxiCash'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Course Details Grid
          _buildCourseDetailsGrid(course),
        ],
      ),
    );
  }

  Widget _buildEnrollmentButton(Map<String, dynamic> course, bool isFree) {
    if (_hasAccess) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _handleStartLearning,
          icon: const Icon(Icons.play_circle_outline),
          label: Text(isFr ? 'Commencer à apprendre' : 'Start Learning'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    if (isFree) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _loading
              ? null
              : () => _handleFreeCourseEnrollment(course),
          icon: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Icon(Icons.add),
          label: Text(
            _loading
                ? (isFr ? 'Inscription...' : 'Enrolling...')
                : (isFr ? 'S\'inscrire gratuitement' : 'Enroll for Free'),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : () => _handlePremiumCoursePayment(course),
        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Icon(Icons.credit_card),
        label: Text(
          _loading
              ? (isFr ? 'Traitement...' : 'Processing...')
              : '${isFr ? "Acheter" : "Buy Now"} - \$${_getCurrentPrice(course).toStringAsFixed(2)}',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildCourseDetailsGrid(Map<String, dynamic> course) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  isFr ? 'Leçons' : 'Lectures',
                  '${(course['chapters'] as List?)?.length ?? 0}',
                  Icons.book_outlined,
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  isFr ? 'Durée' : 'Duration',
                  _getTotalDuration(course['totalDuration']),
                  Icons.timer_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  isFr ? 'Langue' : 'Language',
                  course['language'] ?? 'N/A',
                  Icons.language,
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  isFr ? 'Certificat' : 'Certificate',
                  isFr ? 'Oui' : 'Yes',
                  Icons.workspace_premium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(Map<String, dynamic> course) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection(
          isFr ? 'Ce que vous apprendrez' : 'What you\'ll learn',
          course['benefits'],
        ),
        _buildSection(
          isFr ? 'Prérequis' : 'Requirements',
          course['requirements'],
        ),
        if ((course['tags'] as List?)?.isNotEmpty ?? false) ...[
          const SizedBox(height: 20),
          Text(
            isFr ? 'Étiquettes' : 'Tags',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
        const SizedBox(height: 30),
        Text(
          isFr ? 'Pourquoi choisir ce cours ?' : 'Why choose this course?',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(
          isFr ? 'Vidéos d\'experts' : 'Expert-led videos',
          isFr
              ? 'Apprenez avec des tutoriels étape par étape'
              : 'Learn from industry professionals with step-by-step tutorials',
        ),
        _buildFeatureItem(
          isFr ? 'Ressources téléchargeables' : 'Downloadable resources',
          isFr
              ? 'Accédez aux PDF et modèles hors ligne'
              : 'Access PDFs, cheat sheets, and templates for offline learning',
        ),
        _buildFeatureItem(
          isFr ? 'Support communautaire' : 'Community support',
          isFr
              ? 'Posez vos questions sur les forums'
              : 'Get answers to your questions via discussion forums',
        ),
        _buildFeatureItem(
          isFr ? 'Certificat de fin' : 'Certificate of completion',
          isFr
              ? 'Obtenez une certification pour valoriser vos compétences'
              : 'Earn certification to showcase your skills',
        ),
      ],
    );
  }

  Widget _buildSection(String title, dynamic content) {
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

  Widget _buildFeatureItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.check, size: 16, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 12),
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
                Text(
                  description,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurriculumTab(Map<String, dynamic> course) {
    final chapters = course['chapters'] as List<dynamic>? ?? [];

    if (chapters.isEmpty) {
      return Center(
        child: Text(
          isFr ? 'Aucun programme disponible' : 'No curriculum available yet',
        ),
      );
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
        subtitle: Text('${lessons.length} ${isFr ? 'leçons' : 'lessons'}'),
        children: lessons.asMap().entries.map((entry) {
          return _buildLessonTile(entry.value, entry.key + 1, isLocked);
        }).toList(),
      ),
    );
  }

  Widget _buildLessonTile(
    Map<String, dynamic> lesson,
    int lessonNumber,
    bool isLocked,
  ) {
    final hasVideo = lesson['video'] != null;
    final hasQuiz = lesson['quiz'] != null;
    final duration = lesson['video']?['duration'];

    return ListTile(
      leading: Icon(
        hasVideo ? Icons.play_circle_outline : Icons.article_outlined,
        color: isLocked ? Colors.grey : Colors.blue,
      ),
      title: Text(lesson['title'] ?? 'Lesson $lessonNumber'),
      subtitle: Row(
        children: [
          if (hasVideo && duration != null) ...[
            const Icon(Icons.videocam, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              '${(duration / 60).floor()}min',
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
      trailing: isLocked
          ? const Icon(Icons.lock, size: 20, color: Colors.grey)
          : const Icon(Icons.chevron_right),
      onTap: isLocked
          ? null
          : () {
              // TODO: Navigate to lesson
            },
    );
  }

  Widget _buildReviewsTab(Map<String, dynamic> course) {
    final rating = course['rating'] ?? 0.0;
    final totalReviews = course['totalReviews'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Rating Summary
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 24,
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                isFr ? '$totalReviews avis' : '$totalReviews reviews',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Reviews List (placeholder)
        if (totalReviews == 0)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                isFr ? 'Aucun avis' : 'No reviews yet',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ),
          )
        else
          Center(
            child: Text(
              isFr ? 'Les avis apparaîtront ici' : 'Reviews will appear here',
            ),
          ),
      ],
    );
  }
}

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
