#!/bin/bash
# F-05 — Password hash embedded in every issued JWT
# Exit 0 = finding present · 1 = absent/fixed · 2 = rig error
# Safety: one login with a throwaway account; decodes (does not crack) the token payload.
# ROE 2026-10-27.
set -u
BASE="${BASE:-http://127.0.0.1:3000}"
UA="Forefront-Retest/1.0 (ROE 2026-10-27)"
EMAIL="f05-retest-$(date -u +%s)@example.com"
PASS="Retest1!pass"

code=$(curl -sS --max-time 15 -A "$UA" -o /dev/null -w '%{http_code}' "$BASE/") \
  || { echo "RIG ERROR: liveness GET / failed"; exit 2; }
case "$code" in 2*|3*) ;; *) echo "RIG ERROR: liveness HTTP $code"; exit 2 ;; esac

curl -sS --max-time 15 -A "$UA" -X POST "$BASE/api/Users" \
  -H 'Content-Type: application/json' \
  --data "{\"email\":\"$EMAIL\",\"password\":\"$PASS\",\"passwordRepeat\":\"$PASS\",\"securityQuestion\":{\"id\":1},\"securityAnswer\":\"x\"}" \
  -o /dev/null || { echo "RIG ERROR: account creation failed"; exit 2; }

login=$(curl -sS --max-time 15 -A "$UA" -X POST "$BASE/rest/user/login" \
  -H 'Content-Type: application/json' \
  --data "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}") \
  || { echo "RIG ERROR: login failed"; exit 2; }

token=$(printf '%s' "$login" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
[ -n "$token" ] || { echo "RIG ERROR: no token"; exit 2; }

payload=$(printf '%s' "$token" | cut -d. -f2 | tr '_-' '/+')
# pad base64
case $(( ${#payload} % 4 )) in 2) payload="$payload==" ;; 3) payload="$payload=" ;; esac
decoded=$(printf '%s' "$payload" | base64 -d 2>/dev/null)

if printf '%s' "$decoded" | grep -qi '"password"'; then
  echo "PRESENT: JWT payload contains a password field (hash leak)"
  exit 1
fi
echo "ABSENT: JWT payload has no password field"
exit 0
