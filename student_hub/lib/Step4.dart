import 'package:flutter/material.dart';

void main() {
  runApp(const StudentHubApp());
}

class StudentHubApp extends StatelessWidget {
  const StudentHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Hub',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const CourseListScreen(),
    );
  }
}


class CourseListScreen extends StatelessWidget {
  const CourseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Hub'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add Course Clicked!')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          GestureDetector(
            onLongPress: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Drop Course?"),
                  content: const Text("Are you sure you want to drop CS101?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Course Dropped!')),
                        );
                      },
                      child: const Text("Drop", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
            child: Card(
              child: ListTile(
                title: const Text('CS101: Intro to Programming', style: TextStyle(fontSize: 18)),
                subtitle: const Text('Long press to drop course'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const CourseDetailScreen(courseName: 'CS101'),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0); 
                        const end = Offset.zero;
                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeOut));
                        return SlideTransition(position: animation.drive(tween), child: child);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class CourseDetailScreen extends StatelessWidget {
  final String courseName;
  const CourseDetailScreen({super.key, required this.courseName});

  @override
  Widget build(BuildContext context) {
    //////////////////////////////////////////////
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(courseName),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          // ADD THE TAB BAR
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Syllabus', icon: Icon(Icons.menu_book)),
              Tab(text: 'Grades', icon: Icon(Icons.grade)),
            ],
          ),
        ),
        // ADD THE VIEWPAGER EQUIVALENT
        body: const TabBarView(
          children: [
            SyllabusTab(), 
            GradesTab(),   
          ],
        ),
      ),
    );
  }
}

class SyllabusTab extends StatelessWidget {
  const SyllabusTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Syllabus content goes here'));
  }
}

class GradesTab extends StatelessWidget {
  const GradesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Grades content goes here'));
  }
}
////////////////////////////////////////////