<script lang="ts">
  import { mouseSteering } from '../stores';
  import { toggleMouseSteering } from '../controller';
  import Switch from '../components/Switch.svelte';

  const rows: Array<[string, string]> = [
    ['F1', 'Przełącz Mouse Steering on/off'],
    ['Ruch myszy', 'Symuluje obrót kamery (waydroid shell input swipe)'],
    ['Czułość', 'x2.5 proporcjonalnie do ruchu myszy'],
  ];
</script>

<div class="page col">
  <h1 class="page-title">Mouse Steering (FPS)</h1>

  <div class="card pad">
    <div class="switch-row">
      <span class="lead">Tryb FPS:</span>
      <Switch checked={$mouseSteering} onchange={(v) => toggleMouseSteering(v)} />
      <span class="state" class:on={$mouseSteering}>{$mouseSteering ? 'AKTYWNY' : 'WYŁĄCZONY'}</span>
    </div>
    <div class="divider"></div>
    {#each rows as [k, v] (k)}
      <div class="kv"><span class="kbd wide-kbd">{k}</span><span class="soft">{v}</span></div>
    {/each}
  </div>

  <div class="track" class:active={$mouseSteering}>
    <div class="track-glyph">◉</div>
    <div class="track-text">
      {$mouseSteering
        ? 'Śledzenie aktywne — poruszaj myszą w tym oknie, aby sterować kamerą'
        : 'Włącz tryb FPS lub naciśnij F1'}
    </div>
  </div>
</div>
