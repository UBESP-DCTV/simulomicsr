#!/usr/bin/env bash
# Catena della sessione S5, dalla radice del repository. Si ferma al primo errore.
set -e
E=analysis/audit/2026-11-03-S5-gate-e-insiemi
export WORKERS=48
Rscript $E/20-fit-bracci.R > $E/20-out.txt 2>&1
Rscript $E/30-rem-k2.R > $E/30-out.txt 2>&1
Rscript $E/35-riproduzione-194.R > $E/35-out.txt 2>&1
Rscript $E/40-incertezza.R > $E/40-out.txt 2>&1
Rscript $E/42-controllo-positivo.R > $E/42-out.txt 2>&1
echo CATENA-FINITA > $E/catena-esito.txt
