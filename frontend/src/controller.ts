import { get } from 'svelte/store';
import * as api from './api';
import type { Action, JobResult } from './api';
import {
  DEFAULT_DATA_DIR, WD_H, WD_W, circlesToMappings, mappingsToCircles,
  type AppInfo, type Instance, type KeyMapping, type LogKind, type StoreApp,
} from './models';
import {
  apps, circles, currentInstance, checking, dialog, instances, logs, mouseSteering,
  needsSetup, selected, stage, statusText, tab,
} from './stores';

// ── Logi ───────────────────────────────────────
let logSeq = 0;

function pad2(n: number): string {
  return n < 10 ? `0${n}` : String(n);
}

function timestamp(): string {
  const n = new Date();
  return `${pad2(n.getHours())}:${pad2(n.getMinutes())}:${pad2(n.getSeconds())}`;
}

export function classify(msg: string): LogKind {
  if (msg.includes('❌') || msg.includes('⚠️')) return 'err';
  if (msg.includes('✅') || msg.includes('🎉')) return 'ok';
  return 'info';
}

export function log(msg: string): void {
  logs.update((l) => {
    const next = [...l, { id: ++logSeq, text: `[${timestamp()}] ${msg}`, kind: classify(msg) }];
    return next.length > 500 ? next.slice(next.length - 500) : next;
  });
}

export function clearLogs(): void {
  logs.set([]);
}

// ── Uruchamianie poleceń ───────────────────────
function currentDataDir(): string {
  const list = get(instances);
  const i = get(currentInstance);
  return i < list.length ? list[i].data_dir : DEFAULT_DATA_DIR;
}

function currentName(): string {
  const list = get(instances);
  return list.length > 0 ? list[get(currentInstance)].name : '–';
}

/** Czytelny zapis polecenia do logu (tylko opis — backend sam składa i cytuje polecenie). */
function describe(action: Action, arg: string, arg2: string): string {
  switch (action) {
    case 'status': return 'waydroid status';
    case 'session_start': return 'waydroid session start';
    case 'session_stop': return 'waydroid session stop';
    case 'show_ui': return 'waydroid show-full-ui';
    case 'app_list': return 'waydroid app list';
    case 'app_launch': return `waydroid app launch ${arg}`;
    case 'app_remove': return `waydroid app remove ${arg}`;
    case 'app_install': return `waydroid app install ${arg}`;
    case 'store_install': return `waydroid app install (${arg}: ${arg2})`;
    case 'instance_create': return `pkexec mkdir -p /var/lib/waydroid_${arg}`;
    case 'waydroid_init_gapps': return 'waydroid init -s GAPPS';
    case 'waydroid_init': return 'waydroid init';
    case 'waydroid_shell': return 'waydroid shell';
    case 'container_logs': return 'journalctl -u waydroid-container -n 80 --no-pager';
    case 'binder_modprobe': return 'pkexec modprobe binder_linux num_devices=4';
    case 'binder_ls': return 'ls -la /dev/binder*';
    case 'kernel_version': return 'uname -r';
    case 'adb_devices': return 'adb devices';
    case 'adb_shell': return 'adb shell';
    case 'adb_ping': return 'adb shell ping -c 3 8.8.8.8';
    case 'ram': return 'free -h';
    case 'disk': return 'df -h /var/lib/waydroid';
    default: return action;
  }
}

/** Odpowiednik `_run`: zleca akcję, loguje wyjście, odświeża status. */
export async function run(action: Action, arg = '', arg2 = '', silent = false): Promise<JobResult | null> {
  if (!silent) log(`🚀 ${describe(action, arg, arg2)}`);
  try {
    const res = await api.runJob(action, { arg, arg2, dataDir: currentDataDir() });
    for (const line of res.lines) log(line);
    if (res.code !== 0 && !silent) log(`⚠️ Kod wyjścia: ${res.code}`);
    void updateStatus();
    return res;
  } catch (e) {
    if (!silent) log(`❌ Błąd: ${String(e)}`);
    return null;
  }
}

// ── Status ─────────────────────────────────────
let statusBusy = false;

export async function updateStatus(): Promise<void> {
  if (statusBusy) return;
  statusBusy = true;
  try {
    const r = await api.runJob('status', { dataDir: currentDataDir() });
    const out = r.code === 0 ? r.lines.join(' | ').trim() : 'Zatrzymany';
    statusText.set(`${currentName()} › ${out}`);
  } catch {
    statusText.set('Błąd statusu');
  } finally {
    statusBusy = false;
  }
}

export const startSession = () => run('session_start');
export const stopSession = () => run('session_stop');
export const showFullUi = () => run('show_ui');

// ── Instancje ──────────────────────────────────
function defaultInstances(): Instance[] {
  return [{ name: 'Domyślna', data_dir: DEFAULT_DATA_DIR }];
}

