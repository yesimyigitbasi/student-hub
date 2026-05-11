// ═══════════════════════════════════════════════════════════════════════════
// CMPE408 Week 12 — Step 2: Motion Events (Accelerometer + Shake Detection)
//
// New in this step:
//   • sensors_plus dependency
//   • Live accelerometer & gyroscope streams
//   • Shake detection with threshold + debounce
//   • Animated widget that tilts with the phone
//   • Haptic feedback on shake
//
// pubspec.yaml additions:
//   dependencies:
//     sensors_plus: ^4.0.2
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';        // HapticFeedback
import 'package:sensors_plus/sensors_plus.dart';
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
    BrowserScreen(),
    SensorsScreen(),                                       // ← NEW
    PlaceholderScreen(icon: Icons.map,     label: 'Maps & GPS'),
    PlaceholderScreen(icon: Icons.storage, label: 'SQLite'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.web),       label: 'Browser'),
          NavigationDestination(icon: Icon(Icons.vibration), label: 'Sensors'),
          NavigationDestination(icon: Icon(Icons.map),       label: 'Maps'),
          NavigationDestination(icon: Icon(Icons.storage),   label: 'Notes'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sensors Screen
// ─────────────────────────────────────────────────────────────────────────────
class SensorsScreen extends StatefulWidget {
  const SensorsScreen({super.key});

  @override
  State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen> {
  // ── Accelerometer state ──────────────────────────────────────────────────
  double _ax = 0, _ay = 0, _az = 0;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  // ── Gyroscope state ──────────────────────────────────────────────────────
  double _gx = 0, _gy = 0, _gz = 0;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  // ── Shake detection ──────────────────────────────────────────────────────
  static const _shakeThreshold = 20.0;
  DateTime? _lastShake;
  int _shakeCount = 0;

  @override
  void initState() {
    super.initState();

    // Accelerometer stream (uiInterval ≈ 60 Hz — smooth animation)
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen((event) {
      setState(() {
        _ax = event.x;
        _ay = event.y;
        _az = event.z;
      });
      _detectShake(event);
    });

    // Gyroscope stream
    _gyroSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((event) {
      setState(() {
        _gx = event.x;
        _gy = event.y;
        _gz = event.z;
      });
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();   // ← Always cancel streams to stop GPS/sensor use
    _gyroSub?.cancel();
    super.dispose();
  }

  // ── Shake detection algorithm ────────────────────────────────────────────
  void _detectShake(AccelerometerEvent e) {
    final magnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    final force = (magnitude - 9.8).abs();   // subtract gravity

    if (force > _shakeThreshold) {
      final now = DateTime.now();
      if (_lastShake != null &&
          now.difference(_lastShake!) < const Duration(milliseconds: 500)) {
        return;   // debounce
      }
      _lastShake = now;
      setState(() => _shakeCount++);
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shake #$_shakeCount detected! 📳'),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  // ── Tilt angles derived from accelerometer ───────────────────────────────
  double get _tiltX => (_ax / 9.8).clamp(-1.0, 1.0);
  double get _tiltY => (_ay / 9.8).clamp(-1.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Motion Sensors'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _shakeCount = 0),
            tooltip: 'Reset shake count',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Tilt visualizer ─────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Tilt Visualizer',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Grid background
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              border: Border.all(color: Colors.blue.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          // Cross-hair lines
                          Positioned(
                            left: 100, top: 0, bottom: 0,
                            child: Container(width: 1, color: Colors.blue.shade200),
                          ),
                          Positioned(
                            top: 100, left: 0, right: 0,
                            child: Container(height: 1, color: Colors.blue.shade200),
                          ),
                          // Ball that moves with tilt
                          Positioned(
                            left: 100 + _tiltX * 80 - 15,
                            top:  100 - _tiltY * 80 - 15,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.primary,
                                boxShadow: const [
                                  BoxShadow(blurRadius: 6, color: Colors.black26),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Tilt your phone to move the ball',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Accelerometer values ────────────────────────────────────
            _SensorCard(
              title: 'Accelerometer (m/s²)',
              icon: Icons.phone_android,
              values: [
                ('X', _ax, Colors.red),
                ('Y', _ay, Colors.green),
                ('Z', _az, Colors.blue),
              ],
            ),
            const SizedBox(height: 12),

            // ── Gyroscope values ────────────────────────────────────────
            _SensorCard(
              title: 'Gyroscope (rad/s)',
              icon: Icons.rotate_90_degrees_ccw,
              values: [
                ('X', _gx, Colors.orange),
                ('Y', _gy, Colors.purple),
                ('Z', _gz, Colors.teal),
              ],
            ),
            const SizedBox(height: 12),

            // ── Shake counter ───────────────────────────────────────────
            Card(
              color: _shakeCount > 0 ? Colors.orange.shade50 : null,
              child: ListTile(
                leading: const Icon(Icons.vibration, size: 32),
                title: const Text('Shake Count'),
                subtitle: const Text('Shake the device hard!'),
                trailing: Text(
                  '$_shakeCount',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable card that shows sensor axis values with progress bars.
class _SensorCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<(String, double, Color)> values;

  const _SensorCard({
    required this.title,
    required this.icon,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 12),
            for (final (axis, value, color) in values) ...[
              Row(children: [
                SizedBox(
                  width: 20,
                  child: Text(axis, style: TextStyle(
                      fontWeight: FontWeight.bold, color: color)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: ((value + 20) / 40).clamp(0.0, 1.0),
                    backgroundColor: color.withOpacity(0.15),
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: Text(value.toStringAsFixed(2),
                      style: const TextStyle(fontFamily: 'monospace')),
                ),
              ]),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BrowserScreen (unchanged from Step 1) — abbreviated for brevity
// ─────────────────────────────────────────────────────────────────────────────
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});
  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late final WebViewController _controller;
  final _urlCtrl = TextEditingController(text: 'https://flutter.dev');
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse('https://flutter.dev'));
  }

  @override
  void dispose() { _urlCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browser'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _urlCtrl,
              decoration: InputDecoration(
                hintText: 'Enter URL…', isDense: true, filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward),
                    onPressed: () => _controller.loadRequest(
                        Uri.parse(_urlCtrl.text.startsWith('http') ? _urlCtrl.text : 'https://${_urlCtrl.text}'))),
              ),
              onSubmitted: (url) => _controller.loadRequest(
                  Uri.parse(url.startsWith('http') ? url : 'https://$url')),
            ),
          ),
        ),
      ),
      body: Stack(children: [
        WebViewWidget(controller: _controller),
        if (_loading) const LinearProgressIndicator(),
      ]),
      bottomNavigationBar: BottomAppBar(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios),
              onPressed: () async { if (await _controller.canGoBack()) _controller.goBack(); }),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _controller.reload()),
          IconButton(icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () async { if (await _controller.canGoForward()) _controller.goForward(); }),
        ]),
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final IconData icon;
  final String label;
  const PlaceholderScreen({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 80, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text('$label\ncoming soon…', textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
      ])),
    );
  }
}
