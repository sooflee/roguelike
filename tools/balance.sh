#!/usr/bin/env bash
# Self-play balance metrics. Requires Godot 4.7.x on PATH as `godot`.
#
#   ./tools/balance.sh                          # greedy, fixed seeds, 60 runs
#   ./tools/balance.sh curve-aware              # one policy
#   ./tools/balance.sh all                      # every policy, for the gap
#   RUNS=200 SEEDS=holdout ./tools/balance.sh all
#
# The timeout is the same guard tools/test.sh uses, and for the same reason: if
# the script fails to COMPILE, Godot loads the scene with no script attached, so
# nothing ever calls quit() and the run hangs forever instead of failing.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LIMIT="${LIMIT:-300}"
RUNS="${RUNS:-60}"
SEEDS="${SEEDS:-fixed}"

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "godot not found. Set GODOT=/path/to/Godot or install Godot 4.7.x." >&2
  exit 127
fi

"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

run_policy() {  # $1 = policy name
  local log; log=$(mktemp)
  "$GODOT" --headless --path . tests/balance.tscn -- \
    "--policy=$1" "--runs=$RUNS" "--seeds=$SEEDS" >"$log" 2>&1 &
  local pid=$!
  ( sleep "$LIMIT"; kill -9 $pid 2>/dev/null ) &
  local watcher=$!
  disown $watcher 2>/dev/null || true
  wait $pid; local rc=$?
  kill $watcher 2>/dev/null

  grep -E "BALANCE|METRIC|CARD|^--|^ *$" "$log" | grep -vE "^ *$" || true
  local bad=0
  if grep -qE "Parse Error|Compile Error" "$log"; then
    echo "COMPILE ERRORS ($1):" >&2
    grep -E "Parse Error|Compile Error" "$log" | sort -u >&2
    bad=1
  fi
  if grep -qE "SCRIPT ERROR" "$log"; then
    echo "RUNTIME ERRORS ($1):" >&2
    grep -E "SCRIPT ERROR" "$log" | sort -u | head -10 >&2
    bad=1
  fi
  if [ "$rc" -eq 137 ]; then
    echo "TIMED OUT after ${LIMIT}s ($1) — never called quit()." >&2
    bad=1
  fi
  rm -f "$log"
  [ "$bad" -eq 0 ] && [ "$rc" -eq 0 ]
}

fail=0
case "${1:-greedy}" in
  all)
    for p in greedy curve-blind curve-aware; do
      run_policy "$p" || fail=1
      echo
    done
    ;;
  *) run_policy "${1:-greedy}" || fail=1 ;;
esac
exit "$fail"
