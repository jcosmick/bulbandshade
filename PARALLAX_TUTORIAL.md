# Parallasse: prop in primo piano e sullo sfondo

Torna alla guida generale: [LEVEL_DESIGN.md](LEVEL_DESIGN.md)

Due prefab in `prefabs/parallax/` aggiungono prop puramente decorativi che
scorrono a velocità diversa dal livello, per dare profondità:

| Prefab | Dove sta | `scroll_scale` | `z_index` | `modulate` |
|---|---|---|---|---|
| `parallax_front.tscn` | Davanti a tutto (anche alla lampadina) | `(1.8, 1)` | 50 | quasi nero `(0.12, 0.12, 0.15)` |
| `parallax_back.tscn` | Dietro agli elementi di gioco, davanti al muro | `(0.6, 1)` | -8 | scurito `(0.45, 0.45, 0.5)` |

Entrambi usano lo script `scripts/parallax_props.gd`.

## Passi

1. Trascina `parallax_front.tscn` e/o `parallax_back.tscn` nella scena del
   livello, come figli della radice.
2. Aggiungi i prop (da `prefabs/props/`) come **figli** del Parallax.
   Non mettere niente con collisioni: sono solo decorazioni.
3. Posiziona ogni prop **dentro il rettangolo del livello**, nel punto in cui
   vuoi vederlo passare al centro dell'area di gioco (lo schermo sopra i
   controlli). Vicino ai bordi del livello, dove la telecamera si ferma, conta
   invece la vista con la telecamera ferma al bordo: un prop messo nei primi
   540 px è esattamente lì nella schermata iniziale. All'avvio lo script lo sposta
   da solo per compensare `scroll_scale`: tu ragioni sempre in coordinate del
   livello.
4. La `scale` dei prop è quella che vedi nell'editor ed è anche quella in
   gioco. Se cambi `scroll_scale.x` del Parallax, i prop figli vengono
   ridimensionati subito in proporzione (da 1.2 a 2.4 diventano grandi il
   doppio), così il livello resta coerente mentre lo costruisci.

## Regolazioni

- **Velocità / distanza**: `scroll_scale` del Parallax. Sopra 1 = più vicino
  alla telecamera, sotto 1 = più lontano. Lascia `y = 1` se il livello non
  scorre in verticale. Cambiandolo, posizione e dimensione dei prop si
  aggiornano da sole.
- **Dimensione automatica**: `scale_with_depth` sul Parallax (attivo di
  default). Spegnilo se cambiando `scroll_scale` vuoi che i prop tengano la
  loro `scale`.
- **Colore**: `modulate` sul nodo Parallax vale per tutti i prop figli. Più
  basso = più scuro; l'ultimo valore è l'opacità.
- **Ordine**: `z_index` del Parallax (è assoluto, `z_as_relative = false`).
  Lo sfondo della stanza è a -10, le decorazioni normali tra -6 e -4.
- **Più distanze**: aggiungi più istanze con `scroll_scale` diversi. Il layer
  più lontano deve avere lo `z_index` più basso, e i layer di sfondo vanno
  tenuti tra -9 e -7 (sotto -10 finiscono dietro il muro).
- **Wooom di passaggio** (solo primo piano): di default i prop sono muti.
  Trascina un prop in `pass_sound_always` del Parallax per fargli fare il
  wooom a ogni passaggio davanti alla telecamera, o in `pass_sound_once` per
  farglielo fare solo la prima volta (anche dopo una morte; si azzera uscendo
  dal livello). Se è in tutte e due vale `pass_sound_once`. Con le liste vuote
  il layer non crea nessun lettore audio.

| Layer | Prefab | `scroll_scale` | `z_index` |
|---|---|---|---|
| Molto lontano | `parallax_back` | `(0.4, 1)` | -9 |
| Lontano | `parallax_back` | `(0.7, 1)` | -8 |
| Vicino | `parallax_front` | `(1.4, 1)` | 49 |
| Molto vicino | `parallax_front` | `(2.0, 1)` | 50 |

## Limiti

- La parallasse si vede solo se la telecamera si muove, cioè in livelli più
  larghi di 1080 px o più alti dello schermo (`level_rect`).
- In gioco coincide con l'editor solo il prop su cui è centrata la telecamera:
  gli altri dello stesso layer sono spostati di `(scroll_scale - 1)` volte la
  loro distanza dal centro, e le distanze tra i prop si vedono moltiplicate per
  `scroll_scale` (con 1.8 due prop a 500 px nell'editor sono a 900 px in
  gioco). Più `scroll_scale` è vicino a 1, più il gioco somiglia all'editor.
- Il nodo del layer è un `Node2D` (non `Parallax2D`): si può spostare
  nell'editor e i prop lo seguono.
- Nell'editor i prop si vedono nella posizione "logica" (dove passano al
  centro dell'area di gioco), non in quella che hanno in un dato momento del gioco.

Esempio: `levels/level_09.tscn`.
