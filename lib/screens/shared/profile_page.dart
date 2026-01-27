import 'package:flutter/material.dart';
import 'package:tanga_acadamie/screens/login_page.dart';
import 'package:tanga_acadamie/storage_service.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          IconButton(
            onPressed: () async {
              await logout();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            color: Colors.redAccent,
            icon: Icon(Icons.logout),
          ),
        ],
      ),
    );
  }
}
