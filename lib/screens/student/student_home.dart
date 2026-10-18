import 'package:flutter/material.dart';
import 'package:tanga_acadamie/screens/shared/custom_appbar.dart';
import 'package:tanga_acadamie/screens/shared/explore_page.dart';
import 'package:tanga_acadamie/screens/shared/profile_page.dart';
import 'package:tanga_acadamie/screens/student/student_chat_list.dart';
import 'package:tanga_acadamie/screens/student/student_dashboard.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

class StudentHome extends StatefulWidget {
  final bool isLoggedIn;
  final Map<String, dynamic> user;
  const StudentHome({super.key, required this.isLoggedIn, required this.user});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  late int _index;

  final List<Widget> _pages = const [
    ExplorePage(),
    StudentDashboard(),
    StudentChatList(),
    ProfilePage(),
  ];

  // Pages are built lazily on first visit and then kept alive, so switching
  // tabs neither disposes their state nor re-runs their network requests.
  final Set<int> _loadedPages = {};

  void _onItemTapped(int index) {
    setState(() {
      _index = index;
      _loadedPages.add(index);
    });
  }

  @override
  void initState() {
    super.initState();
    _index = widget.isLoggedIn ? 1 : 0;
    _loadedPages.add(_index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppbar(isLoggedIn: widget.isLoggedIn),
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _pages.length; i++)
            _loadedPages.contains(i) ? _pages[i] : const SizedBox.shrink(),
        ],
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
                _buildNavItem(0, Icons.explore_outlined, Icons.explore, isFr ? 'Explorer' : 'Explore'),
                _buildNavItem(1, Icons.school_outlined, Icons.school, isFr ? 'Apprendre' : 'Learn'),
                _buildNavItem(2, Icons.chat_bubble_outline, Icons.chat_bubble, isFr ? 'Messages' : 'Messages'),
                _buildNavItem(3, Icons.person_outline, Icons.person, isFr ? 'Profil' : 'Profile'),
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
