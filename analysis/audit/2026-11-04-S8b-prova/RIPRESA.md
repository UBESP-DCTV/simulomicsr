# Riprendere la prova S8b dopo una fermata del server

I job sul DGX non dipendono da questo server: continuano anche a server spento. Lo script locale riparte dall'ultimo passo finito (`stato/*.done`, `jobs/*.rds`).

1. Fai il login grafico: la chiave ssh passa dal portachiavi della sessione.
2. Controlla i dischi: `ls /mnt/micron/simulomicsr-dati /mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16`.
3. Controlla ssh: `ssh -o BatchMode=yes u0044@logindgx.hpc.ict.unipd.it hostname`.
4. Riavvia la catena dalla radice del repository:
   `setsid nohup Rscript analysis/audit/2026-11-04-S8b-prova/50-notte.R >> analysis/audit/2026-11-04-S8b-prova/log/notte.out 2>&1 < /dev/null &`
5. Non usare `poddgx01`.

Il passo `s3-recluster` non si riprende a metà: se il server si ferma durante quel passo, riparte dall'inizio (circa 2,4 ore).
