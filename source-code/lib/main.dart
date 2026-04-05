// ─────────────────────────────────────────────
//  HackerDeck v4.0 — Entry Point
// ─────────────────────────────────────────────
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:hackerdeck/theme.dart';
import 'package:hackerdeck/setup_wizard.dart';
import 'package:hackerdeck/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setTitle('HackerDeck v4.0');
    await windowManager.setSize(const Size(1400, 900));
    await windowManager.setMinimumSize(const Size(900, 650));
    await windowManager.center();
    await windowManager.show();
  });
  runApp(const HackerDeckApp());
}

class HackerDeckApp extends StatelessWidget {
  const HackerDeckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HackerDeck',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _Bootstrap(),
    );
  }
}

// Checks environment on startup — shows wizard if Waydroid missing
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  bool _checking = true;
  bool _needsSetup = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    // Check waydroid binary
    final waydroid = Process.runSync('which', ['waydroid'], runInShell: true);
    // Check binder device (more reliable than checking lxc-ls package)
    final binder = Process.runSync('test', ['-e', '/dev/binder'], runInShell: true);
    // Need setup if waydroid missing OR binder missing
    final needs = waydroid.exitCode != 0 || binder.exitCode != 0;
    if (mounted) setState(() { _checking = false; _needsSetup = needs; });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: Color(0xFF00E5FF)),
          SizedBox(height: 16),
          Text('Sprawdzanie środowiska…', style: TextStyle(color: Colors.white54)),
        ])),
      );
    }
    if (_needsSetup) {
      return SetupWizard(onFinished: () => setState(() => _needsSetup = false));
    }
    return const HackerDeckHome();
  }
}
