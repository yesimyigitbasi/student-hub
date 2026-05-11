
import 'package:flutter/material.dart';

void main() {
  runApp(const Week12App());
}

class Week12App extends StatelessWidget {
  const Week12App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CMPE408 Week 12',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF065A82)),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

/// Bottom-navigation shell that will host all four feature screens.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  // We'll replace these placeholders one by one in later steps.
  static const _screens = <Widget>[
    PlaceholderScreen(icon: Icons.web, label: 'WebView'),
    PlaceholderScreen(icon: Icons.vibration, label: 'Sensors'),
    PlaceholderScreen(icon: Icons.map, label: 'Maps & GPS'),
    PlaceholderScreen(icon: Icons.storage, label: 'SQLite'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.web), label: 'Browser'),
          NavigationDestination(icon: Icon(Icons.vibration), label: 'Sensors'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Maps'),
          NavigationDestination(icon: Icon(Icons.storage), label: 'Notes'),
        ],
      ),
    );
  }
}

/// Generic placeholder used before each feature is implemented.
class PlaceholderScreen extends StatelessWidget {
  final IconData icon;
  final String label;

  const PlaceholderScreen({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              '$label\ncoming soon…',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}
