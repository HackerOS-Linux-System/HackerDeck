<script lang="ts">
  import { currentInstance, instances } from '../stores';
  import { deleteInstance, openDialog, switchInstance } from '../controller';
</script>

<div class="page col">
  <div class="page-head">
    <h1 class="page-title">Instancje Waydroid</h1>
    <span class="spacer"></span>
    <button class="btn" onclick={() => openDialog('instance')}>＋ Nowa instancja</button>
  </div>

  <div class="banner amber">
    <span>ⓘ</span>
    <span>Każda instancja ma własny katalog danych Android. Po utworzeniu nowej instancji uruchom „waydroid init” w Narzędziach.</span>
  </div>

  <div class="list scroll">
    {#each $instances as inst, i (inst.name + inst.data_dir)}
      <div class="card row-card">
        <span class="avatar" class:active={i === $currentInstance}>◆</span>
        <div class="row-info">
          <div class="inst-name" class:active={i === $currentInstance}>{inst.name}</div>
          <div class="faint tiny">{inst.data_dir}</div>
        </div>
        {#if i === $currentInstance}
          <span class="badge-active">AKTYWNA</span>
        {:else}
          <button class="btn small-btn" onclick={() => switchInstance(i)}>Przełącz</button>
        {/if}
        {#if i !== 0}
          <button class="mini red" onclick={() => deleteInstance(i)}>✕</button>
        {/if}
      </div>
    {/each}
  </div>
</div>
