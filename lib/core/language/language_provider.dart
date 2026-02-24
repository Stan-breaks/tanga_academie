import 'package:hive/hive.dart';

/// Global language variable: 'en' or 'fr'
String currentLanguage = 'en';

/// Load saved language from storage. Call once in main().
Future<void> initLanguage() async {
  final box = await Hive.openBox('settingsBox');
  currentLanguage = box.get('language', defaultValue: 'en') as String;
  await box.close();
}

/// Update & persist the language.
Future<void> setLanguage(String lang) async {
  currentLanguage = lang;
  final box = await Hive.openBox('settingsBox');
  await box.put('language', lang);
  await box.close();
}

/// Shorthand: returns true when French is active.
bool get isFr => currentLanguage == 'fr';
