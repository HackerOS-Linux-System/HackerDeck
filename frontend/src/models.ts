export const WD_W = 720;
export const WD_H = 1280;
export const DEFAULT_DATA_DIR = '/var/lib/waydroid';

export interface Instance {
  name: string;
  data_dir: string;
}

export interface KeyMapping {
  key: string;
  type: 'tap';
  x: number;
  y: number;
}

/** Kółko na scenie keymappera (współrzędne Waydroid). */
export interface KeyCircle {
  key: string;
  x: number;
  y: number;
}

export interface AppInfo {
  name: string;
  package: string;
}

export interface StoreApp {
  name: string;
  category: string;
  description: string;
  icon: string;
  downloadUrl: string;
  version: string;
}

export type TabId = 'dashboard' | 'apps' | 'store' | 'instances' | 'keymapper' | 'mouse' | 'tools';

export type LogKind = 'info' | 'err' | 'ok';

export interface LogLine {
  id: number;
  text: string;
  kind: LogKind;
}

export interface StageRect {
  x: number;
  y: number;
  w: number;
  h: number;
}

export function circlesToMappings(circles: KeyCircle[]): KeyMapping[] {
  return circles.map((c) => ({ key: c.key, type: 'tap', x: Math.round(c.x), y: Math.round(c.y) }));
}

export function mappingsToCircles(mappings: KeyMapping[]): KeyCircle[] {
  return mappings.filter((m) => m.type === 'tap').map((m) => ({ key: m.key, x: m.x, y: m.y }));
}
