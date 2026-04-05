// ─────────────────────────────────────────────
//  HackerDeck — Tools Page
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';

class ToolsPage extends StatelessWidget {
  final void Function(List<String> args) onRun;
  final VoidCallback onClearLogs;

  const ToolsPage({super.key, required this.onRun, required this.onClearLogs});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Narzędzia systemowe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _section('Waydroid', [
          _btn(Icons.sync, 'Reinicjalizuj (GAPPS)', () => onRun(['waydroid', 'init', '-s', 'GAPPS'])),
          _btn(Icons.sync_alt, 'Reinicjalizuj (vanilla)', () => onRun(['waydroid', 'init'])),
          _btn(Icons.settings_applications, 'waydroid shell', () => onRun(['waydroid', 'shell'])),
          _btn(Icons.bug_report, 'Logi kontenera', () => onRun(['journalctl', '-u', 'waydroid-container', '-n', '80', '--no-pager'])),
          _btn(Icons.info_outline, 'waydroid status', () => onRun(['waydroid', 'status'])),
        ]),
        const SizedBox(height: 16),
        _section('Binder / Kernel', [
          _btn(Icons.memory, 'Załaduj binder_linux', () => onRun(['pkexec', 'modprobe', 'binder_linux', 'num_devices=4'])),
          _btn(Icons.list_alt, 'Sprawdź /dev/binder', () => onRun(['ls', '-la', '/dev/binder*'])),
          _btn(Icons.terminal, 'Wersja kernela', () => onRun(['uname', '-r'])),
        ]),
        const SizedBox(height: 16),
        _section('ADB', [
          _btn(Icons.usb, 'Lista urządzeń ADB', () => onRun(['adb', 'devices'])),
          _btn(Icons.terminal, 'ADB shell', () => onRun(['adb', 'shell'])),
          _btn(Icons.network_check, 'Ping test (przez ADB)', () => onRun(['adb', 'shell', 'ping', '-c', '3', '8.8.8.8'])),
        ]),
        const SizedBox(height: 16),
        _section('System', [
          _btn(Icons.memory, 'Użycie RAM', () => onRun(['free', '-h'])),
          _btn(Icons.storage, 'Dysk /var/lib/waydroid', () => onRun(['df', '-h', '/var/lib/waydroid'])),
          _btn(Icons.cleaning_services, 'Wyczyść logi', onClearLogs),
        ]),
      ]),
    );
  }

  Widget _section(String title, List<Widget> btns) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: btns),
    ]);
  }

  Widget _btn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFF131929), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: const Color(0xFF00E5FF)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
        ]),
      ),
    );
  }
}
