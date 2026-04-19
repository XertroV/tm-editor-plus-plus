#!/usr/bin/env bash
# Live memory probe: compare compute-path wrappers vs healthy pmt.Items wrappers.
# Requires: TM in editor mode, any map open. The probe uses a standard macroblock
# that is known to exist in the stock inventory.

set -u

MBPATH="${MBPATH:-Stadium\\\\Macroblocks\\\\LightSculpture\\\\Spring\\\\FlowerWhiteSmall.Macroblock.Gbx}"
X="${X:-10}"
Y="${Y:-10}"
Z="${Z:-10}"
DUMP_LEN="${DUMP_LEN:-256}"

CALL=/home/xertrov/src/openplanet/my-plugins/tm-control-mcp/tools/call.py

die() { echo "ERROR: $*" >&2; exit 1; }

echo "==> Mode check"
mode_json=$(python3 "$CALL" GetMode '{}') || die "GetMode failed"
echo "$mode_json"
case "$mode_json" in
    *'"mode":"Editor"'*) ;;
    *) die "TM is not in Editor mode. Open a map first." ;;
esac

echo
echo "==> Healthy wrappers (pmt.Items)"
python3 "$CALL" DevGetPointers '{"listPmtItems":true,"pmtItemsLimit":3,"listAnchoredObjects":true,"anchoredObjectsLimit":3}'

echo
echo "==> Compute-path wrappers (MacroblockInstanceItemsResults) — pointers only, no field access"
python3 "$CALL" DevComputeItemsPointers "$(printf '{"mbPath":"%s","x":%s,"y":%s,"z":%s}' "$MBPATH" "$X" "$Y" "$Z")"

echo
echo "To dump wrapper memory for a specific ptr, run:"
echo "  python3 $CALL DevSafeRead '{\"ptr\":\"<PTR>\",\"kind\":\"bytes\",\"len\":$DUMP_LEN}'"
