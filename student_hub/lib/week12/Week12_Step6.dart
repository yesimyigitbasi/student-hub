// ═══════════════════════════════════════════════════════════════════════════
// CMPE408 Week 12 — Step 6: SQLite — Transactions, Batch, and Statistics
//
// New in this step:
//   • db.transaction() for atomic multi-step operations
//   • db.batch() for bulk inserts
//   • Statistics screen with chart data from SQLite
//   • Pin / unpin notes (ALTER TABLE migration example)
//   • Export all notes as a formatted string
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
    NotesScreen(),
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
// DATA MODEL  (extended: added pinned field)
// ═════════════════════════════════════════════════════════════════════════════
class Note {
  int? id;
  String title;
  String content;
  DateTime createdAt;
  bool pinned;

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.pinned = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'pinned': pinned ? 1 : 0,
      };

  factory Note.fromMap(Map<String, dynamic> m) => Note(
        id: m['id'] as int?,
        title: m['title'] as String,
        content: m['content'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        pinned: (m['pinned'] as int? ?? 0) == 1,
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// DATABASE HELPER  (v2 — adds pinned column)
// ═════════════════════════════════════════════════════════════════════════════
class DatabaseHelper {
  static Database? _db;
  static const _dbName = 'notes_v2.db';
  static const _dbVersion = 2;           // ← bumped for migration
  static const table = 'notes';

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
        created_at TEXT    NOT NULL,
        pinned     INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _seedData(db);
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      // Add pinned column to existing database
      await db.execute(
          'ALTER TABLE $table ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0');
    }
  }

  // ── Batch seed ─────────────────────────────────────────────────────────────
  static Future<void> _seedData(Database db) async {
    final batch = db.batch();
    final now = DateTime.now();
    final samples = [
      Note(title: 'Welcome! 👋', content: 'Swipe left to delete. Tap to edit. Long-press to pin.', createdAt: now, pinned: true),
      Note(title: 'SQLite Batch Insert', content: 'This note was inserted via db.batch() — much faster than inserting one-by-one in a loop!', createdAt: now.subtract(const Duration(hours: 1))),
      Note(title: 'Transactions', content: 'Use db.transaction() for atomic operations that must all succeed or all fail.', createdAt: now.subtract(const Duration(hours: 2))),
      Note(title: 'Pinned notes appear first', content: 'Ordering: pinned DESC, created_at DESC', createdAt: now.subtract(const Duration(hours: 3))),
    ];
    for (final n in samples) {
      batch.insert(table, n.toMap());
    }
    await batch.commit(noResult: true);
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────
  static Future<int> insertNote(Note note) async {
    final db = await database;
    return db.insert(table, note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Note>> getAllNotes() async {
    final db = await database;
    final maps = await db.query(table,
        orderBy: 'pinned DESC, created_at DESC');
    return maps.map(Note.fromMap).toList();
  }

  static Future<List<Note>> searchNotes(String query) async {
    final db = await database;
    final maps = await db.query(table,
        where: 'title LIKE ? OR content LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'pinned DESC, created_at DESC');
    return maps.map(Note.fromMap).toList();
  }

  static Future<int> updateNote(Note note) async {
    final db = await database;
    return db.update(table, note.toMap(),
        where: 'id = ?', whereArgs: [note.id]);
  }

  static Future<int> deleteNote(int id) async {
    final db = await database;
    return db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> togglePin(int id, bool currentlyPinned) async {
    final db = await database;
    await db.update(table, {'pinned': currentlyPinned ? 0 : 1},
        where: 'id = ?', whereArgs: [id]);
  }

  // ── Statistics ─────────────────────────────────────────────────────────────
  static Future<Map<String, int>> getStats() async {
    final db = await database;
    final total = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) as c FROM $table')) ?? 0;
    final pinned = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) as c FROM $table WHERE pinned=1')) ?? 0;
    final today = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) as c FROM $table WHERE date(created_at) = date('now')")) ?? 0;
    return {'total': total, 'pinned': pinned, 'today': today};
  }

  // ── Transaction: duplicate note ────────────────────────────────────────────
  static Future<void> duplicateNote(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final maps = await txn.query(table, where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) throw Exception('Note $id not found');
      final original = Note.fromMap(maps.first);
      final copy = Note(
        title: '${original.title} (copy)',
        content: original.content,
        createdAt: DateTime.now(),
      );
      await txn.insert(table, copy.toMap());
    });
  }

  // ── Export all notes as text ───────────────────────────────────────────────
  static Future<String> exportAll() async {
    final notes = await getAllNotes();
    final sb = StringBuffer('=== My Notes Export ===\n\n');
    for (final n in notes) {
      sb.writeln('# ${n.title}');
      sb.writeln('Created: ${n.createdAt}${n.pinned ? ' [PINNED]' : ''}');
      sb.writeln(n.content);
      sb.writeln('─' * 40);
    }
    return sb.toString();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// NOTES SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late Future<List<Note>> _notesFuture;
  final _searchCtrl = TextEditingController();
  bool _searching = false;

  @override void initState() { super.initState(); _refresh(); }
  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _refresh([String q = '']) {
    setState(() {
      _notesFuture = q.isEmpty ? DatabaseHelper.getAllNotes() : DatabaseHelper.searchNotes(q);
    });
  }

  Future<void> _openForm([Note? note]) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => NoteFormScreen(note: note)));
    _refresh(_searchCtrl.text);
  }

  Future<void> _showStats() async {
    final stats = await DatabaseHelper.getStats();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Statistics'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _StatRow('Total notes', '${stats['total']}'),
          _StatRow('Pinned notes', '${stats['pinned']}'),
          _StatRow('Created today', '${stats['today']}'),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _exportNotes() async {
    final text = await DatabaseHelper.exportAll();
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notes copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl, autofocus: true,
                decoration: const InputDecoration(hintText: 'Search…', border: InputBorder.none),
                onChanged: _refresh,
              )
            : const Text('My Notes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(icon: Icon(_searching ? Icons.close : Icons.search),
              onPressed: () { setState(() => _searching = !_searching); if (!_searching) { _searchCtrl.clear(); _refresh(); } }),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'stats') _showStats();
              if (v == 'export') _exportNotes();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'stats',  child: ListTile(leading: Icon(Icons.bar_chart), title: Text('Statistics'))),
              PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.share), title: Text('Export to clipboard'))),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<Note>>(
        future: _notesFuture,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final notes = snap.data ?? [];
          if (notes.isEmpty) {
            return Center(child: Text(
              _searching ? 'No results.' : 'No notes yet.\nTap + to add one!',
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)));
          }
          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (_, i) {
              final note = notes[i];
              return Dismissible(
                key: Key('n${note.id}'),
                direction: DismissDirection.endToStart,
                background: Container(color: Colors.red,
                    alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white)),
                onDismissed: (_) async { await DatabaseHelper.deleteNote(note.id!); _refresh(_searchCtrl.text); },
                child: ListTile(
                  leading: note.pinned
                      ? Icon(Icons.push_pin, color: Theme.of(context).colorScheme.primary)
                      : null,
                  title: Text(note.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(note.content, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') { _openForm(note); }
                      if (v == 'pin') { await DatabaseHelper.togglePin(note.id!, note.pinned); _refresh(_searchCtrl.text); }
                      if (v == 'dup') { await DatabaseHelper.duplicateNote(note.id!); _refresh(_searchCtrl.text); }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Edit'))),
                      PopupMenuItem(value: 'pin', child: ListTile(leading: Icon(note.pinned ? Icons.push_pin_outlined : Icons.push_pin), title: Text(note.pinned ? 'Unpin' : 'Pin'))),
                      const PopupMenuItem(value: 'dup', child: ListTile(leading: Icon(Icons.copy), title: Text('Duplicate'))),
                    ],
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
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label, value;
  const _StatRow(this.label, this.value);
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    ]));
}

