<script lang="ts">
  import { addCircle, closeDialog } from '../controller';

  let key = $state('');
  let input: HTMLInputElement | undefined = $state();

  $effect(() => {
    input?.focus();
  });

  function submit(e: Event) {
    e.preventDefault();
    const k = key.trim().toLowerCase();
    if (!k) return;
    addCircle(k);
    closeDialog();
  }
</script>

<div class="overlay">
  <form class="dialog" onsubmit={submit}>
    <h3>Nowy mapping klawisza</h3>
    <input type="text" placeholder="w / a / s / d / space / f2…" bind:value={key} bind:this={input} />
    <p class="hint-text">Kółko pojawi się na środku sceny. Kliknij je, a potem kliknij docelowe miejsce.</p>
    <div class="dialog-actions">
      <button type="button" class="btn flat" onclick={closeDialog}>Anuluj</button>
      <button type="submit" class="btn" disabled={key.trim() === ''}>Dodaj</button>
    </div>
  </form>
</div>
