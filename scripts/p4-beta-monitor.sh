#!/bin/bash
# P4 β cron monitor — generates log file readable on-demand.
# Setup: crontab -e
#   0 */2 * * * /home/user/simulomicsr/scripts/p4-beta-monitor.sh >> /home/user/simulomicsr/analysis/p4-beta-monitor.log 2>&1

set -uo pipefail
TS=$(date -u "+%Y-%m-%dT%H:%M:%SZ")
echo "==== [$TS] P4 β monitor ===="

# squeue snapshot
echo "-- SLURM jobs --"
ssh -o BatchMode=yes dgx 'bash -lc "squeue -u u0044 --format=\"%A %j %T %M %l\""' 2>&1 || \
  echo "[ATTENTION] ssh failed"

# Latest slurm.out tail per job attivo
echo "-- Last slurm.out tail (50 lines) --"
ssh -o BatchMode=yes dgx 'bash -lc "tail -50 ~/p4-beta/slurm-*.out 2>/dev/null | head -200"' 2>&1 || \
  echo "[no slurm.out yet]"

# Conta record nei JSONL output corrente (live throughput)
echo "-- Output JSONL line count --"
ssh -o BatchMode=yes dgx 'bash -lc "for f in ~/p4-beta/output/*/predictions.jsonl; do echo \"\$f: \$(wc -l < \$f) lines\"; done"' 2>&1 || \
  echo "[no output yet]"

echo ""
