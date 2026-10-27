# 2026-10-27 — i dati pesanti di simulomicsr su `/mnt/micron`

**Perché.** La radice (`/`) era al 90% (90 GB liberi su 916) e il repo pesava 81 GB,
quasi tutti dati gitignorati. Scelta dell'utente fra tre opzioni (copia + link del repo
intero / spostamento pulito / solo i dati): **solo i dati**, più la cache R. Codice, git,
worktree (`simulomicsr-mega`, `simulomicsr-chatui`) e sessioni Claude restano in
`/home/user/simulomicsr`; ogni percorso scritto negli script e nei `run_metadata` resta valido.

## Che cosa sta dove

| percorso di sempre | ora punta a | forma |
|---|---|---|
| `analysis/input` | `/mnt/micron/simulomicsr-dati/input` | link della cartella |
| `analysis/p4-bundles` | `/mnt/micron/simulomicsr-dati/p4-bundles` | link della cartella |
| `analysis/p4-output/<voce>` | `/mnt/micron/simulomicsr-dati/p4-output/<voce>` | **416 link, uno per voce**; i 17 file tracciati restano veri |
| `~/.cache/R/simulomicsr` | `/mnt/micron/simulomicsr-dati/cache-R-simulomicsr` | link della cartella |

- `p4-output` non può diventare un link intero: contiene 17 file tracciati, che git
  vedrebbe cancellati. Le voci spostate sono scelte **per regola** (ogni voce che non è un
  file tracciato), elenco in `p4-output-voci-spostate.txt`.
- Un link al posto di una cartella ignorata con `dir/` git lo mostra come `??` (provato su
  un repo a vuoto): in `.gitignore` le righe `analysis/input/` e `analysis/p4-bundles/`
  hanno perso la barra finale. È l'unica modifica a un file tracciato.
- **I run nuovi** scritti in `analysis/p4-output/<nuova-cartella>` finiscono ancora sulla
  radice: se pesano, spostali con lo stesso schema (o scrivili direttamente su micron).

## Verifica

- Copia `rsync -aHAX`; manifesto SHA-256 letto dalla **sorgente**
  (`/mnt/micron/simulomicsr-dati/SHA256SUMS-<area>.txt`); `sync` e page cache della
  destinazione sfrattata (`../2026-08-21-S2-deliverable-in-salvo/20-sfratta-page-cache.py`:
  0/34.698.226 pagine residenti); `sha256sum -c` sulla destinazione.
- **34.972/34.972 file identici**: input 200 · p4-bundles 1.657 · cache R 29.316 ·
  p4-output 3.799 (= 3.816 − 17 tracciati). Link e cartelle identici (nome e bersaglio).
  87,72 GiB; lo sfratto ne dichiara 132,36 perché `os.walk` conta due volte l'H5
  attraverso il link relativo `archs4-human-gene-v2.5.h5` (44,6 GiB): non tocca la verifica.
- Dopo lo scambio: `git status` identico a prima salvo ` M .gitignore`; 0 link rotti;
  `20-prova-funzionale.R` legge H5 (888.821 × 67.186), parquet dello Stadio 3 A3
  (571.680 righe), cache R e fa scrittura + rename atomico nella cache — tutto dai percorsi
  di sempre.

## Il primo lancio si è fermato (`copia-e-verifica.lancio1-fermo-su-comm.log`)

`comm` girava con la collazione di sistema, gli elenchi erano ordinati in `LC_ALL=C`:
«not in sorted order» e, con `set -e`, il job è uscito dopo aver copiato tre aree su
quattro (solo scritture su micron, sorgente intatta). E il monitor non l'ha segnalato:
filtrava per parole d'errore che quel messaggio non conteneva, e il suo `pgrep -f` trovava
sé stesso. Corretto con `LC_ALL=C comm`; il secondo lancio è stato seguito per SID della
sessione e con tutte le righe del log.

## Originali cancellati

- Con l'ok dell'utente, gli originali in `/home/user/simulomicsr-dati-vecchi-2026-10-27/`
  (4 aree, 34.972 file, 88 GB) sono stati cancellati lo stesso giorno: radice da 83% a 73%
  (241 GB liberi). La prova funzionale ripetuta dopo passa. `ripristina` non serve più:
  l'unica copia dei dati è ora `/mnt/micron/simulomicsr-dati/` (il deliverable ha in più
  la sua copia in `/mnt/micron/simulomicsr-salvataggio/`).
