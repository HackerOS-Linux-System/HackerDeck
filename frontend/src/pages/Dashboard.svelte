<script lang="ts">
  import { apps, circles, currentInstance, instances } from '../stores';
  import { showFullUi, startSession, stopSession, updateStatus } from '../controller';

  let inst = $derived($instances[$currentInstance]);
</script>

<div class="page scroll">
  <h1 class="page-title big">Dashboard</h1>

  <div class="quick-row">
    <button class="quick green" onclick={startSession}><span class="q-glyph">▶</span><span>Start sesji</span></button>
    <button class="quick red" onclick={stopSession}><span class="q-glyph">■</span><span>Stop wszystko</span></button>
    <button class="quick blue" onclick={showFullUi}><span class="q-glyph">↗</span><span>Pełny UI</span></button>
    <button class="quick orange" onclick={() => updateStatus()}><span class="q-glyph">↻</span><span>Odśwież status</span></button>
  </div>

  <div class="stat-row">
    <div class="card stat">
      <div class="muted small">Aktywna instancja</div>
      <div class="stat-value">{inst ? inst.name : '–'}</div>
      {#if inst}<div class="faint tiny">{inst.data_dir}</div>{/if}
    </div>
    <div class="card stat">
      <div class="muted small">Aplikacje</div>
      <div class="stat-value huge">{$apps.length}</div>
    </div>
    <div class="card stat">
      <div class="muted small">Mapowania klawiszy</div>
      <div class="stat-value huge">{$circles.length}</div>
    </div>
  </div>

  <div class="card pad">
    <div class="bold">Skróty klawiszowe</div>
    <div class="kv"><span class="kbd">F1</span><span class="soft">Włącz / wyłącz Mouse Steering (FPS)</span></div>
    <div class="kv"><span class="kbd">Zmapowane klawisze</span><span class="soft">Generują dotknięcia ekranu Waydroid</span></div>
  </div>
</div>
