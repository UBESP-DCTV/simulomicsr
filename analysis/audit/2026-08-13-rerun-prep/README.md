# I tre cambi del re-run — evidenza

Finding: `docs/findings/2026-08-13-tre-cambi-implementati.md`.
Previsioni depositate prima del run: `PREVISIONI-PRIMA-DEL-RUN.md`.

Gli script si lanciano dalla radice del progetto, in quest'ordine. Ognuno legge
gli `.rds` prodotti dai precedenti.

| script | che cosa fa | costo |
|---|---|---|
| `D1-accensione-corsie.R` | l'interruttore acceso, misurato col codice di produzione. **Accettazione positiva** (2.152 → 2.146 entry, gli stessi 6 cluster) e **negativa** (spento = byte-identico a oggi) | 4 min |
| `D2-confine-marcatore.R` | il confine allargato su tutto il corpus e sul deliverable. ⚠️ **Prima versione dello strumento: mutilava le etichette con un `=`**, tenuta come cicatrice | 12 min |
| `D2b-effetto-vero.R` | l'effetto sui confronti POOLATI, non sugli assegnati: i 5 segnalati sono tutti fuori da `n_min` | 12 min |
| `D2c-k-stadio3.R` | dove il cambio agisce davvero: il `k` dello Stadio 3 (bleomicina 10 → 9), non il `k_eff` | 5 s |
| `D2d-corpus.R` | il corpus intero con lo strumento corretto, e il costo del case-sensitive su ko/kd isolato | 10 min |
| `D3D4-mappe.R` | le due mappe accese: 7 fusioni, k_eff prima e dopo, con e senza corsie. **È lo script che ha trovato l'ottava fusione non voluta (ATRA)** | 6 min |
| `P3-controllo-pipeline.R` | Stadio 1 (guard `is_zero_timepoint` su 508.037 record) e Stadio 2 (un record per studio) | 20 min |
| `P3b-funnel-e-guardie.R` | il funnel dello Stadio 4 e le guardie che devono restare accese | 1 min |
| `P5-previsioni.R` | le previsioni sui 351 candidati veri, coi tre cambi uno sopra l'altro | 15 min |

Le cinque invarianti dello Stadio 3 non sono qui: si rilanciano con lo strumento
che esiste già,
`V15_DIR=analysis/p4-output/20260803T164558Z-stage3-v15-7f986159 Rscript analysis/audit/2026-08-02-fix/60-invarianti-v15.R`
(tutte tornano, misurato il 2026-08-13).

`D1-lookup.rds` è la corrispondenza campione → libreria costruita dall'H5
(5.721 campioni, 1.810 librerie): si ricostruisce in 3 minuti se manca.
`s2.rds` (la cache del master Stadio 2) vive in `../2026-08-12-corsie/`.
