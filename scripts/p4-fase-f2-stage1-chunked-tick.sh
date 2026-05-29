#!/bin/bash
# scripts/p4-fase-f2-stage1-chunked-tick.sh
#
# RED ALERT FASE F2: orchestrator chunked per il fullrun Stadio 1 sul
# bacino v2 (508.037 sample, 51 chunk mainstream). Variante del tick beta
# (scripts/p4-beta-stage1-chunked-tick.sh) con path/slug/state SEPARATI:
# NON tocca alcun artefatto beta.
#
# Una transizione di stato per invocazione. Idempotente. Cron ogni 3 min.
#   - chunk corrente senza job_rds  -> submit
#   - RUNNING/PENDING               -> wait next tick
#   - COMPLETED                     -> avanza + submit immediato (cascade)
#   - FAILED/CANCELLED/...          -> HALT (intervento operatore)
#
# Config INVARIATA (dgx_config(): temp=0, rep_pen=1.1, max_model_len=4096,
# microbatch=500). Lo script di submit e' lo stesso del beta
# (analysis/p4-beta-stage1-fullrun.R), parametrizzato via FULLRUN_INPUT /
# FULLRUN_SLUG.
#
# State machine: analysis/p4-fase-f2-chunked-state.txt (int = chunk 0..50).

set -uo pipefail

PROJECT=/home/user/simulomicsr
cd "$PROJECT" || exit 1

export SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-/run/user/1000/keyring/ssh}"

CHUNKS_DIR=analysis/input/v2-chunks
TOTAL_CHUNKS=51
LAST_IDX=$((TOTAL_CHUNKS - 1))
DGX_USER=u0044
DGX_HOST=logindgx.hpc.ict.unipd.it
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=15"
LOG=analysis/p4-fase-f2-chunked-orchestrator.log
STATE_FILE=analysis/p4-fase-f2-chunked-state.txt
LOCKFILE=/tmp/p4-fase-f2-chunked-orchestrator.lock
MAX_ITER=3

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$LOG"
}

exec 9>"$LOCKFILE"
if ! flock -n 9; then
  log "tick: lock busy, skip"
  exit 0
fi

[ -f "$STATE_FILE" ] || echo 0 > "$STATE_FILE"

# do_step: 0=ADVANCED 1=STOP 2=FATAL
do_step() {
  local CURR N SLUG CHUNK JOB_RDS SLURM_JID STATE
  CURR=$(cat "$STATE_FILE")

  if [ "$CURR" -gt "$LAST_IDX" ]; then
    log "tick: all $TOTAL_CHUNKS chunks COMPLETED. Idle."
    return 1
  fi

  N=$(printf "%02d" "$CURR")
  SLUG="f2-stage1-chunk$N"
  CHUNK="$CHUNKS_DIR/chunk-$N.jsonl"

  if [ ! -f "$CHUNK" ]; then
    log "tick: chunk $N: input $CHUNK MISSING -- HALT"
    return 2
  fi

  JOB_RDS=$(ls -1t analysis/p4-output/*-${SLUG}-*-job.rds 2>/dev/null | head -1)

  if [ -z "$JOB_RDS" ]; then
    log "tick: chunk $N: no job_rds, submitting..."
    FULLRUN_INPUT="$CHUNK" FULLRUN_SLUG="$SLUG" \
      Rscript analysis/p4-beta-stage1-fullrun.R >> "$LOG" 2>&1
    JOB_RDS=$(ls -1t analysis/p4-output/*-${SLUG}-*-job.rds 2>/dev/null | head -1)
    if [ -z "$JOB_RDS" ]; then
      log "tick: chunk $N: SUBMIT FAILED -- HALT"
      return 2
    fi
    SLURM_JID=$(Rscript --vanilla -e 'cat(readRDS(commandArgs(TRUE)[1])$slurm_job_id)' \
      "$JOB_RDS" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    log "tick: chunk $N: SUBMITTED slurm=$SLURM_JID job_rds=$JOB_RDS"
    return 1
  fi

  SLURM_JID=$(Rscript --vanilla -e 'cat(readRDS(commandArgs(TRUE)[1])$slurm_job_id)' \
    "$JOB_RDS" 2>/dev/null | grep -oE '[0-9]+' | head -1)
  if [ -z "$SLURM_JID" ]; then
    log "tick: chunk $N: cannot extract slurm_job_id from $JOB_RDS -- HALT"
    return 2
  fi

  STATE=$(ssh $SSH_OPTS "${DGX_USER}@${DGX_HOST}" \
    "bash -lc 'sacct -j $SLURM_JID --format=State -P -n 2>/dev/null | head -1'" \
    2>/dev/null | tr -d '[:space:]')

  case "$STATE" in
    COMPLETED)
      log "tick: chunk $N: COMPLETED (slurm=$SLURM_JID), advance to $((CURR+1))"
      echo $((CURR + 1)) > "$STATE_FILE"
      return 0
      ;;
    FAILED|CANCELLED|CANCELLED+|TIMEOUT|NODE_FAIL|OUT_OF_MEMORY|BOOT_FAIL|DEADLINE|PREEMPTED)
      log "tick: chunk $N: state=$STATE (slurm=$SLURM_JID) -- HALT"
      return 2
      ;;
    RUNNING|PENDING|CONFIGURING|REQUEUED|RESIZING|SUSPENDED|"")
      log "tick: chunk $N: state=$STATE (slurm=$SLURM_JID), waiting"
      return 1
      ;;
    *)
      log "tick: chunk $N: state=$STATE UNKNOWN (slurm=$SLURM_JID), waiting"
      return 1
      ;;
  esac
}

for i in $(seq 1 "$MAX_ITER"); do
  do_step
  rc=$?
  case $rc in
    0) continue ;;
    1) exit 0 ;;
    2) exit 2 ;;
  esac
done

log "tick: hit MAX_ITER=$MAX_ITER cascade cap, stop"
exit 0