// ═════════════════════════════════════════════════════════════════════════════
// NOTE FORM SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class NoteFormScreen extends StatefulWidget {
  final Note? note;
  const NoteFormScreen({super.key, this.note});
  @override State<NoteFormScreen> createState() => _NoteFormState();
}

class _NoteFormState extends State<NoteFormScreen> {
  final _fk = GlobalKey<FormState>();
  late final TextEditingController _tc, _cc;
  bool _saving = false;
  @override void initState() { super.initState(); _tc = TextEditingController(text: widget.note?.title ?? ''); _cc = TextEditingController(text: widget.note?.content ?? ''); }
  @override void dispose() { _tc.dispose(); _cc.dispose(); super.dispose(); }
  Future<void> _save() async { if (!_fk.currentState!.validate()) return; setState(() => _saving = true); final n = Note(id: widget.note?.id, title: _tc.text.trim(), content: _cc.text.trim(), createdAt: widget.note?.createdAt ?? DateTime.now(), pinned: widget.note?.pinned ?? false); if (n.id == null) await DatabaseHelper.insertNote(n); else await DatabaseHelper.updateNote(n); if (mounted) Navigator.pop(context); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.note == null ? 'New Note' : 'Edit Note'), backgroundColor: Theme.of(context).colorScheme.inversePrimary, actions: [if (_saving) const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) else IconButton(icon: const Icon(Icons.save), onPressed: _save)]),
    body: Form(key: _fk, child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      TextFormField(controller: _tc, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()), validator: (v) => (v==null||v.trim().isEmpty)?'Required':null),
      const SizedBox(height: 12),
      Expanded(child: TextFormField(controller: _cc, decoration: const InputDecoration(labelText: 'Content', border: OutlineInputBorder(), alignLabelWithHint: true), maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top, validator: (v) => (v==null||v.trim().isEmpty)?'Required':null)),
    ]))),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Earlier screens (abbreviated stubs — same as Step 5)
