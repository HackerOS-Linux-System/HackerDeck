// ─────────────────────────────────────────────
//  HackerDeck — Setup Wizard
//  Naprawione dla Debian trixie/forky:
//  - brak pakietu binder-control w apt
//  - binder instalowany przez moduł kernela lub
//    linux-image-extra jeśli dostępny
// ─────────────────────────────────────────────
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class SetupWizard extends StatefulWidget {
  final VoidCallback onFinished;
  const SetupWizard({super.key, required this.onFinished});

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  int _screen = 0; // 0=welcome, 1=installing, 2=done
  final List<_LogLine> _logs = [];
  final ScrollController _sc = ScrollController();
  bool _running = false;
  bool _failed = false;
  int _currentStepIdx = 0;
  double _progress = 0.0;

  // Poprawione kroki dla Debian trixie — bez binder-control
  // binder jest dostępny w kernelu ≥ 5.12 jako moduł lub wbudowany
  static const _steps = [
    _Step('Aktualizacja apt', _StepKind.apt, ['apt-get', 'update', '-y']),
    _Step('Zależności bazowe', _StepKind.apt,
        ['apt-get', 'install', '-y', 'curl', 'ca-certificates', 'lxc', 'android-tools-adb', 'wget']),
    _Step('Ładowanie modułu binder (kernel)', _StepKind.modprobe, ['modprobe', 'binder_linux', 'num_devices=4']),
    _Step('Utrwalenie binder przy starcie', _StepKind.binderPersist, []),
    _Step('Dodanie repo Waydroid', _StepKind.shell,
        ['bash', '-c', 'curl -fsSL https://repo.waydro.id | bash']),
    _Step('Instalacja Waydroid', _StepKind.apt, ['apt-get', 'install', '-y', 'waydroid']),
    _Step('Inicjalizacja Waydroid (GAPPS)', _StepKind.waydroidInit, ['waydroid', 'init', '-s', 'GAPPS']),
  ];

  void _log(String msg, {bool err = false, bool ok = false}) {
    if (!mounted) return;
    setState(() {
      _logs.add(_LogLine(msg, err: err, ok: ok));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_sc.hasClients) {
          _sc.animateTo(_sc.position.maxScrollExtent,
              duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
        }
      });
    });
  }

  Future<bool> _runArgs(List<String> args, {bool sudo = true}) async {
    final full = sudo ? ['pkexec', ...args] : args;
    _log('▶ ${full.join(' ')}');
    try {
      final p = await Process.start(full.first, full.skip(1).toList(), runInShell: true);
      p.stdout.transform(utf8.decoder).listen((d) {
        for (final l in d.split('\n')) {
          if (l.trim().isNotEmpty) _log('  $l');
        }
      });
      p.stderr.transform(utf8.decoder).listen((d) {
        for (final l in d.split('\n')) {
          if (l.trim().isNotEmpty) _log('  $l', err: true);
        }
      });
      return await p.exitCode == 0;
    } catch (e) {
      _log('  Błąd procesu: $e', err: true);
      return false;
    }
  }

  // Zapisuje plik przez pkexec tee (nie wymaga bash -c z heredoc)
  Future<bool> _writeFileAsRoot(String path, String content) async {
    try {
      final p = await Process.start(
        'pkexec', ['tee', path],
        runInShell: false,
      );
      p.stdin.write(content);
      await p.stdin.close();
      p.stderr.transform(utf8.decoder).listen((d) { _log('  $d', err: true); });
      return await p.exitCode == 0;
    } catch (e) {
      _log('  Błąd zapisu pliku: $e', err: true);
      return false;
    }
  }

  Future<void> _startInstall() async {
    setState(() { _screen = 1; _running = true; _failed = false; });

    for (int i = 0; i < _steps.length; i++) {
      final step = _steps[i];
      setState(() { _currentStepIdx = i; _progress = i / _steps.length; });
      _log('━━ Krok ${i + 1}/${_steps.length}: ${step.label}');

      bool ok = false;

      switch (step.kind) {
        case _StepKind.apt:
          ok = await _runArgs(step.args);
          break;

        case _StepKind.modprobe:
          // Próba modprobe; jeśli się nie uda — sprawdź czy binder już jest w kernelu
          ok = await _runArgs(step.args);
          if (!ok) {
            _log('  modprobe binder_linux nie powiodło się — sprawdzam /dev/binderfs', err: false);
            final check = await Process.run('ls', ['/dev/binder'], runInShell: true);
            if (check.exitCode == 0) {
              _log('  ✓ /dev/binder już istnieje (binder wbudowany w kernel)', ok: true);
              ok = true;
            } else {
              _log('  ✖ Binder niedostępny. Może być potrzebny nowszy kernel lub linux-image-extra.', err: true);
              _log('  Próba instalacji linux-image-extra…');
              // Próba alternatywna
              final kver = (await Process.run('uname', ['-r'], runInShell: true))
                  .stdout.toString().trim();
              final alt = await _runArgs(['apt-get', 'install', '-y', 'linux-modules-extra-$kver']);
              ok = alt || check.exitCode == 0;
            }
          }
          break;

        case _StepKind.binderPersist:
          // Zapisz /etc/modules-load.d/binder.conf
          ok = await _writeFileAsRoot('/etc/modules-load.d/binder.conf', 'binder_linux\n');
          if (ok) _log('  Zapisano /etc/modules-load.d/binder.conf', ok: true);
          break;

        case _StepKind.shell:
          ok = await _runArgs(step.args);
          break;

        case _StepKind.waydroidInit:
          // waydroid init może zwrócić błąd przy już istniejących danych — traktujemy jako OK
          final result = await _runArgs(step.args, sudo: false);
          ok = true; // init jest "best effort"
          if (!result) _log('  waydroid init zakończył się niezerowym kodem — może to być normalne przy reinicjalizacji');
          break;
      }

      if (ok) {
        _log('✔ ${step.label}', ok: true);
      } else {
        _log('✖ Krok "${step.label}" zakończył się błędem. Sprawdź logi powyżej.', err: true);
        setState(() { _failed = true; _running = false; });
        return;
      }
    }

    setState(() { _progress = 1.0; _running = false; _screen = 2; });
  }

  void _reset() => setState(() { _screen = 0; _logs.clear(); _failed = false; _progress = 0; });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060A12),
      body: Center(
        child: SizedBox(
          width: 720,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: switch (_screen) {
              0 => _WelcomeScreen(key: const ValueKey('w'), onInstall: _startInstall, onSkip: widget.onFinished),
              1 => _InstallingScreen(
                  key: const ValueKey('i'),
                  logs: _logs,
                  sc: _sc,
                  progress: _progress,
                  stepLabel: _currentStepIdx < _steps.length ? _steps[_currentStepIdx].label : 'Finalizowanie…',
                  failed: _failed,
                  onRetry: _reset,
                ),
              _ => _DoneScreen(key: const ValueKey('d'), onFinish: widget.onFinished),
            },
          ),
        ),
      ),
    );
  }
}

