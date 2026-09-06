#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../../.." && pwd)"
run_id="$1"
[[ "$run_id" =~ ^[A-Za-z0-9_-]+$ ]] || exit 2
stage="/tmp/epp-kv-transport-$run_id"
fixture_dir="$HOME/tm-docs/Tests/EppKVTransport/$run_id/"
mkdir -p "$stage"
dotnet run --project "$here/../fixture" -- "$fixture_dir"
cp "$here/Main.as" "$here/info.toml" "$stage/"
python3 - "$repo/src/FromML.as" "$stage/TransportLiteral.as" <<'PY'
import pathlib,sys
source=pathlib.Path(sys.argv[1]).read_text()
start=source.index('    string MapKVStringLiteral(')
end=source.index('\n    ML_Event@ MakeMapKVMessage',start)
pathlib.Path(sys.argv[2]).write_text('namespace ToML {\n'+source[start:end]+'\n}\n')
PY
printf 'const string FixtureDir = "Tests/EppKVTransport/%s/";\n' "$run_id" > "$stage/Config.as"
openplanet-lsp check --format plain "$stage"
sha256sum "$stage/"*.as > "$fixture_dir/source-sha256.txt"
