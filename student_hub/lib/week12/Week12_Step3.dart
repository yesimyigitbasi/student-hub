// ═══════════════════════════════════════════════════════════════════════════
// CMPE408 Week 12 — Step 3: Google Maps (static display + markers)
//
// New in this step:
//   • google_maps_flutter dependency
//   • GoogleMap widget with custom initial position (Istanbul)
//   • Tap-to-add markers with InfoWindow
//   • Long-press to clear all markers
//   • Map type switcher (normal / satellite / terrain)
//
// pubspec.yaml additions:
//   dependencies:
//     google_maps_flutter: ^2.9.0
//
//  IMPORTANT: Replace YOUR_API_KEY in:
//   Android: android/app/src/main/AndroidManifest.xml
//   iOS:     ios/Runner/AppDelegate.swift
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
    SensorsScreen(),
    MapsScreen(),                                          // ← NEW
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
// Maps Screen
// ─────────────────────────────────────────────────────────────────────────────
class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  MapType _mapType = MapType.normal;
  int _markerCount = 0;

  // Istanbul — Bosphorus Bridge area
  static const _initialCamera = CameraPosition(
    target: LatLng(41.0455, 29.0049),
    zoom: 13,
  );

  // Famous Istanbul landmarks as starting markers
  static const _landmarks = <String, LatLng>{
    'Hagia Sophia':     LatLng(41.0086, 28.9802),
    'Blue Mosque':      LatLng(41.0054, 28.9768),
    'Topkapi Palace':   LatLng(41.0115, 28.9833),
    'Grand Bazaar':     LatLng(41.0108, 28.9681),
    'Galata Tower':     LatLng(41.0257, 28.9742),
  };

  @override
  void initState() {
    super.initState();
    // Pre-populate with Istanbul landmarks
    _landmarks.forEach((name, pos) {
      _markers.add(Marker(
        markerId: MarkerId(name),
        position: pos,
        infoWindow: InfoWindow(
          title: name,
          snippet: 'Lat: ${pos.latitude.toStringAsFixed(4)}, Lon: ${pos.longitude.toStringAsFixed(4)}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    });
  }

  void _onMapTap(LatLng pos) {
    _markerCount++;
    setState(() {
      _markers.add(Marker(
        markerId: MarkerId('pin_$_markerCount'),
        position: pos,
        infoWindow: InfoWindow(
          title: 'Pin #$_markerCount',
          snippet: '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        onTap: () {
          // Extra action when marker itself is tapped
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Marker #$_markerCount tapped!')),
          );
        },
      ));
    });
  }

  void _clearMarkers() {
    setState(() {
      // Keep only the predefined landmarks
      _markers = {
        for (final entry in _landmarks.entries)
          Marker(
            markerId: MarkerId(entry.key),
            position: entry.value,
            infoWindow: InfoWindow(title: entry.key),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
      };
      _markerCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Maps'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Map type toggle
          PopupMenuButton<MapType>(
            icon: const Icon(Icons.layers),
            onSelected: (type) => setState(() => _mapType = type),
            itemBuilder: (_) => const [
              PopupMenuItem(value: MapType.normal,    child: Text('Normal')),
              PopupMenuItem(value: MapType.satellite, child: Text('Satellite')),
              PopupMenuItem(value: MapType.terrain,   child: Text('Terrain')),
              PopupMenuItem(value: MapType.hybrid,    child: Text('Hybrid')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearMarkers,
            tooltip: 'Clear custom pins',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCamera,
            mapType: _mapType,
            markers: _markers,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            onMapCreated: (ctrl) => _mapController = ctrl,
            onTap: _onMapTap,
            onLongPress: (_) => _clearMarkers(),
          ),
          // Info overlay
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_markers.length} markers  •  Tap to add',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Fly camera to Hagia Sophia
          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              const CameraPosition(
                target: LatLng(41.0086, 28.9802),
                zoom: 16,
                tilt: 45,
                bearing: 30,
              ),
            ),
          );
        },
        tooltip: 'Go to Hagia Sophia',
        child: const Icon(Icons.location_city),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BrowserScreen (Step 1) — abbreviated
// ─────────────────────────────────────────────────────────────────────────────
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});
  @override State<BrowserScreen> createState() => _BrowserScreenState();
}
class _BrowserScreenState extends State<BrowserScreen> {
  late final WebViewController _controller;
  final _urlCtrl = TextEditingController(text: 'https://flutter.dev');
  bool _loading = false;
  @override void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse('https://flutter.dev'));
  }
  @override void dispose() { _urlCtrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Browser'),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      bottom: PreferredSize(preferredSize: const Size.fromHeight(56),
        child: Padding(padding: const EdgeInsets.all(8), child: TextField(
          controller: _urlCtrl, keyboardType: TextInputType.url,
          decoration: InputDecoration(hintText: 'Enter URL…', isDense: true,
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward),
              onPressed: () { final url = _urlCtrl.text; _controller.loadRequest(Uri.parse(url.startsWith('http') ? url : 'https://$url')); })),
          onSubmitted: (url) => _controller.loadRequest(Uri.parse(url.startsWith('http') ? url : 'https://$url')),
        ))),
    ),
    body: Stack(children: [
      WebViewWidget(controller: _controller),
      if (_loading) const LinearProgressIndicator(),
    ]),
    bottomNavigationBar: BottomAppBar(child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () async { if (await _controller.canGoBack()) _controller.goBack(); }),
      IconButton(icon: const Icon(Icons.refresh), onPressed: () => _controller.reload()),
      IconButton(icon: const Icon(Icons.arrow_forward_ios), onPressed: () async { if (await _controller.canGoForward()) _controller.goForward(); }),
    ])),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SensorsScreen (Step 2) — abbreviated
