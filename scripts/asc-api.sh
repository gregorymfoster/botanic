#!/usr/bin/env bash
#
# Minimal App Store Connect API client.
# Signs an ES256 JWT with openssl (no PyJWT/cryptography needed) and calls the API.
#
# Usage:
#   ASC_KEY_ID=XXX ASC_ISSUER_ID=YYY ASC_KEY_PATH=/path/AuthKey_XXX.p8 \
#     ./asc-api.sh GET  /v1/apps
#   ./asc-api.sh POST  /v1/bundleIds '{"data":{...}}'
#   ./asc-api.sh PATCH /v1/appStoreVersions/ID '@body.json'   # @file reads from disk
#
# Env (all required unless a default works for you):
#   ASC_KEY_ID       App Store Connect API key id (the XXX in AuthKey_XXX.p8)
#   ASC_ISSUER_ID    Issuer id from Users and Access > Integrations > App Store Connect API
#   ASC_KEY_PATH     Path to the .p8 private key (keep it OUT of the repo)
#
# Prints the raw JSON response to stdout. Pipe through `jq`.
set -euo pipefail

KEY_ID="${ASC_KEY_ID:?set ASC_KEY_ID}"
ISSUER_ID="${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
KEY_PATH="${ASC_KEY_PATH:?set ASC_KEY_PATH to the AuthKey_*.p8 file}"

[[ -f "$KEY_PATH" ]] || { echo "Key not found: $KEY_PATH" >&2; exit 1; }

b64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '='; }

now=$(date +%s); exp=$((now + 1100))   # ASC rejects tokens with lifetime > 20 min
header=$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$KEY_ID" | b64url)
payload=$(printf '{"iss":"%s","iat":%d,"exp":%d,"aud":"appstoreconnect-v1"}' "$ISSUER_ID" "$now" "$exp" | b64url)
signing_input="${header}.${payload}"

# openssl emits a DER ECDSA signature; JOSE needs raw r||s (64 bytes). Convert in python.
sig_der=$(printf '%s' "$signing_input" | openssl dgst -sha256 -sign "$KEY_PATH" | openssl base64 -e -A)
sig=$(python3 - "$sig_der" <<'PY'
import sys, base64
der = base64.b64decode(sys.argv[1])
assert der[0] == 0x30
i = 2
assert der[i] == 0x02; i += 1
rlen = der[i]; i += 1; r = der[i:i+rlen]; i += rlen
assert der[i] == 0x02; i += 1
slen = der[i]; i += 1; s = der[i:i+slen]
r = r.lstrip(b'\x00').rjust(32, b'\x00')
s = s.lstrip(b'\x00').rjust(32, b'\x00')
print(base64.urlsafe_b64encode(r + s).decode().rstrip('='))
PY
)
JWT="${signing_input}.${sig}"

METHOD="${1:-GET}"
PATHQ="${2:?usage: asc-api.sh METHOD /v1/path [json-body-or-@file]}"
BODY="${3:-}"

args=(-sS -X "$METHOD" "https://api.appstoreconnect.apple.com${PATHQ}" -H "Authorization: Bearer ${JWT}")
[[ -n "$BODY" ]] && args+=(-H "Content-Type: application/json" -d "$BODY")
curl "${args[@]}"
