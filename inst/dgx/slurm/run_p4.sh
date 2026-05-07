#!/bin/bash
# Template SLURM per run P4. I placeholder della forma "doppio underscore
# NOME doppio underscore" vengono sostituiti da .dgx_render_slurm_template()
# in R/dgx-utils.R.
#
# Path: /home/<user>/ NON /mnt/home/<user>/ — i compute UniPD HPC
# (poddgx01/02/03) non montano /mnt/home/. Verificato col probe job 19720
# il 2026-05-07 su poddgx03.
#
# Esecuzione singularity: diretta, NO srun (allineato a smoke_1gpu.sh
# validato col job 19723 il 2026-05-07).
#SBATCH --job-name=simulomicsr-p4-__RUN_ID_SHORT__
#SBATCH --partition=dgx12cluster
#SBATCH --account=dctv_dgx
__NODELIST_DIRECTIVE__
#SBATCH --export=NONE
#SBATCH --chdir=/home/__USER__
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=200G
#SBATCH --gres=gpu:4
#SBATCH --time=__TIME__
#SBATCH --mail-user=__MAIL_USER__
#SBATCH --mail-type=ALL
#SBATCH --output=/home/__USER__/simulomicsr-dgx/runs/__RUN_ID__/slurm-%j.out
#SBATCH --error=/home/__USER__/simulomicsr-dgx/runs/__RUN_ID__/slurm-%j.err

set -euo pipefail

module load singularity/4.2.0
module load slurm/slurm/23.02.7

# --export=NONE blocca env inheritance dal login (necessario per evitare
# che SBATCH_PARTITION del login override la partition richiesta). Quindi
# HF_TOKEN va sourcato esplicitamente qui.
[ -f ~/.simulomicsr-dgx.env ] && . ~/.simulomicsr-dgx.env

REMOTE_ROOT=/home/__USER__/simulomicsr-dgx
RUN_ID=__RUN_ID__

mkdir -p "$REMOTE_ROOT/runs/$RUN_ID" "$REMOTE_ROOT/models/HF_HOME"

if [ -z "${HF_TOKEN:-}" ]; then
    echo "[WARN] HF_TOKEN non settato. Modelli gated potrebbero fallire al download (a meno che HF cache non sia gia' popolata)." >&2
fi

echo "[INFO] Run ID: $RUN_ID"
echo "[INFO] Node: $(hostname)"
echo "[INFO] Job ID: $SLURM_JOB_ID"
echo "[INFO] Workdir: $REMOTE_ROOT"

SINGULARITY_BIN=/cm/shared/apps/singularity/4.2.0/bin/singularity

"$SINGULARITY_BIN" exec \
  --nv \
  --bind /home/__USER__:/home/__USER__ \
  --bind "$REMOTE_ROOT/bundles/$RUN_ID:/work/bundle" \
  --bind "$REMOTE_ROOT/runs/$RUN_ID:/work/run" \
  --bind "$REMOTE_ROOT/models/HF_HOME:/work/models/HF_HOME" \
  --bind "$REMOTE_ROOT/runtime/python:/opt/simulomicsr/runtime/python" \
  --env "HF_TOKEN=${HF_TOKEN:-}" \
  --env "HF_HOME=/work/models/HF_HOME" \
  --env "TRANSFORMERS_CACHE=/work/models/HF_HOME" \
  "$REMOTE_ROOT/runtime/simulomicsr-vllm.sif" \
  python3 /opt/simulomicsr/runtime/python/run_p4_vllm.py \
    --bundle /work/bundle --output /work/run --workers 4

echo "[INFO] Job completed"
