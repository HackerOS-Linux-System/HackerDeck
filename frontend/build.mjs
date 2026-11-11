import { readFileSync, writeFileSync } from 'node:fs';
import esbuild from 'esbuild';
import sveltePlugin from 'esbuild-svelte';

// Silver ładuje jeden plik IIFE (ES2020) przez app::load_js — bez modułów ES.
const watch = process.argv.includes('--watch');
const ctx = await esbuild.context({
  entryPoints: ['src/main.ts'],
  bundle: true,
  format: 'iife',
  target: 'es2020',
  plugins: [sveltePlugin({ compilerOptions: { dev: watch } })],
  mainFields: ['svelte', 'browser', 'module', 'main'],
  conditions: ['svelte', 'browser'],
  define: { 'process.env.NODE_ENV': watch ? '"development"' : '"production"' },
  minify: !watch,
  outfile: 'dist/app.js',
  logLevel: 'info',
});
if (watch) { await ctx.watch(); console.log('obserwuję zmiany…'); }
else { await ctx.rebuild(); await ctx.dispose(); }

// Frontend wbudowany w binarkę: generujemy src/assets.h# (stringi H#), żeby program działał
// z dowolnego katalogu i bez plików frontend/ obok binarki. Tryb dev: HACKERDECK_DEV=1.
if (!watch) {
  const esc = (t) => t.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\r/g, '\\r').replace(/\n/g, '\\n').replace(/\t/g, '\\t')
    .replace(/[\u0000-\u001f]/g, (c) => '\\u' + c.charCodeAt(0).toString(16).padStart(4, '0'));
  const js = readFileSync('dist/app.js', 'utf8');
  if (/<\/script/i.test(js)) throw new Error('bundle zawiera </script — nie da się go wbudować inline');
  const html = readFileSync('index.html', 'utf8').replace('</body>', '<script>' + js + '</script></body>');
  const css = readFileSync('style.css', 'utf8');
  const out = ';; WYGENEROWANE przez frontend/build.mjs — nie edytuj ręcznie.\n'
    + 'pub fn index_html() -> string is\n    return "' + esc(html) + '"\nend\n\n'
    + 'pub fn style_css() -> string is\n    return "' + esc(css) + '"\nend\n';
  writeFileSync('../src/assets.h#', out);
  console.log('wbudowano frontend → src/assets.h# (' + out.length + ' B)');
}
