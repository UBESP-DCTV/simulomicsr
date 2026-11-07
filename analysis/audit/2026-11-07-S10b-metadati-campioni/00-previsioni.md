# S10b, il rilevatore sui fatti dello Stadio 1: cancelli e previsioni

Depositato il 2026-11-07, prima di applicare la regola ai 1.903 confronti e prima di leggere il riferimento
(`30-riferimento.csv` della S10) oltre le righe citate nell'handout e nel finding S10. Dopo il risultato questo file
non cambia.

## Oggetto

- Deliverable `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`
  (194 meta-analisi), non toccato. Manifesto verificato a inizio sessione (`10-manifesto-inizio.txt`).
- I 1.903 confronti poolati: `analysis/audit/2026-08-20-rilettura-194/dispatch-A3.rds`, elemento `tenuti`
  (`gsm_t`, `gsm_c`). Classe e token dell'entità: gli ingressi veri della regola di produzione catturati in S10
  (`20-ingressi-regola.rds`, colonne `cls_regola`, `entity_regola`, `extra_stop`). Tabella: `20-confronti.csv`.
- I fatti dello Stadio 1: master `analysis/p4-output/A3-stage1-master-innestato.jsonl`, quello scritto in
  `run_metadata.json` dello Stadio 3 del deliverable. `20-estrai-fatti.py` ne ha letto lo SHA-256: coincide
  (`53f7f49a…`). 15.559 campioni su 15.559 trovati, tutti con `parsed_json` e `valid_schema` TRUE
  (`20-estrai-out.txt`).
