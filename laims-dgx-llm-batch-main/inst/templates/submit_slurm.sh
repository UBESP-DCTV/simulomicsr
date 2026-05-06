#!/bin/bash
# TEMPLATE ONLY
# Render this file before use. Replace __PLACEHOLDER__ values with concrete
# cluster-specific settings.

#SBATCH --job-name=__JOB_NAME__
#SBATCH --partition=__PARTITION__
#SBATCH --account=__ACCOUNT__
#SBATCH --nodelist=__NODELIST__
#SBATCH --nodes=__NODES__
__SBATCH_MAIL_USER__
__SBATCH_MAIL_TYPE__
#SBATCH --gres=gpu:__GPUS__
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=__CPUS__
#SBATCH --mem=__MEM__
#SBATCH --time=__TIME__
#SBATCH --output=__SLURM_OUTPUT_PATH__
#SBATCH --error=__SLURM_ERROR_PATH__

set -euo pipefail

module load singularity/4.2.0
module load slurm/slurm/23.02.7

echo "[INFO] Starting DGX LLM batch job"
echo "[INFO] Run dir: __RUN_PATH__"
echo "[INFO] Bundle: __BUNDLE_PATH__"
echo "[INFO] Output: __OUTPUT_PATH__"
echo "[INFO] Home: __HOME_PATH__"
echo "[INFO] HF cache: __HF_CACHE_PATH__"
echo "[INFO] SIF: __SIF_PATH__"

mkdir -p "__RUN_PATH__"
mkdir -p "__OUTPUT_PATH__"
mkdir -p "__HOME_PATH__"
mkdir -p "__HF_CACHE_PATH__"

# Match the known-good cluster-native launch pattern: execute Singularity via
# `srun` inside the existing allocation, while preserving the package-specific
# binds, status path, and runtime entrypoint.
srun __APPTAINER_BIN__ exec \
  --nv \
  --pwd "__CONTAINER_HOME__" \
  --env "HF_HOME=__CONTAINER_HF_CACHE__,TRANSFORMERS_CACHE=__CONTAINER_HF_CACHE__" \
  --bind "__HOME_PATH__:__CONTAINER_HOME__" \
  --bind "__RUN_PATH__:/work/run" \
  --bind "__BUNDLE_PATH__:/work/bundle" \
  --bind "__OUTPUT_PATH__:/work/output" \
  --bind "__HF_CACHE_PATH__:__CONTAINER_HF_CACHE__" \
  "__SIF_PATH__" \
  /bin/sh /opt/laims/runtime/bin/run-batch \
    --bundle /work/bundle \
    --output /work/output \
    --status-path /work/run/status.json

echo "[INFO] Job completed"
