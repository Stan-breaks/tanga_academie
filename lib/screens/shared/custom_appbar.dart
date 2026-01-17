import 'package:flutter/material.dart';

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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF455A64), // Blue Grey 700
              Color(0xFF607D8B), // Blue Grey 500
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.school, color: Colors.white, size: 24),
          ),
          SizedBox(width: 12),
          Text(
            'Tanga Academie',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: EdgeInsets.only(right: 12, top: 8, bottom: 8),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(51),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              isLoggedIn ? 'Logout' : 'Login',
              style: TextStyle(
                color: isLoggedIn ? Colors.red.shade300 : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
