// ─────────────────────────────────────────────
//  HackerDeck — Apps Page
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:hackerdeck/models.dart';

class AppsPage extends StatelessWidget {
  final List<AppInfo> apps;
  final VoidCallback onRefresh;
  final VoidCallback onInstallApk;
  final void Function(String package) onLaunch;
  final void Function(String package) onRemove;

  const AppsPage({
    super.key,
    required this.apps,
    required this.onRefresh,
    required this.onInstallApk,
    required this.onLaunch,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Text('Aplikacje', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          ElevatedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Odśwież')),
          const SizedBox(width: 8),
          ElevatedButton.icon(onPressed: onInstallApk, icon: const Icon(Icons.install_desktop, size: 16), label: const Text('Zainstaluj APK')),
        ]),
      ),
      Expanded(
        child: apps.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.android, size: 64, color: Colors.white12),
                const SizedBox(height: 12),
                const Text('Brak aplikacji', style: TextStyle(color: Colors.white38)),
                const SizedBox(height: 8),
                TextButton(onPressed: onRefresh, child: const Text('Odśwież listę')),
              ]))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: apps.length,
                itemBuilder: (ctx, i) => _AppCard(
                  app: apps[i],
                  onLaunch: () => onLaunch(apps[i].package),
                  onRemove: () => onRemove(apps[i].package),
                ),
              ),
      ),
    ]);
  }
}

class _AppCard extends StatelessWidget {
  final AppInfo app;
  final VoidCallback onLaunch;
  final VoidCallback onRemove;

  const _AppCard({required this.app, required this.onLaunch, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onLaunch,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.android, size: 48, color: Color(0xFF00E5FF)),
            const SizedBox(height: 8),
            Text(app.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(app.package, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 10)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _MiniBtn(icon: Icons.play_arrow, color: Colors.greenAccent, onTap: onLaunch),
              const SizedBox(width: 8),
              _MiniBtn(icon: Icons.delete_outline, color: Colors.redAccent, onTap: onRemove),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MiniBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
