import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/process_run.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setTitle('HackerDeck v3.0');
    await windowManager.setSize(const Size(1300, 850));
    await windowManager.setMinimumSize(const Size(800, 600));
    await windowManager.show();
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HackerDeck',
      theme: ThemeData.dark().copyWith(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
      ),
      home: const HackerDeckHome(),
    );
  }
}

class HackerDeckHome extends StatefulWidget {
  const HackerDeckHome({super.key});

  @override
  State<HackerDeckHome> createState() => _HackerDeckHomeState();
}

class _HackerDeckHomeState extends State<HackerDeckHome>
    with WidgetsBindingObserver, WindowListener {
  // --------------------- Dane ---------------------
  List<Instance> instances = [];
  int currentInstance = 0;

  List<KeyMapping> keyMappings = [];
  List<KeyCircle> circles = [];

  bool mouseSteering = false;
  double lastMouseX = 0, lastMouseY = 0;
  final FocusNode _focusNode = FocusNode();

  final List<String> logs = [];
  final ScrollController _logScrollController = ScrollController();
  Timer? _statusTimer;

  // --------------------- Inicjalizacja ---------------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    windowManager.addListener(this);
    _loadConfigs();
    _loadKeyMappings();
    _startStatusTimer();
    _focusNode.requestFocus();
    _checkWaydroid();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this);
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {}

  @override
  void onWindowFocus() {
    _focusNode.requestFocus();
  }

  // --------------------- Pliki konfiguracyjne ---------------------
  Future<Directory> _getConfigDir() async {
    final home = Platform.environment['HOME'];
    if (home == null) throw Exception('HOME not set');
    final dir = Directory('$home/.config/hackerdeck');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _loadConfigs() async {
    try {
      final configDir = await _getConfigDir();
      final file = File('${configDir.path}/instances.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        instances = List<Instance>.from(
          (jsonDecode(content) as List).map((e) => Instance.fromJson(e)),
        );
      } else {
        instances = [Instance(name: 'Domyślna', dataDir: '/var/lib/waydroid')];
        await _saveInstances();
      }
    } catch (e) {
      _addLog('Błąd ładowania instancji: $e');
      instances = [Instance(name: 'Domyślna', dataDir: '/var/lib/waydroid')];
    }
    setState(() {});
  }

  Future<void> _saveInstances() async {
    final configDir = await _getConfigDir();
    final file = File('${configDir.path}/instances.json');
    await file.writeAsString(jsonEncode(instances.map((e) => e.toJson()).toList()));
  }

  Future<void> _loadKeyMappings() async {
    try {
      final configDir = await _getConfigDir();
      final file = File('${configDir.path}/keymaps.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        keyMappings = List<KeyMapping>.from(
          (jsonDecode(content) as List).map((e) => KeyMapping.fromJson(e)),
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
      _addLog('Błąd ładowania keymap: $e');
    }
    setState(() {});
  }

  Future<void> _saveKeyMappings() async {
    keyMappings = circles
        .map((c) => KeyMapping(key: c.key, type: 'tap', x: c.x, y: c.y))
        .toList();
    final configDir = await _getConfigDir();
    final file = File('${configDir.path}/keymaps.json');
    await file.writeAsString(jsonEncode(keyMappings.map((e) => e.toJson()).toList()));
  }

  // --------------------- Wykonywanie poleceń ---------------------
  Future<void> _runCommand(List<String> args, {bool needsRoot = false}) async {
    _addLog('🚀 ${args.join(' ')}');
    List<String> fullArgs = args;
    if (needsRoot) {
      fullArgs = ['pkexec', ...args];
    }

    Map<String, String> env = {};
    if (currentInstance < instances.length &&
        instances[currentInstance].dataDir != '/var/lib/waydroid') {
      env['WAYDROID_DATA'] = instances[currentInstance].dataDir;
    }

    try {
      final process = await Process.start(fullArgs.first, fullArgs.skip(1).toList(),
          environment: env, runInShell: true);
      process.stdout.transform(utf8.decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.isNotEmpty) _addLog(line);
        }
      });
      process.stderr.transform(utf8.decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.isNotEmpty) _addLog(line);
        }
      });
      final exitCode = await process.exitCode;
      if (exitCode != 0) _addLog('⚠️ Polecenie zakończone z kodem $exitCode');
      _updateStatus();
      _refreshAppList();
    } catch (e) {
      _addLog('❌ Błąd wykonania: $e');
    }
  }

  void _addLog(String msg) {
    if (mounted) {
      setState(() {
        logs.add(msg);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_logScrollController.hasClients) {
            _logScrollController.animateTo(
              _logScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      });
    }
  }

  // --------------------- Funkcje interfejsu ---------------------
  String _statusText = 'HackerDeck v3.0 gotowy';

  Future<void> _updateStatus() async {
    try {
      final result = await Process.run('waydroid', ['status'], runInShell: true);
      if (result.exitCode == 0) {
        final output = (result.stdout as String).trim();
        setState(() {
          _statusText = 'Instancja: ${instances[currentInstance].name} | $output';
        });
      } else {
        setState(() {
          _statusText = 'Instancja: ${instances[currentInstance].name} | Waydroid nie działa';
        });
      }
    } catch (e) {
      setState(() {
        _statusText = 'Instancja: ${instances[currentInstance].name} | Błąd statusu';
      });
    }
  }

  void _startStatusTimer() {
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) => _updateStatus());
    _updateStatus();
  }

  bool _isWaydroidInstalled() {
    try {
      final result = Process.runSync('which', ['waydroid'], runInShell: true);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  void _checkWaydroid() {
    if (!_isWaydroidInstalled()) {
      _addLog('🔴 Waydroid nie jest zainstalowany. Przejdź do zakładki Narzędzia, aby zainstalować.');
    }
  }

  // --------------------- Lista aplikacji ---------------------
  List<AppInfo> _apps = [];
  Future<void> _refreshAppList() async {
    try {
      final result = await Process.run('waydroid', ['app', 'list'], runInShell: true);
      if (result.exitCode != 0) return;
      final lines = (result.stdout as String).split('\n');
      List<AppInfo> apps = [];
      AppInfo? current;
      for (var line in lines) {
        line = line.trim();
        if (line.startsWith('Name:')) {
          current = AppInfo(name: line.substring(5).trim());
        } else if (line.startsWith('Package:')) {
          if (current != null) {
            current.package = line.substring(8).trim();
            current.icon = await _getAppIcon(current.package);
            apps.add(current);
            current = null;
          }
        }
      }
      setState(() {
        _apps = apps;
      });
    } catch (e) {
      _addLog('Błąd odświeżania listy aplikacji: $e');
    }
  }

  Future<String> _getAppIcon(String pkg) async {
    try {
      final result = await Process.run(
        'sh',
        ['-c', 'find /var/lib/waydroid/overlay -name "*.png" -path "*/$pkg*" | head -1'],
        runInShell: true,
      );
      if (result.exitCode == 0 && (result.stdout as String).isNotEmpty) {
        return (result.stdout as String).trim();
      }
    } catch (_) {}
    return '';
  }

  // --------------------- Instalacja APK ---------------------
  Future<void> _installApk() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Wybierz plik .apk',
      type: FileType.custom,
      allowedExtensions: ['apk'],
    );
    if (result != null && result.files.single.path != null) {
      await _runCommand(['waydroid', 'app', 'install', result.files.single.path!],
          needsRoot: false);
      await Future.delayed(const Duration(seconds: 2));
      _refreshAppList();
    }
  }

  // --------------------- Zarządzanie instancjami ---------------------
  void _createNewInstance(String name) async {
    if (name.isEmpty) return;
    final dataDir = '/var/lib/waydroid_instance_${instances.length}';
    await _runCommand(['pkexec', 'mkdir', '-p', dataDir], needsRoot: true);
    await _runCommand(['pkexec', 'cp', '-r', '/var/lib/waydroid', dataDir], needsRoot: true);
    instances.add(Instance(name: name, dataDir: dataDir));
    await _saveInstances();
    setState(() {});
  }

  void _switchInstance(int index) {
    setState(() {
      currentInstance = index;
    });
    _updateStatus();
    _addLog('Przełączono na instancję: ${instances[currentInstance].name}');
  }

  // --------------------- Wizualny keymapper ---------------------
  int _draggingIndex = -1;
  Offset _dragStart = Offset.zero;
  Offset _circleStart = Offset.zero;

  void _addCircle(Offset position, String key) {
    setState(() {
      circles.add(KeyCircle(key: key, x: position.dx, y: position.dy, radius: 35));
    });
    _saveKeyMappings();
  }

  void _startDrag(int index, Offset startPos, Offset circlePos) {
    _draggingIndex = index;
    _dragStart = startPos;
    _circleStart = circlePos;
  }

  void _updateDrag(Offset newPos) {
    if (_draggingIndex != -1) {
      final delta = newPos - _dragStart;
      setState(() {
        circles[_draggingIndex] = circles[_draggingIndex].copyWith(
          x: _circleStart.dx + delta.dx,
          y: _circleStart.dy + delta.dy,
        );
      });
    }
  }

  void _endDrag() {
    if (_draggingIndex != -1) {
      _saveKeyMappings();
      _draggingIndex = -1;
    }
  }

  // --------------------- Mouse Steering ---------------------
  void _toggleMouseSteering(bool value) async {
    setState(() {
      mouseSteering = value;
    });
    if (value) {
      _addLog('🎮 Mouse Steering AKTYWNY (F1 do wyłączenia)');
      // Ukrywanie kursora wymagałoby użycia natywnego kodu – w tej wersji pomijamy.
    } else {
      _addLog('Mouse Steering wyłączony');
    }
  }

  void _onMouseMove(PointerEvent event) {
    if (!mouseSteering) return;
    final dx = event.localPosition.dx - lastMouseX;
    final dy = event.localPosition.dy - lastMouseY;
    lastMouseX = event.localPosition.dx;
    lastMouseY = event.localPosition.dy;
    final centerX = 360;
    final centerY = 640;
    _runCommand([
      'waydroid',
      'shell',
      'input',
      'touchscreen',
      'swipe',
      centerX.toString(),
      centerY.toString(),
      (centerX + (dx * 2.5).toInt()).toString(),
      (centerY + (dy * 2.5).toInt()).toString(),
      '80',
    ], needsRoot: false);
  }

  // --------------------- Obsługa klawiszy ---------------------
  void _onKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.f1) {
        _toggleMouseSteering(!mouseSteering);
        return;
      }
      final keyName = event.logicalKey.keyLabel.toLowerCase();
      for (final mapping in keyMappings) {
        if (mapping.key == keyName && mapping.type == 'tap') {
          _runCommand([
            'waydroid',
            'shell',
            'input',
            'tap',
            mapping.x.toInt().toString(),
            mapping.y.toInt().toString(),
          ], needsRoot: false);
          break;
        }
      }
    }
  }

  // --------------------- Instalator Waydroid ---------------------
  Future<void> _fullInstaller() async {
    _addLog('=== ROZPOCZYNAM INSTALACJĘ HACKERDECK ===');
    await _runCommand(['pkexec', 'apt', 'update'], needsRoot: true);
    await _runCommand(['pkexec', 'apt', 'install', '-y', 'curl', 'ca-certificates'], needsRoot: true);
    await _runCommand(['pkexec', 'bash', '-c', 'curl -s https://repo.waydro.id | bash'], needsRoot: true);
    await _runCommand(['pkexec', 'apt', 'install', '-y', 'waydroid'], needsRoot: true);
    await _runCommand(['waydroid', 'init', '-s', 'GAPPS'], needsRoot: false);
    _addLog('🎉 Instalacja zakończona! Uruchom ponownie HackerDeck.');
    final configDir = await _getConfigDir();
    await File('${configDir.path}/installed').writeAsString('1');
  }

  // --------------------- Budowanie UI ---------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: _onKeyEvent,
        child: Column(
          children: [
            // Górny pasek statusu
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.computer, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_statusText)),
                ],
              ),
            ),
            // Główny notebook (zakładki)
            Expanded(
              child: DefaultTabController(
                length: 6,
                child: Column(
                  children: [
                    TabBar(
                      isScrollable: true,
                      tabs: const [
                        Tab(text: 'Status'),
                        Tab(text: 'Aplikacje'),
                        Tab(text: 'Instancje'),
                        Tab(text: 'Visual Keymapper'),
                        Tab(text: 'Mouse Steering (FPS)'),
                        Tab(text: 'Narzędzia'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildStatusPage(),
                          _buildAppsPage(),
                          _buildInstancesPage(),
                          _buildVisualKeymapperPage(),
                          _buildMouseSteeringPage(),
                          _buildToolsPage(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Obszar logów
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade800)),
              ),
              child: ListView.builder(
                controller: _logScrollController,
                reverse: true,
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Text(
                      logs[logs.length - 1 - index],
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------- Strona Status ---------------------
  Widget _buildStatusPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          ElevatedButton.icon(
            onPressed: () => _runCommand(['waydroid', 'container', 'start'], needsRoot: false),
            icon: const Icon(Icons.play_arrow),
            label: const Text('▶ Start kontenera'),
          ),
          ElevatedButton.icon(
            onPressed: () => _runCommand(['waydroid', 'session', 'start'], needsRoot: false),
            icon: const Icon(Icons.play_arrow),
            label: const Text('▶ Start sesji'),
          ),
          ElevatedButton.icon(
            onPressed: () => _runCommand(['waydroid', 'show-full-ui'], needsRoot: false),
            icon: const Icon(Icons.visibility),
            label: const Text('📺 Pełny interfejs'),
          ),
          ElevatedButton.icon(
            onPressed: () => _runCommand(['waydroid', 'session', 'stop'], needsRoot: false),
            icon: const Icon(Icons.stop),
            label: const Text('⏹ Zatrzymaj wszystko'),
          ),
        ],
      ),
    );
  }

  // --------------------- Strona Aplikacje ---------------------
  Widget _buildAppsPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _refreshAppList,
                icon: const Icon(Icons.refresh),
                label: const Text('Odśwież listę'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _installApk,
                icon: const Icon(Icons.install_desktop),
                label: const Text('📦 Zainstaluj APK'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _apps.length,
            itemBuilder: (context, index) {
              final app = _apps[index];
              return ListTile(
                leading: app.icon.isNotEmpty
                    ? Image.file(File(app.icon), width: 48, height: 48, fit: BoxFit.cover)
                    : const Icon(Icons.android, size: 48),
                title: Text(app.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(app.package),
                trailing: ElevatedButton(
                  onPressed: () => _runCommand(['waydroid', 'app', 'launch', app.package],
                      needsRoot: false),
                  child: const Text('Uruchom'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --------------------- Strona Instancje ---------------------
  Widget _buildInstancesPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: instances.length,
              itemBuilder: (context, index) {
                final inst = instances[index];
                final isActive = index == currentInstance;
                return Card(
                  child: ListTile(
                    title: Text(
                      inst.name,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _switchInstance(index),
                      child: const Text('Przełącz'),
                    ),
                  ),
                );
              },
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  String name = '';
                  return AlertDialog(
                    title: const Text('Nowa instancja'),
                    content: TextField(
                      onChanged: (v) => name = v,
                      decoration: const InputDecoration(hintText: 'Nazwa (np. PUBG)'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Anuluj'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (name.isNotEmpty) {
                            _createNewInstance(name);
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Utwórz'),
                      ),
                    ],
                  );
                },
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('➕ Nowa instancja'),
          ),
        ],
      ),
    );
  }

  // --------------------- Strona Visual Keymapper ---------------------
  Widget _buildVisualKeymapperPage() {
    return GestureDetector(
      onPanStart: (details) {
        for (int i = 0; i < circles.length; i++) {
          final circle = circles[i];
          final pos = details.localPosition;
          if ((pos.dx - circle.x).abs() < circle.radius &&
              (pos.dy - circle.y).abs() < circle.radius) {
            _startDrag(i, pos, Offset(circle.x, circle.y));
            break;
          }
        }
      },
      onPanUpdate: (details) => _updateDrag(details.localPosition),
      onPanEnd: (_) => _endDrag(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        String key = '';
                        return AlertDialog(
                          title: const Text('Nowy klawisz'),
                          content: TextField(
                            onChanged: (v) => key = v,
                            decoration:
                                const InputDecoration(hintText: 'w / a / s / d / space / f1 ...'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Anuluj'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                if (key.isNotEmpty) {
                                  _addCircle(Offset(360, 640), key);
                                  Navigator.pop(context);
                                }
                              },
                              child: const Text('Zapisz'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.add_circle),
                  label: const Text('Dodaj klawisz'),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Kliknij → podaj klawisz.\nKółka przeciągaj myszką.\nOkno możesz umieścić nad Waydroid.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(12),
              child: CustomPaint(
                painter: KeymapperPainter(circles: circles),
                size: Size.infinite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------- Strona Mouse Steering ---------------------
  Widget _buildMouseSteeringPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('F1 = włącz/wyłącz tryb FPS\nRuch myszy = spojrzenie kamerą (PUBG, Free Fire)'),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Mouse Steering: '),
              Switch(
                value: mouseSteering,
                onChanged: _toggleMouseSteering,
              ),
            ],
          ),
          Expanded(
            child: MouseRegion(
              onHover: _onMouseMove,
              child: Container(),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------- Strona Narzędzia ---------------------
  Widget _buildToolsPage() {
    if (!_isWaydroidInstalled()) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _fullInstaller,
          icon: const Icon(Icons.download),
          label: const Text('🚀 Zainstaluj Waydroid + GAPPS'),
        ),
      );
    } else {
      return Center(
        child: ElevatedButton.icon(
          onPressed: () => _runCommand(['waydroid', 'init', '-s', 'GAPPS'], needsRoot: false),
          icon: const Icon(Icons.sync),
          label: const Text('🔄 Reinicjalizuj Waydroid'),
        ),
      );
    }
  }
}

// --------------------- Modele danych ---------------------
class Instance {
  final String name;
  final String dataDir;

  Instance({required this.name, required this.dataDir});

  factory Instance.fromJson(Map<String, dynamic> json) {
    return Instance(
      name: json['name'] as String,
      dataDir: json['data_dir'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'data_dir': dataDir};
}

class KeyMapping {
  final String key;
  final String type;
  final double x;
  final double y;

  KeyMapping({required this.key, required this.type, required this.x, required this.y});

  factory KeyMapping.fromJson(Map<String, dynamic> json) {
    return KeyMapping(
      key: json['key'] as String,
      type: json['type'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'key': key, 'type': type, 'x': x, 'y': y};
}

class KeyCircle {
  final String key;
  final double x;
  final double y;
  final double radius;

  KeyCircle({required this.key, required this.x, required this.y, required this.radius});

  KeyCircle copyWith({String? key, double? x, double? y, double? radius}) {
    return KeyCircle(
      key: key ?? this.key,
      x: x ?? this.x,
      y: y ?? this.y,
      radius: radius ?? this.radius,
    );
  }
}

class AppInfo {
  String name;
  String package;
  String icon;

  AppInfo({required this.name, this.package = '', this.icon = ''});
}

// --------------------- Malarz wizualnego keymapper'a ---------------------
class KeymapperPainter extends CustomPainter {
  final List<KeyCircle> circles;

  KeymapperPainter({required this.circles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.cyan.withOpacity(0.9)..style = PaintingStyle.fill;
    final textPaint = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (final circle in circles) {
      canvas.drawCircle(Offset(circle.x, circle.y), circle.radius, paint);
      textPaint.text = TextSpan(
        text: circle.key.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 28),
      );
      textPaint.layout();
      textPaint.paint(
        canvas,
        Offset(circle.x - textPaint.width / 2, circle.y - textPaint.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant KeymapperPainter oldDelegate) {
    return circles != oldDelegate.circles;
  }
}
