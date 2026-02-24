import 'package:flutter/material.dart';
import 'package:tanga_acadamie/screens/instructor/instructor_chat_list.dart';
import 'package:tanga_acadamie/screens/instructor/instructor_dashboard.dart';
import 'package:tanga_acadamie/screens/shared/custom_appbar.dart';
import 'package:tanga_acadamie/screens/shared/profile_page.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

class InstructorHomePage extends StatefulWidget {
  final bool isLoggedIn;
  final Map<String, dynamic> user;
  const InstructorHomePage({
    super.key,
    required this.isLoggedIn,
    required this.user,
  });

  @override
  State<InstructorHomePage> createState() => _InstructorHomeState();
}

class _InstructorHomeState extends State<InstructorHomePage> {
  late int _index;

  final List<Widget> _pages = const [
    InstructorDashboard(),
    InstructorChatList(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _index = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _index = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppbar(isLoggedIn: widget.isLoggedIn),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_index],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.book_outlined, Icons.book, isFr ? 'Tableau de bord' : 'Dashboard'),
                _buildNavItem(1, Icons.chat_bubble_outline, Icons.chat_bubble, isFr ? 'Messages' : 'Messages'),
                _buildNavItem(2, Icons.person_outline, Icons.person, isFr ? 'Profil' : 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _index == index;
    
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? Colors.blueAccent : Colors.grey.shade500,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
