#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
run_id="${1:-$(date -u +%Y%m%dT%H%M%S)-$$}"
[[ "$run_id" =~ ^[A-Za-z0-9_-]+$ ]] || exit 2
run_dir="Tests/EppKVStorage/$run_id/"
fixture_dir="$HOME/tm-docs/$run_dir"
stage="/tmp/epp-kv-storage-$run_id"
mkdir -p "$stage"
dotnet run --project "$here/fixture" -- "$fixture_dir"
cp "$here/harness/"* "$stage/"
cp "$repo/src/Editor/MapKV.as" "$repo/src/Editor/MapKV_Types.as" "$repo/ascall-spikes/AsCall.as" "$repo/ascall-spikes/Hex.as" "$stage/"
printf 'const string RunId = "%s";\nconst string RunDir = "%s";\n' "$run_id" "$run_dir" > "$stage/RunConfig.as"
openplanet-lsp check --format plain "$stage"
sha256sum "$stage/"*.as > "$fixture_dir/source-sha256.txt"
printf '%s\n' "$stage" > /tmp/epp-kv-storage-latest-stage
printf '%s\n' "$fixture_dir" > /tmp/epp-kv-storage-latest-fixture
printf 'Staged %s\nFixture %s\n' "$stage" "$fixture_dir"
