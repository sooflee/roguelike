#!/usr/bin/env bash
# Rewrites every card's authored text from its own effects, then restores the
# file's hand-authored compact layout.
#
# Card text must exactly equal CardData.describe(false) (D-24), so any rename of
# a status, keyword or resource invalidates every card that mentions it. This is
# the one command that fixes them all.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LIMIT="${LIMIT:-120}"

"$GODOT" --headless --path . tests/sync_card_text.tscn >/tmp/sync_text.log 2>&1 &
pid=$!
( sleep "$LIMIT"; kill -9 $pid 2>/dev/null ) & watcher=$!
disown $watcher 2>/dev/null || true
wait $pid; rc=$?
kill $watcher 2>/dev/null
grep -E "sync_card_text:|^  " /tmp/sync_text.log || true
if grep -qE "Parse Error|SCRIPT ERROR" /tmp/sync_text.log; then
  grep -E "Parse Error|SCRIPT ERROR" /tmp/sync_text.log | sort -u >&2
  exit 1
fi
[ "$rc" -eq 0 ] || exit "$rc"

python3 tools/format_cards.py
