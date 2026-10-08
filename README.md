# HackerDeck (H# + bit + Silver + Svelte + TypeScript + CSS)

Nakładka na Waydroid (odpowiednik BlueStacks) — przepisana z Fluttera.

| Warstwa | Technologia |
|---|---|
| Backend / okno | **H#** (`src/*.h#`), framework okienkowy **Silver** 0.2 |
| Pakiety i build | **bit** (`Bit.hk`) |
| Interfejs | **Svelte 5** (runes) + **TypeScript**, bundlowane esbuildem do `frontend/dist/app.js` |
| Style | zwykły **CSS** (`frontend/style.css`, tylko podzbiór obsługiwany przez Silver) |

## Budowanie
```sh
bit            # npm install + build frontendu (hook pre-build) → kompilacja H# → start
bit watch      # drugi terminal: przebudowa frontendu przy zapisie (hot reload)
bit typecheck  # svelte-check + tsc
bit install-local   # do /usr/lib/HackerOS/HackerDeck + /usr/bin/hackerdeck
```
Wymagania: `bit`, `h#`, SDL2 (`silver doctor`), `node`/`npm`, `zenity` lub `kdialog` (dialog wyboru APK).
Dane: `~/.config/hackerdeck/{instances,keymaps}.json` — ten sam format co wersja Flutter.

## Architektura
- `src/main.h#` — komendy dla JS (`env_check`, `config_load/save`, `set_ctx`, `exec`), `on_tick` (kolejka zadań, położenie sceny keymappera, Mouse Steering), `on_event` (F1 + zmapowane klawisze).
- `src/actions.h#` — **biała lista** poleceń. JS wysyła nazwę akcji + argumenty; linię powłoki składa H# i cytuje (`shell::sq`). Nigdy odwrotnie.
- `src/shell.h#`, `src/store.h#` — cytowanie/walidacja, pliki konfiguracji.
- `frontend/src/controller.ts` (port `home.dart`), `wizard.ts` (port `setup_wizard.dart`), `api.ts` (typowany kontrakt), `pages/*.svelte`.

Zadania w tle: `exec` odkłada polecenie w stanie → `on_tick` odpala `app::spawn_task` → wynik wraca zdarzeniem `silver://task` (ostatnia linia `@@exit=N`).

## Różnice względem wersji Flutter (wynikają z ograniczeń Silvera)
- **Keymapper:** Silver nie ma `<canvas>` ani zdarzenia `mousemove`, więc zamiast przeciągania: klik w kółko = zaznacz, klik w scenę = przenieś; do tego pola X/Y i strzałki ±10. Prawy klik = usuń. Scena jest skalowana do 720×1280 (współrzędne Waydroid jak w oryginale); jej położenie H# podaje do JS zdarzeniem `hd:stage`.
- **Mouse FPS:** ruch liczy H# z `app.mouse_x/y` w `on_tick` (działa w oknie, gdy włączony FPS i otwarta jest strona „Mouse FPS”).
- **Kreator instalacji:** wyjście kroku pojawia się po jego zakończeniu (brak strumieniowania).
- Ikony to znaki Unicode (brak SVG/fontów ikon w Silverze); filtr kategorii to chipy zamiast `DropdownButton`.
- Drobne poprawki: nazwa instancji jest walidowana (`[A-Za-z0-9_-]`), instancja dodawana tylko gdy `pkexec mkdir` się powiodło; sklep sprawdza, że pobrany plik to APK (nagłówek `PK`), inaczej otwiera stronę; skróty nie odpalają się podczas pisania w polu tekstowym; lista aplikacji rozpoznaje `packageName:` (oryginał szukał `Package:`).
- Instalacja z release'u (`install.hl` ze starego repo) zastąpiona `bit install-local`.

## Stan weryfikacji
- ✅ Frontend: `npm install`, `esbuild` (bundle ~100 KB, składnia OK) i `svelte-check` — 0 błędów, 0 ostrzeżeń.
- ⚠️ **Backend H# nie był kompilowany ani uruchamiany** (brak kompilatora H# w moim środowisku); pisany wg dokumentacji i kodu Silvera/bit. Oczekuj poprawek po pierwszym `bit build` (Silver 0.2 sam zastrzega to samo). Szczególnie sprawdź: `layout::LayoutBox`/`dom::find_by_id` w `main.h#` oraz zachowanie `app::emit` jako instrukcji.
- ⚠️ Układ i wygląd w oknie Silvera nieoglądane.
