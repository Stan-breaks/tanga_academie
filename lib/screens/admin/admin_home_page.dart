import 'package:flutter/material.dart';
import 'package:tanga_acadamie/screens/admin/admin_dashboard.dart';
import 'package:tanga_acadamie/screens/admin/admin_courses_page.dart';
import 'package:tanga_acadamie/screens/admin/admin_chat_list.dart';
import 'package:tanga_acadamie/screens/shared/custom_appbar.dart';
import 'package:tanga_acadamie/screens/shared/profile_page.dart';

class AdminHomePage extends StatefulWidget {
  final bool isLoggedIn;
  final Map<String, dynamic> user;
  
  const AdminHomePage({
    super.key,
    required this.isLoggedIn,
    required this.user,
  });

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  late int _index;

  final List<Widget> _pages = const [
    AdminDashboard(),
    AdminCoursesPage(),
    AdminChatList(),
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
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        fixedColor: Colors.blueGrey,
        currentIndex: _index,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books_outlined),
            activeIcon: Icon(Icons.library_books),
            label: 'Courses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            activeIcon: Icon(Icons.message),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
