// ─────────────────────────────────────────────
//  HackerDeck — Main Home Shell
// ─────────────────────────────────────────────
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/process_run.dart';
import 'package:window_manager/window_manager.dart';

import 'package:hackerdeck/models.dart';
import 'package:hackerdeck/store_data.dart';
import 'package:hackerdeck/pages/dashboard_page.dart';
import 'package:hackerdeck/pages/apps_page.dart';
import 'package:hackerdeck/pages/store_page.dart';
import 'package:hackerdeck/pages/instances_page.dart';
import 'package:hackerdeck/pages/keymapper_page.dart';
import 'package:hackerdeck/pages/mouse_page.dart';
import 'package:hackerdeck/pages/tools_page.dart';

class HackerDeckHome extends StatefulWidget {
  const HackerDeckHome({super.key});
  @override
  State<HackerDeckHome> createState() => _HackerDeckHomeState();
}

class _HackerDeckHomeState extends State<HackerDeckHome>
    with WidgetsBindingObserver, WindowListener {

  // ── State ──────────────────────────────────
  List<Instance> instances = [];
  int currentInstance = 0;

  List<KeyMapping> keyMappings = [];
  List<KeyCircle> circles = [];

  bool mouseSteering = false;
  double _lastMouseX = 0, _lastMouseY = 0;

  final FocusNode _focusNode = FocusNode();
  final List<String> _logs = [];
  final ScrollController _logSc = ScrollController();
  Timer? _statusTimer;
  String _statusText = 'HackerDeck v4.0 — gotowy';

  List<AppInfo> _apps = [];
  final List<StoreApp> _storeApps = buildStoreApps();

  int _tab = 0;
  bool _logExpanded = true;

  // Keymapper drag state
  int _dragIdx = -1;
  Offset _dragStart = Offset.zero;
  Offset _circleStart = Offset.zero;

  // ── Lifecycle ──────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    windowManager.addListener(this);
    _focusNode.requestFocus();
    _loadConfigs();
    _loadKeyMappings();
    _startStatusTimer();
    _refreshAppList();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this);
    _statusTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void onWindowFocus() => _focusNode.requestFocus();

  // ── Config dir ─────────────────────────────
  Future<Directory> _configDir() async {
    final home = Platform.environment['HOME'] ?? '/tmp';
    final d = Directory('$home/.config/hackerdeck');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  // ── Load / save instances ──────────────────
  Future<void> _loadConfigs() async {
    try {
      final d = await _configDir();
      final f = File('${d.path}/instances.json');
      if (await f.exists()) {
        instances = List<Instance>.from(
          (jsonDecode(await f.readAsString()) as List).map((e) => Instance.fromJson(e as Map<String, dynamic>)),
        );
      } else {
        instances = [Instance(name: 'Domyślna', dataDir: '/var/lib/waydroid')];
        await _saveInstances();
      }
    } catch (e) {
      instances = [Instance(name: 'Domyślna', dataDir: '/var/lib/waydroid')];
      _log('Błąd ładowania instancji: $e');
    }
    setState(() {});
  }

  Future<void> _saveInstances() async {
    final d = await _configDir();
    await File('${d.path}/instances.json')
        .writeAsString(jsonEncode(instances.map((e) => e.toJson()).toList()));
  }

  // ── Load / save keymaps ────────────────────
  Future<void> _loadKeyMappings() async {
    try {
      final d = await _configDir();
      final f = File('${d.path}/keymaps.json');
      if (await f.exists()) {
        keyMappings = List<KeyMapping>.from(
          (jsonDecode(await f.readAsString()) as List).map((e) => KeyMapping.fromJson(e as Map<String, dynamic>)),
        );
        circles = keyMappings
            .where((m) => m.type == 'tap')
            .map((m) => KeyCircle(key: m.key, x: m.x, y: m.y, radius: 35))
            .toList();
      } else {
        keyMappings = [
          KeyMapping(key: 'w', type: 'tap', x: 500, y: 300),
          KeyMapping(key: 's', type: 'tap', x: 500, y: 700),
          KeyMapping(key: 'a', type: 'tap', x: 300, y: 500),
          KeyMapping(key: 'd', type: 'tap', x: 700, y: 500),
        ];
        circles = keyMappings
            .map((m) => KeyCircle(key: m.key, x: m.x, y: m.y, radius: 35))
            .toList();
        await _saveKeyMappings();
      }
    } catch (e) {
      _log('Błąd ładowania keymap: $e');
    }
    setState(() {});
  }

  Future<void> _saveKeyMappings() async {
    keyMappings = circles
        .map((c) => KeyMapping(key: c.key, type: 'tap', x: c.x, y: c.y))
        .toList();
    final d = await _configDir();
    await File('${d.path}/keymaps.json')
        .writeAsString(jsonEncode(keyMappings.map((e) => e.toJson()).toList()));
  }

  // ── Command runner ─────────────────────────
  Future<void> _run(List<String> args, {bool silent = false}) async {
    if (!silent) _log('🚀 ${args.join(' ')}');
    final env = <String, String>{};
    if (currentInstance < instances.length &&
        instances[currentInstance].dataDir != '/var/lib/waydroid') {
      env['WAYDROID_DATA'] = instances[currentInstance].dataDir;
    }
    try {
      final p = await Process.start(
        args.first, args.skip(1).toList(),
        environment: env, runInShell: true,
      );
      p.stdout.transform(utf8.decoder).listen((d) {
        for (final l in d.split('\n')) { if (l.trim().isNotEmpty) _log(l); }
      });
      p.stderr.transform(utf8.decoder).listen((d) {
        for (final l in d.split('\n')) { if (l.trim().isNotEmpty) _log(l); }
      });
      final code = await p.exitCode;
      if (code != 0 && !silent) _log('⚠️ Kod wyjścia: $code');
      _updateStatus();
    } catch (e) {
      if (!silent) _log('❌ Błąd: $e');
    }
  }

  void _log(String msg) {
    if (!mounted) return;
    setState(() {
      _logs.add('[${_ts()}] $msg');
      if (_logs.length > 500) _logs.removeAt(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logSc.hasClients) {
          _logSc.animateTo(_logSc.position.maxScrollExtent,
              duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
        }
      });
    });
  }

  String _ts() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
  }

  // ── Status ─────────────────────────────────
  Future<void> _updateStatus() async {
    try {
      final r = await Process.run('waydroid', ['status'], runInShell: true);
      final out = r.exitCode == 0
          ? (r.stdout as String).trim().replaceAll('\n', ' | ')
          : 'Zatrzymany';
      if (mounted) setState(() => _statusText = '${instances.isNotEmpty ? instances[currentInstance].name : "–"} › $out');
    } catch (_) {
      if (mounted) setState(() => _statusText = 'Błąd statusu');
    }
  }

  void _startStatusTimer() {
    _statusTimer = Timer.periodic(const Duration(seconds: 6), (_) => _updateStatus());
    _updateStatus();
  }

  // ── Apps ───────────────────────────────────
  Future<void> _refreshAppList() async {
    try {
      final r = await Process.run('waydroid', ['app', 'list'], runInShell: true);
      if (r.exitCode != 0) return;
      final lines = (r.stdout as String).split('\n');
      final apps = <AppInfo>[];
      AppInfo? cur;
      for (var line in lines) {
        line = line.trim();
        if (line.startsWith('Name:')) {
          cur = AppInfo(name: line.substring(5).trim());
        } else if (line.startsWith('Package:') && cur != null) {
          cur.package = line.substring(8).trim();
          apps.add(cur);
          cur = null;
        }
      }
      if (mounted) setState(() => _apps = apps);
    } catch (e) {
      _log('Błąd listy aplikacji: $e');
    }
  }

  Future<void> _installApk() async {
    final r = await FilePicker.platform.pickFiles(
      dialogTitle: 'Wybierz plik .apk',
      type: FileType.custom,
      allowedExtensions: ['apk'],
    );
    if (r != null && r.files.single.path != null) {
      await _run(['waydroid', 'app', 'install', r.files.single.path!]);
      await Future.delayed(const Duration(seconds: 2));
      _refreshAppList();
    }
  }

  Future<void> _downloadAndInstallStore(StoreApp app) async {
    final tmp = await getTemporaryDirectory();
    final dest = '${tmp.path}/${app.name.replaceAll(' ', '_')}.apk';
    _log('📥 Pobieranie ${app.name}…');
    try {
      final dl = await Process.run('wget', ['-q', '-O', dest, app.downloadUrl], runInShell: true);
      if (dl.exitCode != 0) {
        await Process.run('curl', ['-L', '-o', dest, app.downloadUrl], runInShell: true);
      }
      if (await File(dest).exists() && await File(dest).length() > 1024) {
        await _run(['waydroid', 'app', 'install', dest]);
        await Future.delayed(const Duration(seconds: 2));
        _refreshAppList();
      } else {
        _log('❌ Bezpośrednie pobieranie nieudane — otwieranie strony…');
        await Process.run('xdg-open', [app.downloadUrl], runInShell: true);
      }
    } catch (e) {
      _log('❌ Błąd pobierania: $e');
    }
  }

  // ── Instances ──────────────────────────────
  void _createInstance(String name) async {
    if (name.isEmpty) return;
    final dataDir = '/var/lib/waydroid_$name';
    await _run(['pkexec', 'mkdir', '-p', dataDir]);
    instances.add(Instance(name: name, dataDir: dataDir));
    await _saveInstances();
    setState(() {});
    _log('✅ Instancja "$name" utworzona');
  }

  void _switchInstance(int i) {
    setState(() => currentInstance = i);
    _updateStatus();
    _log('🔄 Przełączono → ${instances[i].name}');
  }

  Future<void> _deleteInstance(int i) async {
    if (i == 0) { _log('❌ Nie można usunąć domyślnej instancji'); return; }
    instances.removeAt(i);
    if (currentInstance >= instances.length) currentInstance = instances.length - 1;
    await _saveInstances();
    setState(() {});
  }

  // ── Keymapper ──────────────────────────────
  void _addCircle(Offset pos, String key) {
    setState(() => circles.add(KeyCircle(key: key, x: pos.dx, y: pos.dy, radius: 35)));
    _saveKeyMappings();
  }

  void _removeCircle(int i) {
    setState(() => circles.removeAt(i));
    _saveKeyMappings();
  }

  void _onDragStart(int i, Offset start, Offset cPos) {
    _dragIdx = i; _dragStart = start; _circleStart = cPos;
  }

  void _onDragUpdate(Offset pos) {
    if (_dragIdx < 0) return;
    final delta = pos - _dragStart;
    setState(() {
      circles[_dragIdx] = circles[_dragIdx].copyWith(
        x: _circleStart.dx + delta.dx,
        y: _circleStart.dy + delta.dy,
      );
    });
  }

  void _onDragEnd() {
    if (_dragIdx >= 0) { _saveKeyMappings(); _dragIdx = -1; }
  }

  // ── Mouse Steering ─────────────────────────
  void _toggleMouseSteering(bool v) {
    setState(() => mouseSteering = v);
    _log(v ? '🎮 Mouse Steering AKTYWNY — F1 wyłącza' : '🖱️ Mouse Steering wyłączony');
  }

  void _onMouseMove(PointerEvent e) {
    if (!mouseSteering) return;
    final dx = e.localPosition.dx - _lastMouseX;
    final dy = e.localPosition.dy - _lastMouseY;
    _lastMouseX = e.localPosition.dx;
    _lastMouseY = e.localPosition.dy;
    _run([
      'waydroid', 'shell', 'input', 'touchscreen', 'swipe',
      '360', '640',
      (360 + (dx * 2.5).toInt()).toString(),
      (640 + (dy * 2.5).toInt()).toString(),
      '80',
    ], silent: true);
  }

  // ── Key events ─────────────────────────────
  void _onKey(RawKeyEvent e) {
    if (e is! RawKeyDownEvent) return;
    if (e.logicalKey == LogicalKeyboardKey.f1) {
      _toggleMouseSteering(!mouseSteering);
      return;
    }
    final name = e.logicalKey.keyLabel.toLowerCase();
    for (final m in keyMappings) {
      if (m.key == name && m.type == 'tap') {
        _run(['waydroid', 'shell', 'input', 'tap', m.x.toInt().toString(), m.y.toInt().toString()], silent: true);
        break;
      }
    }
  }

  // ── Dialogs ────────────────────────────────
  void _showNewInstanceDialog() {
    String name = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nowa instancja'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(onChanged: (v) => name = v, decoration: const InputDecoration(labelText: 'Nazwa', hintText: 'np. Gaming, Praca…')),
          const SizedBox(height: 6),
          const Text('Katalog: /var/lib/waydroid_<nazwa>', style: TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
          ElevatedButton(onPressed: () { if (name.isNotEmpty) { _createInstance(name); Navigator.pop(ctx); }}, child: const Text('Utwórz')),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: _onKey,
        child: Column(children: [
          _TopBar(
            statusText: _statusText,
            mouseSteering: mouseSteering,
            onStart: () => _run(['waydroid', 'session', 'start']),
            onStop: () => _run(['waydroid', 'session', 'stop']),
            onShowUI: () => _run(['waydroid', 'show-full-ui']),
          ),
          Expanded(
            child: Row(children: [
              _Sidebar(selected: _tab, onSelect: (i) => setState(() => _tab = i)),
              Expanded(child: _pageContent()),
            ]),
          ),
          _LogPanel(
            logs: _logs,
            sc: _logSc,
            expanded: _logExpanded,
            onToggle: () => setState(() => _logExpanded = !_logExpanded),
          ),
        ]),
      ),
    );
  }

  Widget _pageContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: switch (_tab) {
        0 => DashboardPage(
            key: const ValueKey(0),
            instances: instances,
            currentInstance: currentInstance,
            appsCount: _apps.length,
            keymapCount: keyMappings.length,
            onStart: () => _run(['waydroid', 'session', 'start']),
            onStop: () => _run(['waydroid', 'session', 'stop']),
            onShowUI: () => _run(['waydroid', 'show-full-ui']),
            onRefreshStatus: _updateStatus,
          ),
        1 => AppsPage(
            key: const ValueKey(1),
            apps: _apps,
            onRefresh: _refreshAppList,
            onInstallApk: _installApk,
            onLaunch: (p) => _run(['waydroid', 'app', 'launch', p]),
            onRemove: (p) => _run(['waydroid', 'app', 'remove', p]),
          ),
        2 => StorePage(
            key: const ValueKey(2),
            apps: _storeApps,
            onInstall: _downloadAndInstallStore,
          ),
        3 => InstancesPage(
            key: const ValueKey(3),
            instances: instances,
            currentInstance: currentInstance,
            onSwitch: _switchInstance,
            onDelete: _deleteInstance,
            onNew: _showNewInstanceDialog,
          ),
        4 => KeymapperPage(
            key: const ValueKey(4),
            circles: circles,
            draggingIndex: _dragIdx,
            onDragStart: _onDragStart,
            onDragUpdate: _onDragUpdate,
            onDragEnd: _onDragEnd,
            onAdd: _addCircle,
            onRemove: _removeCircle,
            onClear: () { setState(() => circles.clear()); _saveKeyMappings(); },
          ),
        5 => MouseSteeringPage(
            key: const ValueKey(5),
            mouseSteering: mouseSteering,
            onToggle: _toggleMouseSteering,
            onHover: _onMouseMove,
          ),
        _ => ToolsPage(
            key: const ValueKey(6),
            onRun: _run,
            onClearLogs: () => setState(() => _logs.clear()),
          ),
      },
    );
  }
}

