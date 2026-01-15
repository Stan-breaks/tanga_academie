import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart';
import 'package:flutter/material.dart';
import 'package:tanga_acadamie/screens/forgot_password_page.dart';
import 'package:tanga_acadamie/screens/home_page.dart';
import 'package:tanga_acadamie/screens/signup_page.dart';
import 'package:tanga_acadamie/screens/verification_page.dart';
import 'package:tanga_acadamie/storage_service.dart';

//check if token is there then redirect if it is there
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailcontroller = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isobscure = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Tanga Acadamie",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailcontroller,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _isobscure,
                decoration: InputDecoration(
                  labelText: "password",
                  border: OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isobscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isobscure = !_isobscure;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final email = _emailcontroller.text;
                  final password = _passwordController.text;
                  final apiUrl = dotenv.env['API_URL'];
                  if (apiUrl == null) {
                    throw Exception("API_URL not found in .env file");
                  }

                  final response = await post(
                    Uri.parse('$apiUrl/api/auth/login'),
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({
                      "emailOrUsername": email,
                      "password": password,
                    }),
                  );
                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    final token = data["token"];
                    final user = data["user"];

                    await saveUser(user);
                    await saveToken(token);

                    if (!context.mounted) return;
                    if (user['isVerified']) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomePage()),
                      );
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VerificationPage(email: email),
                        ),
                      );
                    }
                  } else {
                    final error = response.body;
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error)));
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text("Login"),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordPage(),
                    ),
                  );
                },
                child: const Text("Forgot password?"),
              ),
              const SizedBox(height: 30),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignupPage()),
                  );
                },
                child: const Text(
                  "Don't have an account?",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
