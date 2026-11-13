#!/bin/bash
# F-08 — Verbose error pages exposing stack traces / SQL errors
# Exit 0 = finding present · 1 = absent/fixed · 2 = rig error
# Safety: one malformed GET, read-only. ROE 2026-10-27.
set -u
BASE="${BASE:-http://127.0.0.1:3000}"
UA="Forefront-Retest/1.0 (ROE 2026-10-27)"

code=$(curl -sS --max-time 15 -A "$UA" -o /dev/null -w '%{http_code}' "$BASE/") \
  || { echo "RIG ERROR: liveness GET / failed"; exit 2; }
case "$code" in 2*|3*) ;; *) echo "RIG ERROR: liveness HTTP $code"; exit 2 ;; esac

body=$(curl -sS --max-time 15 -A "$UA" --get \
  --data-urlencode "q='))" "$BASE/rest/products/search") \
  || { echo "RIG ERROR: request failed"; exit 2; }

if printf '%s' "$body" | grep -qiE 'SQLITE_ERROR|Sequelize|at Object\.|node_modules'; then
  echo "PRESENT: verbose error details returned to the client"
  exit 1
fi
echo "ABSENT: generic error handling"
exit 0