// ─────────────────────────────────────────────────────────────────────────────
Future<Position> determinePosition() async { if (!await Geolocator.isLocationServiceEnabled()) throw Exception('Location disabled'); var p = await Geolocator.checkPermission(); if (p == LocationPermission.denied) p = await Geolocator.requestPermission(); if (p == LocationPermission.denied || p == LocationPermission.deniedForever) throw Exception('Permission denied'); return Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)); }

class BrowserScreen extends StatefulWidget { const BrowserScreen({super.key}); @override State<BrowserScreen> createState() => _BrowserScreenState(); }
class _BrowserScreenState extends State<BrowserScreen> { late final WebViewController _c; bool _l=false; @override void initState(){super.initState();_c=WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..setNavigationDelegate(NavigationDelegate(onPageStarted:(_)=>setState(()=>_l=true),onPageFinished:(_)=>setState(()=>_l=false)))..loadRequest(Uri.parse('https://flutter.dev'));} @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Browser'), backgroundColor: Theme.of(context).colorScheme.inversePrimary), body: Stack(children: [WebViewWidget(controller: _c), if (_l) const LinearProgressIndicator()])); }

class SensorsScreen extends StatefulWidget { const SensorsScreen({super.key}); @override State<SensorsScreen> createState() => _SensorsScreenState(); }
class _SensorsScreenState extends State<SensorsScreen> { double _ax=0,_ay=0; StreamSubscription<AccelerometerEvent>? _s; int _shakes=0; DateTime? _last; @override void initState(){super.initState();_s=accelerometerEventStream(samplingPeriod:SensorInterval.uiInterval).listen((e){setState((){_ax=e.x;_ay=e.y;});final f=(sqrt(e.x*e.x+e.y*e.y+e.z*e.z)-9.8).abs();if(f>20){final n=DateTime.now();if(_last==null||n.difference(_last!)>const Duration(milliseconds:500)){_last=n;setState(()=>_shakes++);HapticFeedback.heavyImpact();}}});} @override void dispose(){_s?.cancel();super.dispose();} @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Sensors'), backgroundColor: Theme.of(context).colorScheme.inversePrimary), body: Center(child: Text('Shakes: $_shakes', style: const TextStyle(fontSize: 32)))); }

class TrackMeScreen extends StatefulWidget { const TrackMeScreen({super.key}); @override State<TrackMeScreen> createState() => _TrackMeState(); }
class _TrackMeState extends State<TrackMeScreen> { GoogleMapController? _mc; StreamSubscription<Position>? _sub; bool _t=false; final List<LatLng> _p=[]; Set<Marker> _mk={}; Set<Polyline> _pl={}; static const _cam=CameraPosition(target:LatLng(41.0082,28.9784),zoom:15); Future<void> _toggle() async {if(_t){await _sub?.cancel();setState(()=>_t=false);}else{try{final pos=await determinePosition();final ll=LatLng(pos.latitude,pos.longitude);_p.clear();setState((){_t=true;_mk={Marker(markerId:const MarkerId('s'),position:ll)};});_sub=Geolocator.getPositionStream(locationSettings:const LocationSettings(accuracy:LocationAccuracy.best,distanceFilter:3)).listen((pos){final ll=LatLng(pos.latitude,pos.longitude);setState((){_p.add(ll);_mk={Marker(markerId:const MarkerId('m'),position:ll)};if(_p.length>1)_pl={Polyline(polylineId:const PolylineId('t'),points:List.from(_p),color:Colors.blue,width:5)};});_mc?.animateCamera(CameraUpdate.newLatLng(ll));});}catch(e){setState(()=>_t=false);}}} @override void dispose(){_sub?.cancel();super.dispose();} @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Track Me'), backgroundColor: Theme.of(context).colorScheme.inversePrimary), body: GoogleMap(initialCameraPosition:_cam,markers:_mk,polylines:_pl,myLocationEnabled:true,onMapCreated:(c)=>_mc=c), floatingActionButton: FloatingActionButton.extended(onPressed:_toggle,backgroundColor:_t?Colors.red:null,label:Text(_t?'Stop':'Start'),icon:Icon(_t?Icons.stop:Icons.play_arrow))); }
