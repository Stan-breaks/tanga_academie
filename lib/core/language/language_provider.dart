import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// The language the app falls back to when the user has never picked one.
const String defaultLanguage = 'fr';

/// Languages the app can display.
const List<String> supportedLanguages = <String>['fr', 'en'];

/// Global language variable: 'en' or 'fr'.
String currentLanguage = defaultLanguage;

/// Notifies the root [MaterialApp] when the language changes so that Flutter's
/// own localized widgets (date pickers, text selection menus, etc.) switch too.
final ValueNotifier<String> languageNotifier = ValueNotifier<String>(
  defaultLanguage,
);

/// Load saved language from storage. Call once in main().
Future<void> initLanguage() async {
  final box = await Hive.openBox('settingsBox');
  final saved = box.get('language', defaultValue: defaultLanguage);
  currentLanguage = saved is String && supportedLanguages.contains(saved)
      ? saved
      : defaultLanguage;
  languageNotifier.value = currentLanguage;
  await box.close();
}

/// Update & persist the language.
Future<void> setLanguage(String lang) async {
  final value = supportedLanguages.contains(lang) ? lang : defaultLanguage;
  currentLanguage = value;
  languageNotifier.value = value;
  final box = await Hive.openBox('settingsBox');
  await box.put('language', value);
  await box.close();
}

/// Shorthand: returns true when French is active.
bool get isFr => currentLanguage == 'fr';
