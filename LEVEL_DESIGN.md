# Creare un livello in Godot

I livelli si fanno direttamente nell'editor di Godot: tutti gli elementi
(`Block`, `PushBox`, `WindowLight`, ...) sono script `@tool` e si disegnano
mentre li sposti e li ridimensioni.

**Indice**

1. [Passi per un nuovo livello](#1-passi-per-un-nuovo-livello)
2. [Coordinate: le due regole da ricordare](#2-coordinate-le-due-regole-da-ricordare)
3. [La stanza e la telecamera](#3-la-stanza-e-la-telecamera)
4. [Prefab disponibili](#4-prefab-disponibili)
5. [Dove va l'origine di ogni elemento](#5-dove-va-lorigine-di-ogni-elemento)
6. [Meccaniche speciali](#6-meccaniche-speciali)
7. [Controllare i salti](#7-controllare-i-salti)
8. [Registrare e provare il livello](#8-registrare-e-provare-il-livello)
9. [Limiti dell'editor](#9-limiti-delleditor)

---

## 1. Passi per un nuovo livello

Panoramica; ogni passo rimanda alla sezione con i dettagli.

1. **Copia il template.** Nel pannello FileSystem fai tasto destro su
   `prefabs/level_structures/level_template.tscn` → *Duplicate…*, chiamalo per esempio
   `levels/level_08.tscn` e aprilo. Contiene già sfondo, soffitto, pareti,
   pavimento, `Player` e `Goal`.

2. **Imposta il nodo radice.** Nell'Inspector:
   - `level_name`: il titolo mostrato nel menu, nel formato `8 · Nome`
     (il menu mostra la parte dopo `·`)
   - `icon`: l'icona della scheda nel menu (`crate`, `glass`, `rain`,
     `warehouse`, `rail`, `factory`)
   - `level_rect`: l'area del livello

3. **Adatta la stanza** a `level_rect`: sfondo, soffitto, pareti e pavimento
   → [sezione 3](#3-la-stanza-e-la-telecamera).

4. **Aggiungi gli elementi.** Trascina un `.tscn` da `prefabs/`
   ([sezione 4](#4-prefab-disponibili)) nella vista 2D e regola i parametri
   nell'Inspector. Per la posizione usa la [sezione 5](#5-dove-va-lorigine-di-ogni-elemento).
   - Per ridimensionare usa `size`, **non** lo scale del nodo.
   - Attiva lo snap alla griglia (icona magnete nella toolbar 2D, passo 10–20 px).
   - Ctrl+D duplica un elemento già configurato.
   - Dai nomi chiari ai nodi (`LedgeGoal`, `PitWater`, ...).
   - I nodi devono chiamarsi **esattamente `Player` e `Goal`** ed essere
     figli diretti della radice: il gioco li cerca per nome. Se Godot
     rinomina un'istanza (es. `Goal2`), correggila.

5. **Controlla i salti** con le curve del `Player` e i `JumpArc`
   → [sezione 7](#7-controllare-i-salti).

6. **Registra il livello** in `progress.gd` e **provalo** con F6
   → [sezione 8](#8-registrare-e-provare-il-livello).

---

## 2. Coordinate: le due regole da ricordare

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

---

## 3. La stanza e la telecamera

### Valori in base a `level_rect`

Quando cambi `level_rect` sul nodo radice, aggiorna anche questi nodi del
template. Questi sono i valori usati nei livelli esistenti:

| Nodo | `position` | `size` / altro |
|---|---|---|
| radice (`Level`) | — | `level_rect = (0, 0, W, H)` |
| `Background` | — | `rect = (0, 0, W, H)`, `wainscot_y = H - 400` |
| `Ceiling` | `(W/2, 40)` | `(W, 80)` → bordo inferiore a y = 80 |
| `WallLeft` | `(30, H/2)` | `(60, H)` → superficie a x = 60 |
| `WallRight` | `(W - 30, H/2)` | `(60, H)` → superficie a x = W - 60 |
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

Più semplice: usa **`water_basin.tscn`**, che crea da solo fondo, sponde e
acqua **e taglia da solo il pavimento** (`cut_floor`, attivo di default): non
serve spezzare il `Floor`. Mettilo con `y = pavimento` (il bordo delle sponde
a filo del pavimento) e scegli la larghezza con `size.x`. Nell'editor il buco
segue la vasca quando la sposti. Si tagliano solo i `Block` di terreno: le
casse (`casts_shadow`) e quelle appese restano intere. Per una vasca da
saltare appoggiata sul pavimento usa `y = pavimento - size.y` (toccandolo
soltanto non lo taglia).

### Telecamera

La telecamera non va aggiunta al livello: la crea `game.gd` e dipende solo da
`level_rect`.

- Se `level_rect` **sta nello schermo** (fino a 1080 px di larghezza e circa
  1520 di altezza), la telecamera è **fissa** e inquadra tutto il livello.
- Se è **più largo di 1080 px o più alto dello schermo**, la telecamera mostra
  1080 px di larghezza e **segue la lampadina** senza uscire da `level_rect`.

Quindi `level_rect` deve coprire esattamente il livello: se è più grande si
vedono zone vuote, se è più piccolo pezzi di livello restano fuori
inquadratura (e le ombre si fermano al suo bordo).

### Zoom trigger

Lo zoom che il gioco calcola per far stare la stanza sopra i comandi è lo
**zoom base**. Per vedere di più (un salto lungo, un'area ampia) o stringere
l'inquadratura in un punto preciso del livello si usa uno **Zoom trigger**
(`prefabs/gameplay/zoom_trigger.tscn`): una soglia che cambia il
**moltiplicatore di zoom** quando la lampadina la attraversa.

1. Trascina il prefab nel livello, come figlio diretto della radice.
2. Imposta `size` perché l'area copra tutto il passaggio: per un corridoio
   un'area stretta e alta quanto il livello (es. `(200, H)`), per un pozzo
   un'area larga quanto il pozzo e bassa. Nell'editor si vede il bordo
   azzurro dell'area, con i due valori di zoom.
3. Scegli `axis`:
   - **Horizontal**: "prima" = sinistra, "dopo" = destra.
   - **Vertical**: "prima" = sopra, "dopo" = sotto.
4. Imposta `zoom_before` (lato "prima") e `zoom_after` (lato "dopo").
   Sono moltiplicatori dello zoom base: `1.0` = zoom normale, `< 1.0`
   allontana (si vede di più), `> 1.0` avvicina. Così valgono uguali su ogni
   telefono.
5. Se serve, cambia `duration` (default 0.8 s; `0` = cambio netto),
   `transition` ed `easing` (default sine, ease-in-out).

Come si comporta:

- Conta solo **il lato da cui la lampadina esce** dall'area: uscendo dopo si
  passa a `zoom_after`, uscendo prima a `zoom_before`. All'ingresso non
  succede niente, quindi entrare e uscire dallo stesso lato non cambia lo zoom.
- Lo zoom resta così finché non si attraversa un altro trigger. Tornando
  indietro si ritrova lo zoom di prima. Per tornare allo zoom normale metti un
  trigger con il valore `1.0` dal lato giusto.
- Se si attraversa un trigger mentre lo zoom sta ancora cambiando, la nuova
  transizione parte dallo zoom attuale, senza scatti.
- Durante una **cutscene** (telecamera su `camera_focus`) i trigger non
  cambiano l'inquadratura: la richiesta resta in attesa e, se se ne
  attraversano più di uno, conta l'ultimo. Quando la cutscene finisce
  (`camera_focus` torna null) parte la transizione verso quello zoom, con la
  `duration` e l'easing del trigger. Le cutscene non impostano lo zoom da sole.
  Caricare, ricominciare o morire scarta la richiesta in attesa.
- La telecamera continua a inseguire la lampadina come sempre: il margine del
  salto e la velocità di inseguimento restano in pixel del livello.
- Caricare o ricominciare il livello, o cambiare la dimensione della
  finestra, riporta il moltiplicatore a `1.0`.
- Nei livelli **fissi** (telecamera che non segue) i trigger non fanno niente.
- Uno zoom-out che fa vedere oltre `level_rect` mostra il nero fuori dal
  livello: scegli valori che restino dentro.
- Sul Pixel 4a uno zoom-out porta a schermo più luci: prima di usare zoom-out
  ampi misura il framerate sul telefono.

Per provarli c'è il test `tests/zoom_test.tscn` (vedi l'intestazione dello
script).

---

## 4. Prefab disponibili

Tutti in `prefabs/`, divisi in quattro cartelle:

| Cartella | Cosa contiene | Sezioni qui sotto |
|---|---|---|
| `level_structures/` | Template, terreno, casse, vetro, finestre, acqua, pulsante: ciò che forma il percorso e le sue meccaniche | Struttura, Casse, Vetro, Luce, Acqua, `floor_button` |
| `gameplay/` | Lampadina, arrivo, checkpoint, lucine collezionabili, suggerimento del flash, zoom trigger | Giocatore e obiettivi, `flash_hint`, `zoom_trigger` |
| `props/` | Oggetti di scena, solo estetici o che reagiscono appena alla lampadina | Decorazioni |
| `gizmos/` | Strumenti visibili solo nell'editor, in gioco si cancellano | Strumenti |

Le **varianti** sono lo stesso script con valori già
impostati: puoi sempre partire dal prefab base e cambiare i parametri.

### Struttura

| Prefab | Cosa è | Parametri principali |
|---|---|---|
| `level_template.tscn` | Livello vuoto di partenza | — |
| `block.tscn` | Terreno solido (pavimenti, pareti, sporgenze) | `size` |

### Giocatore e obiettivi

| Prefab | Cosa è | Parametri principali |
|---|---|---|
| `player.tscn` | La lampadina | `flash_radius` (750), `flash_cooldown` (2.5 s), `show_jump_arc` |
| `goal.tscn` | Portalampada di arrivo | — |
| `checkpoint.tscn` | Punto di ripartenza | — |
| `mini_bulb.tscn` | Mini lampadina collezionabile → [6.2](#62-lucine-collezionabili-minibulb) | `id` (unico!), `color` |

### Casse (proiettano un'ombra solida al flash)

| Prefab | Cosa è | Parametri principali |
|---|---|---|
| `crate.tscn` | Cassa di legno fissa, 120×90 | `size` |
| `tall_crate.tscn` | Variante: cassa alta 140×300 (colonna / muro d'ombra) | `size` |
| `hanging_crate.tscn` | Cassa appesa con catena (la catena è solo decorativa) | `size`, `chain_length` |
| `push_box.tscn` | Cassa spingibile, cade con la gravità | `size` |
| `rail_crate.tscn` | Cassa che scorre su un binario quando viene attivata → [6.1](#61-pulsante-che-muove-una-cassa-floorbutton--railcrate) | `size`, `chain_length`, `travel`, `rail_left`, `rail_right`, `hanger_length`, `speed` |

`crate`, `tall_crate` e `hanging_crate` sono tutti `Block` con
`casts_shadow = true`: un `Block` qualsiasi diventa una cassa attivando
`casts_shadow`, e prende una catena impostando `chain_length > 0`.

### Vetro

| Prefab | Cosa è | Parametri principali |
|---|---|---|
| `glass_pane.tscn` | Lastra/mensola di vetro 200×30: solida ma lascia passare la luce | `size` |
| `glass_cube.tscn` | Variante: cubo di vetro 160×160 | `size` |

### Luce

Il fascio di una finestra impedisce alle ombre solide di esistere dove passa.
Muri e casse lo bloccano, il vetro no.

| Prefab | Cosa è | Parametri principali |
|---|---|---|
| `window_light.tscn` | Finestra sulla **parete sinistra**, fascio verso destra | `opening`, `direction`, `length`, `on_time`, `off_time`, `phase` |
| `window_light_right.tscn` | Variante: finestra sulla **parete destra** (ruotata 180°), fascio verso sinistra | come sopra |
| `skylight.tscn` | Variante: lucernario sul **soffitto** (ruotato 90°), fascio verso il basso | come sopra |

- `direction` è in coordinate del livello e va scelta coerente con la parete:
  x positiva per la parete sinistra, x negativa per la destra, `(0, 1)` per
  il lucernario. La y dà l'inclinazione (es. `(1, 0.1)` quasi orizzontale,
  `(1, 0.5)` in diagonale).
- `length`: lunghezza massima del fascio (0 = finché non incontra un muro).
- **Persiana intermittente:** con `on_time` e `off_time` > 0 la finestra si
  apre e chiude a ciclo (es. 2.5 / 2.5). Usa `phase` per sfasare più finestre.

### Acqua (cortocircuito)

| Prefab | Cosa è | Parametri principali |
|---|---|---|
| `water_pool.tscn` | Pozza d'acqua | `size` |
| `water_basin.tscn` | Vasca contenuta: fondo + sponde + acqua in un solo nodo, con anteprima nell'editor | `size`, `cut_floor`, `wall_thickness`, `bottom_thickness`, `freeboard`, `left_wall`, `right_wall` |
| `water_drip.tscn` | Rubinetto che gocciola. Le gocce attraversano le ombre solide e si fermano solo sulle superfici vere | `interval`, `phase`, `mount`, `pipe_length`, `max_fall` |

- `mount`: dove è fissato il tubo — `ceiling`, `wall_left`, `wall_right`.
  Allunga `pipe_length` finché il tubo tocca il soffitto o la parete.
- `phase`: ritardo della prima goccia, per non sincronizzare più rubinetti.

### Interazione e tutorial

| Prefab | Cosa è | Parametri principali |
|---|---|---|
| `floor_button.tscn` | Pulsante a pavimento → [6.1](#61-pulsante-che-muove-una-cassa-floorbutton--railcrate) | `target` (nodo da attivare) |
| `flash_hint.tscn` | Zona invisibile: finché la lampadina è dentro col flash carico, il pulsante del flash pulsa → [6.3](#63-suggerimento-del-flash-flashhint) | `size` |
| `zoom_trigger.tscn` | Soglia invisibile che cambia lo zoom della telecamera quando la lampadina la attraversa → [Zoom trigger](#zoom-trigger) | `size`, `axis`, `zoom_before`, `zoom_after`, `duration`, `transition`, `easing` |

### Decorazioni (nessuna interazione)

Solo estetica: niente collisioni, niente ombre, la lampadina ci passa davanti.
Stanno dietro a tutti gli elementi di gioco e si illuminano col buio come lo
sfondo.

| Prefab | Cosa è | Parametri principali |
|---|---|---|
| `cobweb.tscn` | Ragnatela d'angolo | `corner`, `radius`, `threads`, `rings`, `spider_drop` |
| `cobweb_spider.tscn` | Variante: angolo in alto a destra con ragnetto appeso | come sopra |
| `barrel.tscn` | Barile di legno 90×120 | `size`, `lying` |
| `barrel_lying.tscn` | Variante: barile sdraiato su un fianco | come sopra |
| `pipe.tscn` | Tubo dritto lungo 300 px | `shape`, `points`, `width`, `joint_spacing`, `end_flanges`, `valve` |
| `pipe_elbow.tscn` | Variante: gomito con volantino (`shape = elbow`) | `leg_a`, `leg_b`, `bend_angle`, più quelli sopra |

- `corner`: in quale angolo sta la ragnatela; la tela si apre verso
  l'interno della stanza. `spider_drop` > 0 aggiunge un ragno appeso a quella
  distanza (ha senso negli angoli in alto).
- Il barile è più scuro delle casse apposta, per non confonderlo con gli
  oggetti che fanno ombra. Con `lying` larghezza e altezza si scambiano.
- `points` del tubo sono coordinate **locali** rispetto al nodo. Il tubo è
  una `Line2D`, quindi i punti si piazzano col mouse: seleziona il nodo e
  usa i pulsanti che compaiono nella toolbar 2D (*crea* per aggiungere punti
  cliccando, *modifica* per trascinarli, *cancella* per toglierli). Ogni
  punto intermedio diventa un gomito. Fai toccare le estremità (con flangia) a un muro o
  al soffitto. `joint_spacing = 0` toglie i raccordi lungo i tratti.
- Gomito (`shape = elbow`): l'origine è il **punto d'angolo**. `leg_a` è la
  lunghezza del braccio che sale dall'angolo, `leg_b` quella dell'altro
  braccio, girato di `bend_angle` gradi (90 = verso destra, -90 = verso
  sinistra, 45 = in diagonale). Accorciando i bracci l'angolo resta fermo.
  Per orientarlo in altro modo ruota il nodo.

Altre decorazioni statiche:

| Prefab | Cosa è | Parametri principali |
|---|---|---|
| `edge_web.tscn` | Ragnatela che pende lungo un bordo (sotto piattaforme o soffitto) | `width`, `depth`, `pattern` |
| `fan.tscn` | Ventola da muro; in gioco le pale girano | `radius`, `speed` (giri/s, 0 = ferma), `blades` |
| `vent.tscn` | Bocchetta d'aerazione a lamelle | `size`, `slat_spacing` |
| `sack_pile.tscn` | Pila di sacchi di juta | `rows`, `sack_size` |
| `wall_crack.tscn` | Crepa nell'intonaco | `size`, `branches`, `direction`, `spread`, `pattern` |
| `exposed_bricks.tscn` | Chiazza senza intonaco coi mattoni a vista | `size`, `pattern` |
| `wall_switch.tscn` | Interruttore a muro | `kind` |
| `dust.tscn` | Polvere sospesa: granelli che galleggiano in un rettangolo, visibili **solo nella luce** (vicino alla lampadina e nei fasci delle finestre) | `size`, `amount`, `speed` |
| `wall_socket.tscn` | Variante: presa (`kind = socket` o `double_socket`) | `kind` |

- `pattern` (crepe, mattoni, ragnatele lungo i bordi): cambialo per avere una
  forma diversa; due istanze con lo stesso valore sono identiche.
- `Dust`: nell'editor si vede solo un riquadro giallo con scritto
  *dust*. Mettila dove passa un fascio di finestra o in zone che la
  lampadina attraversa; un rettangolo grande con `amount` 60–100 basta.
- `EdgeWeb` pende sotto una linea che va dall'origine verso destra; ruotata
  di 180° si appoggia sopra un bordo.

### Decorazioni che reagiscono alla lampadina

Non bloccano la lampadina e non fanno ombra: si muovono e basta.

| Prefab | Cosa è | Parametri principali |
|---|---|---|
| `jar.tscn` | Barattolo (`kind`: `jar` vasetto, `can` latta, `bottle` bottiglia): camminandoci contro (o atterrandoci sopra) la lampadina lo calcia; saltella, rimbalza sui muri e può restare sdraiato o capovolto | `kind` |
| `rope.tscn` | Fune appesa che ondeggia quando la lampadina la attraversa | `length`, `segments`, `end_style`, `thickness` |
| `rope_hook.tscn` | Variante: fune con gancio in fondo | come sopra |
| `ground_plant.tscn` | Pianta da serra a terra; ogni foglia si piega quando la lampadina la tocca | `kind`, `height`, `pot`, `pot_width`, `pattern` |
| `vine.tscn` | Rampicante che pende sotto un bordo; i tralci si scostano al passaggio | `width`, `length`, `density`, `leaf_style`, `flowers`, `pattern` |

- I barattoli si fermano sui solidi, sulle ombre solide (se l'ombra sparisce
  cadono) e sugli altri barattoli: si possono **impilare**. Per metterne uno
  sopra un altro, la y del barattolo sopra è la cima di quello sotto:
  `y sotto - altezza sotto` (altezze: `jar` 41, `can` 36, `bottle` 55).
  Calciando quello in basso la pila crolla; un barattolo lanciato contro un
  altro lo spinge. Quando la lampadina riparte dal checkpoint tornano al loro posto,
  come le casse spingibili.
- `end_style` della fune: `knot` (nodo), `hook` (gancio), `loop` (cappio).
- Piante da serra: le foglie ondeggiano piano; ogni foglia o fronda si
  piega solo quando la lampadina la tocca, e toccando i fusti (palma, banano)
  si muove tutta la chioma sopra. `kind`: `palm` (areca a più fusti),
  `monstera` (su un tutore), `fern` (felce, in vaso sta su un trespolo alto
  circa metà pianta), `banana`, `cactus` (rigido, non si muove); `pot`:
  `terracotta`, `planter` (fioriera) o `none` (piantata nel pavimento).
  `height` è l'altezza indicativa vaso compreso (la lampadina è alta 104).
- Rampicanti: come `EdgeWeb` pendono sotto una linea lunga `width` che parte
  dall'origine verso destra. `length` è la lunghezza dei tralci più lunghi,
  `density` quanti tralci ogni 100 px, `leaf_style` `ivy` o `heart`.
- `pattern` di piante e rampicanti: come per crepe e ragnatele, cambia la forma.

### Parallasse (primo piano e sfondo)

| Prefab | Cosa è | Parametri principali |
|---|---|---|
| `parallax/parallax_front.tscn` | Layer di prop davanti alla telecamera, scuri e veloci | `scroll_scale`, `modulate` |
| `parallax/parallax_back.tscn` | Layer di prop di sfondo, lenti e attenuati | `scroll_scale`, `modulate` |

Guida completa: [PARALLAX_TUTORIAL.md](PARALLAX_TUTORIAL.md)

### Strumenti (solo editor)

| Prefab | Cosa è | Parametri principali |
|---|---|---|
| `jump_arc.tscn` | Gizmo del salto, in gioco si cancella da solo → [sezione 7](#7-controllare-i-salti) | `fall_depth` |
| `flash_preview.tscn` | Gizmo del flash: mostra le ombre che crea un flash da quel punto → [sezione 7.1](#71-anteprima-delle-ombre-flashpreview) | `flash_radius`, `windows_open`, `rail_crates_arrived`, `show_jump_arc` |

---

## 5. Dove va l'origine di ogni elemento

| Elemento | L'origine è... | Posizione da impostare |
|---|---|---|
| `Block`, `Crate`, `TallCrate`, `PushBox`, `GlassPane`, `GlassCube`, `WaterPool`, `FlashHint` | il centro | y = `pavimento - size.y / 2` (se appoggia) |
| `HangingCrate` | il centro della cassa (la catena sale da sopra) | y libera; `chain_length` fino al soffitto |
| `Player` | il centro della capsula | y = `pavimento - 52` |
| `Goal` | il bordo superiore del portalampada | y = `pavimento - 120` |
| `Checkpoint` | la base | y = `pavimento` |
| `FloorButton` | la base | y = `pavimento` |
| `JumpArc` | i piedi | y = `pavimento` |
| `FlashPreview` | i piedi della lampadina che fa il flash | y = `pavimento` (o più su per un flash in salto) |
| `MiniBulb` | il centro del vetro | y = `pavimento - 50` (se appoggiata) |
| `WindowLight` | la superficie del muro, centro dell'apertura | x = 60 (sinistra) / x = W - 60 (destra) |
| `Skylight` | la superficie del soffitto, centro dell'apertura | y = 80 (bordo inferiore del soffitto) |
| `WaterBasin` | il centro del bordo superiore delle sponde | y = `pavimento` (incassata) o `pavimento - size.y` (appoggiata) |
| `WaterDrip` | la bocca del rubinetto (le gocce partono da lì) | libera; poi regola `pipe_length` |
| `RailCrate` | il centro della cassa nella posizione di **partenza** | vedi [6.1](#61-pulsante-che-muove-una-cassa-floorbutton--railcrate) |
| `Cobweb` | l'angolo (es. soffitto ∩ parete) | x = 60 / W - 60, y = 80 (o il pavimento) |
| `Barrel` | il centro | y = `pavimento - size.y / 2` (sdraiato: `pavimento - size.x / 2`) |
| `EdgeWeb` | l'estremità sinistra del bordo | y = bordo inferiore della piattaforma / del soffitto |
| `Fan`, `Vent`, `WallSwitch`, `WallSocket`, `ExposedBricks`, `Dust` | il centro | libera, sul muro |
| `WallCrack` | il punto da cui parte la crepa | libera, sul muro |
| `SackPile` | la base al centro | y = `pavimento` |
| `Jar` | la base | y = `pavimento` |
| `Rope` | il punto d'aggancio | y = 80 (bordo inferiore del soffitto) |
| `GroundPlant` | la base al centro | y = `pavimento` |
| `HangingVine` (`vine`) | l'estremità sinistra del bordo | y = bordo inferiore della piattaforma / del soffitto |
| `Pipe` | il primo punto di `points` (gomito: il punto d'angolo) | libera; poi sposta i punti / regola i bracci |

Esempio: un `PushBox` 160×160 su un pavimento a y = 2420 va a y = 2340.

---

## 6. Meccaniche speciali

### 6.1 Pulsante che muove una cassa (`FloorButton` + `RailCrate`)

Il pulsante si preme quando ci sale sopra la **lampadina**: le casse spinte
non lo premono. Resta premuto per sempre e chiama `activate()` sul suo
`target`. Al momento l'unico elemento che ha `activate()` è `RailCrate`, che
scorre una volta sola da partenza ad arrivo.

**Passo 1 — la cassa sul binario.** Trascina `rail_crate.tscn` nel livello e
mettilo **dove la cassa parte**.

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

**Passo 2 — il pulsante.**

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

### 6.2 Lucine collezionabili (`MiniBulb`)

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
4. **Registra il livello** in `progress.gd` ([sezione 8](#8-registrare-e-provare-il-livello)).
   Con F6 su un livello non registrato i progressi non si salvano, quindi la
   lucina **non apparirà nel menu**.

Per riprovare a raccoglierla, cancella i progressi: il file è
`%APPDATA%\Godot\app_userdata\Bulb & Shade\progress.cfg` (sezione
`[mini_bulbs]`, oppure tutto il file).

### 6.3 Suggerimento del flash (`FlashHint`)

Una zona rettangolare invisibile in gioco (nell'editor è un riquadro giallo
con scritto *flash hint*). Mentre la lampadina è dentro e il flash è carico,
il pulsante del flash pulsa per suggerire di usarlo. Smette appena la
lampadina fa un flash; se esce e rientra (es. dopo essere caduta in acqua)
ricomincia.

- Mettila dove il giocatore **deve** usare il flash per proseguire, coprendo
  la zona da cui il flash funziona (nel tutorial: 248×180 davanti alla cassa).
- Deve essere figlia diretta della radice del livello, accanto al `Player`.
- Usala con parsimonia: è pensata per i primi livelli.

---

## 7. Controllare i salti

Il `Player` mostra nell'editor le curve del salto (`show_jump_arc`):

- **gialla**: salto pieno con rincorsa (atterra ~475 px più in là alla stessa quota)
- **azzurra**: salto da fermo (~435 px)
- **tratteggio**: altezza massima, **~290 px**

Metti un `JumpArc` sul bordo di ogni piattaforma per vedere dove si arriva
da lì: in gioco si cancella da solo, quindi puoi lasciarlo nel livello.
`fall_depth` regola quanto in basso proseguono le curve.

- Le curve seguono i piedi; il corpo sporge ~30 px per lato.
- Le sezioni che si superano solo col flash vanno distanziate di **almeno
  360 px**, così non si possono saltare.

### 7.1 Anteprima delle ombre (`FlashPreview`)

Trascina `prefabs/gizmos/flash_preview.tscn` nel livello e mettilo dove la lampadina
farà il flash: l'origine sono i **piedi**, come per `JumpArc`. Il gizmo usa
lo stesso calcolo del gioco e si aggiorna da solo quando sposti o
ridimensioni casse, muri, vetri e finestre.

- **Sagoma gialla**: la lampadina fantasma; il cerchio grande è il raggio
  del flash (preso dal `Player`, oppure da `flash_radius` se > 0).
- **Viola**: le ombre solide che nascono dal flash.
- **Bordo verde**: i lati delle ombre su cui si cammina (rivolti verso
  l'alto, pendenza fino a 55°). Da sotto le ombre si attraversano.
- **Giallo tenue**: i fasci delle finestre, che cancellano le ombre.
- **X rossa** con *dentro un fascio*: da lì il flash non fa ombre.
- La scritta *flash: N ombre* dice quante ombre nascono.

Opzioni nell'Inspector:

- `windows_open`: spegnilo per vedere le ombre con le persiane chiuse
  (per le finestre intermittenti controlla entrambi i casi).
- `rail_crates_arrived`: mette le `RailCrate` a fine corsa, cioè com'è il
  livello dopo aver premuto il pulsante.
- `show_jump_arc`: disegna anche le curve del salto da quel punto, per
  vedere se dall'ombra si arriva dove serve.

Per un flash fatto **in salto** alza il gizmo (al massimo ~290 px sopra il
pavimento). Per una sequenza di flash metti un gizmo per ogni flash; le ombre
durano 4 s. Anche questo gizmo in gioco si cancella da solo.

Limiti: la `PushBox` è considerata dov'è nell'editor (per provarla spostata
duplica il livello o sposta temporaneamente la cassa) e le ombre di gizmo
diversi non si influenzano tra loro, come in gioco.

---

## 8. Registrare e provare il livello

**Registra.** Aggiungi il percorso in fondo a `LEVELS` in
`scripts/progress.gd`:

```gdscript
"res://levels/level_08.tscn",
```

Senza questo passaggio il livello non compare nel menu e i progressi
(record e lucine) non vengono salvati.

**Prova.** Con il livello aperto premi **F6**: il livello riparte dentro
`scenes/game.tscn` (telecamera, buio, ombre, comandi). Oppure F5 e scegli
il livello dal menu. F6 funziona anche se il livello non è ancora in
`progress.gd`, ma in quel caso i progressi non vengono salvati.

---

## 9. Limiti dell'editor

- Le ombre generate dal flash nell'editor si vedono solo con un
  `FlashPreview` ([7.1](#71-anteprima-delle-ombre-flashpreview)); la durata
  e i tempi (persiane, gocce) vanno comunque provati in gioco.
- Delle finestre nell'editor si vede solo la cornice: il fascio di luce
  compare solo in gioco o nell'anteprima di un `FlashPreview`.
- Dei rubinetti nell'editor si vede una linea tratteggiata fino al punto in
  cui atterrano le gocce; le gocce vere solo in gioco.
