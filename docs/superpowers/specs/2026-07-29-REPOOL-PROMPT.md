# Prompt di apertura — sessione RE-POOL v13 + etichette

Copiare da qui in giù.

---

RE-POOL — si esegue. Il deliverable è censito e i limiti sono dichiarati: manca poolarlo.

LEGGI PRIMA, INTERO: `docs/superpowers/specs/2026-07-29-REPOOL-HANDOUT.md`, poi
`docs/findings/2026-07-28-censimento-v13.md` e `docs/decisions/0026-mega-branch-out-of-deliverable.md`.

CONTESTO SENZA SCONTI. Per mesi questo progetto ha chiamato "publication-grade" raggruppamenti in
cui studi che misuravano cose diverse finivano nella stessa meta-analisi: 157 su 184. Due
re-cluster (17 ore di calcolo) hanno rifatto l'ancoraggio a partire dal CONTRASTO e chiuso cinque
meccanismi di incoerenza con regole, non con liste. Oggi il deliverable è **305 gruppi, 296
coerenti (97,0%), letti uno per uno**, con 2.158 studi-slot. Ma **non è ancora poolato**: I², τ² e
i geni significativi non esistono.

IL LAVORO DI OGGI, due cose in parallelo:
1. **RE-POOL Stadio 4 (~50 ore)**. DRY_RUN prima, poi il full con `setsid` (verifica SID==PID:
   `run_in_background` uccide i run lunghi). Aggiornamento ogni ora: fatto X, manca Y, ETA Z.
2. **Correzione delle etichette**, mentre il re-pool gira. Il nome mostrato di decine di gruppi è
   sbagliato mentre l'ID è giusto (`CHEBI:5931` "chloride" è insulina, `CHEBI:16335` "glucose" è
   adenosina). Verificato: `canonical_name` non entra nel pooling, quindi si può fare a valle senza
   toccare il run. Con TDD, in una colonna NUOVA, senza sovrascrivere la provenienza.

GATE DEL DRY_RUN: Layer A deve dare **305 cluster, tutti `rem_group`**. Se compaiono `mega`,
`mega_aug` o `rem`, la selezione non legge `deliverable_methods`: FERMATI.

ANTI-STALE a fine run, obbligatoria: `Methods` contiene solo `rem_group`; i `cluster_id` iniziano
con `cgroup_L5_`; ~305 cluster poolati. Il `k_effective` poolato può essere MINORE del `k` (collasso
dei bracci intra-studio) ma mai maggiore.

DECISIONI GIÀ PRESE, non ri-litigare: `mega`/`mega_aug`/`rem` sono fuori dal deliverable; soglia
k≥3; cache del recupero-nome ferma a v7; i nove gruppi incoerenti restano e vanno nei Methods; i
due difetti su TGF-β1 (frammentazione in tre gruppi 65+11+3, e GSE233083 dove l'entità sta su
entrambi i bracci) sono un LIMITE DICHIARATO, non si correggono.

REGOLE: il gate è la coerenza, mai il numero. Verifica su TUTTI, mai a campione — e se un insieme è
identico a uno già verificato, provalo confrontando gli insiemi, non assumerlo. Nessun LLM nella
pipeline. Nessun altro run pesante senza il mio GO. Fail onesto coi numeri: se resta il 3%, scrivi
3%. Vietato scrivere "validato/finale/paper-grade" senza prova per-gruppo su tutti. Se una misura
contraddice una conclusione precedente, ritrattala subito e per iscritto.

Parlami come a un essere umano: breve, chiaro, senza gergo.

Branch `review-scientific-consistency-2026-06-10`, master invariato.
