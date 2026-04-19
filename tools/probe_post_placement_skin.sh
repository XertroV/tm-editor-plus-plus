#!/usr/bin/env bash
# Live probe: run the full AddItemToNamedMacroblock → PlaceNamedMacroblock
# flow and dump the skinApplication report. Answers task #2's branch question
# (branch-A: pmt.Items populated, match-logic bug; branch-B: pmt.Items stays
# empty, public-API dead). Requires: TM in Editor mode with a map open.
#
# Tunable env vars (defaults are placeholders — override for your workspace):
#   NAME        — in-memory macroblock key (defaults to "probe_skin")
#   ITEM_PATH   — backslash-separated game-relative path to a .Item.Gbx
#   BG_SKIN     — url or pack-desc path for the background skin
#   FG_SKIN     — optional foreground skin
#   X Y Z       — placement coord inside the current map

set -u

NAME="${NAME:-probe_skin}"
ITEM_PATH="${ITEM_PATH:-}"
BG_SKIN="${BG_SKIN:-}"
FG_SKIN="${FG_SKIN:-}"
X="${X:-10}"
Y="${Y:-10}"
Z="${Z:-10}"

CALL=/home/xertrov/src/openplanet/my-plugins/tm-control-mcp/tools/call.py

die() { echo "ERROR: $*" >&2; exit 1; }

if [[ -z "$ITEM_PATH" ]]; then
    die "Set ITEM_PATH to a game-relative .Item.Gbx path (backslash-separated)."
fi
if [[ -z "$BG_SKIN" ]]; then
    die "Set BG_SKIN to a skin pack desc URL or path."
fi

echo "==> Mode check"
mode_json=$(python3 "$CALL" GetMode '{}') || die "GetMode failed"
echo "$mode_json"
case "$mode_json" in
    *'"mode":"Editor"'*) ;;
    *) die "TM is not in Editor mode. Open a map first." ;;
esac

echo
echo "==> Baseline GetMapInfo"
python3 "$CALL" GetMapInfo '{}'

echo
echo "==> Register named macroblock $NAME with skinned item"
python3 "$CALL" AddItemToNamedMacroblock "$(cat <<EOF
{"name":"$NAME","itemPath":"$ITEM_PATH","x":$X,"y":$Y,"z":$Z,"bgSkin":"$BG_SKIN","fgSkin":"$FG_SKIN"}
EOF
)"

echo
echo "==> PlaceNamedMacroblock $NAME (runs place + apply + report)"
python3 "$CALL" PlaceNamedMacroblock "$(printf '{"name":"%s"}' "$NAME")"

echo
echo "==> Post GetMapInfo (watch nbItems and nbScriptItems)"
python3 "$CALL" GetMapInfo '{}'

echo
echo "Read skinApplication.errors[*] from the PlaceNamedMacroblock response above."
echo "  errors[i].nbScriptItems == 0  → branch-B (pmt.Items persistently empty; public API dead)."
echo "  errors[i].nbScriptItems > 0   → branch-A (match-logic bug; hunt in FindScriptItemForMapItem)."
echo "  empty errors[] + applied[*]   → success path; skins landed."
