#!/usr/bin/env bash
set -euo pipefail

APPID="${TM_STEAM_APPID:-2225070}"
CRASH_TITLE="${TM_OP_CRASH_TITLE:-Crash in \"Openplanet.dll\"}"
WAIT_AFTER_OK="${TM_OP_CRASH_WAIT_AFTER_OK:-12}"
WAIT_AFTER_UBI_KILL="${TM_OP_CRASH_WAIT_AFTER_UBI_KILL:-5}"
DRY_RUN=0
KILL_STUCK=1
KILL_UBISOFT=1
LAUNCH=1

usage() {
  cat <<'EOF'
Usage: tools/restart_tm_after_openplanet_crash.sh [options]

Detect an Openplanet.dll crash dialog, dismiss it, wait for Trackmania to exit,
then relaunch Trackmania through Steam.

Options:
  --dry-run       Print what would happen without pressing OK, killing, or launching.
  --no-kill       Do not terminate Trackmania if it stays alive after the dialog closes.
  --no-kill-ubi   Do not terminate Ubisoft Connect / UplayWebCore processes.
  --no-launch     Dismiss/clean up only; do not launch Steam.
  --appid ID      Steam app id to launch. Default: 2225070.
  --wait SECONDS  Seconds to wait after pressing OK before killing stuck TM.
  --ubi-wait SEC  Seconds to wait after Ubisoft cleanup before relaunch. Default: 5.
  -h, --help      Show this help.
EOF
}

log() {
  printf '[%(%Y-%m-%d %H:%M:%S)T] %s\n' -1 "$*"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --no-kill)
      KILL_STUCK=0
      shift
      ;;
    --no-kill-ubi)
      KILL_UBISOFT=0
      shift
      ;;
    --no-launch)
      LAUNCH=0
      shift
      ;;
    --appid)
      APPID="${2:?--appid needs a value}"
      shift 2
      ;;
    --wait)
      WAIT_AFTER_OK="${2:?--wait needs a value}"
      shift 2
      ;;
    --ubi-wait)
      WAIT_AFTER_UBI_KILL="${2:?--ubi-wait needs a value}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required tool not found: %s\n' "$1" >&2
    exit 3
  fi
}

require_tool xdotool
require_tool steam

find_crash_windows() {
  xdotool search --onlyvisible --name "$CRASH_TITLE" 2>/dev/null || true
}

trackmania_pids() {
  local proc arg normalized has_tm_arg argv0
  for proc in /proc/[0-9]*; do
    [[ -r "$proc/cmdline" ]] || continue
    has_tm_arg=0
    argv0=""
    while IFS= read -r -d '' arg; do
      [[ -n "$arg" ]] || continue
      normalized="${arg//\\//}"
      normalized="${normalized,,}"
      if [[ -z "$argv0" ]]; then
        argv0="$normalized"
      fi
      if [[ "$normalized" == "trackmania.exe" || "$normalized" == */trackmania.exe ]]; then
        has_tm_arg=1
      fi
    done < "$proc/cmdline"
    if [[ "$argv0" == "trackmania.exe" || "$argv0" == */trackmania.exe || "$has_tm_arg" == "1" ]]; then
      basename "$proc"
    fi
  done
}

wait_for_tm_exit() {
  local deadline pids
  deadline=$((SECONDS + WAIT_AFTER_OK))
  while (( SECONDS < deadline )); do
    pids="$(trackmania_pids | xargs echo || true)"
    if [[ -z "$pids" ]]; then
      log "Trackmania.exe exited."
      return 0
    fi
    sleep 1
  done
  return 1
}

ubisoft_pids() {
  local proc cmdline lower
  for proc in /proc/[0-9]*; do
    [[ -r "$proc/cmdline" ]] || continue
    cmdline="$(tr '\0' ' ' < "$proc/cmdline" 2>/dev/null || true)"
    [[ -n "$cmdline" ]] || continue
    lower="${cmdline,,}"
    if [[ "$lower" == *"ubisoft game launcher"* || "$lower" == *"upc.exe"* || "$lower" == *"uplaywebcore.exe"* || "$lower" == *"ubisoftconnect.exe"* ]]; then
      basename "$proc"
    fi
  done
}

terminate_pids() {
  local label pids
  label="$1"
  shift
  pids="$*"
  [[ -n "$pids" ]] || return 0
  log "Terminating $label PID(s): $pids"
  kill $pids 2>/dev/null || true
  sleep 3
  local still_alive=()
  local pid
  for pid in $pids; do
    if [[ -d "/proc/$pid" ]]; then
      still_alive+=("$pid")
    fi
  done
  if [[ "${#still_alive[@]}" -gt 0 ]]; then
    log "$label still alive after SIGTERM; killing PID(s): ${still_alive[*]}"
    kill -9 "${still_alive[@]}" 2>/dev/null || true
  fi
}

windows="$(find_crash_windows | xargs echo || true)"
if [[ -z "$windows" ]]; then
  log "No Openplanet.dll crash dialog found."
  exit 0
fi

log "Found Openplanet crash dialog window(s): $windows"

for win in $windows; do
  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY RUN: would activate window $win and press Return."
  else
    log "Dismissing crash dialog window $win."
    xdotool windowactivate --sync "$win" key Return
  fi
done

if [[ "$DRY_RUN" == "1" ]]; then
  pids="$(trackmania_pids | xargs echo || true)"
  log "DRY RUN: Trackmania PID(s): ${pids:-none}"
  ubi_pids="$(ubisoft_pids | xargs echo || true)"
  log "DRY RUN: Ubisoft PID(s): ${ubi_pids:-none}"
  log "DRY RUN: would wait ${WAIT_AFTER_OK}s, kill stuck TM/Ubisoft if needed, wait ${WAIT_AFTER_UBI_KILL}s, then run: steam -applaunch $APPID"
  exit 0
fi

if ! wait_for_tm_exit; then
  pids="$(trackmania_pids | xargs echo || true)"
  if [[ -n "$pids" && "$KILL_STUCK" == "1" ]]; then
    log "Trackmania still alive after ${WAIT_AFTER_OK}s."
    terminate_pids "Trackmania" $pids
  elif [[ -n "$pids" ]]; then
    log "Trackmania still alive after ${WAIT_AFTER_OK}s; --no-kill set, leaving PID(s): $pids"
  fi
fi

ubi_pids="$(ubisoft_pids | xargs echo || true)"
if [[ -n "$ubi_pids" && "$KILL_UBISOFT" == "1" ]]; then
  terminate_pids "Ubisoft Connect" $ubi_pids
  log "Waiting ${WAIT_AFTER_UBI_KILL}s after Ubisoft cleanup."
  sleep "$WAIT_AFTER_UBI_KILL"
elif [[ -n "$ubi_pids" ]]; then
  log "Ubisoft Connect PID(s) still alive; --no-kill-ubi set, leaving PID(s): $ubi_pids"
fi

if [[ "$LAUNCH" == "1" ]]; then
  log "Launching Trackmania via Steam appid $APPID."
  steam -applaunch "$APPID" >/tmp/tm-openplanet-crash-restart-steam.log 2>&1 &
  disown || true
else
  log "--no-launch set; not restarting Trackmania."
fi
