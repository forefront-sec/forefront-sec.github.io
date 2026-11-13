# Finding validation suite — OWASP Juice Shop worked example

Safe, re-runnable checks for the eight findings in the
[Juice Shop worked example](https://forefrontsecurity.ai/report/example/),
run against a stock OWASP Juice Shop instance. Each script tests one finding and exits:

- **0** = fixed / absent (the fix landed)
- **1** = finding still present (vulnerable)
- **2** = rig error (could not determine)

This is the same validator-pack convention every Forefront report ships.

## Usage

```bash
BASE=http://127.0.0.1:3000 ./run-all.sh          # report all findings
BASE=http://127.0.0.1:3000 ./run-all.sh --fail-on-present
```

Or run a single check:

```bash
BASE=http://127.0.0.1:3000 ./F-04-bola.sh
```

## Safety

- One request at a time; non-destructive except two labeled, reversible state changes:
  - **F-04** creates one throwaway low-priv account (unique email) to prove the BOLA.
  - **F-06** performs one unauthenticated PUT on product 1's description, then restores it.
- Only run these against a target you own or are authorized to test. The default target is a
  local Juice Shop instance (`127.0.0.1:3000`).

## Known limitation

**F-03** checks the *precondition* (JWT key material reachable at `/encryptionkeys/jwt.pub`).
The full forgery proof lives in `../evidence/F-03-jwtforgery.txt`; reproducing it requires the
private key, which is not distributed with this example.
