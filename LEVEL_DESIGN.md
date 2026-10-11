# Creare un livello in Godot

I livelli si fanno direttamente nell'editor di Godot: tutti gli elementi
(`Block`, `PushBox`, `Mirror`, ...) sono script `@tool` e si disegnano mentre
li sposti e li ridimensioni.

## Prefab disponibili (`prefabs/`)

| Prefab | Cosa è | Parametri principali |
|---|---|---|
| `block.tscn` | Terreno solido (pavimenti, pareti, sporgenze) | `size` |
| `crate.tscn` | Cassa di legno che proietta un'ombra solida al flash | `size` |
| `hanging_crate.tscn` | Cassa appesa con catena (la catena è solo decorativa) | `size`, `chain_length` |
| `push_box.tscn` | Cassa spingibile | `size` |
| `glass_pane.tscn` | Vetro: solido ma lascia passare la luce | `size` |
| `mirror.tscn` | Specchio che riflette il flash | `length`, `flash_radius`, rotazione |
| `water_pool.tscn` | Acqua (cortocircuito) | `size` |
| `water_drip.tscn` | Tubo che gocciola | `interval`, `phase`, `mount`, `pipe_length` |
| `window_light.tscn` | Finestra con fascio di luce, anche intermittente | `opening`, `direction`, `on_time`, `off_time`, `phase` |
| `rail_crate.tscn` | Cassa che scorre su un binario quando viene attivata | `size`, `chain_length`, `travel`, `rail_left`, `rail_right`, `hanger_length`, `speed` |
| `floor_button.tscn` | Pulsante a pavimento | `target` (nodo da attivare) |
| `mini_bulb.tscn` | Mini lampadina collezionabile | `id` (unico!), `color` |
| `checkpoint.tscn` | Punto di ripartenza | — |
| `goal.tscn` | Portalampada di arrivo | — |
| `player.tscn` | La lampadina | `flash_radius`, `flash_cooldown`, `show_jump_arc` |
| `jump_arc.tscn` | Gizmo del salto (solo editor) | `fall_depth` |
| `level_template.tscn` | Livello vuoto di partenza | — |

## Coordinate: le due regole da ricordare

- **y cresce verso il basso.** (0, 0) è l'angolo in alto a sinistra del livello.
- **Ogni elemento con `size` è centrato sul suo nodo.** Per un blocco che va
  da x1 a x2 e da y1 (bordo superiore) a y2 (bordo inferiore):

  ```
  position = ((x1 + x2) / 2, (y1 + y2) / 2)
  size     = (x2 - x1, y2 - y1)
  ```

  Esempio: un pavimento alto 100 con il bordo superiore a y = 2420 va messo a
  y = 2470.

Nel resto del file **W** e **H** sono larghezza e altezza di `level_rect`, e
**"pavimento"** è la y del bordo *superiore* della superficie su cui l'oggetto
appoggia.

## La stanza: valori in base a `level_rect`

Quando cambi `level_rect` sul nodo radice, aggiorna anche questi nodi del
template. Questi sono i valori usati nei livelli esistenti:

| Nodo | `position` | `size` / altro |
|---|---|---|
| radice (`Level`) | — | `level_rect = (0, 0, W, H)` |
| `Background` | — | `rect = (0, 0, W, H)`, `wainscot_y = H - 400` |
| `Ceiling` | `(W/2, 40)` | `(W, 80)` |
| `WallLeft` | `(30, H/2)` | `(60, H)` |
| `WallRight` | `(W - 30, H/2)` | `(60, H)` |
| `Floor` | `(W/2, H - 50)` | `(W, 100)` → pavimento a `H - 100` |

- `wainscot_y` è dove finisce la carta da parati a righe e inizia la
  zoccolatura in legno. Con `H - 400` la zoccolatura è alta circa 300 px sopra
  il pavimento. Se lo lasci al valore di default (1200), in un livello alto lo
  sfondo cambia a metà schermo.
- Le pareti devono essere alte **quanto tutto il livello**: se sono più corte
  resta un buco da cui la lampadina esce.
- Per un soffitto più spesso (spessore T): `position (W/2, T/2)`, `size (W, T)`.

Esempio per `level_rect = (0, 0, 3080, 2520)`:

| Nodo | `position` | `size` / altro |
|---|---|---|
| `Background` | — | `rect = (0, 0, 3080, 2520)`, `wainscot_y = 2120` |
| `Ceiling` | `(1540, 40)` | `(3080, 80)` |
| `WallLeft` | `(30, 1260)` | `(60, 2520)` |
| `WallRight` | `(3050, 1260)` | `(60, 2520)` |
| `Floor` | `(1540, 2470)` | `(3080, 100)` |

