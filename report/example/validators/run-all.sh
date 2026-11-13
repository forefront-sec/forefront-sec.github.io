#!/bin/bash
# run-all — execute the Juice Shop finding-validation suite sequentially.
# Exit 0 = all checks ran (findings may be present) · 2 = rig error.
# --fail-on-present: exit 1 if any finding is still present (CI/retest gate).
# Safety: one request at a time; read-only except two labeled, reversible writes
# (F-04 test account, F-06 product description). ROE 2026-10-27.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
FAIL_ON_PRESENT=0
[ "${1:-}" = "--fail-on-present" ] && FAIL_ON_PRESENT=1

BASE="${BASE:-http://127.0.0.1:3000}"
UA="Forefront-Retest/1.0 (ROE 2026-10-27)"
export BASE
mkdir -p results
LOG="results/verify-$(date -u +%Y%m%dT%H%M%SZ).log"
: > "$LOG"
log(){ printf '%s\n' "$*" | tee -a "$LOG"; }

log "# Finding validation — $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
log "# Semantics: exit 0 = fixed/absent · 1 = finding present · 2 = rig error"
log "# Target: $BASE"
log ""

code=$(curl -sS --max-time 15 -A "$UA" -o /dev/null -w '%{http_code}' "$BASE/") \
  || { log "RIG ERROR: liveness request failed"; exit 2; }
case "$code" in 2*|3*) ;; *) log "RIG ERROR: liveness HTTP $code"; exit 2 ;; esac
log "liveness: HTTP $code"
log ""

present=0; absent=0; rig=0
for s in F-*.sh; do
  [ -f "$s" ] || continue
  id=$(printf '%s' "$s" | cut -d- -f1-2)
  out=$(bash "$s" 2>&1); rc=$?
  case "$rc" in
    0) status="FIXED";  absent=$((absent+1)) ;;
    1) status="PRESENT"; present=$((present+1)) ;;
    2) status="RIG-ERROR"; rig=$((rig+1)) ;;
    *) status="UNKNOWN($rc)"; rig=$((rig+1)) ;;
  esac
  log "$status  $id"
  printf '%s\n' "$out" | sed 's/^/    /' | tee -a "$LOG"
done

log ""
log "Summary: present=$present absent=$absent rig=$rig"
log "Log: $LOG"
[ "$rig" -gt 0 ] && exit 2
[ "$FAIL_ON_PRESENT" -eq 1 ] && [ "$present" -gt 0 ] && exit 1
exit 0
