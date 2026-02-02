import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tanga_acadamie/screens/login_page.dart';
import 'package:tanga_acadamie/screens/verification_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

// todo: role setting in the SignupPage
class _SignupPageState extends State<SignupPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _userNameController = TextEditingController();
  final _emailController = TextEditingController();
  String _role = "student";
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isobsure = true;
  bool _isobureConfirm = true;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "S'inscrire",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 40),

                // First Name + Last Name Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: "Prénom",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: "Nom de famille",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Username (full width - important for uniqueness)
                TextField(
                  controller: _userNameController,
                  decoration: InputDecoration(
                    labelText: "Nom d'utilisateur",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),

                // Email (full width - needs space for long emails)
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),

                // Role Dropdown (full width)
                DropdownButtonFormField(
                  initialValue: _role,
                  items: const [
                    DropdownMenuItem(value: "student", child: Text("Étudiant")),
                    DropdownMenuItem(
                      value: "instructor",
                      child: Text("Instructeur"),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _role = value!;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: "Je veux m'inscrire en tant que *",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),

                // Password + Confirm Password Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _isobsure,
                        decoration: InputDecoration(
                          labelText: "Mot de passe",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _isobsure = !_isobsure;
                              });
                            },
                            icon: Icon(
                              _isobsure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _confirmPasswordController,
                        obscureText: _isobureConfirm,
                        decoration: InputDecoration(
                          labelText: "Confirmer",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _isobureConfirm = !_isobureConfirm;
                              });
                            },
                            icon: Icon(
                              _isobureConfirm
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  "Image de profil",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final pickedfile = await _picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (pickedfile != null) {
                      setState(() {
                        _selectedImage = File(pickedfile.path);
                      });
                    }
                  },
                  child: Container(
                    height: 120, // Reduced from 150
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Center(
                            child: Text("Appuyez pour sélectionner Image"),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Sign Up Button
                ElevatedButton(
                  onPressed: () async {
                    final firstName = _firstNameController.text;
                    final lastName = _lastNameController.text;
                    final userName = _userNameController.text;
                    final email = _emailController.text;
                    final password = _passwordController.text;
                    final confirmPassword = _confirmPasswordController.text;
                    if (confirmPassword != password) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Passwords do not match")),
                      );
                      return;
                    }

                    final apiUrl = dotenv.env['API_URL'];
                    if (apiUrl == null) {
                      throw Exception("API_URL not found in .env file");
                    }
                    var request =
                        MultipartRequest(
                            'POST',
                            Uri.parse('$apiUrl/api/auth/register'),
                          )
                          ..fields["firstName"] = firstName
                          ..fields["lastName"] = lastName
                          ..fields["username"] = userName
                          ..fields["email"] = email
                          ..fields["role"] = _role
                          ..fields["password"] = password
                          ..fields["confirmPassword"] = confirmPassword
                          ..headers["Content-Type"] = "application/json";

                    if (_selectedImage != null) {
                      request.files.add(
                        await MultipartFile.fromPath(
                          'profile',
                          _selectedImage!.path,
                        ),
                      );
                    }
                    var response = await request.send();
                    if (response.statusCode == 200) {
                      if (!context.mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VerificationPage(email: email),
                        ),
                      );
                    } else {
                      final responseBody = await response.stream.bytesToString();
                      final decoded = jsonDecode(responseBody);

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to register: ${decoded['errors']}")),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: const Text("Sign up"),
                ),
                const SizedBox(height: 12),

                // Login Link
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: const Text("You have an account?"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
