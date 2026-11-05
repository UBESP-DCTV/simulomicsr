#!/bin/bash
# S8b: re-pool della prova in 16 pezzi, ricomposizione, conteggio degli ingressi. Scrive solo in /mnt/micron/simulomicsr-prove/S8b.
cd /home/user/simulomicsr
F=analysis/audit/2026-11-04-S8b-prova; PD=/mnt/micron/simulomicsr-prove/S8b/pezzi; S3=$(cat $F/stadio3-prova.txt)
V=analysis/audit/2026-08-16-A3/verdetti-A3.csv; M2=analysis/p4-output/S8b-stage2-master-innestato.jsonl
mkdir -p $PD; L=$F/log/repool.log
echo "[$(date +%H:%M:%S)] inizio pezzi" >> $L
for i in $(seq 1 16); do
  PEZZO=$i N_PEZZI=16 PEZZI_DIR=$PD STAGE3_DIR=$S3 STAGE2_MASTER=$M2 VERDETTI_PATH=$V Rscript analysis/p4-fase-f5-stage4-layer-a-rebuild-v16.R > $F/log/repool-pezzo-$i.log 2>&1 &
done
wait
n=$(ls $PD/pezzo-*-di-16.rds 2>/dev/null | wc -l)
echo "[$(date +%H:%M:%S)] pezzi scritti: $n su 16" >> $L
[ "$n" -eq 16 ] || { echo "[$(date +%H:%M:%S)] FERMO: mancano pezzi" >> $L; exit 1; }
PEZZI_DIR=$PD STAGE3_DIR=$S3 VERDETTI_PATH=$V Rscript $F/80-ricomponi.R > $F/log/ricomponi.log 2>&1 || { echo "[$(date +%H:%M:%S)] FERMO: ricomposizione" >> $L; exit 1; }
echo "[$(date +%H:%M:%S)] ricomposizione finita" >> $L
Rscript $F/81-ingressi.R > $F/log/ingressi.log 2>&1 || { echo "[$(date +%H:%M:%S)] FERMO: conteggio" >> $L; exit 1; }
echo "[$(date +%H:%M:%S)] FINITO" >> $L