### Buchi nel pavimento e acqua

Per fare una fossa dividi il `Floor` in più blocchi (es. `FloorStart`,
`FloorRight`) e usa la formula del centro per ognuno. Sul fondo della fossa
metti un blocco basso (`PitBottom`, alto 20, a y = `H - 10`). Se la fossa è
piena d'acqua aggiungi un `WaterPool` largo quanto la fossa, appoggiato sul
fondo: `y = fondo - size.y / 2`.

## Dove va l'origine di ogni elemento

| Elemento | L'origine è... | y da impostare |
|---|---|---|
| `Block`, `Crate`, `PushBox`, `GlassPane`, `WaterPool` | il centro | `pavimento - size.y / 2` (se appoggia) |
| `Player` | il centro della capsula | `pavimento - 52` |
| `Goal` | il bordo superiore del portalampada | `pavimento - 120` |
| `Checkpoint` | la base | `pavimento` |
| `FloorButton` | la base | `pavimento` |
| `JumpArc` | i piedi | `pavimento` |
| `MiniBulb` | il centro del vetro | `pavimento - 50` (se appoggiata) |
| `RailCrate` | il centro della cassa nella posizione di **partenza** | vedi sotto |

Esempio: un `PushBox` 160×160 su un pavimento a y = 2420 va a y = 2340.

## Pulsante che muove una cassa (`FloorButton` + `RailCrate`)

Il pulsante si preme quando ci sale sopra la **lampadina**: le casse spinte
non lo premono. Resta premuto per sempre e chiama `activate()` sul suo
`target`. Al momento l'unico elemento che ha `activate()` è `RailCrate`, che
scorre una volta sola da partenza ad arrivo.

### 1. Posiziona la cassa sul binario

Trascina `rail_crate.tscn` nel livello e mettilo **dove la cassa parte**.

- `travel`: di quanto si sposta in orizzontale (negativo = verso sinistra).
  Nell'editor l'**arrivo** è disegnato come rettangolo di legno trasparente:
  sistemalo dove ti serve la cassa a fine corsa.
- `rail_left` / `rail_right`: estremi del binario, in x **relative alla
  partenza**. Il binario deve coprire partenza e arrivo con un po' di
  margine:

  ```
  rail_left  ≤ min(0, travel) - size.x / 2 - 20
  rail_right ≥ max(0, travel) + size.x / 2 + 20
  ```

- `chain_length`: distanza tra il carrello e la cassa. Scegli prima
  l'altezza della cassa, poi allunga la catena per arrivare al binario.
- `hanger_length`: lunghezza dei tiranti tra binario e soffitto. Perché
  tocchino il soffitto:

  ```
  hanger_length = (y - size.y / 2 - chain_length - 34) - bordo_inferiore_soffitto
  ```

  (34 = carrello + binario). Con il soffitto standard il bordo inferiore è
  a y = 80.
- `speed`: velocità dello spostamento in px/s (320 di default).

Esempio dal livello 6: cassa a `(520, 900)`, `size (140, 100)`,
`chain_length 663`, soffitto fino a y = 80 →
`hanger_length = 900 - 50 - 663 - 34 - 80 = 73`.

### 2. Posiziona il pulsante

1. Trascina `floor_button.tscn` nel livello con l'origine **sul pavimento**
   (y = bordo superiore della superficie). Il pulsante è largo 90 px:
   lascia almeno 45 px per lato sulla piattaforma.
2. Seleziona il pulsante e, nell'Inspector, clicca su **`target` → Assign...**
   e scegli il nodo `RailCrate`. Verrà salvato come `../RailCrate`.
3. Se rinomini la cassa dopo, ricontrolla `target`: se il percorso non è
   valido il pulsante si preme ma non succede niente.

Mettilo dove la lampadina lo raggiunge **prima** di aver bisogno della cassa,
e controlla con un `JumpArc` che, a cassa arrivata, il percorso sia davvero
superabile.

## Lucine collezionabili (`MiniBulb`)

Quando la lampadina tocca una mini lampadina, questa viene **salvata subito**
nei progressi, anche se il livello non viene finito. Da quel momento:

- nel **menu iniziale** compare accanto alla lampadina grande, del suo colore,
  in ordine di ritrovamento (alternate a sinistra e a destra, 6 per fila);
- nel livello resta come **fantasma** semitrasparente e non si può riprendere.

Per aggiungerne una:

1. Trascina `mini_bulb.tscn` nel livello. L'origine è il centro del vetro:
   appoggiata su un pavimento va a `pavimento - 50`. Mettila in un punto
   nascosto o difficile, ma raggiungibile (controlla con un `JumpArc`).