// ── Top bar ────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String statusText;
  final bool mouseSteering;
  final VoidCallback onStart, onStop, onShowUI;

  const _TopBar({
    required this.statusText,
    required this.mouseSteering,
    required this.onStart,
    required this.onStop,
    required this.onShowUI,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1120),
        border: Border(bottom: BorderSide(color: Color(0xFF1E2A40))),
      ),
      child: Row(children: [
        const Icon(Icons.android, color: Color(0xFF00E5FF), size: 22),
        const SizedBox(width: 10),
        const Text('HackerDeck', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF00E5FF))),
        const Text(' v4.0', style: TextStyle(color: Colors.white38, fontSize: 13)),
        const SizedBox(width: 24),
        Expanded(child: Text(statusText, style: const TextStyle(fontSize: 12, color: Colors.white54), overflow: TextOverflow.ellipsis)),
        IconButton(icon: const Icon(Icons.play_arrow, color: Colors.greenAccent), tooltip: 'Start sesji', onPressed: onStart),
        IconButton(icon: const Icon(Icons.stop, color: Colors.redAccent), tooltip: 'Stop', onPressed: onStop),
        IconButton(icon: const Icon(Icons.open_in_new, color: Color(0xFF00E5FF)), tooltip: 'Pełny UI', onPressed: onShowUI),
        if (mouseSteering) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.orange)),
            child: const Text('🎮 FPS MODE', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ]),
    );
  }
}

