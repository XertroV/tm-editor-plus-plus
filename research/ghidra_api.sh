#!/usr/bin/env bash
# Helper: query the ghidra-mcp HTTP API (SSH tunnel :18742). See research/Ghidra.md.
# Usage: ghidra_api.sh GET /endpoint
#        ghidra_api.sh GET /endpoint 'k=v&k2=v2'
#        ghidra_api.sh GET /endpoint k=v k2=v2
#        ghidra_api.sh POST /endpoint '{"json":"body"}'
#        ghidra_api.sh POST /endpoint '{"json":"body"}' program=Trackmania.exe
set -euo pipefail
BASE="${GHIDRA_API_BASE:-http://127.0.0.1:18742}"
method="${1:?method}"; path="${2:?path}"; shift 2

urlencode_pairs() {
  local item p
  for item in "$@"; do
    if [[ "$item" == *'&'* && "$item" == *'='* ]]; then
      IFS='&' read -ra parts <<< "$item"
      for p in "${parts[@]}"; do
        [[ -n "$p" ]] && printf '%s\0' "$p"
      done
    elif [[ -n "$item" ]]; then
      printf '%s\0' "$item"
    fi
  done
}

if [[ "$method" == "GET" ]]; then
  args=()
  while IFS= read -r -d '' item; do
    args+=(--data-urlencode "$item")
  done < <(urlencode_pairs "$@")
  if ((${#args[@]})); then
    curl -sG "$BASE$path" "${args[@]}"
  else
    curl -s "$BASE$path"
  fi
else
  body=""
  qargs=()
  for item in "$@"; do
    if [[ "$item" == \{* || ( -z "$body" && "$item" != *=* ) ]]; then
      body="$item"
    elif [[ "$item" == *=* ]]; then
      qargs+=(--url-query "$item")
    fi
  done
  if [[ -z "$body" ]]; then
    echo "ghidra_api.sh: POST body required" >&2
    exit 2
  fi
  # --url-query keeps the JSON on the POST body; curl -G rejects this mix.
  curl -s -X POST "$BASE$path" "${qargs[@]}" -H 'Content-Type: application/json' -d "$body"
fi
