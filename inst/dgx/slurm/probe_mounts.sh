#!/bin/bash
# Probe minimale: mappa i filesystem visibili dal compute node + verifica GPU.
# Niente container, niente vLLM. Output va in /home/u0044/... (come scRNA_DGX),
# perche' /mnt/home/u0044/ non e' visibile da tutti i compute (es. poddgx01).
#
# Submit:
#   sbatch /home/u0044/simulomicsr-dgx-probe/probe_mounts.sh
#SBATCH --job-name=simulomicsr_probe
#SBATCH --partition=dgx12cluster
#SBATCH --account=dctv_dgx
#SBATCH --output=/home/u0044/simulomicsr-dgx-probe/slurm-%x_%j.out
#SBATCH --error=/home/u0044/simulomicsr-dgx-probe/slurm-%x_%j.err
#SBATCH --export=NONE
#SBATCH --chdir=/home/u0044
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --gres=gpu:1
#SBATCH --time=00:05:00

echo "=== PROBE START ==="
echo "Date: $(date)"
echo "Node: $(hostname)"
echo "Job: ${SLURM_JOB_ID:-na}"
echo "PWD: $(pwd)"
echo ""

echo "=== Mount probe ==="
echo "--- /home/u0044 ---"
ls -la /home/u0044 2>&1 | head -10
echo ""
echo "--- /mnt/home/u0044 ---"
ls -la /mnt/home/u0044 2>&1 | head -10
echo ""
echo "--- /mnt/projects/dctv/dgx ---"
ls -la /mnt/projects/dctv/dgx 2>&1 | head -10
echo ""
echo "--- /mnt/projects/dctv/dgx/u0044 (se esiste) ---"
ls -la /mnt/projects/dctv/dgx/u0044 2>&1 | head -10
echo ""
echo "--- mountpoint -q test ---"
for p in /home /mnt/home /mnt/projects /mnt/projects/dctv /mnt/projects/dctv/dgx ; do
  if [ -d "$p" ]; then echo "  $p: EXISTS" ; else echo "  $p: MISSING" ; fi
done
echo ""

echo "=== GPU host ==="
nvidia-smi || echo "FAIL nvidia-smi"
echo ""

echo "=== Singularity bin ==="
ls -la /cm/shared/apps/singularity/4.2.0/bin/singularity 2>&1
which singularity 2>&1 || true
echo ""

echo "=== SIF candidates ==="
for p in /home/u0044/simulomicsr-dgx/runtime/simulomicsr-vllm.sif \
         /mnt/home/u0044/simulomicsr-dgx/runtime/simulomicsr-vllm.sif \
         /mnt/projects/dctv/dgx/u0044/simulomicsr-dgx/runtime/simulomicsr-vllm.sif ; do
  if [ -f "$p" ]; then echo "  FOUND: $p ($(du -h "$p" | cut -f1))"; else echo "  miss : $p"; fi
done

echo ""
echo "=== PROBE OK ==="
