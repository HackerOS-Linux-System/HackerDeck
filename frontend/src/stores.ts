import { writable } from 'svelte/store';
import type { AppInfo, Instance, KeyCircle, LogLine, StageRect, TabId } from './models';

// start
export const checking = writable(true);
export const needsSetup = writable(false);

// nawigacja i okna dialogowe
export const tab = writable<TabId>('dashboard');
export const dialog = writable<'instance' | 'key' | null>(null);

// pasek statusu i logi
export const statusText = writable('HackerDeck v4.0 — gotowy');
export const logs = writable<LogLine[]>([]);
export const logExpanded = writable(true);

// aplikacje i instancje
export const apps = writable<AppInfo[]>([]);
export const instances = writable<Instance[]>([]);
export const currentInstance = writable(0);

// keymapper
export const circles = writable<KeyCircle[]>([]);
export const selected = writable(-1);
/** Położenie sceny #stage w oknie — podaje je H# (JS nie widzi układu). */
export const stage = writable<StageRect>({ x: 0, y: 0, w: 0, h: 0 });

// Mouse Steering (FPS)
export const mouseSteering = writable(false);
