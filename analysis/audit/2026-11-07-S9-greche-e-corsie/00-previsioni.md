# S9 — Le lettere greche e il crash delle corsie: attese depositate prima del calcolo

Scritte il 2026-11-07, prima di ogni conteggio sui dati. Committate da sole. Dopo il
risultato non si cambiano.

Oggetto: Stadio 3 del deliverable A3 v16,
`analysis/p4-output/20260818T110906Z-stage3-v16-7f986159`, costruito dal master
`analysis/p4-output/A3-stage2-master-innestato.jsonl` (SHA-256 `b9947746…`).
Deliverable: `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`
(194 meta-analisi). Insieme principale: `analysis/audit/2026-11-03-S5-gate-e-insiemi/80-insieme-40.csv`.

## Che cosa si simula

**La regola simulata.** Ogni carattere dell'insieme G diventa il suo nome latino in
tutte le stringhe che entrano nella chiave d'entità di un confronto, prima di
`.ca_member_contrast()`: etichetta del trattato, etichetta del controllo,
`factor_levels` dei due bracci, nome dell'anchor del trattato. Il resto della
stringa non cambia (niente `tolower`, niente normalizzazione Unicode). È la regola
«la forma greca vale come la forma ASCII», cioè il criterio di
`98-greche-tutti-i-resolver.R`.

**L'insieme G (criterio di esaustività).**

- tutti i caratteri del blocco Unicode «Greek and Coptic» (U+0370–U+03FF) e del
  blocco «Greek Extended» (U+1F00–U+1FFF);
- due sosia usati nelle etichette biologiche: µ (U+00B5, segno di micro) e ß
  (U+00DF, usato per beta).

Traduzione: le 24 lettere minuscole e maiuscole con il loro nome inglese
(α → alpha, Δ → Delta), le forme con accento e le varianti di simbolo (ϐ, ϑ, ϕ, ϰ,
ϱ, ϵ, ς) come la lettera di base. **Eccezioni dichiarate:** μ (U+03BC) e µ (U+00B5)
diventano `u`, come `ug` e `um` nelle liste delle unità del codice; ß diventa `beta`.
Un carattere di G senza traduzione resta com'è e si conta a parte.

**Perché il criterio è esaustivo.** La chiave d'entità di un confronto è una funzione
deterministica di quelle cinque stringhe e dell'ID dell'anchor. Se nessuna delle
cinque contiene un carattere di G, la traduzione non le cambia e la chiave non può
cambiare. Il calcolo verifica questa affermazione su tutti i confronti (cancello 3),
non la assume.

**Che cosa lo strumento non vede.** La simulazione non ricalcola l'anchor del
campione trattato (recupero del nome, overlay, ID dell'anchor, completezza del
tier S). Un fix dei nove resolver potrebbe cambiare anche quello. Conto i confronti
eleggibili il cui anchor o i cui fatti dello Stadio 1 contengono un carattere di G:
è il limite superiore di quello che lo strumento non vede.

## Cancelli

| # | cancello | passa se |
|---|---|---|
| 1 | manifesto SHA-256 del deliverable, all'inizio e alla fine | «VERIFICA OK» due volte |
| 2 | il regime senza traduzione riproduce lo Stadio 3 | per ogni confronto: chiave uguale a `anchor_key` di `assignments.parquet` per tutti i 27.395 record cgroup eleggibili; ragione di scarto uguale a `non_clusterable.rds` per tutti gli scarti cgroup; 53.915 record costruiti |
| 3 | copertura e controllo negativo | entrambi i regimi calcolati su tutti i confronti con due bracci validi; per tutti i confronti senza caratteri di G il regime con traduzione dà lo stesso esito in tutti i campi |
| 4 | controllo positivo | (a) la traduzione porta le 10 forme greche di `98-greche-tutti-i-resolver.R` esattamente sulla loro forma ASCII; (b) il confronto piantato `treatment=IFN-γ` contro `treatment=IFN-β` è `no_delta` senza traduzione e non è `no_delta` con la traduzione |
| 5 | il fix delle corsie e nient'altro | `.lane_index(c(NA, "a_L001", "a_L002"))` dà `NA, 1, 2` senza errore; il test nuovo esercita `build_lane_library_lookup()` con un altro gruppo candidato corsia e passa; la suite `stage4` ha 0 fallimenti; `98-greche-tutti-i-resolver.R` dà ancora 45 su 90 con il CSV identico a quello committato |

## Previsioni

Unità: il confronto per P1 e P5, la meta-analisi o il gruppo per P2-P4. P2-P4 sono
conteggi sull'intera popolazione, quindi non hanno errore di campionamento: si
giudica il valore. Per P1 e P5 l'IC 95% viene da un bootstrap per studio, B = 2.000,
seme 20261107.

| # | quantità | atteso | intervallo di rilevanza | da dove viene il margine |
|---|---|---:|---|---|
| P1 | quota dei confronti dello Stadio 2 A3 con almeno un carattere di G | 1,0% | 0,3%–3% | giudizio: sotto 0,3% il problema non tocca i gruppi; sopra 3% è un difetto di tutto il corpus. Lo dico al PI |
| P2 | meta-analisi delle 194 il cui gruppo cambia (entra o esce almeno un confronto) | 3 | 0–5 | soglia del progetto: la clausola di decadenza della sessione sui due insiemi (S5) usa «più di 5 su 194» |
| P3 | meta-analisi delle 40 il cui gruppo cambia | 0 | 0 | soglia del progetto: la stessa clausola usa «anche una sola dentro le 40» |
| P4 | gruppi nuovi con almeno 3 studi, nati da fusioni o da confronti ripescati | 1 | 0–2 | giudizio: sopra 2 il fix crea meta-analisi nuove da leggere a mano. Lo dico al PI |
| P5 | rapporto fra la quota di P1 nel master S14 e quella nel master A3 | 1,0 | 0,5–2 | giudizio: fuori da questo intervallo la misura su A3 non rappresenta la ricostruzione sui master S14, e va rifatta. Lo dico al PI |

**Lettura delle previsioni.** Atteso: il problema tocca pochi confronti, e la chiave
d'entità li tratta già quasi tutti, perché `.ca_resolve_entity()` traduce le greche
nei rami dei farmaci e della genetica. Le differenze attese stanno nei punti che non
traducono: il confronto fra i valori dei due bracci (`.ca_normalize_value`), il
rilevatore di righe (`.rp_agents`), le combinazioni e il ripiego `STR:`.

**Da controllare qui, ricevuto dal disegno della validazione esterna (S6):**
`17β-estradiol` è nell'insieme principale. Atteso: il suo gruppo non cambia.

**Nessuna scelta guarda la validazione esterna.** La regola simulata è fissata qui,
prima del calcolo, e non dipende dall'esito del confronto con LINCS di nessuna
meta-analisi.
