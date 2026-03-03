import 'package:flutter/material.dart';
import 'package:tanga_acadamie/screens/home_page.dart';
import 'package:tanga_acadamie/screens/login_page.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

class CustomAppbar extends StatelessWidget implements PreferredSizeWidget {
  final bool isLoggedIn;
  const CustomAppbar({super.key, required this.isLoggedIn});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
              Color(0xFF42A5F5), // Blue 400
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Row(
        children: [
          SizedBox(
            width: 50,
            height: 70,
            child: ClipRect(
              child: Image.asset('public/logo.jpeg', fit: BoxFit.contain),
            ),
          ),

          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tanga Academie',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                isFr ? 'Apprendre • Grandir • Réussir' : 'Learn • Grow • Succeed',
                style: TextStyle(
                  color: Colors.black.withAlpha(200),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
          decoration: BoxDecoration(
            gradient: isLoggedIn
                ? LinearGradient(
                    colors: [
                      Colors.red.shade400.withAlpha(200),
                      Colors.red.shade600.withAlpha(200),
                    ],
                  )
                : const LinearGradient(colors: [Colors.white, Colors.white]),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(25),
              onTap: () async {
                if (isLoggedIn) {
                  await logout();
                  if (!context.mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HomePage(isLoggedIn: false),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLoggedIn ? Icons.logout_rounded : Icons.login_rounded,
                      size: 18,
                      color: isLoggedIn ? Colors.white : Colors.blueAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isLoggedIn ? (isFr ? 'Déconnexion' : 'Logout') : (isFr ? 'Connexion' : 'Login'),
                      style: TextStyle(
                        color: isLoggedIn ? Colors.white : Colors.blueAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
