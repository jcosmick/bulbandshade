# Creare un livello in Godot

I livelli si fanno direttamente nell'editor di Godot: tutti gli elementi
(`Block`, `PushBox`, `Mirror`, ...) sono script `@tool` e si disegnano mentre
li sposti e li ridimensioni.

## Prefab disponibili (`prefabs/`)

| Prefab | Cosa è | Parametri principali |
|---|---|---|
| `block.tscn` | Terreno solido (pavimenti, pareti, sporgenze) | `size` |
| `crate.tscn` | Cassa di legno che proietta un'ombra solida al flash | `size` |
| `hanging_crate.tscn` | Cassa appesa con catena (decorativa) | `size`, `chain_length` |
| `push_box.tscn` | Cassa spingibile | `size` |
| `glass_pane.tscn` | Vetro: solido ma lascia passare la luce | `size` |
| `mirror.tscn` | Specchio che riflette il flash | `length`, `flash_radius`, rotazione |
| `water_pool.tscn` | Acqua (cortocircuito) | `size` |
| `water_drip.tscn` | Tubo che gocciola | `interval`, `phase`, `mount`, `pipe_length` |
| `window_light.tscn` | Finestra con fascio di luce, anche intermittente | `opening`, `direction`, `on_time`, `off_time`, `phase` |
| `rail_crate.tscn` | Cassa che scorre su un binario | `size`, `travel`, `rail_left`, `rail_right`, `speed` |
| `floor_button.tscn` | Pulsante a pavimento | `target` (nodo da attivare) |
| `mini_bulb.tscn` | Mini lampadina collezionabile | `id` (unico!), `color` |
| `checkpoint.tscn` | Punto di ripartenza | — |
| `goal.tscn` | Portalampada di arrivo | — |
| `player.tscn` | La lampadina | `flash_radius`, `flash_cooldown`, `show_jump_arc` |
| `jump_arc.tscn` | Gizmo del salto (solo editor) | `fall_depth` |
| `level_template.tscn` | Livello vuoto di partenza | — |

## Passi

1. **Copia il template.** Nel pannello FileSystem fai tasto destro su
   `prefabs/level_template.tscn` → *Duplicate…*, chiamalo per esempio
   `levels/level_07.tscn` e aprilo. Contiene già sfondo, soffitto, pareti,
   pavimento, `Player` e `Goal`.

2. **Imposta il nodo radice.** Nell'Inspector:
   - `level_name`: il titolo mostrato nel menu (es. `7 · Nome`)
   - `icon`: l'icona della scheda nel menu
   - `level_rect`: l'area giocabile (inquadratura e limite delle ombre)

   Se cambi `level_rect`, aggiorna anche `rect` del nodo `Background` e
   posizione/`size` di soffitto, pareti e pavimento.

3. **Aggiungi gli elementi.** Trascina un `.tscn` da `prefabs/` nella vista 2D,
   poi regola i parametri nell'Inspector.
   - Per ridimensionare usa `size`, **non** lo scale del nodo.
   - Attiva lo snap alla griglia (icona magnete nella toolbar 2D, passo 10–20 px).
   - Ctrl+D duplica un elemento già configurato.
   - Dai nomi chiari ai nodi (`LedgeGoal`, `PitWater`, ...).

4. **Rispetta queste regole:**
   - I nodi devono chiamarsi **esattamente `Player` e `Goal`**: il gioco li
     cerca per nome. Se Godot rinomina un'istanza (es. `Goal2`), correggila.
   - I blocchi sono **centrati** sul nodo: un pavimento alto 100 con il bordo
     superiore a y = 1420 va messo a y = 1470.
   - L'origine del **Goal** è 120 px *sopra* il pavimento su cui poggia.
   - L'origine di **Checkpoint** e **JumpArc** va *sul* pavimento.
   - Ogni **MiniBulb** ha bisogno di un `id` unico in tutto il gioco.
   - Ogni **FloorButton** ha bisogno di un `target`.

5. **Controlla i salti.** Il `Player` mostra nell'editor le curve del salto:
   - **gialla**: salto pieno con rincorsa (atterra ~475 px più in là alla stessa quota)
   - **azzurra**: salto da fermo (~435 px)
   - **tratteggio**: altezza massima, **~290 px**

   Metti un `JumpArc` sul bordo di ogni piattaforma per vedere dove si arriva
   da lì: in gioco si cancella da solo, quindi puoi lasciarlo nel livello.
   Le curve seguono i piedi; il corpo sporge ~30 px per lato.
   Le sezioni che si superano solo col flash vanno distanziate di **almeno
   360 px**, così non si possono saltare.

6. **Registra il livello.** Aggiungi il percorso in fondo a `LEVELS` in
   `scripts/progress.gd`:

   ```gdscript
   "res://levels/level_07.tscn",
   ```

   Senza questo passaggio il livello non compare nel menu.

7. **Provalo.** Premi F5 e scegli il livello dal menu.

## Limiti

Le ombre generate dal flash si vedono solo in gioco: `shadow_system` non gira
nell'editor. Per verificare un puzzle con le ombre bisogna quindi avviare il
gioco.
