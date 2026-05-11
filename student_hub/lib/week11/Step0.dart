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
      appBar: AppBar(title: const Text('Student Hub')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
           Card(child: ListTile(title: Text('CS101: Intro to Programming'))),
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
    return Scaffold(appBar: AppBar(title: Text(courseName)));
  }
}