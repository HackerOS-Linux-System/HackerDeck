<script lang="ts">
  import { tick } from 'svelte';
  import { logExpanded, logs } from '../stores';

  let box: HTMLDivElement | undefined = $state();

  // przewijanie na dół po każdym nowym wpisie
  $effect(() => {
    void $logs.length;
    void tick().then(() => {
      if (box) box.scrollTop = 1000000000;
    });
  });
</script>

<section class="logpanel" class:collapsed={!$logExpanded}>
  <button class="log-head" onclick={() => logExpanded.update((v) => !v)}>
    <span class="log-title">&gt;_ Logi</span>
    <span class="log-count">({$logs.length})</span>
    <span class="log-caret">{$logExpanded ? '▾' : '▴'}</span>
  </button>
  {#if $logExpanded}
    <div class="log-body" bind:this={box}>
      {#each $logs as l (l.id)}
        <div class="log-line {l.kind}">{l.text}</div>
      {/each}
    </div>
  {/if}
</section>
