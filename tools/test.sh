#!/usr/bin/env bash
# Headless test suite. Requires Godot 4.7.x on PATH as `godot`.
#
# The timeout is not paranoia: if the test script fails to COMPILE, Godot loads
# the scene with no script attached, so nothing ever calls quit() and the run
# hangs forever instead of failing. Bound it and treat a timeout as a failure.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LIMIT="${LIMIT:-120}"

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "godot not found. Set GODOT=/path/to/Godot or install Godot 4.7.x." >&2
  exit 127
fi

# First run imports assets and generates .godot/; it can exit non-zero harmlessly.
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

run_scene() {  # $1 = scene path, $2 = label
  local log; log=$(mktemp)
  "$GODOT" --headless --path . "$1" >"$log" 2>&1 &
  local pid=$!
  ( sleep "$LIMIT"; kill -9 $pid 2>/dev/null ) &
  local watcher=$!
  disown $watcher 2>/dev/null || true   # otherwise the shell reports "Terminated"
  wait $pid; local rc=$?
  kill $watcher 2>/dev/null

  grep -E "PASS|FAIL|passed,|view smoke|screen smoke|soak:|playthrough:|reached the end|problems:|defect|DEFECT|fights|mana gauge|card views" "$log" || true
  local bad=0
  if grep -qE "Parse Error|Compile Error" "$log"; then
    echo "COMPILE ERRORS in $2:" >&2
    grep -E "Parse Error|Compile Error" "$log" | sort -u >&2
    bad=1
  fi
  if grep -qE "SCRIPT ERROR" "$log"; then
    echo "RUNTIME ERRORS in $2:" >&2
    grep -E "SCRIPT ERROR" "$log" | sort -u | head -10 >&2
    bad=1
  fi
  if [ "$rc" -eq 137 ]; then
    echo "TIMED OUT after ${LIMIT}s in $2 — never called quit()." >&2
    bad=1
  fi
  rm -f "$log"
  [ "$bad" -eq 0 ] && [ "$rc" -eq 0 ]
}

# Optional filter: ./tools/test.sh rules|view|screens|soak
# The whole suite boots Godot four times and the soak alone plays 14 animated
# fights, so a full run is minutes. During an edit-test loop that cost is paid
# over and over for scenes the change cannot possibly have touched.
ONLY="${1:-all}"   # rules|view|screens|soak|playthrough
want() { [ "$ONLY" = "all" ] || [ "$ONLY" = "$1" ]; }

fail=0
if want rules; then
echo "--- rules ---"
run_scene tests/test_runner.tscn "unit suite" || fail=1
fi

if want view; then
echo "--- view ---"
# Drives the animated combat view through real fights. The unit suite proves the
# rules; this proves the presentation layer survives contact with them.
run_scene tests/view_smoke.tscn "view smoke" || fail=1
fi

if want screens; then
echo "--- screens ---"
# The same argument for the other half of the game: map, event, reward, shop,
# campfire and the potion pickers, each walked with a run state chosen to hit
# its awkward branch.
run_scene tests/screen_smoke.tscn "screen smoke" || fail=1
fi

if want soak; then
echo "--- soak ---"
# Self-play through the real animated view, checking every time it goes idle
# that the screen still agrees with the simulation. D-13 lets the two drift
# apart silently; nothing here corrupts a save, which is exactly why no rules
# test would ever catch it.
LIMIT=240 run_scene tests/soak.tscn "soak" || fail=1
fi

if want playthrough; then
echo "--- playthrough ---"
# One whole run, start to boss, through the real screens. Every other scene
# tests a slice; this is the only one that proves a player can finish.
run_scene tests/playthrough.tscn "playthrough" || fail=1
fi
exit "$fail"
