#!/usr/bin/env bash
# Runs the headless suite: sim and story parity against the Swift goldens, and the app flow. A GDScript parse error can still exit 0, so each step must also
# print its own success line and no SCRIPT ERROR.
#   GODOT=/path/to/godot tools/run_tests.sh [replay args...]
set -uo pipefail
GODOT=${GODOT:-godot}
cd "$(dirname "$0")/.."
fail=0

run() {  # run <success regex> <godot args...>
	local want=$1; shift
	local out
	out=$("$GODOT" --headless --path . "$@" 2>&1)
	local code=$?
	echo "$out" | grep -vE '^Godot Engine|^$' | grep -vE '^ok ' || true
	if [[ $code -ne 0 ]] || ! grep -qE "$want" <<<"$out" || grep -q "SCRIPT ERROR" <<<"$out"; then
		echo "FAILED: $*"
		fail=1
	fi
}

tools/check_sim.sh || fail=1
"$GODOT" --headless --path . --import >/dev/null 2>&1
run '^doubles: [0-9]+ checked, 0 mismatched' -s res://tests/check_doubles.gd
run '^rng: [0-9]+ calls, 0 mismatched' -s res://tests/test_rng.gd
run '^glyphs: [0-9]+ weights checked, 0 failed' -s res://tests/check_glyphs.gd
run '^story: [0-9]+ runs, 0 mismatched' -s res://tests/test_story.gd
run '^flow: [0-9]+ checks, 0 failed' -s res://tests/test_flow.gd
run '^input: [0-9]+ checks, 0 failed' -s res://tests/test_input.gd
run '^eclipse: [0-9]+ checks, 0 failed' -s res://tests/test_eclipse.gd
run '^replay: ([0-9]+)/\1 runs match' -s res://tests/replay.gd -- "$@"
exit $fail
