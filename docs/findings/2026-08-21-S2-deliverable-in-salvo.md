# S2 — Il deliverable in salvo: manifesto, copia, e che cosa sono le quattro cartelle

**Data:** 2026-08-21 · **Sessione:** S2 dell'handout
`docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md` · **Branch:**
`review-scientific-consistency-2026-06-10`, master invariato ·
**Evidenza:** `analysis/audit/2026-08-21-S2-deliverable-in-salvo/`

**In una riga.** Il deliverable A3 v16 (194 meta-analisi) e tutto ciò che serve a
ricostruirlo stanno ora in **un manifesto SHA-256 di 73 file versionato in git**,
in **una copia verificata su un altro dispositivo fisico**
(`/mnt/micron/simulomicsr-salvataggio/`, 9,4 GB), e la cartella sul disco esterno
ha un `README.md` che dice quale delle quattro directory omonime è il deliverable.
**Nulla è stato cancellato né spostato.**

## 1. Che cosa sono le quattro cartelle (misurato, non ricordato)

`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/` contiene quattro directory
con lo stesso suffisso `stage4-v16-3e31e59d` e la stessa forma. Confrontando i
SHA-256 file per file e i `run_metadata.json`:

| cartella | che cos'è | meta-analisi | Stadio 3 |
|---|---|---:|---|
| `20260819T185517Z` | **deliverable corrente, A3 v16** (annotato) | 194 | `20260818T110906Z-stage3-v16-7f986159` |
| `20260819T184204Z` | **duplicato byte-identico** del precedente, senza i due file di annotazione (ricomposizione dei 16 pezzi scritta 13 min prima; stesso `run_metadata.json`) | — | idem |
| `20260815T193851Z` | **riferimento v16b** (master LLM vecchi), corsie collassate (18 righe in `lane_collapses`) | 211 | `20260814T025911Z-stage3-v16-7f986159` |
| `20260815T121010Z` | **v16, superata**: stesso Stadio 3 del riferimento, ma il collasso delle corsie non si accendeva (`collapse_technical_lanes = TRUE`, `lane_collapses` 0 righe, nessun registro `covariate_drops`) | 212 | idem |

Tre cose che i documenti dicevano in modo impreciso o non dicevano:

1. **Il riferimento viene dallo Stadio 3 `20260814T025911Z`, non da `20260815T231154Z`.**
   `CLAUDE.md` §1, l'handout del 20/08 e `00-materiale.R` indicano il secondo; il
   `run_metadata.json` del riferimento dice il primo. **Non ha conseguenze**: le
   due directory sono byte-identiche file per file (`assignments.parquet`,
   `clusters.rds` sha256 `b55e5ff2…`, `non_clusterable.rds`, `record_summary.rds`);
   differisce solo il campo `timestamp` dentro `run_metadata.json` (re-cluster
   seriale a 1 worker in 9 h 21 m vs parallelo a 8 worker in 2 h 28 m, prova E3
   di `2026-08-13-rerun-prep`). Ora è scritto nel README della cartella e in `CLAUDE.md`.
2. **Il `run_metadata.json` dello Stadio 3 vecchio non registra i master**: ha
   solo i conteggi (`stage1_master.n_records` 508.037, `stage2_master.n_records`
   24.394), senza percorso né sha256. Dallo Stadio 3 A3 in poi ci sono percorso,
   conteggio e sha256, e coincidono con i file su disco
   (`A3-stage1-master-innestato.jsonl` `53f7f49a…`, `A3-stage2-master-innestato.jsonl`
   `b9947746…`). La provenienza dei master del riferimento è quindi per
   ricostruzione (script + storia), non per hash.
3. **`p4-beta-archs4-source.json` registra l'MD5 dell'H5, non lo SHA-256**
   (`CLAUDE.md` §9 diceva SHA256; corretto). In `analysis/input/` l'H5 esiste con
   due nomi (`archs4-human-gene-v2.5.h5` e `human_gene_v2.5.h5`).

## 2. Che cosa è stato fatto

