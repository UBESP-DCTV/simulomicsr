#!/bin/bash
# 05-scarica-pesi.sh — scarica sul DGX i pesi dei modelli candidati a secondo lettore, a revisione fissata.
# Gira sul nodo di login (non chiede GPU). I pesi vanno nella cache che il job monta nel contenitore
# (/home/u0044/simulomicsr-dgx/models/HF_HOME): il job monta solo /home, quindi il disco di gruppo non si usa qui.
# Il token di Hugging Face si legge da ~/.simulomicsr-dgx.env e passa per l'ambiente: non si stampa.
# Uso sul DGX:  setsid nohup bash 05-scarica-pesi.sh "modello revisione" ... > scarico.log 2>&1 < /dev/null &
set -u
ROOT=/home/u0044/simulomicsr-dgx
set -a; [ -f ~/.simulomicsr-dgx.env ] && . ~/.simulomicsr-dgx.env; set +a
SING=/cm/shared/apps/singularity/4.2.0/bin/singularity
for spec in "$@"; do
  set -- $spec; modello=$1; rev=$2
  echo "[$(date +%H:%M:%S)] inizio $modello @ $rev"
  "$SING" exec --bind "$ROOT/models/HF_HOME:/work/models/HF_HOME" --env "HF_HOME=/work/models/HF_HOME" \
    "$ROOT/runtime/simulomicsr-vllm.sif" hf download "$modello" --revision "$rev" > /dev/null
  echo "[$(date +%H:%M:%S)] fine $modello, uscita $?, spazio: $(du -sh "$ROOT/models/HF_HOME/hub/models--${modello//\//--}" 2>/dev/null | cut -f1)"
done
echo "SCARICO FINITO"
