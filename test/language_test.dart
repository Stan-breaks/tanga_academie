import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tanga_language_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test(
    'defaults to French when the user has never chosen a language',
    () async {
      await initLanguage();

      expect(defaultLanguage, 'fr');
      expect(currentLanguage, 'fr');
      expect(languageNotifier.value, 'fr');
    },
  );

  test('keeps an explicitly saved English preference', () async {
    final box = await Hive.openBox('settingsBox');
    await box.put('language', 'en');
    await box.close();

    await initLanguage();

    expect(currentLanguage, 'en');
    expect(languageNotifier.value, 'en');
  });

  test('falls back to French for an unsupported saved value', () async {
    final box = await Hive.openBox('settingsBox');
    await box.put('language', 'de');
    await box.close();

    await initLanguage();

    expect(currentLanguage, 'fr');
  });

  test(
    'setLanguage persists the choice and rejects unsupported values',
    () async {
      await setLanguage('en');
      expect(currentLanguage, 'en');

      await setLanguage('de');
      expect(currentLanguage, 'fr');
      expect(languageNotifier.value, 'fr');

      final box = await Hive.openBox('settingsBox');
      expect(box.get('language'), 'fr');
      await box.close();
    },
  );
}
