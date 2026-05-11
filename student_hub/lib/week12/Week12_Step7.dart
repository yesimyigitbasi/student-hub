// ═══════════════════════════════════════════════════════════════════════════
// CMPE408 Week 12 — Step 7: COMPLETE APP (Final)
//
// Full-featured app combining all four modules:
//   🌐 In-App Browser (WebView + JavaScript channel)
//   📱 Motion Sensor Dashboard (Accelerometer, Gyroscope, Shake)
//   🗺️  Live Location Tracker (Google Maps + GPS polyline)
//   🗒️  Local Notes (SQLite CRUD, pin, search, batch, transactions)
//
// ─── REQUIRED pubspec.yaml ──────────────────────────────────────────────────
//
// name: week12_flutter
// description: CMPE408 Week 12 Complete Demo
// publish_to: 'none'
// version: 1.0.0+1
//
// environment:
//   sdk: '>=3.3.0 <4.0.0'
//
// dependencies:
//   flutter:
//     sdk: flutter
//   webview_flutter: ^4.7.0
//   sensors_plus: ^4.0.2
//   google_maps_flutter: ^2.9.0
//   geolocator: ^13.0.2
//   sqflite: ^2.3.3
//   path: ^1.9.0
//
// dev_dependencies:
//   flutter_test:
//     sdk: flutter
//   flutter_lints: ^4.0.0
//
// flutter:
//   uses-material-design: true
//
// ─── Android setup (android/app/src/main/AndroidManifest.xml) ──────────────
//   <application>
//     <meta-data android:name="com.google.android.geo.API_KEY"
//                android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
//   </application>
//   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
//   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
//   android:minSdkVersion="21"
//
// ─── iOS setup (ios/Runner/Info.plist) ─────────────────────────────────────
//   <key>NSLocationWhenInUseUsageDescription</key>
//   <string>We use your location to show it on the map.</string>
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path/path.dart' as path_pkg;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ════════════════════════════════════════════════════════════════════════════
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Week12App());
}

class Week12App extends StatelessWidget {
  const Week12App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CMPE408 – Week 12',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF065A82)),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SHELL
// ════════════════════════════════════════════════════════════════════════════
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;

  static const _screens = <Widget>[
    BrowserScreen(),
    SensorsScreen(),
    TrackMeScreen(),
    NotesScreen(),
  ];