function isInstance(v: unknown): v is Instance {
  const o = v as Partial<Instance> | null;
  return !!o && typeof o.name === 'string' && typeof o.data_dir === 'string';
}

async function saveInstances(): Promise<void> {
  await api.call('config_save', { name: 'instances', text: JSON.stringify(get(instances)) });
}

async function loadInstances(): Promise<void> {
  try {
    const r = await api.call('config_load', { name: 'instances' });
    if (r.exists) {
      const parsed: unknown = JSON.parse(r.text);
      const list = Array.isArray(parsed) ? parsed.filter(isInstance) : [];
      instances.set(list.length > 0 ? list : defaultInstances());
    } else {
      instances.set(defaultInstances());
      await saveInstances();
    }
  } catch (e) {
    instances.set(defaultInstances());
    log(`Błąd ładowania instancji: ${String(e)}`);
  }
  await api.call('set_ctx', { key: 'data_dir', value: currentDataDir() }).catch(() => undefined);
}

export function isValidInstanceName(name: string): boolean {
  return /^[A-Za-z0-9_-]{1,48}$/.test(name);
}

export async function createInstance(name: string): Promise<boolean> {
  if (!isValidInstanceName(name)) {
    log('❌ Nazwa instancji: tylko litery, cyfry, „_” i „-” (max 48 znaków)');
    return false;
  }
  const dataDir = `/var/lib/waydroid_${name}`;
  const res = await run('instance_create', name);
  if (!res || res.code !== 0) {
    log(`❌ Nie udało się utworzyć katalogu ${dataDir}`);
    return false;
  }
  instances.update((l) => [...l, { name, data_dir: dataDir }]);
  await saveInstances();
  log(`✅ Instancja "${name}" utworzona`);
  return true;
}

export async function switchInstance(i: number): Promise<void> {
  currentInstance.set(i);
  await api.call('set_ctx', { key: 'data_dir', value: currentDataDir() }).catch(() => undefined);
  void updateStatus();
  log(`🔄 Przełączono → ${get(instances)[i].name}`);
}

export async function deleteInstance(i: number): Promise<void> {
  if (i === 0) {
    log('❌ Nie można usunąć domyślnej instancji');
    return;
  }
  instances.update((l) => l.filter((_, idx) => idx !== i));
  const count = get(instances).length;
  if (get(currentInstance) >= count) currentInstance.set(count - 1);
  await saveInstances();
  await api.call('set_ctx', { key: 'data_dir', value: currentDataDir() }).catch(() => undefined);
}

// ── Aplikacje ──────────────────────────────────
export function parseAppList(lines: string[]): AppInfo[] {
  const out: AppInfo[] = [];
  let cur: AppInfo | null = null;
  for (const raw of lines) {
    const line = raw.trim();
    if (line.startsWith('Name:')) {
      cur = { name: line.slice(5).trim(), package: '' };
    } else if (cur) {
      // oryginał szukał "Package:"; Waydroid wypisuje "packageName:" — obsługujemy oba
      const m = /^package(?:name)?:\s*(.+)$/i.exec(line);
      if (m) {
        cur.package = m[1].trim();
        out.push(cur);
        cur = null;
      }
    }
  }
  return out;
}

export async function refreshApps(): Promise<void> {
  try {
    const r = await api.runJob('app_list', { dataDir: currentDataDir() });
    if (r.code !== 0) return;
    apps.set(parseAppList(r.lines));
  } catch (e) {
    log(`Błąd listy aplikacji: ${String(e)}`);
  }
}

const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

export async function installApk(): Promise<void> {
  const path = await silver.dialog.open({ title: 'Wybierz plik .apk', description: 'Android APK', pattern: '*.apk' });
  if (!path) return;
  await run('app_install', path);
  await sleep(2000);
  void refreshApps();
}

export async function storeInstall(app: StoreApp): Promise<void> {
  log(`📥 Pobieranie ${app.name}…`);
  const res = await run('store_install', app.name, app.downloadUrl, true);
  if (!res) return;
  if (res.code === 3) {
    log('❌ Bezpośrednie pobieranie nieudane — otwieranie strony…');
  } else if (res.code !== 0) {
    log(`⚠️ Kod wyjścia: ${res.code}`);
  } else {
    await sleep(2000);
    void refreshApps();
  }
}

export const launchApp = (pkg: string) => run('app_launch', pkg);
export const removeApp = (pkg: string) => run('app_remove', pkg);

// ── Keymapper ──────────────────────────────────
function defaultMappings(): KeyMapping[] {
  return [
    { key: 'w', type: 'tap', x: 500, y: 300 },
    { key: 's', type: 'tap', x: 500, y: 700 },
    { key: 'a', type: 'tap', x: 300, y: 500 },
    { key: 'd', type: 'tap', x: 700, y: 500 },
  ];
}

