// ─────────────────────────────────────────────
//  HackerDeck — APK Store Page
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:hackerdeck/models.dart';

class StorePage extends StatefulWidget {
  final List<StoreApp> apps;
  final void Function(StoreApp app) onInstall;

  const StorePage({super.key, required this.apps, required this.onInstall});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  String _search = '';
  String _cat = 'Wszystkie';

  @override
  Widget build(BuildContext context) {
    final cats = ['Wszystkie', ...{...widget.apps.map((a) => a.category)}];
    final filtered = widget.apps.where((a) {
      final mc = _cat == 'Wszystkie' || a.category == _cat;
      final ms = _search.isEmpty || a.name.toLowerCase().contains(_search.toLowerCase());
      return mc && ms;
    }).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Text('Sklep APK', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          SizedBox(
            width: 220,
            child: TextField(
              decoration: const InputDecoration(hintText: 'Szukaj…', prefixIcon: Icon(Icons.search, size: 18), isDense: true, border: OutlineInputBorder()),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _cat,
            items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _cat = v!),
          ),
        ]),
      ),
      Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.07), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withOpacity(0.2))),
        child: const Row(children: [
          Icon(Icons.info_outline, size: 16, color: Colors.blueAccent),
          SizedBox(width: 8),
          Expanded(child: Text('Darmowe aplikacje open-source. Przy braku bezpośredniego linku APK otworzy się strona pobierania.', style: TextStyle(fontSize: 12, color: Colors.white70))),
        ]),
      ),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: filtered.length,
          itemBuilder: (ctx, i) => _StoreCard(app: filtered[i], onInstall: () => widget.onInstall(filtered[i])),
        ),
      ),
    ]);
  }
}

class _StoreCard extends StatelessWidget {
  final StoreApp app;
  final VoidCallback onInstall;
  const _StoreCard({required this.app, required this.onInstall});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(app.icon, style: const TextStyle(fontSize: 30)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)), child: Text(app.category, style: const TextStyle(fontSize: 10, color: Colors.white54))),
          ]),
          const SizedBox(height: 8),
          Text(app.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text('v${app.version}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 6),
          Text(app.description, style: const TextStyle(color: Colors.white60, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onInstall,
              icon: const Icon(Icons.download, size: 14),
              label: const Text('Zainstaluj', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
            ),
          ),
        ]),
      ),
    );
  }
}
