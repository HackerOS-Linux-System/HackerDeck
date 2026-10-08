<script lang="ts">
  import { mouseSteering, statusText } from '../stores';
  import { showFullUi, startSession, stopSession } from '../controller';
</script>

<header class="topbar">
  <span class="logo">◆</span>
  <span class="brand">HackerDeck</span>
  <span class="ver">v4.0</span>
  <span class="status">{$statusText}</span>
  <button class="tb-btn green" onclick={startSession}>▶ Start</button>
  <button class="tb-btn red" onclick={stopSession}>■ Stop</button>
  <button class="tb-btn cyan" onclick={showFullUi}>↗ Pełny UI</button>
  {#if $mouseSteering}
    <span class="fps-badge">🎮 FPS MODE</span>
  {/if}
</header>
