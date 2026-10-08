<script lang="ts">
  import { circles, selected, stage } from '../stores';
  import { WD_H, WD_W } from '../models';
  import {
    clearCircles, moveCircle, nudgeCircle, openDialog, removeCircle, stagePointToWaydroid,
  } from '../controller';

  const R = 16; // promień kółka na ekranie (px)

  // zanim H# poda rozmiar sceny, rysujemy na wartościach zastępczych
  let sw = $derived($stage.w > 0 ? $stage.w : 288);
  let sh = $derived($stage.h > 0 ? $stage.h : 512);
  let vlines = $derived(Array.from({ length: Math.floor(sw / 60) + 1 }, (_, i) => i * 60));
  let hlines = $derived(Array.from({ length: Math.floor(sh / 60) + 1 }, (_, i) => i * 60));
  let cur = $derived($selected >= 0 ? $circles[$selected] : undefined);

  // Silver nie dostarcza zdarzenia mousemove, więc zamiast przeciągania:
  // klik w kółko = zaznacz, klik w scenę = przenieś zaznaczone kółko tam.
  let circleHit = false;

  function onCircleClick(i: number) {
    circleHit = true;
    selected.set($selected === i ? -1 : i);
  }

  function onStageClick(e: MouseEvent) {
    if (circleHit) {
      circleHit = false;
      return;
    }
    if ($selected < 0) return;
    const p = stagePointToWaydroid(e.clientX, e.clientY);
    if (p) moveCircle($selected, p.x, p.y);
  }

  function onCircleContext(e: Event, i: number) {
    e.preventDefault();
    removeCircle(i);
  }

  function setCoord(axis: 'x' | 'y', value: string) {
    if (!cur || value.trim() === '') return;
    const n = Number(value);
    if (Number.isNaN(n)) return;
    if (axis === 'x') moveCircle($selected, n, cur.y);
    else moveCircle($selected, cur.x, n);
  }
</script>

<div class="page col nopad-bottom">
  <div class="page-head">
    <h1 class="page-title">Visual Keymapper</h1>
    <span class="spacer"></span>
    <button class="btn" onclick={() => openDialog('key')}>＋ Dodaj klawisz</button>
    <button class="btn outline" onclick={clearCircles}>Wyczyść</button>
  </div>

  <div class="banner blue">
    <span>☝</span>
    <span>Kliknij kółko, by je zaznaczyć, potem kliknij miejsce na scenie. Prawy klik = usuń. Scena odwzorowuje ekran Waydroid ({WD_W}×{WD_H}).</span>
  </div>

  {#if cur}
    <div class="selbar">
      <span class="sel-key">{cur.key.toUpperCase()}</span>
      <span class="muted small">X</span>
      <input class="num" type="text" value={String(Math.round(cur.x))} oninput={(e) => setCoord('x', e.currentTarget.value)} />
      <span class="muted small">Y</span>
      <input class="num" type="text" value={String(Math.round(cur.y))} oninput={(e) => setCoord('y', e.currentTarget.value)} />
      <button class="mini" onclick={() => nudgeCircle($selected, -10, 0)}>◀</button>
      <button class="mini" onclick={() => nudgeCircle($selected, 10, 0)}>▶</button>
      <button class="mini" onclick={() => nudgeCircle($selected, 0, -10)}>▲</button>
      <button class="mini" onclick={() => nudgeCircle($selected, 0, 10)}>▼</button>
      <button class="mini red" onclick={() => removeCircle($selected)}>✕</button>
    </div>
  {/if}

  <div class="stage-frame">
    <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
    <div id="stage" class="stage" onclick={onStageClick}>
      {#each vlines as gx (gx)}
        <div class="gline v" style="left: {gx}px; height: {sh}px;"></div>
      {/each}
      {#each hlines as gy (gy)}
        <div class="gline h" style="top: {gy}px; width: {sw}px;"></div>
      {/each}
      {#each $circles as c, i (i)}
        <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
        <div
          class="kcircle"
          class:selected={i === $selected}
          style="left: {(c.x / WD_W) * sw - R}px; top: {(c.y / WD_H) * sh - R}px;"
          onclick={() => onCircleClick(i)}
          oncontextmenu={(e) => onCircleContext(e, i)}
        >{c.key.toUpperCase()}</div>
      {/each}
    </div>
  </div>
</div>