2. Imposta **`id`** con un nome **unico in tutto il gioco**. Convenzione:
   `levelNN_colore`, ad esempio `level08_yellow`. Già usati: `level04_red`,
   `level05_green`, `level07_blue`.
   - Se lasci `id` vuoto o duplicato, più lucine diventano la stessa: ne
     prendi una e le altre risultano già prese.
   - Non cambiare l'`id` dopo aver pubblicato il gioco: i giocatori che
     l'avevano già trovata la perderebbero dal menu.
3. Imposta **`color`** con un colore diverso da quelle esistenti (rosso nel
   livello 4, verde nel 5, blu nel 7), ad esempio giallo
   `(1, 0.85, 0.25)` o viola `(0.7, 0.4, 1)`. È il colore che si vede anche
   nel menu.
4. **Registra il livello** in `progress.gd` (vedi sotto). Con F6 su un livello
   non registrato i progressi non si salvano, quindi la lucina **non
   apparirà nel menu**.

Per riprovare a raccoglierla, cancella i progressi: il file è
`%APPDATA%\Godot\app_userdata\Bulb & Shade\progress.cfg` (sezione
`[mini_bulbs]`, oppure tutto il file).

## Passi per un nuovo livello

1. **Copia il template.** Nel pannello FileSystem fai tasto destro su
   `prefabs/level_template.tscn` → *Duplicate…*, chiamalo per esempio
   `levels/level_07.tscn` e aprilo. Contiene già sfondo, soffitto, pareti,
   pavimento, `Player` e `Goal`.

2. **Imposta il nodo radice.** Nell'Inspector:
   - `level_name`: il titolo mostrato nel menu, nel formato `7 · Nome`
     (il menu mostra la parte dopo `·`)
   - `icon`: l'icona della scheda nel menu
   - `level_rect`: l'area del livello

   Poi aggiorna sfondo, soffitto, pareti e pavimento con la tabella
   *La stanza* qui sopra.

3. **Aggiungi gli elementi.** Trascina un `.tscn` da `prefabs/` nella vista 2D,
   poi regola i parametri nell'Inspector.
   - Per ridimensionare usa `size`, **non** lo scale del nodo.
   - Attiva lo snap alla griglia (icona magnete nella toolbar 2D, passo 10–20 px).
   - Ctrl+D duplica un elemento già configurato.
   - Dai nomi chiari ai nodi (`LedgeGoal`, `PitWater`, ...).
   - I nodi devono chiamarsi **esattamente `Player` e `Goal`**: il gioco li
     cerca per nome. Se Godot rinomina un'istanza (es. `Goal2`), correggila.

4. **Controlla i salti.** Il `Player` mostra nell'editor le curve del salto:
   - **gialla**: salto pieno con rincorsa (atterra ~475 px più in là alla stessa quota)
   - **azzurra**: salto da fermo (~435 px)
   - **tratteggio**: altezza massima, **~290 px**

   Metti un `JumpArc` sul bordo di ogni piattaforma per vedere dove si arriva
   da lì: in gioco si cancella da solo, quindi puoi lasciarlo nel livello.
   Le curve seguono i piedi; il corpo sporge ~30 px per lato.
   Le sezioni che si superano solo col flash vanno distanziate di **almeno
   360 px**, così non si possono saltare.

5. **Registra il livello.** Aggiungi il percorso in fondo a `LEVELS` in
   `scripts/progress.gd`:

   ```gdscript
   "res://levels/level_07.tscn",
   ```

   Senza questo passaggio il livello non compare nel menu e i progressi
   (record e lucine) non vengono salvati.

6. **Provalo.** Con il livello aperto premi **F6**: il livello riparte dentro
   `scenes/game.tscn` (telecamera, buio, ombre, comandi). Oppure F5 e scegli
   il livello dal menu. F6 funziona anche se il livello non è ancora in
   `progress.gd`, ma in quel caso i progressi non vengono salvati.

## Telecamera

La telecamera non va aggiunta al livello: la crea `game.gd` e dipende solo da
`level_rect`.

- Se `level_rect` **sta nello schermo** (fino a 1080 px di larghezza e circa
  1520 di altezza), la telecamera è **fissa** e inquadra tutto il livello.
- Se è **più largo di 1080 px o più alto dello schermo**, la telecamera mostra
  1080 px di larghezza e **segue la lampadina** senza uscire da `level_rect`.

Quindi `level_rect` deve coprire esattamente il livello: se è più grande si
vedono zone vuote, se è più piccolo pezzi di livello restano fuori
inquadratura (e le ombre si fermano al suo bordo).

## Limiti

Le ombre generate dal flash si vedono solo in gioco: `shadow_system` non gira
nell'editor. Per verificare un puzzle con le ombre bisogna quindi avviare il
gioco.
