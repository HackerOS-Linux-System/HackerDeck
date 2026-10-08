<script lang="ts">
  import { apps } from '../stores';
  import { installApk, launchApp, refreshApps, removeApp } from '../controller';
</script>

<div class="page col">
  <div class="page-head">
    <h1 class="page-title">Aplikacje</h1>
    <span class="spacer"></span>
    <button class="btn" onclick={() => refreshApps()}>↻ Odśwież</button>
    <button class="btn" onclick={installApk}>⬇ Zainstaluj APK</button>
  </div>

  {#if $apps.length === 0}
    <div class="empty">
      <div class="empty-glyph">◆</div>
      <div class="faint">Brak aplikacji</div>
      <button class="btn flat" onclick={() => refreshApps()}>Odśwież listę</button>
    </div>
  {:else}
    <div class="grid apps-grid scroll">
      {#each $apps as app (app.package + app.name)}
        <div class="card app-card">
          <button class="app-main" onclick={() => launchApp(app.package)}>
            <span class="app-icon">◆</span>
            <span class="app-name">{app.name}</span>
            <span class="app-pkg">{app.package}</span>
          </button>
          <div class="mini-row">
            <button class="mini green" onclick={() => launchApp(app.package)}>▶</button>
            <button class="mini red" onclick={() => removeApp(app.package)}>✕</button>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>
