import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tanga_acadamie/screens/login_page.dart';
import 'package:tanga_acadamie/screens/verification_page.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:tanga_acadamie/core/core.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _firstNameController   = TextEditingController();
  final _lastNameController    = TextEditingController();
  final _userNameController    = TextEditingController();
  final _emailController       = TextEditingController();
  final _passwordController    = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _role = "student";
  bool _isObscure        = true;
  bool _isObscureConfirm = true;
  bool _isLoading        = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _userNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final firstName     = _firstNameController.text.trim();
    final lastName      = _lastNameController.text.trim();
    final userName      = _userNameController.text.trim();
    final email         = _emailController.text.trim();
    final password      = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (firstName.isEmpty || lastName.isEmpty || userName.isEmpty ||
        email.isEmpty || password.isEmpty) {
      _showError(isFr ? 'Veuillez remplir tous les champs obligatoires' : 'Please fill in all required fields');
      return;
    }

    if (confirmPassword != password) {
      _showError(isFr ? 'Les mots de passe ne correspondent pas' : 'Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiUrl = dotenv.env['API_URL'];
      if (apiUrl == null) throw Exception("API_URL not found");

      var request = MultipartRequest('POST', Uri.parse('$apiUrl/api/auth/register'))
        ..fields["firstName"]       = firstName
        ..fields["lastName"]        = lastName
        ..fields["username"]        = userName
        ..fields["email"]           = email
        ..fields["role"]            = _role
        ..fields["password"]        = password
        ..fields["confirmPassword"] = confirmPassword;

      if (_selectedImage != null) {
        request.files.add(await MultipartFile.fromPath('profile', _selectedImage!.path));
      }

      final response = await request.send();

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => VerificationPage(email: email)),
        );
      } else {
        final body = await response.stream.bytesToString();
        String errorMsg;
        try {
          final decoded = jsonDecode(body);
          final errors  = decoded['errors'];
          if (errors is List) {
            errorMsg = errors.map((e) => e is Map ? e['msg'] ?? e.toString() : e.toString()).join(', ');
          } else {
            errorMsg = decoded['message']?.toString() ?? 'Unknown error';
          }
        } catch (_) {
          errorMsg = 'Registration failed (${response.statusCode})';
        }
        _showError(errorMsg);
      }
    } catch (e) {
      _showError(isFr ? 'Une erreur est survenue. Veuillez réessayer.' : 'An error occurred. Please try again.');
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
          Expanded(child: Text(message, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ]),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        margin: const EdgeInsets.all(AppTheme.spaceLg),
        duration: const Duration(seconds: 4),
      ));
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _selectedImage = File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppTheme.screenPadding,
          child: Column(
            children: [
              const SizedBox(height: AppTheme.spaceXxl),
              _buildHeader(),
              const SizedBox(height: AppTheme.spaceXxl),
              _buildCard(),
              const SizedBox(height: AppTheme.spaceXxl),
              _buildLoginLink(),
              const SizedBox(height: AppTheme.spaceXxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.primaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: const Icon(Icons.person_add_rounded, size: 36, color: Colors.white),
        ),
        const SizedBox(height: AppTheme.spaceXl),
        Text(isFr ? 'Créer un compte' : 'Create Account', style: AppTheme.displayStyle),
        const SizedBox(height: AppTheme.spaceSm),
        Text(
          isFr ? 'Rejoignez notre communauté d\'apprentissage' : 'Join our learning community today',
          style: AppTheme.bodySecondaryStyle,
          textAlign: TextAlign.center,
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
          _buildAvatarPicker(),
          const SizedBox(height: AppTheme.spaceXxl),

          // First + Last name
          Row(
            children: [
              Expanded(
                child: AppInputField(
                  controller: _firstNameController,
                  label: isFr ? 'Prénom' : 'First Name',
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: AppInputField(
                  controller: _lastNameController,
                  label: isFr ? 'Nom' : 'Last Name',
                  icon: Icons.person_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),

          AppInputField(
            controller: _userNameController,
            label: isFr ? 'Nom d\'utilisateur' : 'Username',
            icon: Icons.alternate_email,
          ),
          const SizedBox(height: AppTheme.spaceLg),

          AppInputField(
            controller: _emailController,
            label: isFr ? 'E-mail' : 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppTheme.spaceLg),

          _buildRoleDropdown(),
          const SizedBox(height: AppTheme.spaceLg),

          // Password + Confirm row
          Row(
            children: [
              Expanded(
                child: AppInputField(
                  controller: _passwordController,
                  label: isFr ? 'Mot de passe' : 'Password',
                  icon: Icons.lock_outline,
                  obscureText: _isObscure,
                  suffixIcon: IconButton(
                    icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey.shade500, size: 20),
                    onPressed: () => setState(() => _isObscure = !_isObscure),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: AppInputField(
                  controller: _confirmPasswordController,
                  label: isFr ? 'Confirmer' : 'Confirm',
                  icon: Icons.lock_outline,
                  obscureText: _isObscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(_isObscureConfirm ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey.shade500, size: 20),
                    onPressed: () => setState(() => _isObscureConfirm = !_isObscureConfirm),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space2xl),

          AppPrimaryButton(
            label: isFr ? 'Créer un compte' : 'Create Account',
            icon: Icons.person_add_rounded,
            isLoading: _isLoading,
            onPressed: _handleSignup,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPicker() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    image: _selectedImage != null
                        ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _selectedImage == null
                      ? Icon(Icons.person, size: 50, color: Colors.grey.shade400)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spaceSm),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            isFr ? 'Photo de profil (optionnel)' : 'Profile photo (optional)',
            style: AppTheme.captionStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      decoration: AppTheme.inputDecoration(),
      child: DropdownButtonFormField<String>(
        initialValue: _role,
        decoration: InputDecoration(
          labelText: isFr ? 'Je m\'inscris en tant que' : 'I am registering as',
          labelStyle: AppTheme.captionStyle.copyWith(fontSize: 14),
          prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primary, size: 20),
          border: InputBorder.none,
          contentPadding: AppTheme.inputContentPadding,
        ),
        items: [
          DropdownMenuItem(
            value: "student",
            child: Row(children: [
              const Icon(Icons.school, size: 16, color: Colors.green),
              const SizedBox(width: 8),
              Text(isFr ? 'Étudiant' : 'Student'),
            ]),
          ),
          DropdownMenuItem(
            value: "instructor",
            child: Row(children: [
              const Icon(Icons.architecture, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Text(isFr ? 'Instructeur' : 'Instructor'),
            ]),
          ),
        ],
        onChanged: (v) => setState(() => _role = v!),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
              child: Text(
                isFr ? 'Vous avez déjà un compte ?' : 'Already have an account?',
                style: AppTheme.bodySecondaryStyle,
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: AppTheme.spaceLg),
        AppOutlineButton(
          label: isFr ? 'Se connecter' : 'Sign In Instead',
          icon: Icons.login_rounded,
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          ),
        ),
      ],
    );
  }
}
