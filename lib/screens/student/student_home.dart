import 'package:flutter/material.dart';
import 'package:tanga_acadamie/screens/student/explore_page.dart';
import 'package:tanga_acadamie/screens/student/profile_page.dart';
import 'package:tanga_acadamie/screens/student/student_dashboard.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  int _index = 0;

  final List<Widget> _pages = const [ExplorePage(),StudentDashboard(), ProfilePage()];

  void _onItemTapped(int index) {
    setState(() {
      _index = index;
    });
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
