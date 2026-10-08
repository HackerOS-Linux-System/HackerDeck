<script lang="ts">
  import type { Action } from '../api';
  import { clearLogs, runTool } from '../controller';

  interface Tool { glyph: string; label: string; action?: Action }
  interface Section { title: string; tools: Tool[] }

  const sections: Section[] = [
    { title: 'Waydroid', tools: [
      { glyph: '⟲', label: 'Reinicjalizuj (GAPPS)', action: 'waydroid_init_gapps' },
      { glyph: '⇄', label: 'Reinicjalizuj (vanilla)', action: 'waydroid_init' },
      { glyph: '⚙', label: 'waydroid shell', action: 'waydroid_shell' },
      { glyph: '☢', label: 'Logi kontenera', action: 'container_logs' },
      { glyph: 'ⓘ', label: 'waydroid status', action: 'status' },
    ] },
    { title: 'Binder / Kernel', tools: [
      { glyph: '▣', label: 'Załaduj binder_linux', action: 'binder_modprobe' },
      { glyph: '☰', label: 'Sprawdź /dev/binder', action: 'binder_ls' },
      { glyph: '>_', label: 'Wersja kernela', action: 'kernel_version' },
    ] },
    { title: 'ADB', tools: [
      { glyph: '⌁', label: 'Lista urządzeń ADB', action: 'adb_devices' },
      { glyph: '>_', label: 'ADB shell', action: 'adb_shell' },
      { glyph: '⇆', label: 'Ping test (przez ADB)', action: 'adb_ping' },
    ] },
    { title: 'System', tools: [
      { glyph: '▣', label: 'Użycie RAM', action: 'ram' },
      { glyph: '▤', label: 'Dysk /var/lib/waydroid', action: 'disk' },
      { glyph: '✕', label: 'Wyczyść logi' },
    ] },
  ];

  function click(t: Tool) {
    if (t.action) void runTool(t.action);
    else clearLogs();
  }
</script>

<div class="page scroll">
  <h1 class="page-title">Narzędzia systemowe</h1>
  {#each sections as s (s.title)}
    <div class="tool-section">
      <div class="section-title">{s.title.toUpperCase()}</div>
      <div class="tool-row">
        {#each s.tools as t (t.label)}
          <button class="tool" onclick={() => click(t)}>
            <span class="tool-glyph">{t.glyph}</span>
            <span>{t.label}</span>
          </button>
        {/each}
      </div>
    </div>
  {/each}
</div>