| passo dell'handout | artefatto | stato |
|---|---|---|
| 1. checksum di tutti i file, in git | `analysis/audit/2026-08-21-S2-deliverable-in-salvo/SHA256SUMS.txt` — 73 file: le 4 cartelle Stadio 4 (26), gli Stadio 3 A3 + riferimento in entrambe le copie (15) e i 4 master (19 in tutto), i 2 input Stadio 1, 26 file di dizionari/cache. Generato e verificato da `10-manifesto-e-copia.sh` | fatto, verificato sulle origini |
| 2. copia su un supporto diverso | `/mnt/micron/simulomicsr-salvataggio/` (NVMe interno Micron 7450, `/dev/nvme0n1p1`, xfs, 3,5 TB di cui 78 GB usati) — dispositivo diverso sia dal disco esterno Toshiba (`/dev/sda`) sia dal disco di sistema dove sta il repository | fatto, **verificata col manifesto: 73/73 OK** |
| 3. README nella cartella | `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/README.md` (copia versionata: `README-cartella-dati.md`; stesso file anche nella copia) | fatto |
| 4. salvare ciò che serve a ricostruire | nella copia: Stadio 3 A3 e riferimento, master innestati e master vecchi, input Stadio 1 v2 e A3, dizionari ontologici con `name-recovery-lookup` e `geo-series-resolver-cache.rds` | fatto |
| 5. bozza di disponibilità dati e codice | `docs/paper/2026-08-21-dichiarazione-disponibilita-dati-codice-BOZZA.md` | bozza, con le decisioni aperte segnate |

**Esclusi di proposito** dal manifesto e dalla copia: `stage4-counts/` (9,5 GB,
cache delle conte ricostruibile dall'H5, cambia a ogni re-pool) e l'H5 ARCHS4
(47,86 GB, pubblico, ri-scaricabile, MD5 registrato).

Come si verifica, oggi o fra un anno:

```
analysis/audit/2026-08-21-S2-deliverable-in-salvo/10-manifesto-e-copia.sh verifica                                   # le origini
analysis/audit/2026-08-21-S2-deliverable-in-salvo/10-manifesto-e-copia.sh verifica /mnt/micron/simulomicsr-salvataggio  # la copia
```

## 3. Limiti di questa sessione

- **La verifica della copia è stata fatta subito dopo la scrittura** (12 s per
  9,4 GB: i dati erano quasi certamente ancora nella page cache). Va ripetuta
  **a freddo** — dopo un riavvio, o su un'altra sessione — con il comando sopra.
  Non è un dubbio sul contenuto, è che la lettura da disco non è ancora stata
  esercitata.
- **La copia è sulla stessa macchina.** Protegge dal guasto del disco esterno e da
  una sessione che lavora sull'oggetto sbagliato; **non** protegge da furto,
  incendio o guasto della macchina. Per quello serve una copia fuori sede: vedi §4.
- Le quattro cartelle e i due Stadio 3 gemelli **restano dove sono**, come chiede
  l'handout.

## 4. Le decisioni che spettano all'utente

1. **Una seconda copia fuori dalla macchina?** Opzioni, tutte con lo stesso
   script (`copia <DEST>` + `verifica <DEST>`):
   - SSD esterno **Extreme 55AE** (`/dev/sdb`, 3,6 TB, oggi collegato ma **non
     montato**): portabile, separabile dalla macchina; va montato a mano.
   - **DGX UniPD**, `/mnt/projects/dctv/dgx/u0044/` (NFS di gruppo, senza cap):
     fuori sede, ma è un'infrastruttura condivisa e la rete NFS ha già avuto
     un guasto (luglio 2026).
   - Entrambe. *Preferenza:* l'SSD esterno per il deliverable (9,4 GB, minuti),
     il DGX quando si farà S14, che comunque deve portare lì i master.
2. **Le tre cartelle vecchie: tenere o archiviare.** *Preferenza:* archiviare
   (spostare in una sottocartella `archivio/` con il loro hash già nel
   manifesto) `20260819T184204Z`, che è un duplicato byte-identico e serve solo a
   confondere; tenere `20260815T193851Z` (riferimento, usato dagli script di
   confronto) e `20260815T121010Z` (citata da E1/E2/V16c) finché gli script che
   le leggono non sono chiusi. Nessuna cancellazione.
3. **La licenza del codice.** `LICENSE` dice «Copyright 2021 UBEP. All rights
   reserved.»: incompatibile con qualunque dichiarazione di disponibilità del
   codice. Va scelta (la bozza propone MIT o GPL-3, da decidere con UBEP) prima
   di depositare.
