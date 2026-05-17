import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ── Profile Section ──
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _skillController = TextEditingController();
  final _bioController = TextEditingController();

  String _userId = '';
  String _email = '';
  String? _profileImageUrl;
  File? _pickedImage;
  bool _isLoadingProfile = true;
  bool _isSavingProfile = false;

  // ── Password Section ──
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final List<TextEditingController> _codeControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isSendingCode = false;
  bool _isResettingPassword = false;
  bool _codeSent = false;
  bool _passwordChanged = false;

  // Field length limits (matching backend)
  static const _limits = {
    'firstName': 50,
    'lastName': 50,
    'username': 30,
    'skill': 100,
    'bio': 200,
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _skillController.dispose();
    _bioController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (var c in _codeControllers) {
      c.dispose();
    }
    for (var n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = await getUser();
    setState(() {
      _userId = (user['userId'] ?? '').toString();
      _email = (user['email'] ?? '').toString();
      _firstNameController.text = (user['firstName'] ?? '').toString();
      _lastNameController.text = (user['lastName'] ?? '').toString();
      _usernameController.text = (user['username'] ?? '').toString();
      _phoneController.text = (user['phoneNumber'] ?? '').toString();
      _skillController.text = (user['skill'] ?? '').toString();
      _bioController.text = (user['bio'] ?? '').toString();

      final profile = user['profile'];
      if (profile != null && profile.toString().isNotEmpty) {
        _profileImageUrl = ApiConfig.getImageUrl(profile.toString());
      }
      _isLoadingProfile = false;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSavingProfile = true);

    try {
      final token = await getToken();
      if (token == null) throw Exception('Not authenticated');

      final apiUrl = ApiConfig.baseUrl;
      final uri = Uri.parse('$apiUrl/api/users/$_userId');

      final request = http.MultipartRequest('PUT', uri);
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['firstName'] = _firstNameController.text.trim();
      request.fields['lastName'] = _lastNameController.text.trim();
      request.fields['username'] = _usernameController.text.trim();
      request.fields['phoneNumber'] = _phoneController.text.trim();
      request.fields['skill'] = _skillController.text.trim();
      request.fields['bio'] = _bioController.text.trim();

      if (_pickedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('profileImage', _pickedImage!.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final updatedUser = jsonDecode(response.body);
        await saveUser(updatedUser);

        // Refresh local state
        if (updatedUser['profile'] != null) {
          setState(() {
            _profileImageUrl = ApiConfig.getImageUrl(
              updatedUser['profile'].toString(),
            );
            _pickedImage = null;
          });
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(isFr ? 'Profil mis à jour avec succès !' : 'Profile updated successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur de mise à jour');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${isFr ? 'Erreur : ' : 'Error: '}${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  // ── Password Change Methods ──

  Future<void> _sendVerificationCode() async {
    if (_email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFr ? 'Email non trouvé. Veuillez vous reconnecter.' : 'Email not found. Please log in again.'),
        ),
      );
      return;
    }

    setState(() => _isSendingCode = true);

    try {
      final apiUrl = dotenv.env['API_URL'];
      if (apiUrl == null) throw Exception('API_URL not found');

      final response = await http.post(
        Uri.parse('$apiUrl/api/auth/forgotPasswordCode'),
        body: jsonEncode({'email': _email}),
        headers: {'Content-Type': 'application/json'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() => _codeSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isFr ? 'Code envoyé à' : 'Code sent to'} $_email'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Erreur');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${isFr ? 'Erreur : ' : 'Error: '}${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _resetPassword() async {
    final code = _codeControllers.map((c) => c.text).join();
    final newPassword = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFr ? 'Veuillez entrer le code complet (6 chiffres)' : 'Enter the complete code (6 digits)'),
        ),
      );
      return;
    }

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isFr ? 'Veuillez remplir tous les champs' : 'Please fill in all fields')),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isFr ? 'Les mots de passe ne correspondent pas' : 'Passwords do not match')),
      );
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFr ? 'Le mot de passe doit contenir au moins 6 caractères' : 'Password must be at least 6 characters'),
        ),
      );
      return;
    }

    setState(() => _isResettingPassword = true);

    try {
      final apiUrl = dotenv.env['API_URL'];
      if (apiUrl == null) throw Exception('API_URL not found');

      final response = await http.post(
        Uri.parse('$apiUrl/api/auth/resetPassword'),
        body: jsonEncode({
          'email': _email,
          'code': code,
          'newPassword': newPassword,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _passwordChanged = true;
          _codeSent = false;
        });
        // Clear fields
        _passwordController.clear();
        _confirmPasswordController.clear();
        for (var c in _codeControllers) {
          c.clear();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(isFr ? 'Mot de passe réinitialisé avec succès !' : 'Password reset successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Code invalide');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${isFr ? 'Erreur : ' : 'Error: '}${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isResettingPassword = false);
    }
  }

  void _onCodeChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          isFr ? 'Paramètres' : 'Settings',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoadingProfile
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Colors.blueAccent,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isFr ? 'Chargement...' : 'Loading...',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ══════════════════════════════════════
                  // SECTION 1: PROFILE
                  // ══════════════════════════════════════
                  _buildSectionHeader(
                    isFr ? 'Modifier le profil' : 'Edit Profile',
                    Icons.person_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildProfileSection(),
                  const SizedBox(height: 32),

                  // ══════════════════════════════════════
                  // SECTION 2: PASSWORD
                  // ══════════════════════════════════════
                  _buildSectionHeader(
                    isFr ? 'Changer le mot de passe' : 'Change Password',
                    Icons.lock_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordSection(),
                  const SizedBox(height: 32),

                  // ══════════════════════════════════════
                  // SECTION 3: LANGUAGE
                  // ══════════════════════════════════════
                  _buildSectionHeader(
                    isFr ? 'Langue' : 'Language',
                    Icons.translate_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildLanguageSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // ── Section Header ──

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.blueAccent, size: 22),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // PROFILE SECTION
  // ══════════════════════════════════════════════════════════

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Profile Image
          _buildProfileImagePicker(),
          const SizedBox(height: 24),

          // Form Fields (2-column grid for name fields)
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _firstNameController,
                  label: isFr ? 'Prénom' : 'First Name',
                  icon: Icons.person_outline,
                  maxLength: _limits['firstName'],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _lastNameController,
                  label: isFr ? 'Nom' : 'Last Name',
                  icon: Icons.person_outline,
                  maxLength: _limits['lastName'],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _usernameController,
            label: isFr ? "Nom d'utilisateur" : 'Username',
            icon: Icons.alternate_email,
            maxLength: _limits['username'],
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _phoneController,
            label: isFr ? 'Numéro de téléphone' : 'Phone Number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _skillController,
            label: isFr ? 'Compétence / Profession' : 'Skill / Profession',
            icon: Icons.work_outline,
            maxLength: _limits['skill'],
          ),
          const SizedBox(height: 16),

          // Bio (multiline)
          _buildTextField(
            controller: _bioController,
            label: isFr ? 'Biographie' : 'Biography',
            icon: Icons.edit_note,
            maxLength: _limits['bio'],
            maxLines: 4,
            showCounter: true,
          ),
          const SizedBox(height: 24),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSavingProfile ? null : _saveProfile,
              icon: _isSavingProfile
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 20),
              label: Text(
                _isSavingProfile
                    ? (isFr ? 'Enregistrement...' : 'Saving...')
                    : (isFr ? 'Mettre à jour le profil' : 'Update Profile'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.blueAccent.withAlpha(150),
                disabledForegroundColor: Colors.white70,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImagePicker() {
    final hasImage =
        _pickedImage != null ||
        (_profileImageUrl != null && _profileImageUrl!.isNotEmpty);

    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent.withAlpha(25),
                  border: Border.all(
                    color: Colors.blueAccent.withAlpha(50),
                    width: 3,
                  ),
                  image: _pickedImage != null
                      ? DecorationImage(
                          image: FileImage(_pickedImage!),
                          fit: BoxFit.cover,
                        )
                      : (_profileImageUrl != null &&
                            _profileImageUrl!.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(_profileImageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: !hasImage
                    ? const Icon(
                        Icons.person,
                        size: 44,
                        color: Colors.blueAccent,
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isFr ? "Appuyez pour changer l'image" : 'Tap to change image',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int? maxLength,
    int maxLines = 1,
    bool showCounter = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLength: showCounter ? maxLength : null,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            prefixIcon: Icon(icon, size: 20, color: Colors.blueAccent),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            counterText: showCounter ? null : '',
          ),
          inputFormatters: maxLength != null && !showCounter
              ? [LengthLimitingTextInputFormatter(maxLength)]
              : null,
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // PASSWORD SECTION
  // ══════════════════════════════════════════════════════════

  Widget _buildPasswordSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success state
          if (_passwordChanged && !_codeSent) ...[
            _buildPasswordSuccessState(),
          ]
          // Initial state: show "Send Code" button
          else if (!_codeSent) ...[
            _buildSendCodeState(),
          ]
          // Code sent: show code + password fields
          else ...[
            _buildResetPasswordState(),
          ],
        ],
      ),
    );
  }

  Widget _buildSendCodeState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info text
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueAccent.withAlpha(40)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Colors.blueAccent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: isFr
                            ? 'Un code de vérification sera envoyé à '
                            : 'A verification code will be sent to ',
                      ),
                      TextSpan(
                        text: _email,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Send Code Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isSendingCode ? null : _sendVerificationCode,
            icon: _isSendingCode
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.email_outlined, size: 20),
            label: Text(
              _isSendingCode
                  ? (isFr ? 'Envoi en cours...' : 'Sending...')
                  : (isFr ? 'Envoyer le code' : 'Send Code'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.blueAccent.withAlpha(150),
              disabledForegroundColor: Colors.white70,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResetPasswordState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Code sent info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withAlpha(40)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${isFr ? 'Code envoyé à' : 'Code sent to'} $_email',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Verification Code Label
        Text(
          isFr ? 'Code de vérification' : 'Verification Code',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),

        // 6-digit Code Input
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 45,
              child: TextField(
                controller: _codeControllers[index],
                focusNode: _focusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.blueAccent,
                      width: 2,
                    ),
                  ),
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) => _onCodeChanged(value, index),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),

        // New Password
        _buildTextField(
          controller: _passwordController,
          label: isFr ? 'Nouveau mot de passe' : 'New Password',
          icon: Icons.lock_outline,
        ),
        const SizedBox(height: 16),

        // Confirm Password
        _buildTextField(
          controller: _confirmPasswordController,
          label: isFr ? 'Confirmer le mot de passe' : 'Confirm Password',
          icon: Icons.lock_outline,
        ),
        const SizedBox(height: 24),

        // Reset Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isResettingPassword ? null : _resetPassword,
            icon: _isResettingPassword
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.lock_reset, size: 20),
            label: Text(
              _isResettingPassword
                  ? (isFr ? 'Réinitialisation...' : 'Resetting...')
                  : (isFr ? 'Réinitialiser le mot de passe' : 'Reset Password'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.blueAccent.withAlpha(150),
              disabledForegroundColor: Colors.white70,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Resend Code
        Center(
          child: TextButton(
            onPressed: _isSendingCode ? null : _sendVerificationCode,
            child: Text(
              isFr ? 'Renvoyer le code' : 'Resend Code',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blueAccent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordSuccessState() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isFr
              ? 'Mot de passe réinitialisé avec succès !'
              : 'Password reset successfully!',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () {
            setState(() {
              _passwordChanged = false;
              _codeSent = false;
            });
          },
          child: Text(
            isFr ? 'Changer à nouveau' : 'Change Again',
            style: const TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // LANGUAGE SECTION
  // ══════════════════════════════════════════════════════════

  Widget _buildLanguageSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withAlpha(12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueAccent.withAlpha(35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.translate, color: Colors.blueAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isFr
                        ? 'Choisissez votre langue préférée'
                        : 'Choose your preferred language',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Language options
          _buildLanguageOption(
            flag: '🇬🇧',
            label: 'English',
            subtitle: 'English',
            langCode: 'en',
            isSelected: currentLanguage == 'en',
          ),
          const SizedBox(height: 10),
          _buildLanguageOption(
            flag: '🇫🇷',
            label: 'Français',
            subtitle: 'French',
            langCode: 'fr',
            isSelected: currentLanguage == 'fr',
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption({
    required String flag,
    required String label,
    required String subtitle,
    required String langCode,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () async {
        await setLanguage(langCode);
        if (mounted) setState(() {});
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withAlpha(12)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected ? Colors.blueAccent : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? Container(
                      key: const ValueKey('selected'),
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    )
                  : Container(
                      key: const ValueKey('unselected'),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
