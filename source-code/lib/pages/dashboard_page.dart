// ─────────────────────────────────────────────
//  HackerDeck — Dashboard Page
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:hackerdeck/models.dart';

class DashboardPage extends StatelessWidget {
  final List<Instance> instances;
  final int currentInstance;
  final int appsCount;
  final int keymapCount;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onShowUI;
  final VoidCallback onRefreshStatus;

  const DashboardPage({
    super.key,
    required this.instances,
    required this.currentInstance,
    required this.appsCount,
    required this.keymapCount,
    required this.onStart,
    required this.onStop,
    required this.onShowUI,
    required this.onRefreshStatus,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _quickCard(Icons.play_arrow, 'Start sesji', Colors.greenAccent, onStart),
          _quickCard(Icons.stop, 'Stop wszystko', Colors.redAccent, onStop),
          _quickCard(Icons.open_in_new, 'Pełny UI', Colors.blueAccent, onShowUI),
          _quickCard(Icons.refresh, 'Odśwież status', Colors.orangeAccent, onRefreshStatus),
        ]),
        const SizedBox(height: 24),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _statCard(
            'Aktywna instancja',
            instances.isNotEmpty ? instances[currentInstance].name : '–',
            subtitle: instances.isNotEmpty ? instances[currentInstance].dataDir : '',
          )),
          const SizedBox(width: 12),
          Expanded(child: _statCard('Aplikacje', '$appsCount', big: true)),
          const SizedBox(width: 12),
          Expanded(child: _statCard('Mapowania klawiszy', '$keymapCount', big: true)),
        ]),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Skróty klawiszowe', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...[
            ('F1', 'Włącz / wyłącz Mouse Steering (FPS)'),
            ('Zmapowane klawisze', 'Generują dotknięcia ekranu Waydroid'),
          ].map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)), child: Text(e.$1, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
              const SizedBox(width: 12),
              Text(e.$2, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          )),
        ]))),
      ]),
    );
  }

  Widget _quickCard(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _statCard(String label, String value, {String subtitle = '', bool big = false}) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: big ? 32 : 18, fontWeight: FontWeight.bold, color: const Color(0xFF00E5FF))),
      if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
    ])));
  }
}
