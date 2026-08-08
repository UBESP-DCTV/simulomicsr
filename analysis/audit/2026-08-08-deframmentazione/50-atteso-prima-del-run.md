# Previsioni depositate PRIMA del run — de-frammentazione, asse codice↔codice

**Scritto il 2026-08-08, prima di eseguire qualunque re-pool.** Serve a un solo
scopo: se il run non riproduce questi numeri **alla cifra**, ci si ferma e si
misura, non si aggiusta la regola. È la procedura che ha funzionato per v13 e
v15 (dove tornarono TGFB1 78, IL17A 12, 351 candidati e perfino il `run_id`).

Misurato con lo strumento calibrato in `10-strumento-keff.R`, che riproduce il
funnel vero: 11.536 cgroup → 355 pre-dedup → 351 candidati → 214 poolate + 137
scartate, e i `k_eff` del deliverable v15 con **scarto minimo 0 e massimo 0 su
214 righe su 214**.

## Che cosa cambia nel codice

1. `.dedup_rem_group_by_entity()` accetta `entity_canonical` e **fonde** invece
   di scartare, quando due scritture della stessa entità canonica hanno lo
   stesso verso **e la stessa chiave di controllo**. Il `k` del vincente diventa
   il numero di studi **distinti** dell'unione.
2. Il filtro `k >= 3` del ramo `rem_group` è stato spostato **dopo** la fusione.
   Prima stava prima, e le scritture piccole cadevano al gate senza che la dedup
   le vedesse mai: è il motivo per cui IL6 (k=10 + k=1) e IL15 (k=4 + k=2) non si
   fondevano. Filtrare i pezzi prima di ricomporli è la frammentazione in altra
   forma.
3. `stage4_default_config()$rem_group$entity_canonical`, default **NULL**.

## Non-regressione, già verificata sui dati veri (non sulle fixture)

Con `entity_canonical = NULL`, sull'output Stadio 3 v15 (`…-stage3-v15-7f986159`):

| controllo | atteso | misurato |
|---|---|---|
| candidati `rem_group` | 351 | **351** |
| insieme dei `cluster_id` identico ai 351 di v15 | sì | **sì** |
| `k` di ogni candidato invariato | sì | **sì** |

Cambia solo l'attributo `scartati`, che diventa più completo (registra anche i
cluster sotto soglia). Nessun consumatore a valle lo legge — verificato.

## La mappa usata per la misura

⚠️ **Fornita a mano come INPUT DI MISURA, non come configurazione di
produzione.** In produzione va **generata da una regola** (ponte fra registri
sostenuto da un nome canonico, con le guardie di precisione), perché una tabella
di equivalenze scritta a mano è la «lista travestita» che questo progetto ha già
pagato. Finché la regola non è codice di pacchetto misurato, la configurazione
resta NULL e **niente cambia**.

Le cinque equivalenze vengono dal cancello del 2026-08-08 (`32-verdetti-8-fusioni.csv`),
che ha letto le etichette intere di 200 confronti e ha **bocciato 3 fusioni su 8**:

    CHEMBL:CHEMBL265582  -> HGNC:11892     TNF, gene e proteina ricombinante
    MeSH:D015850         -> HGNC:6018      IL-6, descrittore MeSH e gene
    CHEMBL:CHEMBL4297989 -> HGNC:5977      IL-15 ricombinante non glicosilata
    CHEMBL:CHEMBL437472  -> CHEBI:80240    endotelina-1
    CHEMBL:CHEMBL1852688 -> CHEBI:63451    infigratinib / BGJ-398

Bocciate e **non** in mappa: IL-10 (un membro ha come trattato «activated *in the
absence of* IL-10»: verso invertito), GM-CSF (5 membri su 13 misurano
differenziazione), «Compound 4» (identità sbagliata: il ponte è l'alias generico
`compound4`; da un lato una serie med-chem, dall'altro WM-1119, inibitore KAT6A).

## LE PREVISIONI

### Fusioni che devono scattare — 5, non una di più

| assorbito | vincente | chiave | k prima → dopo |
|---|---|---|---|
| `cgroup_L5_4f4d9051` | `cgroup_L5_d9e23e09` | `HGNC:11892‖gain‖vehicle_untreated` | 41 → **48** |
| `cgroup_L5_7a487535` | `cgroup_L5_a25d0964` | `HGNC:6018‖gain‖vehicle_untreated` | 10 → **11** |
| `cgroup_L5_d5036241` | `cgroup_L5_bd40f34f` | `HGNC:5977‖gain‖vehicle_untreated` | 4 → **6** |
| `cgroup_L5_ae927181` | `cgroup_L5_889ae73b` | `CHEBI:63451‖gain‖vehicle_untreated` | 2 → **3** |
| `cgroup_L5_70ec763f` | `cgroup_L5_b7085406` | `CHEBI:80240‖gain‖vehicle_untreated` | 1 → **2** |

### Studi poolati, gruppo per gruppo

| gruppo | k_eff oggi | k_eff previsto | passa il gate k_eff≥3 |
|---|---:|---:|---|
| TNF `HGNC:11892` | 32 | **38** | sì |
| IL-6 `HGNC:6018` | 10 | **11** | sì |
| IL-15 `HGNC:5977` | 3 | **5** | sì |
| infigratinib `CHEBI:63451` | — | 2 | **no** |
| endotelina-1 `CHEBI:80240` | — | 2 | **no** |

### I numeri complessivi

- candidati `rem_group`: **351 → 351** (−1 la riga del TNF assorbita, +1
  infigratinib che con k=3 entra fra i candidati)
- righe del deliverable: **214 → 213** (le due righe del TNF diventano una)
- **meta-analisi nuove: ZERO.** Infigratinib entra fra i candidati ma cade al
  gate dei controlli interni con k_eff=2. Nessuna riga nuova a k=3 esatti — la
  fascia in cui il progetto ha misurato l'80% di gruppi dominati da un solo
  studio, ed è per quello che il glioblastoma fu tolto dalle fusioni il
  2026-08-02.
- studi poolati guadagnati: **+11**, su 3 righe su 214.
- due delle tre righe migliorate sono fra le **debolissime**: IL-6 ha 2,6 studi
  efficaci (Kish) su 10 ed è marcata dominata da un solo studio; IL-15 ne ha 2,1.
  Aggiungere uno studio a un gruppo dominato vale più che aggiungerlo al TNF,
  perché diluisce il dominante.

### Limite dichiarato

Il `k_eff` calcolato qui salta il pre-filtro H5 del re-pool vero, quindi è un
**limite superiore**. Su v15 il suo costo misurato è **zero studi su tutti e
351**, quindi il limite è stretto — ma resta un limite superiore, non una
previsione esatta.

## Costo del run, misurato dal log di v15

I tempi per cluster stanno in `analysis/audit/2026-08-02-fix/50-repool-v15.log`:
mediana **448 s** per cluster, massimo 2.809 s, somma sui 214 = **31,0 ore**.
I cluster che cambiano costano insieme **~54 minuti** (TNF 1.252 s + la riga
assorbita 482 s + IL-6 985 s + IL-15 527 s); le righe assorbite di IL-6 e IL-15
non hanno tempo registrato perché non erano mai state poolate (k=1 e k=2).
La cache dei conteggi ha 27.940 voci e 9 GB: un re-pool sugli stessi cluster
Stadio 3 **non rileggerebbe l'H5 nemmeno una volta**.

⚠️ Un re-pool parziale rende il deliverable **misto**: alcune righe da un run,
il resto da un altro, con versioni di pacchetto diverse. È difendibile solo se la
provenienza è scritta riga per riga.
