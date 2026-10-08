<script lang="ts">
  import { tick } from 'svelte';
  import { finishSetup } from './controller';
  import { failed, progress, resetWizard, screen, startInstall, stepLabel, wizLogs } from './wizard';

  let box: HTMLDivElement | undefined = $state();

  $effect(() => {
    void $wizLogs.length;
    void tick().then(() => {
      if (box) box.scrollTop = 1000000000;
    });
  });

  const features: Array<[string, string, string]> = [
    ['🐧', 'LXC', 'Kontenery Linux — wymagane przez Waydroid'],
    ['⚙️', 'Moduł binder_linux', 'Sterownik kernela (modprobe / wbudowany w ≥5.12)'],
    ['📡', 'ADB + wget', 'Android Debug Bridge i pobieranie APK'],
    ['🤖', 'Waydroid', 'Emulator Androida dla Linuksa'],
    ['🛒', 'Google Play Services', 'GAPPS — opcjonalne, do Sklepu Play'],
  ];
</script>

<div class="wizard-wrap">
  <div class="wizard">
    {#if $screen === 'welcome'}
      <div class="wiz-head">
        <div class="wiz-logo">🤖</div>
        <div>
          <div class="wiz-title">HackerDeck v4.0</div>
          <div class="faint small">Kreator pierwszego uruchomienia</div>
        </div>
      </div>
      <p class="wiz-lead">Wykryto brakujące zależności. Kreator zainstaluje:</p>
      {#each features as [icon, name, desc] (name)}
        <div class="feat">
          <span class="feat-icon">{icon}</span>
          <div>
            <div class="bold small">{name}</div>
            <div class="faint small">{desc}</div>
          </div>
        </div>
      {/each}
      <div class="banner amber">
        <span>⚠️</span>
        <span>Wymagane: Debian trixie/forky, kernel ≥ 5.12 z obsługą binder, dostęp do pkexec.</span>
      </div>
      <button class="btn big-btn" onclick={startInstall}>🚀 Zainstaluj wszystko automatycznie</button>
      <button class="btn flat wide" onclick={() => finishSetup()}>Pomiń — Waydroid jest już zainstalowany</button>
    {:else if $screen === 'installing'}
      <div class="wiz-title plain">Trwa instalacja…</div>
      <div class="cyan-text">{$stepLabel || 'Finalizowanie…'}</div>
      <div class="progress"><div class="progress-fill" style="width: {Math.round($progress * 100)}%;"></div></div>
      <div class="wiz-log" bind:this={box}>
        {#each $wizLogs as l (l.id)}
          <div class="log-line {l.kind}">{l.text}</div>
        {/each}
      </div>
      {#if $failed}
        <button class="btn" onclick={resetWizard}>↻ Spróbuj ponownie</button>
      {/if}
    {:else}
      <div class="done">
        <div class="done-glyph">✔</div>
        <div class="done-title">Instalacja zakończona!</div>
        <p class="muted center">Waydroid i wszystkie zależności są gotowe.<br />Przyjemnego korzystania z HackerDeck!</p>
        <button class="btn big-btn" onclick={() => finishSetup()}>▶ Uruchom HackerDeck</button>
      </div>
    {/if}
  </div>
</div>
