// ═══════════════════════════════════════════════════════════════════════════
// CMPE408 Week 12 — Step 4: GPS + Live Location Tracking on Map
//
// New in this step:
//   • geolocator dependency
//   • Runtime permission handling
//   • getCurrentPosition() — single GPS fix
//   • getPositionStream() — continuous tracking
//   • Polyline drawn as user moves
//   • Distance and elapsed time display
//   • Start / Stop FAB button
//
// pubspec.yaml additions:
//   dependencies:
//     geolocator: ^13.0.2
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
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
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final _screens = const <Widget>[
    BrowserScreen(),
    SensorsScreen(),
    TrackMeScreen(),                                       // ← UPGRADED
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
// Helper: request location permissions and get an initial fix
// ─────────────────────────────────────────────────────────────────────────────
Future<Position> determinePosition() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Location services are disabled. Please enable them in Settings.');
  }

  LocationPermission perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }
  }
  if (perm == LocationPermission.deniedForever) {
    await Geolocator.openAppSettings();
    throw Exception('Location permission permanently denied. Please grant it in Settings.');
  }

  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Track Me Screen — GPS + Maps combined
// ─────────────────────────────────────────────────────────────────────────────
class TrackMeScreen extends StatefulWidget {
  const TrackMeScreen({super.key});
  @override State<TrackMeScreen> createState() => _TrackMeScreenState();
}

class _TrackMeScreenState extends State<TrackMeScreen> {
  // Map
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  CameraPosition _initialCamera = const CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 15,
  );
  bool _mapReady = false;

  // Tracking state
  StreamSubscription<Position>? _posStream;
  bool _tracking = false;
  final List<LatLng> _path = [];
  double _totalDistance = 0; // metres
  Stopwatch _stopwatch = Stopwatch();
  Timer? _timerTick;

  @override
  void initState() {
    super.initState();
    _loadInitialLocation();
  }

  Future<void> _loadInitialLocation() async {
    try {
      final pos = await determinePosition();
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _initialCamera = CameraPosition(target: ll, zoom: 15);
        _markers = {
          Marker(
            markerId: const MarkerId('you'),
            position: ll,
            infoWindow: const InfoWindow(title: 'You are here'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
        };
        _mapReady = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _mapReady = true); // show map anyway
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), duration: const Duration(seconds: 4)),
        );
      }
    }
  }

  Future<void> _toggleTracking() async {
    if (_tracking) {
      // Stop
      await _posStream?.cancel();
      _posStream = null;
      _stopwatch.stop();
      _timerTick?.cancel();
      setState(() => _tracking = false);
    } else {
      // Start
      try {
        final startPos = await determinePosition();
        final startLL = LatLng(startPos.latitude, startPos.longitude);

        setState(() {
          _path.clear();
          _path.add(startLL);
          _totalDistance = 0;
          _markers = {
            Marker(
              markerId: const MarkerId('start'),
              position: startLL,
              infoWindow: const InfoWindow(title: 'Start'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ),
          };
          _polylines.clear();
          _tracking = true;
        });

        _stopwatch
          ..reset()
          ..start();

        _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {}); // Refresh elapsed time display
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(startLL, 17),
        );

        _posStream = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 3, // emit only if moved 3m
          ),
        ).listen((pos) {
          final ll = LatLng(pos.latitude, pos.longitude);

          // Accumulate distance
          if (_path.isNotEmpty) {
            _totalDistance += Geolocator.distanceBetween(
              _path.last.latitude, _path.last.longitude,
              ll.latitude,         ll.longitude,
            );
          }

          setState(() {
            _path.add(ll);
            _markers = {
              Marker(
                markerId: const MarkerId('start'),
                position: _path.first,
                infoWindow: const InfoWindow(title: 'Start'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              ),
              Marker(
                markerId: const MarkerId('current'),
                position: ll,
                infoWindow: InfoWindow(
                  title: 'You',
                  snippet: '${pos.speed.toStringAsFixed(1)} m/s',
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              ),
            };
            if (_path.length > 1) {
              _polylines = {
                Polyline(
                  polylineId: const PolylineId('track'),
                  points: List<LatLng>.from(_path),
                  color: Colors.blue,
                  width: 5,
                ),
              };
            }
          });

          _mapController?.animateCamera(CameraUpdate.newLatLng(ll));
        });
      } catch (e) {
        setState(() => _tracking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  String _formatDistance(double metres) {
    if (metres < 1000) return '${metres.toStringAsFixed(0)} m';
    return '${(metres / 1000).toStringAsFixed(2)} km';
  }

  String _formatElapsed() {
    final e = _stopwatch.elapsed;
    final m = e.inMinutes.toString().padLeft(2, '0');
    final s = (e.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _posStream?.cancel();
    _timerTick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Me'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _mapReady
          ? Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: _initialCamera,
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onMapCreated: (ctrl) => _mapController = ctrl,
                ),
                // Stats overlay
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatChip(
                            icon: Icons.straighten,
                            label: 'Distance',
                            value: _formatDistance(_totalDistance),
                          ),
                          _StatChip(
                            icon: Icons.timer,
                            label: 'Elapsed',
                            value: _formatElapsed(),
                          ),
                          _StatChip(
                            icon: Icons.place,
                            label: 'Points',
                            value: '${_path.length}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Getting your location…'),
              ],
            )),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleTracking,
        backgroundColor: _tracking ? Colors.red : Theme.of(context).colorScheme.primary,
        icon: Icon(_tracking ? Icons.stop : Icons.play_arrow),
        label: Text(_tracking ? 'Stop' : 'Start Tracking'),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Previous screens (abbreviated)
// ─────────────────────────────────────────────────────────────────────────────
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});
  @override State<BrowserScreen> createState() => _BrowserScreenState();
}
class _BrowserScreenState extends State<BrowserScreen> {
  late final WebViewController _c;
  bool _loading = false;
  @override void initState() { super.initState(); _c = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..setNavigationDelegate(NavigationDelegate(onPageStarted: (_) => setState(()=>_loading=true), onPageFinished: (_) => setState(()=>_loading=false)))..loadRequest(Uri.parse('https://flutter.dev')); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Browser'), backgroundColor: Theme.of(context).colorScheme.inversePrimary), body: Stack(children: [WebViewWidget(controller: _c), if (_loading) const LinearProgressIndicator()]));
}

class SensorsScreen extends StatefulWidget {
  const SensorsScreen({super.key});
  @override State<SensorsScreen> createState() => _SensorsScreenState();
}
class _SensorsScreenState extends State<SensorsScreen> {
  double _ax=0, _ay=0; StreamSubscription<AccelerometerEvent>? _sub; int _shakes=0; DateTime? _last;
  @override void initState() { super.initState(); _sub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) { setState(() { _ax = e.x; _ay = e.y; }); final f=(sqrt(e.x*e.x+e.y*e.y+e.z*e.z)-9.8).abs(); if (f>20){final n=DateTime.now(); if(_last==null||n.difference(_last!)>const Duration(milliseconds:500)){_last=n;setState(()=>_shakes++);HapticFeedback.heavyImpact();}}});}
  @override void dispose() { _sub?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Sensors'), backgroundColor: Theme.of(context).colorScheme.inversePrimary), body: Center(child: Text('Shakes: $_shakes\nX:${_ax.toStringAsFixed(1)} Y:${_ay.toStringAsFixed(1)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20))));
}

class PlaceholderScreen extends StatelessWidget {
  final IconData icon; final String label;
  const PlaceholderScreen({super.key, required this.icon, required this.label});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(label)), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 80, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 16), Text('$label\ncoming soon…', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall)])));
}
