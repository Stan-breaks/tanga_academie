import 'package:flutter/material.dart';
import 'package:tanga_acadamie/screens/shared/custom_appbar.dart';
import 'package:tanga_acadamie/screens/shared/explore_page.dart';
import 'package:tanga_acadamie/screens/shared/profile_page.dart';
import 'package:tanga_acadamie/screens/shared/tanga_chat_screen.dart';
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
    if (index == 4 && widget.isLoggedIn) {
      final firstName = (widget.user['firstName'] ?? '').toString();
      final lastName = (widget.user['lastName'] ?? '').toString();
      final fullName = '$firstName $lastName'.trim();
      final email = (widget.user['email'] ?? '').toString();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TangaChatScreen(
            name: fullName.isNotEmpty ? fullName : null,
            email: email.isNotEmpty ? email : null,
          ),
        ),
      );
      return;
    }
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index > 3 ? 0 : _index,
        onDestinationSelected: _onItemTapped,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore_rounded),
            label: isFr ? 'Explorer' : 'Explore',
          ),
          NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school_rounded),
            label: isFr ? 'Apprendre' : 'Learn',
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: const Icon(Icons.chat_bubble_rounded),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: isFr ? 'Profil' : 'Profile',
          ),
          NavigationDestination(
            icon: const Icon(Icons.support_agent_outlined),
            selectedIcon: const Icon(Icons.support_agent_rounded),
            label: isFr ? 'Aide' : 'Help',
          ),
        ],
      ),
    );
  }
}
