import { writable } from 'svelte/store';
import { runJob, type Action } from './api';
import type { LogKind, LogLine } from './models';

type StepKind = 'apt' | 'modprobe' | 'binderPersist' | 'shell' | 'waydroidInit';

export interface Step {
  label: string;
  kind: StepKind;
  action: Action;
}

export const steps: Step[] = [
  { label: 'Aktualizacja apt', kind: 'apt', action: 'wiz_apt_update' },
  { label: 'Zależności bazowe', kind: 'apt', action: 'wiz_apt_deps' },
  { label: 'Ładowanie modułu binder (kernel)', kind: 'modprobe', action: 'wiz_binder' },
  { label: 'Utrwalenie binder przy starcie', kind: 'binderPersist', action: 'wiz_binder_persist' },
  { label: 'Dodanie repo Waydroid', kind: 'shell', action: 'wiz_repo' },
  { label: 'Instalacja Waydroid', kind: 'apt', action: 'wiz_waydroid_install' },
  { label: 'Inicjalizacja Waydroid (GAPPS)', kind: 'waydroidInit', action: 'wiz_waydroid_init' },
];

export type Screen = 'welcome' | 'installing' | 'done';

export const screen = writable<Screen>('welcome');
export const wizLogs = writable<LogLine[]>([]);
export const progress = writable(0);
export const stepLabel = writable('');
export const running = writable(false);
export const failed = writable(false);

let seq = 0;

function wlog(text: string, kind: LogKind = 'info'): void {
  wizLogs.update((l) => [...l, { id: ++seq, text, kind }]);
}

export async function startInstall(): Promise<void> {
  screen.set('installing');
  running.set(true);
  failed.set(false);

  for (let i = 0; i < steps.length; i++) {
    const step = steps[i];
    stepLabel.set(step.label);
    progress.set(i / steps.length);
    wlog(`━━ Krok ${i + 1}/${steps.length}: ${step.label}`);

    let ok = false;
    try {
      const res = await runJob(step.action);
      for (const l of res.lines) wlog(`  ${l}`);
      ok = res.code === 0;

      switch (step.kind) {
        case 'modprobe':
          if (res.lines.some((l) => l.includes('already exists'))) {
            wlog('  ✓ /dev/binder już istnieje (binder wbudowany w kernel)', 'ok');
          }
          break;
        case 'binderPersist':
          if (ok) wlog('  Zapisano /etc/modules-load.d/binder.conf', 'ok');
          break;
        case 'waydroidInit':
          // waydroid init bywa niezerowy przy istniejących danych — krok „best effort” jak w oryginale
          if (!ok) wlog('  waydroid init zakończył się niezerowym kodem — może to być normalne przy reinicjalizacji');
          ok = true;
          break;
        default:
          break;
      }
    } catch (e) {
      wlog(`  Błąd procesu: ${String(e)}`, 'err');
    }

    if (ok) {
      wlog(`✔ ${step.label}`, 'ok');
    } else {
      wlog(`✖ Krok "${step.label}" zakończył się błędem. Sprawdź logi powyżej.`, 'err');
      failed.set(true);
      running.set(false);
      return;
    }
  }

  progress.set(1);
  running.set(false);
  screen.set('done');
}

export function resetWizard(): void {
  screen.set('welcome');
  wizLogs.set([]);
  failed.set(false);
  progress.set(0);
}
