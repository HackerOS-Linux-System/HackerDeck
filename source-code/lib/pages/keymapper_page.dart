// ─────────────────────────────────────────────
//  HackerDeck — Keymapper Page
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:hackerdeck/models.dart';
import 'package:hackerdeck/keymapper_painter.dart';

class KeymapperPage extends StatelessWidget {
  final List<KeyCircle> circles;
  final int draggingIndex;
  final void Function(int index, Offset start, Offset circlePos) onDragStart;
  final void Function(Offset pos) onDragUpdate;
  final VoidCallback onDragEnd;
  final void Function(Offset pos, String key) onAdd;
  final void Function(int index) onRemove;
  final VoidCallback onClear;

  const KeymapperPage({
    super.key,
    required this.circles,
    required this.draggingIndex,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onAdd,
    required this.onRemove,
    required this.onClear,
  });

  void _showAddDialog(BuildContext context) {
    String key = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nowy mapping klawisza'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(onChanged: (v) => key = v, decoration: const InputDecoration(labelText: 'Klawisz', hintText: 'w / a / s / d / space / f2…')),
          const SizedBox(height: 8),
          const Text('Kółko pojawi się na środku. Przeciągnij je na właściwe miejsce.', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
          ElevatedButton(
            onPressed: () {
              if (key.isNotEmpty) {
                onAdd(const Offset(360, 300), key.toLowerCase());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Text('Visual Keymapper', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          ElevatedButton.icon(onPressed: () => _showAddDialog(context), icon: const Icon(Icons.add_circle, size: 16), label: const Text('Dodaj klawisz')),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: onClear, icon: const Icon(Icons.clear_all, size: 16), label: const Text('Wyczyść')),
        ]),
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.07), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withOpacity(0.2))),
        child: const Row(children: [
          Icon(Icons.touch_app, size: 16, color: Colors.blueAccent),
          SizedBox(width: 8),
          Text('Przeciągaj kółka LPM. Prawy klik = usuń. Umieść okno HackerDeck nad Waydroid.', style: TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
      ),
      Expanded(
        child: GestureDetector(
          onPanStart: (d) {
            for (int i = 0; i < circles.length; i++) {
              final c = circles[i];
              final p = d.localPosition;
              if ((p.dx - c.x).abs() < c.radius && (p.dy - c.y).abs() < c.radius) {
                onDragStart(i, p, Offset(c.x, c.y));
                break;
              }
            }
          },
          onPanUpdate: (d) => onDragUpdate(d.localPosition),
          onPanEnd: (_) => onDragEnd(),
          onSecondaryTapDown: (d) {
            for (int i = 0; i < circles.length; i++) {
              final c = circles[i];
              final p = d.localPosition;
              if ((p.dx - c.x).abs() < c.radius && (p.dy - c.y).abs() < c.radius) {
                onRemove(i);
                break;
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              border: Border.all(color: Colors.white12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: KeymapperPainter(circles: circles, draggingIndex: draggingIndex),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
