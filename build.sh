#!/usr/bin/env bash
# Builds installable .kwinscript files (System Settings → KWin Scripts → Install from File) into dist/.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

version=$(python3 -c 'import json; print(json.load(open("package/fullscreen-spaces/metadata.json"))["KPlugin"]["Version"])')
rm -rf dist && mkdir dist

for pkg in fullscreen-spaces fullscreen-spaces-menu; do
    (cd "package/$pkg" && python3 -m zipfile -c "../../dist/$pkg-$version.kwinscript" metadata.json contents)
done

ls -l dist
