#!/bin/bash
# Smoke test 1-GPU forzando poddgx02. Identico a smoke_1gpu.sh con
# l'aggiunta di --nodelist=poddgx02. Se poddgx02 e' in DRAIN/DOWN il
# job resta PENDING; usa squeue per vedere il Reason.
#SBATCH --job-name=simulomicsr_smoke02
#SBATCH --partition=dgx12cluster
#SBATCH --account=dctv_dgx
#SBATCH --nodelist=poddgx02
#SBATCH --output=/home/u0044/simulomicsr-dgx/logs/slurm-%x_%j.out
#SBATCH --error=/home/u0044/simulomicsr-dgx/logs/slurm-%x_%j.err
#SBATCH --export=NONE
#SBATCH --chdir=/home/u0044
#SBATCH --mail-user=luca.vedovelli@unipd.it
#SBATCH --mail-type=ALL
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --gres=gpu:1
#SBATCH --time=01:00:00

set -euo pipefail

module load singularity/4.2.0
module load slurm/slurm/23.02.7

[ -f ~/.simulomicsr-dgx.env ] && . ~/.simulomicsr-dgx.env

WORKDIR=/home/u0044/simulomicsr-dgx
CONTAINER=${WORKDIR}/runtime/simulomicsr-vllm.sif
SINGULARITY=/cm/shared/apps/singularity/4.2.0/bin/singularity

BIND_ARGS=(
    -B /home/u0044:/home/u0044
    -B "${WORKDIR}/models/HF_HOME:/work/models/HF_HOME"
    -B "${WORKDIR}/runtime/python:/opt/simulomicsr/runtime/python"
)

run_in_container() {
    "${SINGULARITY}" exec --nv \
        "${BIND_ARGS[@]}" \
        --env "HF_TOKEN=${HF_TOKEN:-}" \
        --env "HF_HOME=/work/models/HF_HOME" \
        --env "TRANSFORMERS_CACHE=/work/models/HF_HOME" \
        "${CONTAINER}" "$@"
}

echo "=== SIMULOMICSR SMOKE 1-GPU (poddgx02 forced) ==="
echo "Date: $(date)"
echo "Node: $(hostname)"
echo "Job: ${SLURM_JOB_ID}"
echo "Workdir: ${WORKDIR}"
echo ""

[ ! -f "${CONTAINER}" ] && { echo "FAIL: container ${CONTAINER} non trovato"; exit 1; }

echo "=== Step 1: nvidia-smi host ==="
nvidia-smi || { echo "FAIL nvidia-smi host"; exit 1; }
echo ""

echo "=== Step 2: nvidia-smi container ==="
run_in_container nvidia-smi || { echo "FAIL nvidia-smi container"; exit 1; }
echo ""

echo "=== Step 3: torch+cuda ==="
run_in_container python3 -c "import torch; print('torch:', torch.__version__); print('cuda:', torch.cuda.is_available()); print('device:', torch.cuda.get_device_name(0))" || { echo "FAIL torch"; exit 1; }
echo ""

echo "=== Step 4: vllm import ==="
run_in_container python3 -c "from vllm import LLM, SamplingParams; print('vllm import OK')" || { echo "FAIL vllm import"; exit 1; }
echo ""

echo "=== Step 5: Mistral-Small-3.2 load + 1 prompt ==="
run_in_container python3 /opt/simulomicsr/runtime/python/smoke_vllm.py || { echo "FAIL smoke_vllm.py"; exit 1; }
echo ""

echo "=== SMOKE OK ==="
echo "Date: $(date)"
