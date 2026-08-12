# Le corsie di sequenziamento non sono repliche — evidenza

Finding: `docs/findings/2026-08-12-corsie-non-repliche.md`.

Gli script si lanciano dalla radice del progetto, in quest'ordine. Ognuno legge
gli `.rds` prodotti dai precedenti, che sono archiviati qui accanto: si puo'
ripartire da un punto qualsiasi senza rifare tutto.

| script | che cosa fa | costo |
|---|---|---|
| `10-replica-dispatch.R` | replica il loop di `.build_group_rem_dispatch_from_stage3` con gli scarti registrati. **Caso di accettazione: deve riprodurre il dispatch di produzione entry per entry** | 1 min |
| `20-metadati.R` | metadati H5 dei 18.371 campioni poolati; copertura BioSample e SRX | 15 s |
| `22-profondita.R` | profondita' di libreria (da `A3-libsize-scprob-bacino.tsv`): il pre-filtro **provato e scartato** | 5 s |
| `30-candidati.R` | i candidati sull'unita' giusta, con le tre regole misurate una per una | 10 s |
| `41-correlazione-mirata.R` | correlazione sui 4 studi, **prima versione dello strumento: sbagliata** (tutti i geni, coda quasi-nulla) | 20 s |
| `42-correlazione-v2.R` | la stessa cosa sui geni espressi, piu' i controlli negativi | 1 min |
| `43-screening-completo.R` | 313.047 coppie intra-braccio su tutti i 1.115 studi del poolato | 11 min |
| `44-discriminazione.R` | AUC e sensibilita' a soglia fissa: perche' la correlazione **non e' un criterio** | 5 s |
| `50-effetto-sui-214.R` | quali righe del deliverable cambiano. **Accettazione: il `k` ricostruito = `k_effective`** | 20 s |
| `60-peso.R` | quota di peso REM e SE dello studio con le corsie contro i pari | 3 min |
| `70-screening-sd.R` | sd stimata al netto di `n`, cercando anomalie senza guardare le stringhe | 4 min |
| `80-esperimento-corsie.R` | **l'esperimento**: DE con le corsie sommate contro DE con le corsie come repliche | 2 min |
| `90-ampiezza-regola.R` | la regola su tutti gli 888.821 campioni dell'H5 | 1 min |
| `91-falsi-positivi.R` | il controllo negativo che ha trovato i **pozzetti di piastra** | 1 min |
| `92-guardie.R` | effetto delle tre guardie sul corpus intero | 1 min |
| `93-g4.R` | una quarta guardia **proposta e scartata**: non misura nulla | 5 s |
| `94-validazione-pacchetto.R` | il codice di pacchetto contro la misura a mano, sui dati veri | 1 min |
| `95-diff-regole.R` | perche' pacchetto e misura a mano differiscono di 93 librerie | 5 s |
| `98-controllo-nullo.R` | con `lane_lookup = NULL` il gate e' davvero identico a prima? | 2 min |
| `98b-libreria-sui-due-bracci.R` | nessuna libreria sta sui due bracci di un confronto | 10 s |
| `97-influenza.R` | ri-pooling e influenza sul risultato pubblicato | 50 min |
| `97b-nullo-appaiato.R` | **il nullo**: tolto a turno ogni altro studio, 55 pooling (14 worker) | 50 min |

`40-counts.R` e' archiviato ma **non e' stato portato a termine**: leggeva 2.036
geni per tutti i 18.371 campioni con un solo `h5read` a indici sparsi ed e' andato
oltre i 45 minuti senza finire. Sostituito da `43-screening-completo.R`, che legge
uno studio alla volta (11 minuti in tutto).

I file `.rds` di appoggio sono qui, tranne `s2.rds` (la cache del master Stadio 2,
10 MB, si ricostruisce da `analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl`
al primo lancio di `10-replica-dispatch.R`).
