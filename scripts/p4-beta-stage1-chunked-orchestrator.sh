#!/bin/bash
# scripts/p4-beta-stage1-chunked-orchestrator.sh
#
# β Task 10 chunked fullrun: submitta sequenzialmente N chunks da 10k record
# (uno alla volta, attende COMPLETED via sacct, poi passa al prossimo).
#
# Rationale: il fullrun monolitico a 888k record stalla post-microbatch 1 per
# bug vLLM scheduler data-dependent (caeb67 + cc1383, identica config dello
# smoke10k che PASSA). Chunkare in unità da 10k record = pari smoke10k, reset
# engine vLLM tra chunks, isolamento di chunk problematici.
#
# Resume-safe: lo script `p4-beta-stage1-fullrun.R` gia' short-circuita su slug
# esistente. Re-lanciare l'orchestrator riprende dal primo chunk non-COMPLETED.
#
# Usage:
#   nohup bash scripts/p4-beta-stage1-chunked-orchestrator.sh > /dev/null 2>&1 &
#   disown
#   tail -f analysis/p4-beta-chunked-orchestrator.log
#
# Env vars override (opzionale):
#   START=01  END=88  POLL=90

set -uo pipefail

PROJECT=/home/user/simulomicsr
cd "$PROJECT" || { echo "FATAL: cannot cd to $PROJECT"; exit 1; }

# SSH agent: per cron-style esecuzione headless, usa gnome-keyring socket
# (memoria feedback_user_logged_in_for_automation). L'utente DEVE essere
# loggato graficamente, altrimenti l'ssh fallisce per publickey.
export SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-/run/user/1000/keyring/ssh}"

CHUNKS_DIR=analysis/input/chunks
START=${START:-01}
END=${END:-88}
POLL=${POLL:-90}
DGX_USER=u0044
DGX_HOST=logindgx.hpc.ict.unipd.it
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=15"
LOG=analysis/p4-beta-chunked-orchestrator.log

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "$LOG"
}

log "=== orchestrator start: chunks $START..$END, poll=${POLL}s ==="

# Pad: seq -w produce 2-digit con padding zero
for n in $(seq -w "$START" "$END"); do
  CHUNK="$CHUNKS_DIR/chunk-$n.jsonl"
  SLUG="beta-stage1-chunk$n"
  if [ ! -f "$CHUNK" ]; then
    log "SKIP $SLUG: $CHUNK missing"
    continue
  fi

  log "--- chunk $n: submit $SLUG ---"
  # Submit (o resume-print se job_rds esiste gia' per questo slug).
  # Output cattura solo righe rilevanti.
  FULLRUN_INPUT="$CHUNK" FULLRUN_SLUG="$SLUG" \
    Rscript analysis/p4-beta-stage1-fullrun.R 2>&1 \
    | grep -E "Submitted|slurm_job_id|run_id|Records|Resume|slurm_state" \
    | tee -a "$LOG"

  JOB_RDS=$(ls -1t analysis/p4-output/*-${SLUG}-*-job.rds 2>/dev/null | head -1)
  if [ -z "$JOB_RDS" ]; then
    log "FATAL $SLUG: no job_rds found post-submit"
    exit 1
  fi

  SLURM_JID=$(Rscript --quiet -e 'cat(readRDS(commandArgs(TRUE)[1])$slurm_job_id)' \
    "$JOB_RDS" 2>/dev/null)
  if [ -z "$SLURM_JID" ]; then
    log "FATAL $SLUG: cannot extract slurm_job_id from $JOB_RDS"
    exit 1
  fi
  log "$SLUG slurm_job_id=$SLURM_JID  job_rds=$JOB_RDS"

  # Poll loop
  while :; do
    STATE=$(ssh $SSH_OPTS "${DGX_USER}@${DGX_HOST}" \
      "bash -lc 'sacct -j $SLURM_JID --format=State -P -n 2>/dev/null | head -1'" \
      2>/dev/null | tr -d '[:space:]')
    case "$STATE" in
      COMPLETED)
        log "$SLUG state=COMPLETED OK"
        break
        ;;
      FAILED|CANCELLED|CANCELLED+|TIMEOUT|NODE_FAIL|OUT_OF_MEMORY|BOOT_FAIL|DEADLINE|PREEMPTED)
        log "FATAL $SLUG state=$STATE -- orchestrator abort"
        exit 2
        ;;
      RUNNING|PENDING|CONFIGURING|REQUEUED|RESIZING|SUSPENDED|"")
        sleep "$POLL"
        ;;
      *)
        log "$SLUG state=$STATE (unrecognized, continuing poll)"
        sleep "$POLL"
        ;;
    esac
  done
done

log "=== orchestrator end: chunks $START..$END all COMPLETED ==="