  static const _destinations = <NavigationDestination>[
    NavigationDestination(icon: Icon(Icons.web),       selectedIcon: Icon(Icons.web),       label: 'Browser'),
    NavigationDestination(icon: Icon(Icons.vibration), selectedIcon: Icon(Icons.vibration), label: 'Sensors'),
    NavigationDestination(icon: Icon(Icons.map),       selectedIcon: Icon(Icons.map),       label: 'Maps'),
    NavigationDestination(icon: Icon(Icons.note_alt),  selectedIcon: Icon(Icons.note_alt),  label: 'Notes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: _destinations,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 1 — BROWSER SCREEN
// ════════════════════════════════════════════════════════════════════════════
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});
  @override State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late final WebViewController _ctrl;
  final _urlCtrl = TextEditingController(text: 'https://flutter.dev');
  bool _loading = false;
  String _receivedMsg = '';

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (msg) {
          setState(() => _receivedMsg = msg.message);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('JS → Flutter: ${msg.message}')),
          );
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) => setState(() {
          _loading = true;
          _urlCtrl.text = url;
        }),
        onPageFinished: (_) => setState(() => _loading = false),
        onNavigationRequest: (req) {
          if (req.url.contains('doubleclick.net')) {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse('https://flutter.dev'));
  }

  @override
  void dispose() { _urlCtrl.dispose(); super.dispose(); }

  void _navigate(String url) {
    _ctrl.loadRequest(Uri.parse(url.startsWith('http') ? url : 'https://$url'));
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
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _urlCtrl,
              decoration: InputDecoration(
                hintText: 'Enter URL…',
                isDense: true, filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _navigate(_urlCtrl.text),
                ),
              ),
              keyboardType: TextInputType.url,
              onSubmitted: _navigate,
            ),
          ),
        ),
      ),
      body: Stack(children: [
        WebViewWidget(controller: _ctrl),
        if (_loading) const LinearProgressIndicator(),
      ]),
      bottomNavigationBar: BottomAppBar(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () async {
              if (await _ctrl.canGoBack()) _ctrl.goBack();
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _ctrl.reload()),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: () async {
              if (await _ctrl.canGoForward()) _ctrl.goForward();
            },
          ),
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'Run JS demo',
            onPressed: () async {
              await _ctrl.runJavaScript(
                "document.body.style.outline = '4px solid #065A82';",
              );
            },
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 2 — SENSORS SCREEN
// ════════════════════════════════════════════════════════════════════════════
class SensorsScreen extends StatefulWidget {
  const SensorsScreen({super.key});
  @override State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen> {
  double _ax = 0, _ay = 0, _az = 0;
  double _gx = 0, _gy = 0, _gz = 0;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>?     _gyroSub;
  int      _shakes   = 0;
  DateTime? _lastShake;

  @override
  void initState() {
    super.initState();
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen((e) {
      setState(() { _ax = e.x; _ay = e.y; _az = e.z; });
      _detectShake(e);
    });
    _gyroSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((e) => setState(() { _gx = e.x; _gy = e.y; _gz = e.z; }));
  }

  void _detectShake(AccelerometerEvent e) {
    final force = (sqrt(e.x*e.x + e.y*e.y + e.z*e.z) - 9.8).abs();
    if (force > 20) {
      final now = DateTime.now();
      if (_lastShake == null ||
          now.difference(_lastShake!) > const Duration(milliseconds: 500)) {
        _lastShake = now;
        setState(() => _shakes++);
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Shake #$_shakes! 📳'),
              duration: const Duration(milliseconds: 700)),
        );
      }
    }
  }

  @override
  void dispose() { _accelSub?.cancel(); _gyroSub?.cancel(); super.dispose(); }

  double get _tx => (_ax / 9.8).clamp(-1.0, 1.0);
  double get _ty => (_ay / 9.8).clamp(-1.0, 1.0);

  Widget _bar(String label, double v, Color c) => Row(children: [
    SizedBox(width: 22, child: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.bold))),
    const SizedBox(width: 6),
    Expanded(child: LinearProgressIndicator(
      value: ((v + 20) / 40).clamp(0.0, 1.0), color: c,
      backgroundColor: c.withOpacity(0.15))),
    const SizedBox(width: 6),
    SizedBox(width: 52, child: Text(v.toStringAsFixed(2), style: const TextStyle(fontFamily: 'monospace'))),
  ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Motion Sensors'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _shakes = 0),
            tooltip: 'Reset shakes',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Tilt visualizer
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Text('Tilt Visualizer', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(width: 200, height: 200, child: Stack(alignment: Alignment.center, children: [
              Container(decoration: BoxDecoration(color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade300),
                borderRadius: BorderRadius.circular(8))),
              Positioned(left: 100, top: 0, bottom: 0, child: Container(width: 1, color: Colors.blue.shade300)),
              Positioned(top: 100, left: 0, right: 0, child: Container(height: 1, color: Colors.blue.shade300)),
              Positioned(
                left: (100 + _tx * 80 - 15).clamp(0.0, 170.0),
                top:  (100 - _ty * 80 - 15).clamp(0.0, 170.0),
                child: Container(width: 30, height: 30,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                    boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)])),
              ),
            ])),
            const SizedBox(height: 6),
            const Text('Tilt the device to move the dot',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ]))),
          const SizedBox(height: 12),
          // Accelerometer
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            ListTile(leading: const Icon(Icons.phone_android), title: const Text('Accelerometer (m/s²)'), dense: true, contentPadding: EdgeInsets.zero),
            _bar('X', _ax, Colors.red),
            const SizedBox(height: 6),
            _bar('Y', _ay, Colors.green),
            const SizedBox(height: 6),
            _bar('Z', _az, Colors.blue),
          ]))),
          const SizedBox(height: 12),
          // Gyroscope
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            ListTile(leading: const Icon(Icons.rotate_90_degrees_ccw), title: const Text('Gyroscope (rad/s)'), dense: true, contentPadding: EdgeInsets.zero),
            _bar('X', _gx, Colors.orange),
            const SizedBox(height: 6),
            _bar('Y', _gy, Colors.purple),
            const SizedBox(height: 6),
            _bar('Z', _gz, Colors.teal),
          ]))),
          const SizedBox(height: 12),
          // Shake counter
          Card(
            color: _shakes > 0 ? Colors.orange.shade50 : null,
            child: ListTile(
              leading: const Icon(Icons.vibration, size: 32),
              title: const Text('Shake Count'),
              subtitle: const Text('Shake the device hard!'),
              trailing: Text('$_shakes',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 3 — TRACK ME SCREEN
// ════════════════════════════════════════════════════════════════════════════

Future<Position> _getPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw Exception('Location services disabled. Enable them in Settings.');
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied ||
      perm == LocationPermission.deniedForever) {
    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    }
    throw Exception('Location permission denied.');
  }
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
}

