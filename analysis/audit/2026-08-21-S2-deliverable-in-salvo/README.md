# 2026-08-21 — S2: mettere in salvo il deliverable

Evidenza della sessione S2 dell'handout `docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md`.
Finding: `docs/findings/2026-08-21-S2-deliverable-in-salvo.md`.

| file | che cos'è |
|---|---|
| `10-manifesto-e-copia.sh` | `genera` (scrive il manifesto) · `verifica [DEST]` (origini o copia) · `copia DEST` (rsync + verifica). Bash + coreutils + rsync, nessun R. |
| `SHA256SUMS.txt` | manifesto SHA-256 di **73 file**: il deliverable e le tre cartelle Stadio 4 archiviate (`stage4-v16/`, `stage4-v16/archivio/`), gli Stadio 3 A3 e riferimento e i quattro master (`p4-output/`), i due input Stadio 1 (`input/`), dizionari ontologici e cache (`cache/`). Percorsi relativi a quattro prefissi virtuali, così lo stesso manifesto verifica origini e copia. |
| `README-cartella-dati.md` | il `README.md` messo in `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/` e nella copia: **quale** delle quattro cartelle è il deliverable, da quale Stadio 3 viene, con quali master. |
| `20-sfratta-page-cache.py` | `misura` / `sfratta`: quante pagine della copia stanno in RAM (mincore) e loro espulsione con `posix_fadvise(DONTNEED)`, senza root. Serve a fare la verifica **a freddo** senza riavviare. |

Risultato del 2026-08-21: `verifica` sulle origini **73/73 OK**; `copia
/mnt/micron/simulomicsr-salvataggio` → 9,4 GB, `verifica` sulla copia **73/73 OK**
(a caldo). **Ripetuta a freddo** la sera stessa (uptime 16 giorni, nessun riavvio):
prima dello sfratto 100% delle pagine residenti (9,35 GiB), dopo 0%; `verifica`
sulla copia **73/73 OK** in 10,9 s contro 5,4 s in cache. La lettura dal disco
`/mnt/micron` è esercitata.

Esclusi di proposito: `~/.cache/R/simulomicsr/stage4-counts` (9,5 GB, cache
ricostruibile, cambia a ogni re-pool) e l'H5 ARCHS4 (47,86 GB, pubblico; MD5 in
`analysis/p4-output/p4-beta-archs4-source.json`).
