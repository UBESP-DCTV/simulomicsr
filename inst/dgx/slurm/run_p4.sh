#!/bin/bash
# Template SLURM per run P4. I placeholder della forma "doppio-underscore-NOME-doppio-underscore"
# vengono sostituiti da R tramite .dgx_render_slurm_template().
#SBATCH --job-name=simulomicsr-p4-__RUN_ID_SHORT__
#SBATCH --partition=dgx12cluster
#SBATCH --account=dctv_dgx
#SBATCH --nodelist=poddgx02
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=200G
#SBATCH --gres=gpu:4
#SBATCH --time=__TIME__
#SBATCH --mail-user=__MAIL_USER__
#SBATCH --mail-type=ALL
#SBATCH --output=/mnt/home/__USER__/simulomicsr-dgx/runs/__RUN_ID__/slurm-%j.out
#SBATCH --error=/mnt/home/__USER__/simulomicsr-dgx/runs/__RUN_ID__/slurm-%j.err

set -euo pipefail

module load singularity/4.2.0
module load slurm/slurm/23.02.7

REMOTE_ROOT=/mnt/home/__USER__/simulomicsr-dgx
RUN_ID=__RUN_ID__

mkdir -p "$REMOTE_ROOT/runs/$RUN_ID" "$REMOTE_ROOT/models/HF_HOME"

# HF_TOKEN deve essere nell'environment (esportato da .simulomicsr-dgx.env
# o passato da R via sbatch --export=HF_TOKEN). Il sentinel check evita
# crash silenziosi al primo download del modello.
if [ -z "${HF_TOKEN:-}" ]; then
    echo "[WARN] HF_TOKEN non settato. Modelli gated potrebbero fallire al download." >&2
fi

echo "[INFO] Run ID: $RUN_ID"
echo "[INFO] Node: $(hostname)"
echo "[INFO] Job ID: $SLURM_JOB_ID"
echo "[INFO] Workdir: $REMOTE_ROOT"

SINGULARITY_BIN=/cm/shared/apps/singularity/4.2.0/bin/singularity

srun "$SINGULARITY_BIN" exec \
  --nv \
  --bind "$REMOTE_ROOT/bundles/$RUN_ID:/work/bundle" \
  --bind "$REMOTE_ROOT/runs/$RUN_ID:/work/run" \
  --bind "$REMOTE_ROOT/models/HF_HOME:/work/models/HF_HOME" \
  --env "HF_TOKEN=${HF_TOKEN:-}" \
  "$REMOTE_ROOT/runtime/simulomicsr-vllm.sif" \
  python3 /opt/simulomicsr/runtime/python/run_p4_vllm.py \
    --bundle /work/bundle --output /work/run --workers 4

echo "[INFO] Job completed"