- Il riferimento è quello della S10, senza cambi: 129 confronti difettosi, 1.704 puliti, 70 altri negativi.
- La regola: `10-regola.py`, congelata con questo commit. Le sue regole di aggregazione, le classi esentate e le
  12 sotto-regole sono scritte in testa al file. In breve:
  - un campo categoriale differisce se i due bracci hanno valori non vuoti senza nessun valore in comune;
  - un agente è del trattato se sta in più della metà dei campioni trattati e in nessun controllo;
  - farmaci, ambiente e infezioni: due agenti in più nel trattato (n + 1 per un'entità COMBO di n parti);
    malattie: un agente in più, tolti i termini di malattia e l'entità scritta come agente;
  - il donatore non si confronta nelle malattie e nelle infezioni (caso-controllo per disegno);
  - un campo vuoto non è una prova di assenza: la sotto-regola tace.
- **M** = unione delle 12 sotto-regole. `R1x` (soglia a un agente tolta l'entità, la logica di V2 della S10) è una
  variante di confronto, fuori da M e fuori dalla scelta.
- La misura: `40-misura.R`, congelato con questo commit. `R/` non cambia.

## Decisioni del PI (già prese, handout S10b)

1. **N = 85** falsi allarmi sui 1.704 puliti. Una combinazione con più di 85 falsi allarmi non va alla lettura.
2. **Lettura a blocchi di 150.**
3. Alla fine il PI decide quale regola, o quale combinazione con V3 della S10, va alla lettura (S11).

## Criterio con cui propongo la combinazione per la lettura (depositato ora)

Candidate: le 12 sotto-regole di M, V3 della S10 (`S10_V3`) e la parte di V3 senza la soglia a un agente
(`S10_pulita` = greche tradotte, V1, più la regola sul materiale).

1. Tolgo ogni candidata che da sola prende 0 confronti difettosi e fa almeno un falso allarme (la regola P3 della S10).
2. Se l'unione delle rimaste fa al massimo 85 falsi allarmi sui puliti, propongo l'unione.
3. Altrimenti tolgo una candidata alla volta: quella con la precisione marginale più bassa nell'unione (difettosi
   persi / (difettosi persi + falsi allarmi persi) togliendola; a parità, quella con più falsi allarmi marginali),
   finché l'unione scende a 85 o meno.
4. Se nessuna unione con almeno un difettoso sta sotto 85, la regola sui fatti dello Stadio 1 non è recuperabile.

Gli altri negativi (70) non entrano nella scelta: il loro stato è ignoto. **La sensibilità della combinazione scelta è
ottimistica**, perché la scelta usa lo stesso riferimento: la riporto accanto a quella di M, che non ha scelta.

## Controlli (depositati prima: `20-controlli.csv`)

| caso | che cosa scrive lo Stadio 1 | atteso |
|---|---|---|
| `GSE139963` «Hypoxia + TGF-β1» contro «PBS (Vehicle Control)» | due perturbazioni nel trattato (hypoxia, TGF), PBS veicolo nel controllo | **visibile**: R1 segnala |
| `GSE126409`, gli 11 confronti con controllo «vehicle control (time zero)» | controllo `value_hours` 0 e `is_zero_timepoint`; trattato 0,5-24 h | **visibile**: R2a o R2b segnala tutti e 11 |
| `GSE97358` `grp_0002_vs_grp_0003` «TGFB1-treated (Chinese, M)» contro «Control (Malay, M)» | trattato tutto «Chinese», controllo «Malay» e «Indian» | **visibile**: R3b segnala |
| `GSE97358`, gli altri quattro confronti | bracci misti: il trattato contiene anche le etnie del controllo | **invisibile**, dichiarato ora: l'etichetta del gruppo dice un'etnia, i campioni ne hanno diverse |
| `GSE139963` «TGF-β1» contro «PBS (Vehicle Control)» | un agente nel trattato, stessi sesso, sede e materiale | **negativo**: M tace |
| `GSE114686` «Lapatinib 1 µM 24h» contro «DMSO 0.001 µM 24h» | un agente, tempi uguali (24 h), materiale uguale, sede scritta solo nel trattato | **negativo**: M tace |

Ho guardato i fatti dello Stadio 1 di questi casi prima di depositare la regola, per dichiararne la visibilità come
chiede l'handout. Non ho applicato la regola a nessun confronto vero.

## Definizioni e incertezza

Come in S10. Sensibilità = difettosi segnalati / 129. Falsi allarmi = puliti segnalati, sui 1.704. Misura secondaria:
segnalati fra i 199 confronti delle coppie accusate. Famiglie: quelle di `40-esiti.csv` della S10. Unità = studio.
Bootstrap degli studi, B = 2000, seme 20261107, percentili 2,5 e 97,5. La soglia N si applica al conteggio, che è un
censimento dei 1.704.

## Cancelli

| # | cancello | passa se |
|---|---|---|
| C1 | manifesto SHA-256 del deliverable, a inizio e a fine sessione | `VERIFICA OK` entrambe le volte |
| C2 | riproduzione | (a) lo SHA-256 del master letto coincide con `run_metadata.json`; (b) 15.559 campioni su 15.559 trovati; (c) con il riferimento della S10 gli insiemi sono 129 / 1.704 / 70 e V3 della S10 dà 10 difettosi e 51 falsi allarmi |
| C3 | copertura | 1.903 confronti su 1.903 con un esito per ogni sotto-regola |
| C4 | controlli | i tre controlli positivi visibili segnalati (11 su 11 per `GSE126409`); i due negativi taciuti da M |
| C5 | codice di produzione intatto | `git diff --stat R/` vuoto a fine sessione |

## Previsioni

| # | quantità | atteso | intervallo di rilevanza e motivo |
|---|---|---|---|
| P1 | falsi allarmi di M sui 1.704 puliti | 150 | ≤ 85, la soglia del PI. Sopra, M intera non va alla lettura e si applica il criterio di scelta |
| P2 | sensibilità di M sui 129 | 35% | [20%; 50%]. **Giudizio mio**, lo stesso della S10: sotto il 20% i Methods direbbero che il rilevatore vede una piccola minoranza dei difetti; sopra il 50% la maggior parte |
| P3 | difettosi presi da M e non da V3 della S10 | 30 | rilevante sotto 10: sotto 10 i fatti dello Stadio 1 non cambiano la frase «vede meno di un difetto su dieci» |
| P4 | per le quattro famiglie grandi (secondo agente 41, materiale 22, tempo 19, soggetto 14), difettosi presi da M contro V3 | M ne prende almeno uno in più di V3 in ognuna | una famiglia senza guadagno resta «invisibile» nei Methods anche con i fatti dei campioni |
| P5 | quota dei falsi allarmi di M segnalati dalla sede (R5) o dal donatore (R3c) | più della metà | se vera, il criterio di scelta toglie per prime queste due; se falsa, il rumore sta nei campi che dovevano essere precisi e si spiega prima di proporre |

## Che cosa non si fa

- Non si leggono i falsi allarmi: si produce l'elenco e il numero (`40-falsi-allarmi.csv`).
- Non si cambia la regola dopo questo commit. Se un controllo C4 fallisce, ci si ferma e si spiega.
- Non si modifica `difetti.csv` né il riferimento della S10.
- Non si usa la validazione esterna per scegliere.
