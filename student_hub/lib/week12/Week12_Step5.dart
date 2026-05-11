// ═══════════════════════════════════════════════════════════════════════════
// CMPE408 Week 12 — Step 5: SQLite — Model, DatabaseHelper, and CRUD
//
// New in this step:
//   • sqflite + path dependencies
//   • Note data model with toMap / fromMap
//   • DatabaseHelper singleton with full CRUD
//   • NotesScreen with FutureBuilder list
//   • Swipe-to-delete (Dismissible widget)
//
// pubspec.yaml additions:
//   dependencies:
//     sqflite: ^2.3.3
//     path: ^1.9.0
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
    TrackMeScreen(),
    NotesScreen(),                                         // ← NEW
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

// ═════════════════════════════════════════════════════════════════════════════
// DATA MODEL
// ═════════════════════════════════════════════════════════════════════════════
class Note {
  int? id;
  String title;
  String content;
  DateTime createdAt;

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'created_at': createdAt.toIso8601String(),
      };

  factory Note.fromMap(Map<String, dynamic> m) => Note(
        id: m['id'] as int?,
        title: m['title'] as String,
        content: m['content'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Note copyWith({int? id, String? title, String? content, DateTime? createdAt}) =>
      Note(
        id: id ?? this.id,
        title: title ?? this.title,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// DATABASE HELPER  (Singleton)
// ═════════════════════════════════════════════════════════════════════════════
class DatabaseHelper {
  static Database? _db;
  static const _dbName = 'notes.db';
  static const _dbVersion = 1;
  static const table = 'notes';

  /// Returns the open database (opens or creates on first call).
  static Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path_pkg.join(dbPath, _dbName);
    return openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        title      TEXT    NOT NULL,
        content    TEXT    NOT NULL,
        created_at TEXT    NOT NULL
      )
    ''');
    // Seed with sample data on first open
    final now = DateTime.now();
    await db.insert(table, Note(
      title: 'Welcome to Notes! 👋',
      content: 'This app uses sqflite to persist your notes locally on the device. Swipe left to delete.',
      createdAt: now,
    ).toMap());
    await db.insert(table, Note(
      title: 'SQLite is powerful',
      content: 'You can run full SQL queries — SELECT, INSERT, UPDATE, DELETE, JOIN, and more.',
      createdAt: now.subtract(const Duration(hours: 1)),
    ).toMap());
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    // Example: if (oldV < 2) await db.execute('ALTER TABLE $table ADD COLUMN pinned INTEGER DEFAULT 0');
  }

  // ── CREATE ──────────────────────────────────────────────────────────────
  static Future<int> insertNote(Note note) async {
    final db = await database;
    return db.insert(table, note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── READ ALL ─────────────────────────────────────────────────────────────
  static Future<List<Note>> getAllNotes() async {
    final db = await database;
    final maps = await db.query(table, orderBy: 'created_at DESC');
    return maps.map(Note.fromMap).toList();
  }

  // ── SEARCH ───────────────────────────────────────────────────────────────
  static Future<List<Note>> searchNotes(String query) async {
    final db = await database;
    final maps = await db.query(
      table,
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
    return maps.map(Note.fromMap).toList();
  }

  // ── UPDATE ───────────────────────────────────────────────────────────────
  static Future<int> updateNote(Note note) async {
    final db = await database;
    return db.update(table, note.toMap(),
        where: 'id = ?', whereArgs: [note.id]);
  }

  // ── DELETE ───────────────────────────────────────────────────────────────
  static Future<int> deleteNote(int id) async {
    final db = await database;
    return db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  // ── COUNT ────────────────────────────────────────────────────────────────
  static Future<int> countNotes() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM $table');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// NOTES SCREEN  (list)
// ═════════════════════════════════════════════════════════════════════════════
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late Future<List<Note>> _notesFuture;
  final _searchCtrl = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh([String query = '']) {
    setState(() {
      _notesFuture = query.isEmpty
          ? DatabaseHelper.getAllNotes()
          : DatabaseHelper.searchNotes(query);
    });
  }

  Future<void> _delete(int id) async {
    await DatabaseHelper.deleteNote(id);
    _refresh(_searchCtrl.text);
  }

  Future<void> _openForm([Note? note]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteFormScreen(note: note)),
    );
    _refresh(_searchCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search notes…',
                  border: InputBorder.none,
                ),
                onChanged: _refresh,
              )
            : const Text('My Notes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _searching = !_searching);
              if (!_searching) {
                _searchCtrl.clear();
                _refresh();
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Note>>(
        future: _notesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final notes = snapshot.data ?? [];
          if (notes.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  _searching ? 'No notes match your search.' : 'No notes yet.\nTap + to create one!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ]),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notes.length,
            itemBuilder: (context, i) {
              final note = notes[i];
              return Dismissible(
                key: Key('note_${note.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete note?'),
                      content: Text('Delete "${note.title}"?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                },
                onDismissed: (_) => _delete(note.id!),
                child: ListTile(
                  title: Text(note.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    note.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    _formatDate(note.createdAt),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  onTap: () => _openForm(note),
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

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// NOTE FORM SCREEN  (create + edit)
// ═════════════════════════════════════════════════════════════════════════════
class NoteFormScreen extends StatefulWidget {
  final Note? note;
  const NoteFormScreen({super.key, this.note});
  @override State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl   = TextEditingController(text: widget.note?.title   ?? '');
    _contentCtrl = TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final note = Note(
      id: widget.note?.id,
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
      createdAt: widget.note?.createdAt ?? DateTime.now(),
    );

    if (note.id == null) {
      await DatabaseHelper.insertNote(note);
    } else {
      await DatabaseHelper.updateNote(note);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New Note' : 'Edit Note'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
          else
            IconButton(icon: const Icon(Icons.save), onPressed: _save, tooltip: 'Save'),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextFormField(
                controller: _contentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Content is required' : null,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Previous screens (abbreviated stubs)
// ─────────────────────────────────────────────────────────────────────────────

// ── GPS helper ──────────────────────────────────────────────────────────────
Future<Position> determinePosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) throw Exception('Location disabled');
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
  if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) throw Exception('Permission denied');
  return Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
}

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
  double _ax=0,_ay=0; StreamSubscription<AccelerometerEvent>? _sub; int _shakes=0; DateTime? _last;
  @override void initState() { super.initState(); _sub=accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e){setState((){_ax=e.x;_ay=e.y;});final f=(sqrt(e.x*e.x+e.y*e.y+e.z*e.z)-9.8).abs();if(f>20){final n=DateTime.now();if(_last==null||n.difference(_last!)>const Duration(milliseconds:500)){_last=n;setState(()=>_shakes++);HapticFeedback.heavyImpact();}}});}
  @override void dispose() { _sub?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Sensors'), backgroundColor: Theme.of(context).colorScheme.inversePrimary), body: Center(child: Text('Shakes: $_shakes', style: const TextStyle(fontSize: 32))));
}

class TrackMeScreen extends StatefulWidget {
  const TrackMeScreen({super.key});
  @override State<TrackMeScreen> createState() => _TrackMeScreenState();
}
class _TrackMeScreenState extends State<TrackMeScreen> {
  GoogleMapController? _mc; StreamSubscription<Position>? _sub; bool _tracking=false; final List<LatLng> _path=[]; Set<Marker> _mk={}; Set<Polyline> _pl={};
  static const _cam = CameraPosition(target: LatLng(41.0082,28.9784), zoom:15);
  Future<void> _toggle() async { if(_tracking){await _sub?.cancel();setState(()=>_tracking=false);}else{try{final p=await determinePosition();final ll=LatLng(p.latitude,p.longitude);_path.clear();setState((){_tracking=true;_mk={Marker(markerId:const MarkerId('s'),position:ll)};});_sub=Geolocator.getPositionStream(locationSettings:const LocationSettings(accuracy:LocationAccuracy.best,distanceFilter:3)).listen((p){final ll=LatLng(p.latitude,p.longitude);setState((){_path.add(ll);_mk={Marker(markerId:const MarkerId('me'),position:ll)};if(_path.length>1)_pl={Polyline(polylineId:const PolylineId('t'),points:List.from(_path),color:Colors.blue,width:5)};});_mc?.animateCamera(CameraUpdate.newLatLng(ll));});}catch(e){setState(()=>_tracking=false);}}}
  @override void dispose(){_sub?.cancel();super.dispose();}
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Track Me'), backgroundColor: Theme.of(context).colorScheme.inversePrimary), body: GoogleMap(initialCameraPosition:_cam,markers:_mk,polylines:_pl,myLocationEnabled:true,onMapCreated:(c)=>_mc=c), floatingActionButton: FloatingActionButton.extended(onPressed:_toggle,backgroundColor:_tracking?Colors.red:null,label:Text(_tracking?'Stop':'Start'),icon:Icon(_tracking?Icons.stop:Icons.play_arrow)));
}