// ─────────────────────────────────────────────────────────────────────────────
class SensorsScreen extends StatefulWidget {
  const SensorsScreen({super.key});
  @override State<SensorsScreen> createState() => _SensorsScreenState();
}
class _SensorsScreenState extends State<SensorsScreen> {
  double _ax = 0, _ay = 0, _az = 0;
  StreamSubscription<AccelerometerEvent>? _sub;
  int _shakeCount = 0;
  DateTime? _lastShake;
  @override void initState() {
    super.initState();
    _sub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) {
      setState(() { _ax = e.x; _ay = e.y; _az = e.z; });
      final force = (sqrt(e.x*e.x+e.y*e.y+e.z*e.z)-9.8).abs();
      if (force > 20) {
        final now = DateTime.now();
        if (_lastShake == null || now.difference(_lastShake!) > const Duration(milliseconds: 500)) {
          _lastShake = now;
          setState(() => _shakeCount++);
          HapticFeedback.heavyImpact();
        }
      }
    });
  }
  @override void dispose() { _sub?.cancel(); super.dispose(); }
  double get _tiltX => (_ax / 9.8).clamp(-1.0, 1.0);
  double get _tiltY => (_ay / 9.8).clamp(-1.0, 1.0);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Motion Sensors'),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary),
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 200, height: 200, child: Stack(alignment: Alignment.center, children: [
        Container(decoration: BoxDecoration(color: Colors.blue.shade50,
          border: Border.all(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(8))),
        Positioned(left: 100 + _tiltX * 80 - 15, top: 100 - _tiltY * 80 - 15,
          child: Container(width: 30, height: 30, decoration: const BoxDecoration(
            shape: BoxShape.circle, color: Colors.blue))),
      ])),
      const SizedBox(height: 16),
      Text('X: ${_ax.toStringAsFixed(2)}  Y: ${_ay.toStringAsFixed(2)}  Z: ${_az.toStringAsFixed(2)}'),
      const SizedBox(height: 8),
      Text('Shakes: $_shakeCount', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    ])),
  );
}

class PlaceholderScreen extends StatelessWidget {
  final IconData icon;
  final String label;
  const PlaceholderScreen({super.key, required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(label)),
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 80, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 16),
      Text('$label\ncoming soon…', textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall),
    ])),
  );
}
