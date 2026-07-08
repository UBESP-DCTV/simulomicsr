# Piano — Recupero dei farmaci esclusi (augmentation "passo 3")

**Data:** 2026-07-09
**Spec:** `docs/superpowers/specs/2026-07-09-stage4-augmentation-passo3-design.md`
**Finding-misura:** `docs/findings/2026-07-09-stage4-augmentation-passo3-measurement.md`
**Stato:** **BLOCCATO al gate utente sulla direzione.** La misura + validazione hanno riformato il
compito; la scelta di quanto spingersi è dell'utente (spec §7). Nessun codice di produzione scritto.

## In parole semplici

Ho fatto tutto il lavoro di *scoperta* (misura sui dati veri + prova di validazione), che era la
parte più importante e delicata. Il risultato dice che il recupero immaginato (prestare controlli da
altri studi) rende poco ed è scientificamente debole. Prima di scrivere codice che cambia i
risultati, serve che tu scelga la direzione. Sotto, i passi concreti per ciascuna scelta.

## Passi già fatti (questa sessione, tutti reversibili — solo doc + misura)

1. ✅ Caratterizzati i 279 caduti (tipo, nomi, potenziale di recupero) →
   `analysis/audit/2026-07-09-stage4-279-recovery-classification.csv`.
2. ✅ Diagnosticato *perché* cadono (il 93% ha un controllo nello studio, spesso non collegato).
3. ✅ Validazione empirica "swap" su tamoxifene ed enzalutamide (prestito → −93/−99% scoperte).
4. ✅ Scritti finding + spec (6 decisioni di design + alternative scartate).

## Gate utente: scegliere UNA direzione (spec §7)

### Se Opzione 4 (RACCOMANDATA) — documentare come limite noto
1. Aggiungere una riga alla checklist limitazioni del paper (memoria `project_paper_known_limitations`):
   "279 gruppi trattati-solo senza controllo interno appaiabile non producono meta-analisi; recupero
   via controlli prestati scartato perché la validazione mostra perdita del 93–99% delle scoperte".
2. Chiudere: nessun re-pool. Aggiornare CLAUDE.md + ledger. **Fine.**

### Se Opzione 1 (accettabile, ristretta) — solo classe A non ambigua
1. Identificare i pochi cluster classe A con controllo **unico** e disegno chiaro (dallo script
   `scratchpad/classA-ambiguity.R`, ~3 candidati) + rivederli **a mano** (etichette dei gruppi).
2. TDD: estendere `.build_group_rem_dispatch_from_stage3` con un ramo "controllo interno non
   collegato", **gated** su: 1 solo gruppo di controllo ≥2 nello studio, fattori di disegno
   compatibili col trattato. Retrocompat byte-identica dei 4 rami (test).
3. Smoke sui candidati: verificare che i confronti costruiti abbiano senso (direzione, geni noti).
4. **Gate utente** prima di qualunque re-pool. Il re-pool è additivo (nuovo output v9, v8 intatto).

### Se Opzione 2 (sconsigliata) — + prestito ben ancorato
1. Come Opzione 1, più: `.build_borrowed_control_dispatch` (spec §3), abbinamento stretto (linea
   cellulare), Franchini su pool condivisi.
2. **Gate empirico per-cluster obbligatorio**: ripetere lo swap sul cluster candidato; ammettere solo
   se recupero geni ≥60%. (Attesa: quasi nessuno passa — la validazione lo suggerisce.)
3. Gate utente. Limiti dichiarati nel finding.

### Se Opzione 3 — scartata (non pianificata)

## Riusabili
- Script di misura e validazione in `scratchpad/`: `measure-recovery-potential.R`,
  `measure-strict.R`, `classA-ambiguity.R`, `validate-swap.R` (parametrico per cluster_id).
- La validazione swap è il **gate di qualità riusabile** per qualunque futura augmentation di
  controlli: se il recupero-geni crolla, il prestito non è difendibile.

## Cosa NON è stato fatto (di proposito)
- Nessun codice di produzione (la direzione va scelta prima).
- Nessun re-pool / fullrun (la validazione ha fallito il "va bene in modo netto").
- Master invariato, no push.
