<script lang="ts">
  import { storeApps } from '../store-data';
  import { storeInstall } from '../controller';

  let search = $state('');
  let cat = $state('Wszystkie');

  const cats = ['Wszystkie', ...new Set(storeApps.map((a) => a.category))];

  let filtered = $derived(
    storeApps.filter((a) => {
      const matchCat = cat === 'Wszystkie' || a.category === cat;
      const matchSearch = search === '' || a.name.toLowerCase().includes(search.toLowerCase());
      return matchCat && matchSearch;
    }),
  );
</script>

<div class="page col">
  <div class="page-head">
    <h1 class="page-title">Sklep APK</h1>
    <input class="search-input" type="text" placeholder="Szukaj…" bind:value={search} />
  </div>

  <div class="chips">
    {#each cats as c (c)}
      <button class="chip" class:sel={cat === c} onclick={() => (cat = c)}>{c}</button>
    {/each}
  </div>

  <div class="banner blue">
    <span>ⓘ</span>
    <span>Darmowe aplikacje open-source. Przy braku bezpośredniego linku APK otworzy się strona pobierania.</span>
  </div>

  <div class="grid store-grid scroll">
    {#each filtered as app (app.name)}
      <div class="card store-card">
        <div class="store-top">
          <span class="store-icon">{app.icon}</span>
          <span class="spacer"></span>
          <span class="tag">{app.category}</span>
        </div>
        <div class="bold">{app.name}</div>
        <div class="faint tiny">v{app.version}</div>
        <div class="soft small store-desc">{app.description}</div>
        <button class="btn wide" onclick={() => storeInstall(app)}>⬇ Zainstaluj</button>
      </div>
    {/each}
  </div>
</div>
