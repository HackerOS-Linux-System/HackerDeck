<script lang="ts">
  let { checked, onchange }: { checked: boolean; onchange: (value: boolean) => void } = $props();
</script>

<button type="button" class="switch" aria-label="Przełącznik" class:on={checked} onclick={() => onchange(!checked)}>
  <span class="knob"></span>
</button>
