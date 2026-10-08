<script lang="ts">
  import { closeDialog, createInstance, isValidInstanceName } from '../controller';

  let name = $state('');
  let input: HTMLInputElement | undefined = $state();
  let invalid = $derived(name !== '' && !isValidInstanceName(name));

  $effect(() => {
    input?.focus();
  });

  async function submit(e: Event) {
    e.preventDefault();
    const n = name.trim();
    if (!n) return;
    if (await createInstance(n)) closeDialog();
  }
</script>

<div class="overlay">
  <form class="dialog" onsubmit={submit}>
    <h3>Nowa instancja</h3>
    <input type="text" placeholder="Nazwa, np. Gaming, Praca…" bind:value={name} bind:this={input} />
    <p class="hint-text" class:bad={invalid}>
      {invalid ? 'Dozwolone: litery, cyfry, „_” i „-” (bez spacji)' : 'Katalog: /var/lib/waydroid_<nazwa>'}
    </p>
    <div class="dialog-actions">
      <button type="button" class="btn flat" onclick={closeDialog}>Anuluj</button>
      <button type="submit" class="btn" disabled={name.trim() === '' || invalid}>Utwórz</button>
    </div>
  </form>
</div>
