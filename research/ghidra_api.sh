#!/usr/bin/env bash
# Helper: query the ghidra-mcp HTTP API (SSH tunnel :18742). See research/Ghidra.md.
# Usage: ghidra_api.sh GET /endpoint
#        ghidra_api.sh GET /endpoint 'k=v&k2=v2'
#        ghidra_api.sh GET /endpoint k=v k2=v2
#        ghidra_api.sh POST /endpoint '{"json":"body"}'
#        ghidra_api.sh POST /endpoint '{"json":"body"}' program=Trackmania.exe
#
# One-at-a-time: exclusive flock on GHIDRA_API_LOCK (default /tmp/ghidra-api-18742.lock).
# The lock is an fd lock — kernel drops it if this process dies. The lock *file* may
# remain; that is not a stale lock. Holder stamp is informational only.
# Escape: GHIDRA_API_SKIP_LOCK=1
set -euo pipefail

LOCK="${GHIDRA_API_LOCK:-/tmp/ghidra-api-18742.lock}"
LOCK_WAIT="${GHIDRA_API_LOCK_WAIT:-3600}"
CURL_MAX="${GHIDRA_API_CURL_MAX:-260}"
HOLDER="${LOCK}.holder"

now_s() { date +%s.%N; }
secs_since() { awk -v a="$(now_s)" -v b="$1" 'BEGIN{printf "%.3f", a-b}'; }

if [[ -z "${GHIDRA_API_T0:-}" ]]; then
  export GHIDRA_API_T0="$(now_s)"
fi

if [[ "${GHIDRA_API_SKIP_LOCK:-}" != "1" && "${GHIDRA_API_LOCKED:-}" != "1" ]]; then
  export GHIDRA_API_LOCKED=1
  set +e
  flock -w "$LOCK_WAIT" -E 75 "$LOCK" "$0" "$@"
  rc=$?
  set -e
  if [[ "$rc" -eq 75 ]]; then
    echo "ghidra_api.sh: timed out waiting ${LOCK_WAIT}s for $LOCK" >&2
    if [[ -f "$HOLDER" ]]; then
      echo "ghidra_api.sh: last holder: $(cat "$HOLDER")" >&2
    fi
    wait_s="$(secs_since "$GHIDRA_API_T0")"
    echo "ghidra_api.sh: total=${wait_s}s flock_wait=${wait_s}s api_call=0.000s (lock wait)" >&2
  fi
  exit "$rc"
fi

GHIDRA_API_FLOCK_WAIT="$(secs_since "$GHIDRA_API_T0")"

if [[ "${GHIDRA_API_LOCKED:-}" == "1" ]]; then
  printf 'pid=%s start=%s argv=%s\n' "$$" "$(date -Is)" "$*" > "$HOLDER" || true
  trap 'rm -f "$HOLDER"' EXIT
fi

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

# After flock. curl 28 = --max-time / connect-timeout. Print then keep that rc.
do_curl() {
  local rc
  set +e
  curl -sS --connect-timeout 5 --max-time "$CURL_MAX" "$@"
  rc=$?
  set -e
  if [[ "$rc" -eq 28 ]]; then
    echo "ghidra_api.sh: timed out after ${CURL_MAX}s (${method} ${path})" >&2
  fi
  return "$rc"
}

t_curl_start="$(now_s)"
curl_rc=0
if [[ "$method" == "GET" ]]; then
  args=()
  while IFS= read -r -d '' item; do
    args+=(--data-urlencode "$item")
  done < <(urlencode_pairs "$@")
  set +e
  if ((${#args[@]})); then
    do_curl -G "$BASE$path" "${args[@]}"
  else
    do_curl "$BASE$path"
  fi
  curl_rc=$?
  set -e
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
  set +e
  do_curl -X POST "$BASE$path" "${qargs[@]}" -H 'Content-Type: application/json' -d "$body"
  curl_rc=$?
  set -e
fi

api_s="$(secs_since "$t_curl_start")"
total_s="$(secs_since "$GHIDRA_API_T0")"
echo "\n------"
echo "ghidra_api.sh: total=${total_s}s flock_wait=${GHIDRA_API_FLOCK_WAIT}s api_call=${api_s}s (${method} ${path})" >&2
exit "$curl_rc"