class TrackMeScreen extends StatefulWidget {
  const TrackMeScreen({super.key});
  @override State<TrackMeScreen> createState() => _TrackMeScreenState();
}

class _TrackMeScreenState extends State<TrackMeScreen> {
  GoogleMapController? _mapCtrl;
  Set<Marker>   _markers  = {};
  Set<Polyline> _polylines = {};
  CameraPosition _camPos   = const CameraPosition(target: LatLng(41.0082, 28.9784), zoom: 14);
  bool _mapReady  = false;
  bool _tracking  = false;

  StreamSubscription<Position>? _posSub;
  final List<LatLng> _path  = [];
  double _distance = 0;
  Stopwatch _sw = Stopwatch();
  Timer?    _tick;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final pos = await _getPosition();
      final ll  = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _camPos = CameraPosition(target: ll, zoom: 15);
        _markers = { Marker(markerId: const MarkerId('you'), position: ll,
          infoWindow: const InfoWindow(title: 'You are here'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)) };
        _mapReady = true;
      });
    } catch (_) {
      setState(() => _mapReady = true);
    }
  }

  Future<void> _toggle() async {
    if (_tracking) {
      await _posSub?.cancel();
      _sw.stop();
      _tick?.cancel();
      setState(() => _tracking = false);
      return;
    }
    try {
      final pos   = await _getPosition();
      final start = LatLng(pos.latitude, pos.longitude);
      _path.clear();
      _path.add(start);
      _distance = 0;
      _sw.reset(); _sw.start();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      setState(() {
        _tracking = true;
        _polylines.clear();
        _markers = { Marker(markerId: const MarkerId('start'), position: start,
            infoWindow: const InfoWindow(title: 'Start'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)) };
      });
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(start, 17));

      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best, distanceFilter: 3),
      ).listen((p) {
        final ll = LatLng(p.latitude, p.longitude);
        if (_path.isNotEmpty) {
          _distance += Geolocator.distanceBetween(
            _path.last.latitude, _path.last.longitude,
            ll.latitude, ll.longitude);
        }
        setState(() {
          _path.add(ll);
          _markers = {
            Marker(markerId: const MarkerId('start'), position: _path.first,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
            Marker(markerId: const MarkerId('me'), position: ll,
                infoWindow: InfoWindow(snippet: '${p.speed.toStringAsFixed(1)} m/s'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)),
          };
          if (_path.length > 1) {
            _polylines = { Polyline(polylineId: const PolylineId('track'),
                points: List.from(_path), color: Colors.blue, width: 5) };
          }
        });
        _mapCtrl?.animateCamera(CameraUpdate.newLatLng(ll));
      });
    } catch (e) {
      setState(() => _tracking = false);
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String _fmtDist() => _distance < 1000
      ? '${_distance.toStringAsFixed(0)} m'
      : '${(_distance / 1000).toStringAsFixed(2)} km';

  String _fmtTime() {
    final e = _sw.elapsed;
    return '${e.inMinutes.toString().padLeft(2, '0')}:'
        '${(e.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() { _posSub?.cancel(); _tick?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track Me'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary),
      body: _mapReady
          ? Stack(children: [
              GoogleMap(
                initialCameraPosition: _camPos,
                markers: _markers, polylines: _polylines,
                myLocationEnabled: true, myLocationButtonEnabled: true,
                onMapCreated: (c) => _mapCtrl = c,
              ),
              Positioned(top: 12, left: 12, right: 12,
                child: Card(elevation: 4, child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _chip(Icons.straighten, 'Distance', _fmtDist()),
                    _chip(Icons.timer,      'Elapsed',  _fmtTime()),
                    _chip(Icons.place,      'Points',   '${_path.length}'),
                  ]),
                ))),
            ])
          : const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
              children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Getting location…')])),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggle,
        backgroundColor: _tracking ? Colors.red : null,
        icon: Icon(_tracking ? Icons.stop : Icons.play_arrow),
        label: Text(_tracking ? 'Stop' : 'Start Tracking'),
      ),
    );
  }

  Widget _chip(IconData icon, String label, String value) => Column(children: [
    Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
    const SizedBox(height: 2),
    Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
  ]);
}

