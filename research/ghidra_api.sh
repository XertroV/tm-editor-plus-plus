#!/usr/bin/env bash
# Helper: query the ghidra-mcp HTTP API on remote host (via SSH tunnel :18742).
# Usage: ghidra_api.sh GET /endpoint 'k=v&k2=v2'
#        ghidra_api.sh POST /endpoint '{"json":"body"}'
set -euo pipefail
BASE="${GHIDRA_API_BASE:-http://127.0.0.1:18742}"
method="$1"; path="$2"; data="${3:-}"
if [[ "$method" == "GET" ]]; then
  if [[ -n "$data" ]]; then
    curl -sG "$BASE$path" --data-urlencode "$data"
  else
    curl -s "$BASE$path"
  fi
else
  curl -s -X POST "$BASE$path" -H 'Content-Type: application/json' -d "$data"
fi
