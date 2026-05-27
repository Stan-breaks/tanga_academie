import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tanga_acadamie/screens/home_page.dart';
import 'package:tanga_acadamie/screens/login_page.dart';
import 'package:tanga_acadamie/screens/instructor/create_course_page.dart';
import 'package:tanga_acadamie/screens/instructor/instructor_courses_page.dart';
import 'package:tanga_acadamie/screens/instructor/instructor_assignment_page.dart';
import 'package:tanga_acadamie/screens/instructor/instructor_quiz_page.dart';
import 'package:tanga_acadamie/screens/instructor/instructor_student_progress_page.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/auth_service.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  await Hive.initFlutter();
  await dotenv.load(fileName: ".env");
  await initLanguage();

  // Silently refresh access token if near expiry before deciding auth state
  await ensureFreshToken();

  final token = await getToken();
  final user = await getUser();
  final isLoggedIn =
      token != null &&
      token.isNotEmpty &&
      user['email'] != null &&
      user['email'].isNotEmpty &&
      user['role'] != null &&
      user['role'].isNotEmpty;
  FlutterNativeSplash.remove();
  runApp(MyApp(isLoggedIn: isLoggedIn, user: user));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final Map<String, dynamic> user;
  const MyApp({
    super.key,
    required this.isLoggedIn,
    this.user = const {"role": "guest"},
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tanga Academie',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: HomePage(isLoggedIn: isLoggedIn, user: user),
      debugShowCheckedModeBanner: false,
      routes: {
        '/create-course': (context) => const CreateCoursePage(),
        '/instructor-courses': (context) => const InstructorCoursesPage(),
        '/instructor-assignments': (context) => const InstructorAssignmentPage(),
        '/instructor-quiz': (context) => const InstructorQuizPage(),
        '/instructor-student-progress': (context) => const InstructorStudentProgressPage(),
        '/login': (context) => const LoginPage(),
      },
    );
  }
}

