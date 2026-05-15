#!/bin/bash
# scripts/p4-beta-stage1-chunked-tick.sh
#
# Una transizione di stato dell'orchestrator chunked. Idempotente. Da
# invocare via cron ogni 3 min. Avanza UNO chunk alla volta:
#
#   - se chunk corrente non ha job_rds -> submit
#   - se ha job_rds e SLURM state RUNNING/PENDING -> wait next tick
#   - se COMPLETED -> avanza al chunk successivo + submit immediato in
#     stessa esecuzione (cascade, evita 3min di idle tra chunk e chunk)
#   - se FAILED/CANCELLED/etc -> HALT (operator intervention)
#
# State machine persistita in analysis/p4-beta-chunked-state.txt
# (singolo int = chunk corrente, 0..88).
#
# Lock-protected via flock per prevenire run concorrenti.

set -uo pipefail

PROJECT=/home/user/simulomicsr
cd "$PROJECT" || exit 1

# SSH agent (gnome-keyring; persiste finche' utente loggato graficamente)
export SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-/run/user/1000/keyring/ssh}"

CHUNKS_DIR=analysis/input/chunks
TOTAL_CHUNKS=89
LAST_IDX=$((TOTAL_CHUNKS - 1))
DGX_USER=u0044
DGX_HOST=logindgx.hpc.ict.unipd.it
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=15"
LOG=analysis/p4-beta-chunked-orchestrator.log
STATE_FILE=analysis/p4-beta-chunked-state.txt
LOCKFILE=/tmp/p4-beta-chunked-orchestrator.lock
MAX_ITER=3   # cap iterations per tick invocation

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$LOG"
}

# Lock: un tick alla volta
exec 9>"$LOCKFILE"
if ! flock -n 9; then
  log "tick: lock busy, skip"
  exit 0
fi

# Init state se non esiste
[ -f "$STATE_FILE" ] || echo 0 > "$STATE_FILE"

# do_step: ritorna codice strutturato
#   0 = ADVANCED (chunk completato, caller puo' iterare)
#   1 = STOP (submitted/waiting/done/halt) caller exit
#   2 = FATAL halt
do_step() {
  local CURR N SLUG CHUNK JOB_RDS SLURM_JID STATE
  CURR=$(cat "$STATE_FILE")

  if [ "$CURR" -gt "$LAST_IDX" ]; then
    log "tick: all $TOTAL_CHUNKS chunks COMPLETED. Idle."
    return 1
  fi

  N=$(printf "%02d" "$CURR")
  SLUG="beta-stage1-chunk$N"
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

# Loop: cascade fino a STOP/HALT (max MAX_ITER per tick)
for i in $(seq 1 "$MAX_ITER"); do
  do_step
  rc=$?
  case $rc in
    0) continue ;;                  # ADVANCED -> retry (submit next chunk)
    1) exit 0 ;;                    # STOP normale
    2) exit 2 ;;                    # FATAL
  esac
done

log "tick: hit MAX_ITER=$MAX_ITER cascade cap, stop"
exit 0
