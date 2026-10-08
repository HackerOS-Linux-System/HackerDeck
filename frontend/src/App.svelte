<script lang="ts">
  import { onMount } from 'svelte';
  import { boot, shutdown } from './controller';
  import { checking, dialog, needsSetup, tab } from './stores';
  import TopBar from './components/TopBar.svelte';
  import Sidebar from './components/Sidebar.svelte';
  import LogPanel from './components/LogPanel.svelte';
  import NewInstanceDialog from './components/NewInstanceDialog.svelte';
  import AddKeyDialog from './components/AddKeyDialog.svelte';
  import SetupWizard from './SetupWizard.svelte';
  import Dashboard from './pages/Dashboard.svelte';
  import Apps from './pages/Apps.svelte';
  import Store from './pages/Store.svelte';
  import Instances from './pages/Instances.svelte';
  import Keymapper from './pages/Keymapper.svelte';
  import MouseSteering from './pages/MouseSteering.svelte';
  import Tools from './pages/Tools.svelte';

  onMount(() => {
    void boot();
    return () => shutdown();
  });
</script>

{#if $checking}
  <div class="boot">Sprawdzanie środowiska…</div>
{:else if $needsSetup}
  <SetupWizard />
{:else}
  <div class="shell">
    <TopBar />
    <div class="body">
      <Sidebar />
      <main class="content">
        {#if $tab === 'dashboard'}
          <Dashboard />
        {:else if $tab === 'apps'}
          <Apps />
        {:else if $tab === 'store'}
          <Store />
        {:else if $tab === 'instances'}
          <Instances />
        {:else if $tab === 'keymapper'}
          <Keymapper />
        {:else if $tab === 'mouse'}
          <MouseSteering />
        {:else}
          <Tools />
        {/if}
      </main>
    </div>
    <LogPanel />
  </div>
  <!-- Silver nie ma z-index: okna dialogowe muszą być ostatnie w dokumencie -->
  {#if $dialog === 'instance'}
    <NewInstanceDialog />
  {:else if $dialog === 'key'}
    <AddKeyDialog />
  {/if}
{/if}
