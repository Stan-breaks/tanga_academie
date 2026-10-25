import 'package:flutter/material.dart';
import 'package:tanga_acadamie/screens/shared/_stat_card.dart';
import 'package:tanga_acadamie/screens/shared/annoucment_card.dart';
import 'package:tanga_acadamie/screens/shared/course_card.dart';
import 'package:tanga_acadamie/screens/signup_page.dart';
import 'package:tanga_acadamie/screens/student/course_learn_page.dart';
import 'package:tanga_acadamie/screens/login_page.dart';
import 'package:tanga_acadamie/data_fetcher.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';
import 'package:tanga_acadamie/core/theme/app_theme.dart';
import 'package:tanga_acadamie/core/utils/responsive.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  late Future<Map<String, dynamic>> _dashFuture;

  @override
  void initState() {
    super.initState();
    _dashFuture = getStudentDash();
  }

  void _refresh() {
    setState(() {
      _dashFuture = getStudentDash();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _dashFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        } else if (snapshot.hasError) {
          // Check if it's an authentication error
          final errorString = snapshot.error.toString().toLowerCase();
          if (errorString.contains('unauthorized') ||
              errorString.contains('401') ||
              errorString.contains('token') ||
              errorString.contains('not logged')) {
            return _buildNotLoggedInState(context);
          }
          return _buildErrorState(snapshot.error.toString());
        } else if (snapshot.data == null) {
          return _buildNotLoggedInState(context);
        } else {
          final data = snapshot.data!;
          final List activeCourses =
              data['enrolledCourses']?['data']?['active'] ?? [];
          final List announcements = data['announcements']?['data'] ?? [];

          return Scaffold(
            backgroundColor: AppColors.background,
            body: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Welcome Section
                  _buildWelcomeSection(data['username'] ?? 'Guest'),
                  const SizedBox(height: 24),

                  // Stats Grid
                  _buildStatsGrid(data),
                  const SizedBox(height: 20),

                  // Quiz attempts shortcut
                  _buildQuizAttemptsShortcut(context),
                  const SizedBox(height: 32),

                  // Continue Learning Section
                  _buildSectionHeader(
                    context,
                    isFr ? 'Continuer l\'apprentissage' : 'Continue Learning',
                    Icons.play_circle_fill,
                    activeCourses.length,
                  ),
                  const SizedBox(height: 16),
                  _buildActiveCourses(context, activeCourses),
                  const SizedBox(height: 32),

                  // Announcements Section
                  _buildSectionHeader(
                    context,
                    isFr ? 'Annonces de cours' : 'Course Announcements',
                    Icons.campaign,
                    announcements.length,
                  ),
                  const SizedBox(height: 16),
                  _buildAnnouncements(announcements),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              isFr ? 'Chargement du tableau de bord...' : 'Loading your dashboard...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                isFr ? 'Quelque chose a mal tourné' : 'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotLoggedInState(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Icon Container
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.brandGradient,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(70),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),

              // Welcome Text
              Text(
                isFr ? 'Bienvenue à Tanga Academie' : 'Welcome to Tanga Academie',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                isFr ? 'Votre tableau de bord personnalisé vous attend ! Connectez-vous pour accéder à vos cours et suivre vos progrès.' : 'Your personalized learning dashboard awaits! Sign in to access your enrolled courses, track your progress, and continue your learning journey.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Feature Cards
              Row(
                children: [
                  Expanded(
                    child: _buildFeatureCard(
                      Icons.library_books_rounded,
                      isFr ? 'Mes cours' : 'My Courses',
                      isFr ? 'Accéder aux cours inscrits' : 'Access enrolled courses',
                      AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFeatureCard(
                      Icons.trending_up_rounded,
                      isFr ? 'Progrès' : 'Progress',
                      isFr ? 'Suivre votre apprentissage' : 'Track your learning',
                      AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildFeatureCard(
                      Icons.workspace_premium_rounded,
                      isFr ? 'Certificats' : 'Certificates',
                      isFr ? 'Gagner des récompenses' : 'Earn achievements',
                      AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFeatureCard(
                      Icons.chat_rounded,
                      isFr ? 'Contacter' : 'Connect',
                      isFr ? 'Discuter avec les instructeurs' : 'Chat with instructors',
                      AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  style: AppTheme.primaryButtonStyle(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.login_rounded, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        isFr ? 'Se connecter pour continuer' : 'Sign In to Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Signup Text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isFr ? 'Pas de compte ? ' : "Don't have an account? ",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupPage()),
                      );
                    },
                    child: Text(
                      isFr ? 'S\'inscrire' : 'Sign Up',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(String username) {
    final hour = DateTime.now().hour;
    String greeting;
    IconData greetingIcon;

    if (hour < 12) {
      greeting = isFr ? 'Bonjour' : 'Good morning';
      greetingIcon = Icons.wb_sunny_outlined;
    } else if (hour < 17) {
      greeting = isFr ? 'Bon après-midi' : 'Good afternoon';
      greetingIcon = Icons.wb_sunny;
    } else {
      greeting = isFr ? 'Bonsoir' : 'Good evening';
      greetingIcon = Icons.nights_stay_outlined;
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.brandGradient,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(80),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(right: -34, top: -46, child: _heroBubble(146, 16)),
          Positioned(right: 52, bottom: -54, child: _heroBubble(112, 12)),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceXl),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(greetingIcon,
                              color: Colors.white.withAlpha(225), size: 17),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              greeting,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withAlpha(225),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(48),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 13, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              isFr
                                  ? 'Continuez à apprendre !'
                                  : 'Keep learning!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(56),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withAlpha(75), width: 1.5),
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: Colors.white, size: 32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroBubble(double size, int alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(alpha),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> data) {
    final courses = data['enrolledCourses']?['data'];
    return GridView.count(
      crossAxisCount: Responsive.adaptive(context, mobile: 2, tablet: 4),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      children: [
        StatCard(
          title: isFr ? 'Cours inscrits' : 'Enrolled Courses',
          value: "${courses?['all']?.length ?? 0}",
          icon: Icons.library_books_rounded,
          gradientColors: AppColors.primaryGradient,
        ),
        StatCard(
          title: isFr ? 'Terminés' : 'Completed',
          value: "${courses?['completed']?.length ?? 0}",
          icon: Icons.check_circle_rounded,
          gradientColors: AppColors.successGradient,
        ),
        StatCard(
          title: isFr ? 'En cours' : 'In Progress',
          value: "${courses?['active']?.length ?? 0}",
          icon: Icons.trending_up_rounded,
          gradientColors: AppColors.accentGradient,
        ),
        StatCard(
          title: isFr ? 'Investissement' : 'Investment',
          value: "${data['investment']?['data']?['totalInvestment'] ?? 0}",
          icon: Icons.payments_rounded,
          gradientColors: AppColors.secondaryGradient,
        ),
      ],
    );
  }

  Widget _buildQuizAttemptsShortcut(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/student-quiz-attempts'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Icon(Icons.quiz_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFr ? 'Mes tentatives de quiz' : 'My Quiz Attempts',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isFr
                        ? 'Consultez vos scores et votre progression aux quiz'
                        : 'View your quiz scores and progress',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
    int count,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary50,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Icon(icon, color: AppColors.primary, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              if (count > 0)
                Text(
                  isFr ? '$count ${count == 1 ? 'élément' : 'éléments'}' : '$count ${count == 1 ? 'item' : 'items'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveCourses(BuildContext context, List activeCourses) {
    if (activeCourses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 48,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              isFr ? 'Aucun cours actif' : 'No active courses',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFr ? 'Explorez des cours pour commencer votre apprentissage !' : 'Start exploring courses to begin your learning journey!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.gridColumns(context),
        childAspectRatio: 0.82,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: activeCourses.length,
      itemBuilder: (context, index) {
        return CourseCard(
          course: activeCourses[index],
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    CourseLearnPage(courseId: activeCourses[index]['_id']),
              ),
            );
            // Refresh so progress % / completed counts reflect any videos marked
            // complete inside the course.
            if (mounted) _refresh();
          },
        );
      },
    );
  }

  Widget _buildAnnouncements(List announcements) {
    if (announcements.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 48,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              isFr ? 'Aucune annonce' : 'No announcements yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFr ? 'Les instructeurs publieront des mises à jour ici' : 'Instructors will post updates here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
          ],
        ),
      );
    }

    return Column(
      children: announcements
          .map(
            (announcement) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AnnouncementCard(announcement: announcement),
            ),
          )
          .toList(),
    );
  }
}
