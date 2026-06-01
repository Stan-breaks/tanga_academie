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
import 'package:tanga_acadamie/core/core.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController    = TextEditingController();
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
    final email    = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError(isFr ? 'Veuillez remplir tous les champs' : 'Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiUrl = dotenv.env['API_URL'];
      if (apiUrl == null) throw Exception("API_URL not found in .env file");

      final response = await post(
        Uri.parse('$apiUrl/api/auth/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"emailOrUsername": email, "password": password}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data         = jsonDecode(response.body);
        final token        = data["token"];
        final refreshToken = data["refreshToken"];
        final user         = data["user"];

        await saveUser(user);
        await saveToken(token);
        if (refreshToken != null) await saveRefreshToken(refreshToken.toString());

        if (!mounted) return;

        if (user['isVerified']) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomePage(isLoggedIn: true, user: user)),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => VerificationPage(email: email)),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        _showError(errorData['message'] ??
            (isFr ? 'Échec de connexion. Veuillez réessayer.' : 'Login failed. Please try again.'));
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('timeout') || msg.contains('socketexception') || msg.contains('connection')) {
        _showError(isFr
            ? 'Impossible de se connecter au serveur. Vérifiez votre connexion.'
            : 'Cannot reach server. Check your connection.');
      } else {
        _showError(isFr ? 'Une erreur est survenue. Veuillez réessayer.' : 'An error occurred. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppTheme.buttonTextStyle.copyWith(fontWeight: FontWeight.w500))),
        ]),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        margin: const EdgeInsets.all(AppTheme.spaceLg),
        duration: const Duration(seconds: 4),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            final hPad = isWide
                ? ((constraints.maxWidth - 520) / 2).clamp(24.0, double.infinity)
                : AppTheme.spaceXxl;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Column(
                children: [
                  const SizedBox(height: AppTheme.spaceXxl),
                  _buildLogo(),
                  const SizedBox(height: AppTheme.space3xl),
                  _buildCard(),
                  const SizedBox(height: AppTheme.spaceXxl),
                  _buildFooter(),
                  const SizedBox(height: AppTheme.space3xl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300, maxHeight: 180),
          child: ClipRect(child: Image.asset('public/logo.jpeg', fit: BoxFit.contain)),
        ),
        const SizedBox(height: AppTheme.spaceXxl),
        Text(
          isFr
              ? 'Connectez-vous pour continuer votre apprentissage'
              : 'Sign in to continue your learning journey',
          textAlign: TextAlign.center,
          style: AppTheme.bodySecondaryStyle,
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      padding: AppTheme.cardPadding,
      decoration: AppTheme.elevatedCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(isFr ? 'Bon retour !' : 'Welcome back!', style: AppTheme.headlineStyle),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            isFr
                ? 'Entrez vos identifiants pour accéder à votre compte'
                : 'Enter your credentials to access your account',
            style: AppTheme.bodySecondaryStyle,
          ),
          const SizedBox(height: AppTheme.spaceXxl),

          AppInputField(
            controller: _emailController,
            label: isFr ? 'E-mail ou nom d\'utilisateur' : 'Email or Username',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppTheme.spaceLg),

          AppInputField(
            controller: _passwordController,
            label: isFr ? 'Mot de passe' : 'Password',
            icon: Icons.lock_outline,
            obscureText: _isObscure,
            suffixIcon: IconButton(
              icon: Icon(
                _isObscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey.shade500,
                size: 20,
              ),
              onPressed: () => setState(() => _isObscure = !_isObscure),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
              ),
              child: Text(
                isFr ? 'Mot de passe oublié ?' : 'Forgot Password?',
                style: AppTheme.labelStyle.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceXxl),

          AppPrimaryButton(
            label: isFr ? 'Se connecter' : 'Sign In',
            icon: Icons.login_rounded,
            isLoading: _isLoading,
            onPressed: _handleLogin,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
              child: Text(isFr ? 'ou' : 'or', style: AppTheme.bodySecondaryStyle),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: AppTheme.spaceXl),

        AppOutlineButton(
          label: isFr ? 'Créer un nouveau compte' : 'Create New Account',
          icon: Icons.person_add_outlined,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SignupPage()),
          ),
        ),
        const SizedBox(height: AppTheme.spaceLg),

        TextButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage(isLoggedIn: false)),
          ),
          child: Text(
            isFr ? 'Continuer en tant qu\'invité' : 'Continue as Guest',
            style: AppTheme.bodySecondaryStyle,
          ),
        ),
      ],
    );
  }
}
