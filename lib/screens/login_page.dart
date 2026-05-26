import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart';
import 'package:flutter/material.dart';
import 'package:tanga_acadamie/screens/forgot_password_page.dart';
import 'package:tanga_acadamie/screens/home_page.dart';
import 'package:tanga_acadamie/screens/signup_page.dart';
import 'package:tanga_acadamie/screens/verification_page.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isObscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError(
        isFr ? 'Veuillez remplir tous les champs' : 'Please fill in all fields',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiUrl = dotenv.env['API_URL'];
      if (apiUrl == null) {
        throw Exception("API_URL not found in .env file");
      }

      final response = await post(
        Uri.parse('$apiUrl/api/auth/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"emailOrUsername": email, "password": password}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data["token"];
        final user = data["user"];

        await saveUser(user);
        await saveToken(token);

        if (!mounted) return;

        if (user['isVerified']) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomePage(isLoggedIn: true, user: user),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => VerificationPage(email: email)),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        _showError(
          errorData['message'] ??
              (isFr
                  ? 'Échec de connexion. Veuillez réessayer.'
                  : 'Login failed. Please try again.'),
        );
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('timeout') || msg.contains('socketexception') || msg.contains('connection')) {
        _showError(isFr
            ? 'Impossible de se connecter au serveur. Vérifiez votre connexion.'
            : 'Cannot reach server. Check your connection.');
      } else {
        _showError(isFr
            ? 'Une erreur est survenue. Veuillez réessayer.'
            : 'An error occurred. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white),
      body: Container(
        decoration: const BoxDecoration(color: Colors.white),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              final horizontalPad = isWide
                  ? ((constraints.maxWidth - 520) / 2).clamp(24.0, double.infinity)
                  : 24.0;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                child: Column(
                  children: [
                    _buildLogoSection(),
                    const SizedBox(height: 40),
                    _buildLoginCard(),
                    const SizedBox(height: 24),
                    _buildSignUpLink(),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300, maxHeight: 180),
          child: ClipRect(
            child: Image.asset('public/logo.jpeg', fit: BoxFit.contain),
          ),
        ),

        const SizedBox(height: 24),
        // Subtitle
        Text(
          isFr
              ? 'Connectez-vous pour continuer votre apprentissage'
              : 'Sign in to continue your learning journey',
          style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome Text
          Text(
            isFr ? 'Bon retour !' : 'Welcome back!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFr
                ? 'Entrez vos identifiants pour accéder à votre compte'
                : 'Enter your credentials to access your account',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 28),

          // Email Field
          _buildInputField(
            controller: _emailController,
            label: isFr ? 'E-mail ou nom d\'utilisateur' : 'Email or Username',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          // Password Field
          _buildInputField(
            controller: _passwordController,
            label: isFr ? 'Mot de passe' : 'Password',
            icon: Icons.lock_outline,
            isPassword: true,
          ),
          const SizedBox(height: 12),

          // Forgot Password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.blueAccent,
                padding: EdgeInsets.zero,
              ),
              child: Text(
                isFr ? 'Mot de passe oublié ?' : 'Forgot Password?',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Login Button
          _buildLoginButton(),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _isObscure : false,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 15),
          prefixIcon: Icon(icon, color: Colors.blueAccent, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isObscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey.shade500,
                    size: 22,
                  ),
                  onPressed: () {
                    setState(() => _isObscure = !_isObscure);
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          disabledBackgroundColor: Colors.blueAccent.withAlpha(150),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.login_rounded, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    isFr ? 'Se connecter' : 'Sign In',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                isFr ? 'ou' : 'or',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: 20),

        // Sign Up Button
        OutlinedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignupPage()),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blueAccent,
            side: const BorderSide(color: Colors.blueAccent, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_add_outlined, size: 22),
              const SizedBox(width: 10),
              Text(
                isFr ? 'Créer un nouveau compte' : 'Create New Account',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Skip for now
        TextButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const HomePage(isLoggedIn: false),
              ),
            );
          },
          child: Text(
            isFr ? 'Continuer en tant qu\'invité' : 'Continue as Guest',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
