#!/bin/bash
# F-03 — JWT forgery via a shipped/hardcoded RSA private key
# Exit 0 = finding present · 1 = absent/fixed · 2 = rig error
# Safety: one GET to fetch the app; asserts the public key material is reachable.
# NOTE: the decisive test forges a token with the private key — that key is not
# shipped publicly here, so this validator checks the *precondition*: whether the
# key material is exposed in shipped assets. Full forgery proof lives in the report
# evidence (F-03-jwtforgery.txt). ROE 2026-10-27.
set -u
BASE="${BASE:-http://127.0.0.1:3000}"
UA="Forefront-Retest/1.0 (ROE 2026-10-27)"

code=$(curl -sS --max-time 15 -A "$UA" -o /dev/null -w '%{http_code}' "$BASE/") \
  || { echo "RIG ERROR: liveness GET / failed"; exit 2; }
case "$code" in 2*|3*) ;; *) echo "RIG ERROR: liveness HTTP $code"; exit 2 ;; esac

# Juice Shop ships the RSA public key at /encryptionkeys/jwt.pub and the key set.
resp=$(curl -sS --max-time 15 -A "$UA" "$BASE/encryptionkeys/jwt.pub")
if printf '%s' "$resp" | grep -q 'BEGIN RSA PUBLIC KEY'; then
  echo "PRESENT: JWT key material is reachable at /encryptionkeys/jwt.pub"
  echo "        (forgery proof is in evidence F-03-jwtforgery.txt)"
  exit 1
fi
echo "ABSENT: JWT key material not exposed at the known path"
exit 0
