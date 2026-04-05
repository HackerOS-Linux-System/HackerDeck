// ─────────────────────────────────────────────
//  HackerDeck — Mouse Steering Page
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';

class MouseSteeringPage extends StatelessWidget {
  final bool mouseSteering;
  final void Function(bool) onToggle;
  final void Function(PointerEvent) onHover;

  const MouseSteeringPage({
    super.key,
    required this.mouseSteering,
    required this.onToggle,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Mouse Steering (FPS)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Tryb FPS:', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 16),
            Switch(value: mouseSteering, onChanged: onToggle, activeColor: const Color(0xFF00E5FF)),
            const SizedBox(width: 12),
            Text(
              mouseSteering ? 'AKTYWNY' : 'WYŁĄCZONY',
              style: TextStyle(fontWeight: FontWeight.bold, color: mouseSteering ? Colors.greenAccent : Colors.white38),
            ),
          ]),
          const Divider(height: 24),
          ...[
            ('F1', 'Przełącz Mouse Steering on/off'),
            ('Ruch myszy', 'Symuluje obrót kamery (waydroid shell input swipe)'),
            ('Czułość', 'x2.5 proporcjonalnie do ruchu myszy'),
          ].map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Container(width: 120, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)), child: Text(e.$1, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
              const SizedBox(width: 12),
              Text(e.$2, style: const TextStyle(color: Colors.white70)),
            ]),
          )),
        ]))),
        const SizedBox(height: 16),
        Expanded(
          child: MouseRegion(
            onHover: onHover,
            child: Container(
              decoration: BoxDecoration(
                color: mouseSteering ? Colors.orange.withOpacity(0.05) : Colors.transparent,
                border: Border.all(color: mouseSteering ? Colors.orange.withOpacity(0.4) : Colors.white12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.mouse, size: 48, color: mouseSteering ? Colors.orange : Colors.white12),
                const SizedBox(height: 12),
                Text(
                  mouseSteering
                      ? 'Obszar śledzenia aktywny\nPrzesuń mysz tutaj aby sterować kamerą'
                      : 'Włącz tryb FPS lub naciśnij F1',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: mouseSteering ? Colors.orange : Colors.white38),
                ),
              ])),
            ),
          ),
        ),
      ]),
    );
  }
}
