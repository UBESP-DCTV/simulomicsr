# S12r — Piano 1 del lettore dello studio: cancelli e previsioni

Depositate il 2026-11-10, **prima di ogni calcolo** (Task 1 del piano
`docs/superpowers/plans/2026-11-09-lettore-studio-tabella-dei-fattori-plan.md`). Dopo il risultato non si cambiano.

**Unità:** lo studio. **Incertezza:** bootstrap sugli studi, B = 2.000, seme 20261109.

**Da dove vengono i valori attesi.** Sono giudizio motivato dell'agente: non esiste una misura precedente del
progetto contro un riferimento esterno. Il PI lo sa (piano approvato il 2026-11-10).

## La divisione degli studi

`30-divisione.R` → `30-divisione.tsv`. Regola: uno studio che sta fra i 993 già letti va nello sviluppo. Per gli
altri decide il resto della divisione per 3 del numero GSE: 0 sviluppo, 1 giudizio A, 2 giudizio B. Esito:
47 studi di sviluppo, 42 di giudizio A, 40 di giudizio B. Gli 82 studi di giudizio sono chiusi: niente fattori,
livelli, confronti e uscite del modello fino all'apertura (Piano 2).

## Che cosa è già stato visto

`20-atlas-studi-nostri.txt` (committato in 37c882b) contiene i nomi dei tipi di fattore di Atlas per tutti i 129
studi, anche quelli di giudizio. `21-atlas-conta.py` ha contato gruppi e confronti con espressioni regolari su
tutti i 129. Il contenuto (livelli, gruppi, confronti) è stato letto solo per `E-GEOD-52778` ed `E-GEOD-65335`,
che stanno nello sviluppo.

## Cancelli

- **K1.** Il legame SRR → GSM copre tutti gli studi di sviluppo, e dove ENA e il campo `relation` dell'H5 danno
  entrambi un legame, concordano in tutti i casi.
- **K2.** Controllo positivo dello strumento: i gruppi e i confronti di Atlas, dati allo strumento come se fossero
  l'uscita del lettore, danno partizione identica in 47 studi su 47 e ritrovano tutti i confronti di Atlas che
  rispettano la definizione.
- **K3.** La misura di oggi copre 47 studi su 47 (uno studio senza record nel master S14 si conta come zero
  confronti, non si toglie).
- **K4.** Il job gira su `poddgx02`, con `VLLM_BATCH_INVARIANT=1` e `HF_HUB_OFFLINE=1` letti da
  `container-env.txt`, e con `prompt.txt` e `schema.json` del bundle uguali per SHA-256 ai file v0 committati.
- **K5.** Nessuno script del piano riceve un contenuto di uno studio di giudizio: i passi sui 129 studi usano
  `solo_id = TRUE` e i loro `*-out.txt` contengono solo identificativi e conteggi.

## Previsioni

Misure definite nel Task 7 del piano. «Oggi» è il master S14 dello Stadio 2
(`analysis/p4-output/S14-stage2-master.jsonl`) con almeno 2 campioni per braccio.

| | quantità, sui 47 studi di sviluppo | atteso | intervallo di rilevanza | perché |
|---|---|---|---|---|
| P1 | oggi, confronti di Atlas ritrovati (b) | 35% | 20-50% | il 24,9% dei confronti del deliverable è difettoso, e in `GSE52778` oggi i gruppi hanno un campione |
| P2 | oggi, studi con partizione identica (a) | 30% | 15-45% | lo Stadio 2 divide per ogni fatto dello Stadio 1 |
| P3 | lettore meno oggi, confronti ritrovati (b) | +30 punti | l'intervallo al 95% sta sopra 0 | criterio del §5.6 della spec |
| P4 | lettore, studi con partizione identica (a) | 65% | 50-80% | sotto 50% «ordine» non è sostenibile con questo modello e questa vista |
| P5 | errori fra i confronti non elencati da Atlas (c): lettore / oggi | 5% / 25% | 0-10% / 15-35% | la definizione toglie i confronti con due differenze |
| P6 | studi che il lettore non chiude (uscita non valida o troncata, valore non coperto dalla mappa, oltre il contesto) | 4 su 47 | 0-7 | oltre 7 la vista o lo schema v0 vanno cambiati prima di ogni conclusione |
| P7 | uscite identiche al carattere fra due corse | 47 su 47 | 47 | con `VLLM_BATCH_INVARIANT=1` Mistral ha ripetuto 1.903 uscite su 1.903 |
| P8 | confronti di Atlas fuori dalla definizione (due fattori che cambiano) | 10% | 5-20% | descrittiva |

**Come si giudica.** La stima con il suo intervallo al 95%: tutta dentro l'intervallo di rilevanza = confermata;
tutta fuori = smentita; a cavallo = indeterminata.

## Regola di esito (spec §5.6)

Si passa al Piano 2 se P3 è confermata, se il lettore fa meglio di oggi anche in (a) e in (c), e se ogni
disaccordo del lettore ha una causa che la vista, lo schema o un modello più grande possono togliere. In ogni
altro caso il PI vede numeri e cause e decide.
