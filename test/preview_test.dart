import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';
import 'package:tanga_acadamie/core/theme/app_theme.dart';
import 'package:tanga_acadamie/core/widgets/app_card.dart';
import 'package:tanga_acadamie/core/widgets/app_network_image.dart';
import 'package:tanga_acadamie/core/widgets/press_scale.dart';
import 'package:tanga_acadamie/core/widgets/shimmer.dart';
import 'package:tanga_acadamie/screens/shared/_stat_card.dart';
import 'package:tanga_acadamie/screens/shared/course_card.dart';

/// Renders the refreshed design system to `test/goldens/preview.png` so the
/// look can be reviewed without a device. Run:
///   flutter test --update-goldens test/preview_test.dart
///
/// Everything is laid out inside a fixed 360 x 1800 logical viewport (no
/// scrolling), so the whole sheet ends up in the captured image.
Future<void> _loadHind() async {
  final loader = FontLoader('Hind');
  for (final weight in ['Light', 'Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Hind-$weight.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  testWidgets('design system preview', (tester) async {
    await _loadHind();

    tester.view.physicalSize = const Size(360, 1560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        debugShowCheckedModeBanner: false,
        home: const _Preview(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(_Preview),
      matchesGoldenFile('goldens/preview.png'),
    );
  });
}

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final course = {
      'title': 'Développement Web Moderne avec React',
      'category': 'Développement',
      'bannerImage': '',
      'offerType': 'premium',
      'price': 49,
      'discountedPrice': 29,
      'progress': 64,
      'instructor': {'firstName': 'Jean', 'lastName': 'Mbala'},
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _hero(),
              const SizedBox(height: 16),
              _statRow(
                ('Cours inscrits', '8', Icons.library_books_rounded,
                    AppColors.primaryGradient),
                ('Terminés', '3', Icons.check_circle_rounded,
                    AppColors.successGradient),
              ),
              const SizedBox(height: 12),
              _statRow(
                ('En cours', '5', Icons.trending_up_rounded,
                    AppColors.accentGradient),
                ('Investissement', '129', Icons.payments_rounded,
                    AppColors.secondaryGradient),
              ),
              const SizedBox(height: 20),
              const _SectionHeader(title: 'Cours populaires'),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: CourseCard(course: course, onTap: () {})),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CourseCard(
                      course: {
                        'title': 'Initiation au Lingala',
                        'category': 'Langue',
                        'bannerImage': '',
                        'offerType': 'free',
                        'price': 0,
                        'rating': 4.7,
                        'enrollmentCount': 128,
                        'instructor': {'firstName': 'Marie', 'lastName': 'K'},
                      },
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _SectionHeader(title: 'Contenu du cours'),
              const SizedBox(height: 12),
              const _LessonTile(
                title: '1. Introduction au cours',
                meta: '12:30',
                done: true,
              ),
              const SizedBox(height: 10),
              const _LessonTile(
                title: '2. Les bases du HTML',
                meta: '08:45',
                done: false,
              ),
              const SizedBox(height: 20),
              const _SectionHeader(title: 'Reprendre'),
              const SizedBox(height: 12),
              AppCard(
                onTap: () {},
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary50,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: const Icon(Icons.quiz_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Mes tentatives de quiz',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark)),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textHint),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _SectionHeader(title: 'Typographie'),
              const SizedBox(height: 8),
              const Text(
                'Corps de texte en Hind — la police du site web, pour une '
                'identité cohérente entre le site et l\'application.',
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                        onPressed: () {}, child: const Text('Continuer')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                        onPressed: () {}, child: const Text('Détails')),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: const Text('Développement')),
                  Chip(
                    label: const Text('Gratuit'),
                    backgroundColor: AppColors.success50,
                    side: const BorderSide(color: AppColors.success100),
                  ),
                  Chip(
                    label: const Text('Nouveau'),
                    backgroundColor: AppColors.primary100,
                    side: const BorderSide(color: AppColors.primary200),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _SectionHeader(title: 'Chargement (skeleton)'),
              const SizedBox(height: 12),
              const CourseGridSkeleton(count: 2),
              const SizedBox(height: 20),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary100,
                    child: Text('SM',
                        style: TextStyle(
                            color: AppColors.primary700,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    height: 60,
                    child: AppNetworkImage(
                      url: '',
                      radius: 12,
                      width: 120,
                      height: 60,
                    ),
                  ),
                  const SizedBox(width: 12),
                  PressScale(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: const Text('Press',
                          style: TextStyle(fontWeight: FontWeight.w600)),
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

  Widget _hero() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.brandGradient,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bonjour',
                    style: TextStyle(
                        color: Colors.white.withAlpha(225), fontSize: 13.5)),
                const SizedBox(height: 6),
                const Text('Stan',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(48),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: const Text('Continuez à apprendre !',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(56),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(75), width: 1.5),
            ),
            child: const Icon(Icons.school_rounded,
                color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _statRow(
    (String, String, IconData, List<Color>) a,
    (String, String, IconData, List<Color>) b,
  ) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 96,
            child: StatCard(
              title: a.$1,
              value: a.$2,
              icon: a.$3,
              gradientColors: a.$4,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 96,
            child: StatCard(
              title: b.$1,
              value: b.$2,
              icon: b.$3,
              gradientColors: b.$4,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        Text(
          'Voir tout',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primary700,
          ),
        ),
      ],
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.title,
    required this.meta,
    required this.done,
  });

  final String title;
  final String meta;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {},
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: done ? AppColors.success50 : AppColors.primary50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              done ? Icons.check_rounded : Icons.play_arrow_rounded,
              size: 20,
              color: done ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  meta,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            done ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
            size: 18,
            color: AppColors.textHint,
          ),
        ],
      ),
    );
  }
}
