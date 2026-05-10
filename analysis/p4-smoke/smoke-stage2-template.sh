#!/bin/bash
# Template SLURM per smoke test stage2 parametrizzato (Task 22 investigation).
# Placeholder doppio-underscore-NOME-doppio-underscore sostituiti dallo wrapper
# analysis/p4-smoke/run-smoke-stage2.R via .dgx_render_slurm_template().
# Differenze vs inst/dgx/slurm/run_p4.sh:
#   - GPUS / WORKERS configurabili
#   - TIME limit corto (default 1h, smoke deve fallire/passare in pochi min)
#   - mail-type=END (no FAIL spam durante investigation iterativa)
#SBATCH --job-name=smoke-stage2-__RUN_ID_SHORT__
#SBATCH --partition=dgx12cluster
#SBATCH --account=dctv_dgx
__NODELIST_DIRECTIVE__
#SBATCH --export=NONE
#SBATCH --chdir=/home/__USER__
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=__CPUS__
#SBATCH --mem=__MEM__
#SBATCH --gres=gpu:__GPUS__
#SBATCH --time=__TIME__
#SBATCH --mail-user=__MAIL_USER__
#SBATCH --mail-type=END
#SBATCH --output=/home/__USER__/simulomicsr-dgx/runs/__RUN_ID__/slurm-%j.out
#SBATCH --error=/home/__USER__/simulomicsr-dgx/runs/__RUN_ID__/slurm-%j.err

set -euo pipefail

module load singularity/4.2.0
module load slurm/slurm/23.02.7

[ -f ~/.simulomicsr-dgx.env ] && . ~/.simulomicsr-dgx.env

REMOTE_ROOT=/home/__USER__/simulomicsr-dgx
RUN_ID=__RUN_ID__

mkdir -p "$REMOTE_ROOT/runs/$RUN_ID" "$REMOTE_ROOT/models/HF_HOME"

if [ -z "${HF_TOKEN:-}" ]; then
    echo "[WARN] HF_TOKEN non settato." >&2
fi

echo "[INFO] Run ID: $RUN_ID"
echo "[INFO] Node: $(hostname)"
echo "[INFO] Job ID: $SLURM_JOB_ID"
echo "[INFO] Workers: __WORKERS__  GPUs: __GPUS__"

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
    --bundle /work/bundle --output /work/run --workers __WORKERS__

echo "[INFO] Job completed"
