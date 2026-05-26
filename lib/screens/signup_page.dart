import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tanga_acadamie/screens/login_page.dart';
import 'package:tanga_acadamie/screens/verification_page.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _userNameController = TextEditingController();
  final _emailController = TextEditingController();
  String _role = "student";
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isObscure = true;
  bool _isObscureConfirm = true;
  bool _isLoading = false;
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
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final userName = _userNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validation
    if (firstName.isEmpty || lastName.isEmpty || userName.isEmpty || email.isEmpty || password.isEmpty) {
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
      if (apiUrl == null) {
        throw Exception("API_URL not found");
      }

      var request = MultipartRequest(
        'POST',
        Uri.parse('$apiUrl/api/auth/register'),
      )
        ..fields["firstName"] = firstName
        ..fields["lastName"] = lastName
        ..fields["username"] = userName
        ..fields["email"] = email
        ..fields["role"] = _role
        ..fields["password"] = password
        ..fields["confirmPassword"] = confirmPassword;
      // NOTE: do NOT set Content-Type header — multipart sets its own boundary automatically

      if (_selectedImage != null) {
        request.files.add(
          await MultipartFile.fromPath('profile', _selectedImage!.path),
        );
      }

      var response = await request.send();

      if (!mounted) return;

      // Accept 200 or 201 (Created)
      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerificationPage(email: email),
          ),
        );
      } else {
        final responseBody = await response.stream.bytesToString();
        String errorMsg;
        try {
          final decoded = jsonDecode(responseBody);
          final errors = decoded['errors'];
          if (errors is List) {
            errorMsg = errors.map((e) => e is Map ? e['msg'] ?? e.toString() : e.toString()).join(', ');
          } else if (errors is String) {
            errorMsg = errors;
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

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blueAccent.shade100,
              Colors.white,
              Colors.white,
            ],
            stops: const [0.0, 0.25, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 30),
                
                // Logo Section
                _buildLogoSection(),
                const SizedBox(height: 30),
                
                // Signup Card
                _buildSignupCard(),
                const SizedBox(height: 24),
                
                // Login Link
                _buildLoginLink(),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        // Logo Container
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blueAccent.shade200,
                Colors.blueAccent.shade700,
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withAlpha(60),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_add_rounded,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        
        // Title
        Text(
          isFr ? 'Créer un compte' : 'Create Account',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        
        // Subtitle
        Text(
          isFr ? 'Rejoignez notre communauté d\'apprentissage' : 'Join our learning community today',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSignupCard() {
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
          // Profile Image Picker
          _buildProfileImagePicker(),
          const SizedBox(height: 24),
          
          // First Name + Last Name Row
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  controller: _firstNameController,
                  label: isFr ? 'Prénom' : 'First Name',
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputField(
                  controller: _lastNameController,
                  label: isFr ? 'Nom' : 'Last Name',
                  icon: Icons.person_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Username
          _buildInputField(
            controller: _userNameController,
            label: isFr ? 'Nom d\'utilisateur' : 'Username',
            icon: Icons.alternate_email,
          ),
          const SizedBox(height: 16),
          
          // Email
          _buildInputField(
            controller: _emailController,
            label: isFr ? 'E-mail' : 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          
          // Role Dropdown
          _buildRoleDropdown(),
          const SizedBox(height: 16),
          
          // Password Row
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  controller: _passwordController,
                  label: isFr ? 'Mot de passe' : 'Password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  isConfirm: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputField(
                  controller: _confirmPasswordController,
                  label: isFr ? 'Confirmer' : 'Confirm',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  isConfirm: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          
          // Signup Button
          _buildSignupButton(),
        ],
      ),
    );
  }

  Widget _buildProfileImagePicker() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 2),
                image: _selectedImage != null
                    ? DecorationImage(
                        image: FileImage(_selectedImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _selectedImage == null
                  ? Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.grey.shade400,
                    )
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool isPassword = false,
    bool isConfirm = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? (isConfirm ? _isObscureConfirm : _isObscure) : false,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    (isConfirm ? _isObscureConfirm : _isObscure)
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isConfirm) {
                        _isObscureConfirm = !_isObscureConfirm;
                      } else {
                        _isObscure = !_isObscure;
                      }
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _role,
        items: [
          DropdownMenuItem(
            value: "student",
            child: Row(
              children: [
                Icon(Icons.school, size: 18, color: Colors.green),
                SizedBox(width: 8),
                Text(isFr ? 'Étudiant' : 'Student'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: "instructor",
            child: Row(
              children: [
                Icon(Icons.architecture, size: 18, color: Colors.blue),
                SizedBox(width: 8),
                Text(isFr ? 'Instructeur' : 'Instructor'),
              ],
            ),
          ),
        ],
        onChanged: (value) {
          setState(() {
            _role = value!;
          });
        },
        decoration: InputDecoration(
          labelText: isFr ? 'Je souhaite m\'inscrire en tant que' : 'I want to register as',
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: const Icon(Icons.badge_outlined, color: Colors.blueAccent, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildSignupButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSignup,
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
                  const Icon(Icons.person_add_rounded, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    isFr ? 'Créer un compte' : 'Create Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                isFr ? 'Vous avez déjà un compte ?' : 'Already have an account?',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: 16),
        
        // Login Button
        OutlinedButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blueAccent,
            side: const BorderSide(color: Colors.blueAccent, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.login_rounded, size: 20),
              const SizedBox(width: 10),
              Text(
                isFr ? 'Se connecter' : 'Sign In Instead',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