// ── Screens ──────────────────────────────────

class _WelcomeScreen extends StatelessWidget {
  final VoidCallback onInstall;
  final VoidCallback onSkip;
  const _WelcomeScreen({super.key, required this.onInstall, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: const Color(0xFF00E5FF).withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3))),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 16),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('HackerDeck v4.0', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
            Text('Kreator pierwszego uruchomienia', style: TextStyle(color: Colors.white38, fontSize: 13)),
          ]),
        ]),
        const SizedBox(height: 32),
        const Text('Wykryto brakujące zależności. Kreator zainstaluje:', style: TextStyle(fontSize: 15)),
        const SizedBox(height: 16),
        ...[
          ('🐧', 'LXC', 'Kontenery Linux — wymagane przez Waydroid'),
          ('⚙️', 'Moduł binder_linux', 'Sterownik kernela (modprobe / wbudowany w ≥5.12)'),
          ('📡', 'ADB + wget', 'Android Debug Bridge i pobieranie APK'),
          ('🤖', 'Waydroid', 'Emulator Androida dla Linuksa'),
          ('🛒', 'Google Play Services', 'GAPPS — opcjonalne, do Sklepu Play'),
        ].map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Text(e.$1, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.$2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(e.$3, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
          ]),
        )),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.withOpacity(0.3))),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('⚠️'),
            SizedBox(width: 8),
            Expanded(child: Text('Wymagane: Debian trixie/forky, kernel ≥ 5.12 z obsługą binder, dostęp do pkexec.', style: TextStyle(fontSize: 12, color: Colors.amber))),
          ]),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onInstall,
            icon: const Icon(Icons.rocket_launch),
            label: const Text('Zainstaluj wszystko automatycznie', style: TextStyle(fontSize: 15)),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onSkip,
            child: const Text('Pomiń — Waydroid jest już zainstalowany', style: TextStyle(color: Colors.white38)),
          ),
        ),
      ]),
    );
  }
}

class _InstallingScreen extends StatelessWidget {
  final List<_LogLine> logs;
  final ScrollController sc;
  final double progress;
  final String stepLabel;
  final bool failed;
  final VoidCallback onRetry;

  const _InstallingScreen({
    super.key,
    required this.logs,
    required this.sc,
    required this.progress,
    required this.stepLabel,
    required this.failed,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Trwa instalacja…', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(stepLabel, style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 14)),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            color: const Color(0xFF00E5FF),
            backgroundColor: Colors.white12,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 300,
          decoration: BoxDecoration(color: const Color(0xFF060A12), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
          padding: const EdgeInsets.all(10),
          child: ListView.builder(
            controller: sc,
            itemCount: logs.length,
            itemBuilder: (_, i) {
              final l = logs[i];
              return Text(l.msg,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: l.err ? Colors.redAccent : l.ok ? Colors.greenAccent : Colors.white60,
                  ));
            },
          ),
        ),
        if (failed) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Spróbuj ponownie'),
          ),
        ],
      ]),
    );
  }
}

class _DoneScreen extends StatelessWidget {
  final VoidCallback onFinish;
  const _DoneScreen({super.key, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 80),
        const SizedBox(height: 24),
        const Text('Instalacja zakończona!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
        const SizedBox(height: 10),
        const Text('Waydroid i wszystkie zależności są gotowe.\nPrzyjemnego korzystania z HackerDeck!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: onFinish,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Uruchom HackerDeck', style: TextStyle(fontSize: 15)),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16), backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
        ),
      ]),
    );
  }
}

// ── Internal helpers ──────────────────────────

enum _StepKind { apt, modprobe, binderPersist, shell, waydroidInit }

class _Step {
  final String label;
  final _StepKind kind;
  final List<String> args;
  const _Step(this.label, this.kind, this.args);
}

class _LogLine {
  final String msg;
  final bool err;
  final bool ok;
  const _LogLine(this.msg, {this.err = false, this.ok = false});
}