function isMapping(v: unknown): v is KeyMapping {
  const o = v as Partial<KeyMapping> | null;
  return !!o && typeof o.key === 'string' && typeof o.x === 'number' && typeof o.y === 'number';
}

async function saveKeymaps(): Promise<void> {
  try {
    await api.call('config_save', { name: 'keymaps', text: JSON.stringify(circlesToMappings(get(circles))) });
  } catch (e) {
    log(`Błąd zapisu keymap: ${String(e)}`);
  }
}

async function loadKeymaps(): Promise<void> {
  try {
    const r = await api.call('config_load', { name: 'keymaps' });
    if (r.exists) {
      const parsed: unknown = JSON.parse(r.text);
      const list = Array.isArray(parsed) ? parsed.filter(isMapping) : [];
      circles.set(mappingsToCircles(list.map((m) => ({ ...m, type: 'tap' as const }))));
    } else {
      circles.set(mappingsToCircles(defaultMappings()));
      await saveKeymaps();
    }
  } catch (e) {
    log(`Błąd ładowania keymap: ${String(e)}`);
  }
}

function clamp(v: number, max: number): number {
  return Math.max(0, Math.min(max, Math.round(v)));
}

export function addCircle(key: string): void {
  circles.update((c) => [...c, { key, x: WD_W / 2, y: 300 }]);
  selected.set(get(circles).length - 1);
  void saveKeymaps();
}

export function removeCircle(i: number): void {
  circles.update((c) => c.filter((_, idx) => idx !== i));
  selected.set(-1);
  void saveKeymaps();
}

export function clearCircles(): void {
  circles.set([]);
  selected.set(-1);
  void saveKeymaps();
}

export function moveCircle(i: number, x: number, y: number): void {
  circles.update((c) => c.map((k, idx) => (idx === i ? { ...k, x: clamp(x, WD_W), y: clamp(y, WD_H) } : k)));
  void saveKeymaps();
}

export function nudgeCircle(i: number, dx: number, dy: number): void {
  const c = get(circles)[i];
  if (c) moveCircle(i, c.x + dx, c.y + dy);
}

/** Kliknięcie w oknie → współrzędne Waydroid (na podstawie położenia #stage podanego przez H#). */
export function stagePointToWaydroid(clientX: number, clientY: number): { x: number; y: number } | null {
  const s = get(stage);
  if (s.w <= 0 || s.h <= 0) return null;
  return { x: ((clientX - s.x) / s.w) * WD_W, y: ((clientY - s.y) / s.h) * WD_H };
}

// ── Mouse Steering ─────────────────────────────
export async function toggleMouseSteering(on: boolean): Promise<void> {
  mouseSteering.set(on);
  await api.call('set_ctx', { key: 'fps', value: on ? '1' : '0' }).catch(() => undefined);
  log(on ? '🎮 Mouse Steering AKTYWNY — F1 wyłącza' : '🖱️ Mouse Steering wyłączony');
}

// ── Narzędzia ──────────────────────────────────
export const runTool = (action: Action) => run(action);

// ── Cykl życia ─────────────────────────────────
const disposers: Array<() => void> = [];
let statusTimer: ReturnType<typeof setInterval> | undefined;
let homeStarted = false;

async function enterHome(): Promise<void> {
  if (homeStarted) return;
  homeStarted = true;
  await Promise.all([loadInstances(), loadKeymaps()]);
  statusTimer = setInterval(() => void updateStatus(), 6000);
  void updateStatus();
  void refreshApps();
}

/** Start: zdarzenia z H#, sprawdzenie środowiska (Waydroid + /dev/binder), ewentualnie kreator. */
export async function boot(): Promise<void> {
  disposers.push(api.onStage((r) => stage.set(r)));
  disposers.push(api.onFps((on) => {
    mouseSteering.set(on);
    log(on ? '🎮 Mouse Steering AKTYWNY — F1 wyłącza' : '🖱️ Mouse Steering wyłączony');
  }));
  disposers.push(tab.subscribe((t) => {
    void api.call('set_ctx', { key: 'page', value: t }).catch(() => undefined);
  }));

  let setup = false;
  try {
    const env = await api.call('env_check');
    setup = !env.waydroid || !env.binder;
  } catch (e) {
    log(`Błąd sprawdzania środowiska: ${String(e)}`);
  }
  needsSetup.set(setup);
  checking.set(false);
  if (!setup) await enterHome();
}

export async function finishSetup(): Promise<void> {
  needsSetup.set(false);
  await enterHome();
}

export function shutdown(): void {
  disposers.splice(0).forEach((d) => d());
  if (statusTimer !== undefined) clearInterval(statusTimer);
  statusTimer = undefined;
}

export function openDialog(kind: 'instance' | 'key'): void {
  dialog.set(kind);
}

export function closeDialog(): void {
  dialog.set(null);
}
