#!/usr/bin/env bash
# 11-lancia-scarico.sh — lancia i due processi dello scarico, staccati dal terminale (dalla radice del repository).
set -euo pipefail
D=analysis/audit/2026-11-16-archs4-intero; OUT=analysis/input/geo-testi-archs4-2026-11-16
mkdir -p "$D/log" "$OUT"
for P in 0 1; do
  setsid nohup python3 -I "$D/11-scarica-geo.py" "$D/10-elenco.csv" analysis/audit/2026-11-09-lettore-studio/30-divisione.tsv \
    "$OUT" "$D/11-manifesto-geo-$P.tsv" "$D/11-falliti-$P.tsv" "$P" 2 >> "$D/log/scarico-$P.out" 2>&1 < /dev/null &
done
sleep 2; ps -eo pid,sid,args | grep "[1]1-scarica-geo.py"
