export type Action =
  // sesja / status
  | 'status' | 'session_start' | 'session_stop' | 'show_ui'
  // aplikacje
  | 'app_list' | 'app_launch' | 'app_remove' | 'app_install' | 'store_install'
  // instancje
  | 'instance_create'
  // narzędzia
  | 'waydroid_init_gapps' | 'waydroid_init' | 'waydroid_shell' | 'container_logs'
  | 'binder_modprobe' | 'binder_ls' | 'kernel_version'
  | 'adb_devices' | 'adb_shell' | 'adb_ping'
  | 'ram' | 'disk'
  // kreator pierwszego uruchomienia
  | 'wiz_apt_update' | 'wiz_apt_deps' | 'wiz_binder' | 'wiz_binder_persist'
  | 'wiz_repo' | 'wiz_waydroid_install' | 'wiz_waydroid_init';

export type ConfigName = 'instances' | 'keymaps';
export type CtxKey = 'page' | 'fps' | 'data_dir';

interface ExecArgs {
  id: string;
  action: Action;
  arg?: string;
  arg2?: string;
  data_dir?: string;
}

interface Commands {
  env_check: { args: undefined; result: { waydroid: boolean; binder: boolean } };
  config_load: { args: { name: ConfigName }; result: { exists: boolean; text: string } };
  config_save: { args: { name: ConfigName; text: string }; result: { ok: boolean } };
  set_ctx: { args: { key: CtxKey; value: string }; result: { ok: boolean } };
  exec: { args: ExecArgs; result: { queued: boolean } };
}

interface ErrorResult { error: string; code: string }

export async function call<K extends keyof Commands>(
  cmd: K,
  ...args: Commands[K]['args'] extends undefined ? [] : [Commands[K]['args']]
): Promise<Commands[K]['result']> {
  const r = await silver.invoke<Commands[K]['result'] | ErrorResult>(cmd, args[0] as Record<string, unknown> | undefined);
  if (r && typeof r === 'object' && 'error' in r) throw new Error(`${cmd}: ${(r as ErrorResult).error}`);
  return r as Commands[K]['result'];
}

// ── Zadania w tle ───────────────────────────────────────────────
// H# kolejkuje polecenie (komenda "exec"), uruchamia je w on_tick i oddaje wynik
// zdarzeniem "silver://task" {id, output}. Ostatnia linia wyniku to "@@exit=N".

export interface JobResult {
  code: number;
  lines: string[];
}

const pending = new Map<string, (r: JobResult) => void>();
let seq = 0;

export function parseJob(output: string): JobResult {
  const all = output.split('\n');
  let code = 0;
  const lines: string[] = [];
  for (const raw of all) {
    const line = raw.replace(/\r$/, '');
    if (line.startsWith('@@exit=')) {
      const n = parseInt(line.slice(7), 10);
      code = Number.isNaN(n) ? 1 : n;
    } else if (line.trim() !== '') {
      lines.push(line);
    }
  }
  return { code, lines };
}

let listening = false;
function ensureListener(): void {
  if (listening) return;
  listening = true;
  silver.listen<SilverTaskPayload>('silver://task', ({ id, output }) => {
    const done = pending.get(id);
    if (!done) return;
    pending.delete(id);
    done(parseJob(output));
  });
}

/** Zleca akcję z białej listy backendu i czeka na wynik. */
export async function runJob(action: Action, opts: { arg?: string; arg2?: string; dataDir?: string } = {}): Promise<JobResult> {
  ensureListener();
  const id = `j${(++seq).toString(36)}${Date.now().toString(36)}`;
  const result = new Promise<JobResult>((resolve) => pending.set(id, resolve));
  try {
    await call('exec', { id, action, arg: opts.arg, arg2: opts.arg2, data_dir: opts.dataDir });
  } catch (e) {
    pending.delete(id);
    throw e;
  }
  return result;
}

// ── Zdarzenia z H# ─────────────────────────────────────────────
export function onFps(cb: (on: boolean) => void): () => void {
  return silver.listen<{ on: boolean }>('hd:fps', (p) => cb(p.on));
}

export function onStage(cb: (r: { x: number; y: number; w: number; h: number }) => void): () => void {
  return silver.listen<{ x: number; y: number; w: number; h: number }>('hd:stage', cb);
}