// ── Sidebar ───────────────────────────────────
class _Sidebar extends StatelessWidget {
  final int selected;
  final void Function(int) onSelect;

  static const _items = [
    (Icons.dashboard, 'Dashboard'),
    (Icons.apps, 'Aplikacje'),
    (Icons.shop, 'Sklep APK'),
    (Icons.layers, 'Instancje'),
    (Icons.gamepad, 'Keymapper'),
    (Icons.mouse, 'Mouse FPS'),
    (Icons.build, 'Narzędzia'),
  ];

  const _Sidebar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      decoration: const BoxDecoration(
        color: Color(0xFF0D1120),
        border: Border(right: BorderSide(color: Color(0xFF1E2A40))),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        ..._items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          final sel = selected == i;
          return InkWell(
            onTap: () => onSelect(i),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFF00E5FF).withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: sel ? Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)) : null,
              ),
              child: Row(children: [
                Icon(item.$1, size: 18, color: sel ? const Color(0xFF00E5FF) : Colors.white38),
                const SizedBox(width: 10),
                Text(item.$2, style: TextStyle(fontSize: 13, color: sel ? const Color(0xFF00E5FF) : Colors.white54, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

// ── Log panel ─────────────────────────────────
class _LogPanel extends StatelessWidget {
  final List<String> logs;
  final ScrollController sc;
  final bool expanded;
  final VoidCallback onToggle;

  const _LogPanel({required this.logs, required this.sc, required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: expanded ? 180 : 36,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0D16),
        border: Border(top: BorderSide(color: Color(0xFF1E2A40))),
      ),
      child: Column(children: [
        InkWell(
          onTap: onToggle,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              const Icon(Icons.terminal, size: 14, color: Color(0xFF00E5FF)),
              const SizedBox(width: 8),
              const Text('Logi', style: TextStyle(fontSize: 12, color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text('(${logs.length})', style: const TextStyle(fontSize: 11, color: Colors.white38)),
              const Spacer(),
              Icon(expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, size: 16, color: Colors.white38),
            ]),
          ),
        ),
        if (expanded)
          Expanded(
            child: ListView.builder(
              controller: sc,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: logs.length,
              itemBuilder: (_, i) => Text(
                logs[i],
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: logs[i].contains('❌') || logs[i].contains('⚠️')
                      ? Colors.redAccent
                      : logs[i].contains('✅') || logs[i].contains('🎉')
                          ? Colors.greenAccent
                          : Colors.white54,
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
