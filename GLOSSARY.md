# Bulb and Shade

Platform 2D in cui una lampadina attraversa stanze buie: il flash crea ombre solide su cui camminare. Questo glossario fissa i termini comuni a codice, livelli e ticket.

## Telecamera

**Zoom base**:
Lo zoom della telecamera che fa stare la stanza nello spazio sopra la striscia dei comandi, calcolato per ogni schermo. È lo zoom di riferimento di un livello.
_Avoid_: zoom di default, zoom del livello

**Moltiplicatore di zoom**:
Il fattore per cui si moltiplica lo zoom base per avere lo zoom effettivo: 1.0 è lo zoom base, sotto 1.0 la telecamera si allontana, sopra si avvicina.
_Avoid_: livello di zoom, scala

**Zoom trigger**:
Una soglia direzionale nel livello, con un verso (sinistra→destra, destra→sinistra, sopra→sotto o sotto→sopra) e un moltiplicatore di zoom per il lato "prima" (da dove si arriva) e uno per il lato "dopo" (dove si va). Conta il lato da cui la lampadina esce dall'area.
_Avoid_: zona di zoom, zoom area
