import 'package:flutter/material.dart';
import 'package:tanga_acadamie/screens/student/explore_page.dart';
import 'package:tanga_acadamie/screens/student/profile_page.dart';
import 'package:tanga_acadamie/screens/student/student_dashboard.dart';

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
      appBar: AppBar(
        title: const Text('Tanga academie'),
        actions: [
          IconButton(icon: const Icon(Icons.notifications), onPressed: () {}),
        ],
      ),
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        fixedColor: Colors.greenAccent,
        currentIndex: _index,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Learn'),
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
