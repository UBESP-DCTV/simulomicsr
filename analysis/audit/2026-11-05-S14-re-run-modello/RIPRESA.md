# Riprendere la catena del re-run dopo una fermata

I job sul DGX non dipendono da questo server. La catena locale riparte dall'ultimo passo finito (`stato/*.done`, `jobs/*.rds`).

1. Fai il login grafico: la chiave ssh passa dal portachiavi della sessione.
2. Controlla i dischi: `ls /mnt/micron/simulomicsr-dati /mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16`.
3. Controlla ssh: `ssh -o BatchMode=yes u0044@logindgx.hpc.ict.unipd.it hostname`.
4. Controlla che la catena non sia già viva: `pgrep -af 50-catena`.
5. Riavvia dalla radice del repository:
   `setsid nohup Rscript analysis/audit/2026-11-05-S14-re-run-modello/50-catena.R >> analysis/audit/2026-11-05-S14-re-run-modello/log/catena.out 2>&1 < /dev/null &`

**Job fallito.** La catena si ferma. Se il job è finito male per una causa spiegata, cancella solo il suo `jobs/<slug>.rds` e riavvia: la catena lo invia di nuovo. Con più di due fallimenti dello stesso job non rilanciare: isola la causa.

**Non usare `poddgx01`.** Non usare `nodelist = NULL`.
