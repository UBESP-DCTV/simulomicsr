# S12 — Stadio 2b, il disegno: cancelli e previsioni

**Depositate:** 2026-11-07, prima di ogni calcolo sull'ingresso e prima di scrivere regola e prompt.
**Oggetto:** i 1.903 confronti del deliverable A3 v16
`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`
(194 meta-analisi), elencati in `analysis/audit/2026-08-20-rilettura-194/dispatch-A3.rds` (`$tenuti`,
con i GSM di ciascun braccio). Testo dei campioni: `analysis/input/human_gene_v2.5.h5`, gruppo `meta/samples`.
**Unità:** il confronto. Il calcolo copre tutti i 1.903 confronti, non un campione: i conteggi di questa
sessione non hanno intervallo di confidenza. **Seme:** 20261107 (nessuna estrazione casuale prevista).

**Cecità.** In questa sessione non apro `analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/41-riferimento-dopo-S11.csv`
né `difetti.csv`, e non leggo il codice del rilevatore a regole (S10-S10b). Le voci della lista di controllo vengono
da ADR-0028 e dalle decisioni del PI (tempo zero e differenza tecnica sempre errore, S11 §12). Il prompt non usa
esempi presi dai 193.

## Cancelli (binari: se uno fallisce la sessione non vale)

| # | cancello | come si verifica |
|---|---|---|
| C1 | Il manifesto SHA-256 del deliverable passa | `10-manifesto-e-copia.sh verifica` → `10-manifesto-inizio.txt` |
| C2 | L'elenco copre 1.903 confronti su 1.903 e 194 gruppi su 194; ogni GSM di ogni braccio sta nell'H5; il numero di GSM per braccio è uguale a `n_gsm_t` / `n_gsm_c` | script `20-ingressi.R` |
| C3 | L'ingresso non perde testo: per ciascuno dei 1.903 confronti, ogni valore non vuoto di ogni campo di ogni campione compare per intero nel testo d'ingresso (1.903 su 1.903) | script `20-ingressi.R` |
| C4 | Test verdi. Ogni motivo di scarto della regola ha almeno un test che lo fa scattare (controllo positivo); il confronto pulito sintetico passa (controllo negativo). Lo schema accetta un esempio valido e rifiuta gli esempi non validi | `testthat` sui file `test-stage2b-*.R` |
| C5 | Nel prompt, nello schema e nei test non compare nessun accession GEO (`GSE`, `GSM`, `GPL`) | `grep` |

## Previsioni per questa sessione

**P1 — Confronti con un ingresso oltre il limite.** Quantità: numero dei 1.903 confronti il cui ingresso
completo (prompt di sistema + testo dei campioni, senza tagli) supera il limite di token d'ingresso.
Limite: `max_model_len` 32.768 (config della prova, handout S12p) meno 6.144 token riservati alla risposta =
26.624 token. Stima dei token: caratteri / 3 (stima prudente; il conteggio vero di vLLM si misura nello smoke
della prova e, se il rapporto vero è sotto 3 caratteri per token, P1 si ricalcola prima del lancio pieno).
**Atteso: da 0 a 5.** **Intervallo di rilevanza: da 0 a 19.** Motivo: un confronto oltre il limite non si
legge e la regola lo scarta («ingresso incompleto»). Se è pulito, conta come falso allarme. La soglia del
progetto per la prova è 40 falsi allarmi su 1.710 (ADR-0028); 19 confronti (1% dei 1.903) ne consumerebbero
metà prima di cominciare. Sopra 19 il disegno dell'ingresso va cambiato prima della prova.

**P2 — Stringhe tagliate all'origine.** Quantità: numero di campi dell'H5 (fra i campi d'ingresso) in cui
almeno 5 stringhe di tutto il bacino hanno la stessa lunghezza massima, e quella lunghezza è ≥ 255 caratteri
(segno di un taglio fatto da ARCHS4). **Atteso: 0.** **Intervallo di rilevanza: 0.** Motivo: la regola di
metodo «lo strumento deve vedere il dato intero» (`CLAUDE.md` §4). Un solo campo tagliato vuol dire che il
modello non vede tutto il testo, e va scritto come limite e verificato su GEO.

**P3 — Token d'ingresso per confronto (informativa).** Quantità: mediana e 99° percentile della stima dei
token d'ingresso sui 1.903. **Atteso: mediana fra 2.000 e 6.000; 99° percentile sotto 20.000.**
**Intervallo di rilevanza:** mediana sopra 10.000 token. Motivo: con una mediana sopra 10.000 la prova con tre
modelli non sta in una notte su `poddgx02` (handout S12p) e il piano va rifatto.

## Previsioni per la prova cieca (S12p), depositate qui come chiede l'handout

Si giudicano in S12p, dopo che le tre uscite sono su disco con SHA-256. Riferimento: i 193 confronti difettosi
e i 1.710 puliti del deliverable. Un confronto è «accusato» se la regola dello Stadio 2b lo scarta.
Intervallo di confidenza al 95% di Wilson su ogni frazione; unità: il confronto.

| # | quantità | atteso | intervallo di rilevanza | da dove viene il margine |
|---|---|---|---|---|
| P4 | difetti presi (scartati) su 193, modello di produzione | ≥ 130 | [130, 193] | cancello di ADR-0028 (soglia del progetto) |
| P5 | puliti accusati su 1.710, modello di produzione | ≤ 40 | [0, 40] | cancello di ADR-0028 (soglia del progetto) |
| P6 | quota di voci `not_stated` sulle voci della lista (assi × confronti, tutti i 1.903) | < 30% | [0%, 30%] | handout S12; sopra il 30% la regola passa per lo più confronti che nessuno ha letto, e i Methods devono dirlo |

Le stesse soglie valgono per gli altri due modelli della prova. La prova non cambia prompt, schema o regola dopo
il conto (handout S12p).
