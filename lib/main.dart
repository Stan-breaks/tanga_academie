import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tanga_acadamie/screens/home_page.dart';
import 'package:tanga_acadamie/screens/login_page.dart';
import 'package:tanga_acadamie/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await dotenv.load(fileName: ".env");

  final token = await getToken();
  final user = await getUser();
  final isLoggedIn =
      token != null &&
      token.isNotEmpty &&
      user['email'] != null &&
      user['email'].isNotEmpty &&
      user['role'] != null &&
      user['role'].isNotEmpty;
  runApp(MyApp(isLoggedIn: isLoggedIn));
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
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: HomePage(isLoggedIn: isLoggedIn, user: user),
    );
  }
}
