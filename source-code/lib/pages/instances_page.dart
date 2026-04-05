// ─────────────────────────────────────────────
//  HackerDeck — Instances Page
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:hackerdeck/models.dart';

class InstancesPage extends StatelessWidget {
  final List<Instance> instances;
  final int currentInstance;
  final void Function(int) onSwitch;
  final void Function(int) onDelete;
  final VoidCallback onNew;

  const InstancesPage({
    super.key,
    required this.instances,
    required this.currentInstance,
    required this.onSwitch,
    required this.onDelete,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Instancje Waydroid', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          ElevatedButton.icon(onPressed: onNew, icon: const Icon(Icons.add, size: 16), label: const Text('Nowa instancja')),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.07), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.withOpacity(0.2))),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 16, color: Colors.amber),
            SizedBox(width: 8),
            Expanded(child: Text('Każda instancja ma własny katalog danych Android. Po utworzeniu nowej instancji uruchom „waydroid init" w Narzędziach.', style: TextStyle(fontSize: 12, color: Colors.white70))),
          ]),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: instances.length,
            itemBuilder: (ctx, i) {
              final inst = instances[i];
              final active = i == currentInstance;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: active ? const Color(0xFF00E5FF).withOpacity(0.2) : Colors.white10,
                    child: Icon(Icons.android, color: active ? const Color(0xFF00E5FF) : Colors.white38, size: 20),
                  ),
                  title: Text(inst.name, style: TextStyle(fontWeight: active ? FontWeight.bold : FontWeight.normal, color: active ? const Color(0xFF00E5FF) : Colors.white)),
                  subtitle: Text(inst.dataDir, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (active)
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF00E5FF).withOpacity(0.12), borderRadius: BorderRadius.circular(4)), child: const Text('AKTYWNA', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold))),
                    if (!active) ...[
                      ElevatedButton(onPressed: () => onSwitch(i), child: const Text('Przełącz', style: TextStyle(fontSize: 12))),
                      const SizedBox(width: 6),
                    ],
                    if (i != 0)
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => onDelete(i), tooltip: 'Usuń'),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
