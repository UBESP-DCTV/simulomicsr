# Sessione S4, il controllo condiviso (2026-11-02)

Finding: `docs/findings/2026-11-02-S4-controllo-condiviso.md`. Cancelli e previsioni: `00-previsioni.md`.

Solo misura: il deliverable, la copia su micron e la cache delle conte restano come sono.
I file pesanti (`bracci.rds`, `T3-fusi.parquet`, `rem-T*.parquet`, `studio/`) stanno in
`/mnt/micron/simulomicsr-dati/2026-11-02-S4-controllo-condiviso/` e si rifanno con gli script.
Si lancia dalla radice del repository, con `Rscript` senza `--vanilla`, nell'ordine dei numeri.
