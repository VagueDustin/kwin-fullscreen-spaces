#!/bin/bash
# act.sh SECONDS "caption" CMD... — runs CMD and records a caption for mkgif.py, shown for SECONDS.
D=$(dirname "$(readlink -f "$0")")
secs=$1; cap=$2; shift 2
t=$(date +%s.%N)
"$@"
python3 - "$D/.work/captions.json" "$t" "$secs" "$cap" <<'PY'
import json, os, sys
f, t, secs, cap = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), sys.argv[4]
d = json.load(open(f)) if os.path.exists(f) else []
d.append([t, t + secs, cap])
json.dump(d, open(f, "w"))
PY
