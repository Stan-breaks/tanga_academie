import 'package:flutter/material.dart';
import 'package:tanga_acadamie/screens/instructor/instructor_chat_list.dart';
import 'package:tanga_acadamie/screens/instructor/instructor_dashboard.dart';
import 'package:tanga_acadamie/screens/shared/custom_appbar.dart';
import 'package:tanga_acadamie/screens/shared/profile_page.dart';

class InstructorHomePage extends StatefulWidget {
  final bool isLoggedIn;
  final Map<String, dynamic> user;
  const InstructorHomePage({super.key, required this.isLoggedIn, required this.user});

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
    _index = widget.isLoggedIn ? 1 : 0;
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Mon profil',
          ),
        ],

        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
