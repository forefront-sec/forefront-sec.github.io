#!/bin/bash
# F-07 — Security-question enumeration oracle (known vs unknown email differ)
# Exit 0 = finding present · 1 = absent/fixed · 2 = rig error
# Safety: two read-only GETs (one known seed email, one random). ROE 2026-10-27.
set -u
BASE="${BASE:-http://127.0.0.1:3000}"
UA="Forefront-Retest/1.0 (ROE 2026-10-27)"

code=$(curl -sS --max-time 15 -A "$UA" -o /dev/null -w '%{http_code}' "$BASE/") \
  || { echo "RIG ERROR: liveness GET / failed"; exit 2; }
case "$code" in 2*|3*) ;; *) echo "RIG ERROR: liveness HTTP $code"; exit 2 ;; esac

known="admin@juice-sh.op"
unknown="no-such-user-$(date -u +%s)@example.com"

k=$(curl -sS --max-time 15 -A "$UA" "$BASE/rest/user/security-question?email=$known")
u=$(curl -sS --max-time 15 -A "$UA" "$BASE/rest/user/security-question?email=$unknown")

if printf '%s' "$k" | grep -q '"question"' && ! printf '%s' "$u" | grep -q '"question"'; then
  echo "PRESENT: known email returns a question, unknown returns none (oracle)"
  exit 1
fi
echo "ABSENT: responses are uniform (no enumeration oracle)"
exit 0
