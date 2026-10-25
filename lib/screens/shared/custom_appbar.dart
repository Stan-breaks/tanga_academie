import 'package:flutter/material.dart';
import 'package:tanga_acadamie/screens/home_page.dart';
import 'package:tanga_acadamie/screens/login_page.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';
import 'package:tanga_acadamie/core/theme/app_theme.dart';

class CustomAppbar extends StatelessWidget implements PreferredSizeWidget {
  final bool isLoggedIn;
  const CustomAppbar({super.key, required this.isLoggedIn});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: const Border(bottom: BorderSide(color: AppColors.borderLight)),
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Image.asset('public/logo.jpeg', fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tanga Academie',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                Text(
                  isFr ? 'Apprendre • Grandir • Réussir' : 'Learn • Grow • Succeed',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _buildAuthAction(context),
        ),
      ],
    );
  }

  Widget _buildAuthAction(BuildContext context) {
    final fg = isLoggedIn ? AppColors.error700 : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: isLoggedIn ? AppColors.error50 : AppColors.primary,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: isLoggedIn ? Border.all(color: AppColors.error100) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLoggedIn ? Icons.logout_rounded : Icons.login_rounded,
                  size: 17,
                  color: fg,
                ),
                const SizedBox(width: 6),
                Text(
                  isLoggedIn
                      ? (isFr ? 'Déconnexion' : 'Logout')
                      : (isFr ? 'Connexion' : 'Login'),
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
