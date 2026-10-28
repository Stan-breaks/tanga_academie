import 'package:flutter/material.dart';
import 'package:tanga_acadamie/screens/instructor/instructor_chat_list.dart';
import 'package:tanga_acadamie/screens/instructor/instructor_dashboard.dart';
import 'package:tanga_acadamie/screens/shared/custom_appbar.dart';
import 'package:tanga_acadamie/screens/shared/profile_page.dart';
import 'package:tanga_acadamie/screens/shared/tanga_chat_screen.dart';
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

  // Pages are built lazily on first visit and then kept alive, so switching
  // tabs neither disposes their state nor re-runs their network requests.
  final Set<int> _loadedPages = {};

  void _onItemTapped(int index) {
    if (index == 3 && widget.isLoggedIn) {
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
    _index = 0;
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
        selectedIndex: _index > 2 ? 0 : _index,
        onDestinationSelected: _onItemTapped,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard_rounded),
            label: isFr ? 'Tableau de bord' : 'Dashboard',
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