// ════════════════════════════════════════════════════════════════════════════
// 4 — NOTES SCREEN  (full SQLite implementation)
// ════════════════════════════════════════════════════════════════════════════

// ── Model ──────────────────────────────────────────────────────────────────
class Note {
  int? id;
  String title, content;
  DateTime createdAt;
  bool pinned;

  Note({this.id, required this.title, required this.content,
        required this.createdAt, this.pinned = false});

  Map<String, dynamic> toMap() => {
    'id': id, 'title': title, 'content': content,
    'created_at': createdAt.toIso8601String(), 'pinned': pinned ? 1 : 0,
  };

  factory Note.fromMap(Map<String, dynamic> m) => Note(
    id: m['id'] as int?,
    title:   m['title']   as String,
    content: m['content'] as String,
    createdAt: DateTime.parse(m['created_at'] as String),
    pinned: (m['pinned'] as int? ?? 0) == 1,
  );
}

// ── Database Helper ────────────────────────────────────────────────────────
class DatabaseHelper {
  static Database? _db;
  static const _name = 'notes_final.db';
  static const _version = 1;
  static const table = 'notes';

  static Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final p = path_pkg.join(await getDatabasesPath(), _name);
    return openDatabase(p, version: _version, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE $table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL, content TEXT NOT NULL,
          created_at TEXT NOT NULL, pinned INTEGER NOT NULL DEFAULT 0
        )
      ''');
      // Batch seed
      final b = db.batch();
      final now = DateTime.now();
      for (final n in [
        Note(title: 'Welcome! 👋', content: 'Long-press or use menu for options. Swipe left to delete.', createdAt: now, pinned: true),
        Note(title: 'SQLite CRUD', content: 'Create, Read, Update, Delete — all persisted locally on device.', createdAt: now.subtract(const Duration(hours: 1))),
        Note(title: 'Batch & Transactions', content: 'Use batch() for bulk ops, transaction() for atomic multi-step changes.', createdAt: now.subtract(const Duration(hours: 2))),
      ]) { b.insert(table, n.toMap()); }
      await b.commit(noResult: true);
    });
  }

  static Future<int>       insert(Note n) async => (await database).insert(table, n.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  static Future<List<Note>> getAll() async { final db = await database; return (await db.query(table, orderBy: 'pinned DESC, created_at DESC')).map(Note.fromMap).toList(); }
  static Future<List<Note>> search(String q) async { final db = await database; return (await db.query(table, where: 'title LIKE ? OR content LIKE ?', whereArgs: ['%$q%','%$q%'])).map(Note.fromMap).toList(); }
  static Future<int>  update(Note n) async => (await database).update(table, n.toMap(), where: 'id=?', whereArgs: [n.id]);
  static Future<int>  delete(int id)  async => (await database).delete(table, where: 'id=?', whereArgs: [id]);
  static Future<void> togglePin(int id, bool current) async => (await database).update(table, {'pinned': current ? 0 : 1}, where: 'id=?', whereArgs: [id]);
  static Future<void> duplicate(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(table, where: 'id=?', whereArgs: [id]);
      if (rows.isEmpty) return;
      final copy = Note.fromMap(rows.first)
        ..id = null
        ..title = '${rows.first['title']} (copy)';
      await txn.insert(table, copy.toMap());
    });
  }
  static Future<Map<String,int>> stats() async {
    final db = await database;
    final total  = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table')) ?? 0;
    final pinned = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table WHERE pinned=1')) ?? 0;
    final today  = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM $table WHERE date(created_at)=date('now')")) ?? 0;
    return {'total': total, 'pinned': pinned, 'today': today};
  }
}

// ── Notes Screen ──────────────────────────────────────────────────────────
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late Future<List<Note>> _future;
  final _sc = TextEditingController();
  bool _searching = false;

  @override void initState()  { super.initState(); _refresh(); }
  @override void dispose()    { _sc.dispose(); super.dispose(); }

  void _refresh([String q = '']) => setState(() {
    _future = q.isEmpty ? DatabaseHelper.getAll() : DatabaseHelper.search(q);
  });

  Future<void> _openForm([Note? n]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _NoteForm(note: n)));
    _refresh(_sc.text);
  }

  String _dateStr(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    }
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(controller: _sc, autofocus: true,
                decoration: const InputDecoration(hintText: 'Search…', border: InputBorder.none),
                onChanged: _refresh)
            : const Text('My Notes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () { setState(() => _searching = !_searching); if (!_searching) { _sc.clear(); _refresh(); } },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'stats') {
                final s = await DatabaseHelper.stats();
                if (!mounted) return;
                showDialog(context: context, builder: (_) => AlertDialog(
                  title: const Text('Database Stats'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    ListTile(title: const Text('Total notes'), trailing: Text('${s['total']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    ListTile(title: const Text('Pinned'),      trailing: Text('${s['pinned']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    ListTile(title: const Text('Created today'),trailing: Text('${s['today']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                  ]),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                ));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'stats', child: ListTile(leading: Icon(Icons.bar_chart), title: Text('Statistics'))),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<Note>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final notes = snap.data ?? [];
          if (notes.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_searching ? 'No results.' : 'No notes yet.\nTap + to add one!',
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            ]));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final n = notes[i];
              return Dismissible(
                key: Key('note_${n.id}'),
                direction: DismissDirection.endToStart,
                background: Container(color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white)),
                confirmDismiss: (_) => showDialog<bool>(context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete note?'),
                      content: Text('"${n.title}"'),
                      actions: [
                        TextButton(onPressed: ()=>Navigator.pop(ctx,false), child: const Text('Cancel')),
                        TextButton(onPressed: ()=>Navigator.pop(ctx,true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red))),
                      ],
                    )),
                onDismissed: (_) async { await DatabaseHelper.delete(n.id!); _refresh(_sc.text); },
                child: ListTile(
                  leading: n.pinned ? Icon(Icons.push_pin, size: 18,
                      color: Theme.of(context).colorScheme.primary) : null,
                  title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(n.content, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_dateStr(n.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') _openForm(n);
                        if (v == 'pin')  { await DatabaseHelper.togglePin(n.id!, n.pinned); _refresh(_sc.text); }
                        if (v == 'dup')  { await DatabaseHelper.duplicate(n.id!); _refresh(_sc.text); }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Edit'))),
                        PopupMenuItem(value: 'pin',  child: ListTile(leading: Icon(n.pinned ? Icons.push_pin_outlined : Icons.push_pin), title: Text(n.pinned ? 'Unpin' : 'Pin'))),
                        const PopupMenuItem(value: 'dup',  child: ListTile(leading: Icon(Icons.copy), title: Text('Duplicate'))),
                      ],
                    ),
                  ]),
                  onTap: () => _openForm(n),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'New Note',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Note Form ─────────────────────────────────────────────────────────────
class _NoteForm extends StatefulWidget {
  final Note? note;
  const _NoteForm({this.note});
  @override State<_NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<_NoteForm> {
  final _fk = GlobalKey<FormState>();
  late final TextEditingController _tc, _cc;
  bool _saving = false;

  @override void initState() { super.initState(); _tc = TextEditingController(text: widget.note?.title ?? ''); _cc = TextEditingController(text: widget.note?.content ?? ''); }
  @override void dispose() { _tc.dispose(); _cc.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_fk.currentState!.validate()) return;
    setState(() => _saving = true);
    final n = Note(id: widget.note?.id, title: _tc.text.trim(), content: _cc.text.trim(),
        createdAt: widget.note?.createdAt ?? DateTime.now(), pinned: widget.note?.pinned ?? false);
    if (n.id == null) await DatabaseHelper.insert(n); else await DatabaseHelper.update(n);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.note == null ? 'New Note' : 'Edit Note'),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      actions: [
        if (_saving) const Padding(padding: EdgeInsets.all(14),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
        else IconButton(icon: const Icon(Icons.save), onPressed: _save),
      ],
    ),
    body: Form(key: _fk, child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      TextFormField(controller: _tc, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.sentences,
          validator: (v) => (v==null||v.trim().isEmpty) ? 'Title required' : null),
      const SizedBox(height: 12),
      Expanded(child: TextFormField(controller: _cc, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(labelText: 'Content', border: OutlineInputBorder(), alignLabelWithHint: true),
          textCapitalization: TextCapitalization.sentences,
          validator: (v) => (v==null||v.trim().isEmpty) ? 'Content required' : null)),
    ]))),
  );
}
