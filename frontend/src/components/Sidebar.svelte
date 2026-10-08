<script lang="ts">
  import { tab } from '../stores';
  import type { TabId } from '../models';

  const items: Array<{ id: TabId; glyph: string; label: string }> = [
    { id: 'dashboard', glyph: '⌂', label: 'Dashboard' },
    { id: 'apps', glyph: '▦', label: 'Aplikacje' },
    { id: 'store', glyph: '↓', label: 'Sklep APK' },
    { id: 'instances', glyph: '☰', label: 'Instancje' },
    { id: 'keymapper', glyph: '⌨', label: 'Keymapper' },
    { id: 'mouse', glyph: '◉', label: 'Mouse FPS' },
    { id: 'tools', glyph: '⚙', label: 'Narzędzia' },
  ];
</script>

<nav class="sidebar">
  {#each items as item (item.id)}
    <button class="nav-item" class:sel={$tab === item.id} onclick={() => tab.set(item.id)}>
      <span class="nav-glyph">{item.glyph}</span>
      <span class="nav-label">{item.label}</span>
    </button>
  {/each}
</nav>
