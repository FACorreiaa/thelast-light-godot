#!/bin/sh
# Fails on constructs that break bit parity with the Swift simulation (see spikes/README.md).
# Run before every commit that touches sim/. Comments are ignored.
cd "$(dirname "$0")/.." || exit 1
code() { awk '{ line=$0; sub(/#.*/, "", line); if (line ~ /[^ \t]/) print FILENAME ":" FNR ": " line }' sim/*.gd; }
bad=0
# Godot's minf/maxf/clampf drop the sign of a zero tie; Swift keeps it. Use Sw.min_d/Sw.max_d.
if code | grep -v '^sim/sw.gd' | sed -E 's/\b(mini|maxi|min_d|max_d)\(//g' | grep -E '\b(minf|maxf|clampf|clamp|min|max)\('; then
	echo "check_sim: use Sw.min_d/Sw.max_d (or mini/maxi for ints) instead of the lines above"; bad=1
fi
# Godot's Vector2/Rect2 are float32.
if code | grep -E '\b(Vector2|Rect2)\b'; then echo "check_sim: no Vector2/Rect2 in sim/"; bad=1; fi
# Decimal parsing is not correctly rounded in Godot.
if code | grep -E 'to_float\(|float\("'; then echo "check_sim: no String.to_float in sim/"; bad=1; fi
exit $bad
