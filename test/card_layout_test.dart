import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';
import 'package:tanga_acadamie/core/theme/app_theme.dart';
import 'package:tanga_acadamie/core/widgets/shimmer.dart';
import 'package:tanga_acadamie/screens/shared/_stat_card.dart';
import 'package:tanga_acadamie/screens/shared/course_card.dart';

/// Guards the two most reused dashboard widgets against RenderFlex overflow.
///
/// Both are placed in fixed-height `GridView` cells, so their content must fit
/// the smallest cell the app actually produces (a 2-column grid on a 320 dp
/// phone). Regressions here are otherwise only visible on a real device.
Future<void> _loadHind() async {
  final loader = FontLoader('Hind');
  for (final weight in ['Light', 'Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Hind-$weight.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

const _baseCourse = {
  'title': 'Développement Web Moderne avec React et Next.js',
  'category': 'Développement',
  'bannerImage': '',
  'offerType': 'premium',
  'price': 49,
  'discountedPrice': 29,
  'progress': 64,
  'rating': 4.7,
  'enrollmentCount': 128,
  'instructor': {'firstName': 'Jean', 'lastName': 'Mbala'},
};

Future<List<String>> _pumpInCell(
  WidgetTester tester, {
  required Widget child,
  required double width,
  required double height,
}) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    ),
  );
  await tester.pump();

  FlutterError.onError = previous;
  return errors;
}

void main() {
  setUpAll(_loadHind);

  // (label, width, height) — the real cells produced by the app's grids.
  const cells = <(String, double, double)>[
    ('phone 320dp / 2 cols', 137, 137 / 0.82),
    ('phone 360dp / 2 cols', 157, 157 / 0.82),
    ('phone 412dp / 2 cols', 181, 181 / 0.82),
    ('tablet 768dp / 3 cols', 236, 236 / 0.82),
    ('desktop 1024dp / 4 cols', 237.5, 237.5 / 0.82),
  ];

  const variants = <String, Map<String, Object?>>{
    'default': <String, Object?>{},
    'free, no progress': <String, Object?>{
      'offerType': 'free',
      'progress': 0,
      'rating': 0,
    },
    'no instructor': <String, Object?>{'instructor': null},
    'short title': <String, Object?>{'title': 'React'},
  };

  for (final (label, width, height) in cells) {
    for (final variant in variants.entries) {
      testWidgets('CourseCard fits $label (${variant.key})', (tester) async {
        final errors = await _pumpInCell(
          tester,
          width: width,
          height: height,
          child: CourseCard(
            course: {..._baseCourse, ...variant.value},
            onTap: () {},
          ),
        );

        expect(
          errors.where((e) => e.toLowerCase().contains('overflow')),
          isEmpty,
        );
      });
    }
  }

  for (final (label, width, height) in cells) {
    testWidgets('StatCard fits $label', (tester) async {
      final errors = await _pumpInCell(
        tester,
        width: width,
        height: height,
        child: const StatCard(
          title: 'Investissement total',
          value: '129',
          icon: Icons.payments_rounded,
          gradientColors: AppColors.primaryGradient,
        ),
      );

      expect(
        errors.where((e) => e.toLowerCase().contains('overflow')),
        isEmpty,
      );
    });
  }

  testWidgets('CourseCardSkeleton fills its cell without overflowing', (
    tester,
  ) async {
    final errors = await _pumpInCell(
      tester,
      width: 157,
      height: 157 / 0.82,
      child: const CourseCardSkeleton(),
    );

    expect(errors.where((e) => e.toLowerCase().contains('overflow')), isEmpty);
  });

  testWidgets('CourseGridSkeleton lays out inside a scroll view', (
    tester,
  ) async {
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exceptionAsString());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(child: CourseGridSkeleton(count: 4)),
        ),
      ),
    );
    await tester.pump();

    FlutterError.onError = previous;
    expect(errors.where((e) => e.toLowerCase().contains('overflow')), isEmpty);
  });

  group('StatCard foreground contrast', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    const gradients = <String, List<Color>>{
      'primaryGradient': AppColors.primaryGradient,
      'brandGradient': AppColors.brandGradient,
      'secondaryGradient': AppColors.secondaryGradient,
      'accentGradient': AppColors.accentGradient,
      'successGradient': AppColors.successGradient,
      'warningGradient': AppColors.warningGradient,
      'infoGradient': AppColors.infoGradient,
      'purpleGradient': AppColors.purpleGradient,
    };

    for (final entry in gradients.entries) {
      test('${entry.key} keeps the stat text readable', () {
        final on = StatCard.onColorFor(entry.value);
        for (final stop in entry.value) {
          // 3:1 is the WCAG AA minimum for large text (the stat value is 26px).
          expect(
            contrast(on, stop),
            greaterThanOrEqualTo(3.0),
            reason: '${entry.key} stop $stop against $on',
          );
        }
      });
    }
  });
}
