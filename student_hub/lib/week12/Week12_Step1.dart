// ═══════════════════════════════════════════════════════════════════════════
// CMPE408 Week 12 — Step 1: WebView
//
// New in this step:
//   • webview_flutter dependency
//   • WebViewController with JS enabled
//   • NavigationDelegate (loading indicator)
//   • Bottom navigation bar (back / reload / forward)
//   • URL bar with TextField
//
// pubspec.yaml additions:
//   dependencies:
//     webview_flutter: ^4.7.0
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  final _screens = const <Widget>[
    BrowserScreen(),                                      // ← NEW
    PlaceholderScreen(icon: Icons.vibration, label: 'Sensors'),
    PlaceholderScreen(icon: Icons.map,       label: 'Maps & GPS'),
    PlaceholderScreen(icon: Icons.storage,   label: 'SQLite'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.web),      label: 'Browser'),
          NavigationDestination(icon: Icon(Icons.vibration),label: 'Sensors'),
          NavigationDestination(icon: Icon(Icons.map),      label: 'Maps'),
          NavigationDestination(icon: Icon(Icons.storage),  label: 'Notes'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WebView Screen
// ─────────────────────────────────────────────────────────────────────────────
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late final WebViewController _controller;
  final _urlController = TextEditingController(text: 'https://flutter.dev');
  bool _isLoading = false;
  String _currentUrl = 'https://flutter.dev';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() {
            _isLoading = true;
            _currentUrl = url;
            _urlController.text = url;
          }),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onHttpError: (err) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('HTTP error: ${err.response?.statusCode}')),
            );
          },
          onNavigationRequest: (request) {
            // Block navigation to external ad domains (example)
            if (request.url.contains('doubleclick.net')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_currentUrl));
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _navigateTo(String url) {
    // Ensure the URL has a scheme
    final uri = Uri.tryParse(
      url.startsWith('http') ? url : 'https://$url',
    );
    if (uri != null) {
      _controller.loadRequest(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('In-App Browser'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: 'Enter URL…',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _navigateTo(_urlController.text),
                ),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: _navigateTo,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const LinearProgressIndicator(),       // top loading bar
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              tooltip: 'Back',
              onPressed: () async {
                if (await _controller.canGoBack()) {
                  await _controller.goBack();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload',
              onPressed: () => _controller.reload(),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              tooltip: 'Forward',
              onPressed: () async {
                if (await _controller.canGoForward()) {
                  await _controller.goForward();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.javascript),
              tooltip: 'Run JS',
              onPressed: () async {
                // Demo: change page background via JavaScript
                await _controller.runJavaScript(
                  "document.body.style.outline = '4px solid red';",
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder (unchanged from Step 0)
// ─────────────────────────────────────────────────────────────────────────────
class PlaceholderScreen extends StatelessWidget {
  final IconData icon;
  final String label;
  const PlaceholderScreen({super.key, required this.icon, required this.label});

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
            Text('$label\ncoming soon…',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
