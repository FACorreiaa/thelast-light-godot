class_name Sw
extends RefCounted
## Swift standard library behaviour that Godot's built-ins do not reproduce bit for bit.
##
## Swift `min(x, y)` is `y < x ? y : x` and `max(x, y)` is `y >= x ? y : x`, so on a tie between
## -0.0 and +0.0 the sign follows the argument order. Godot's minf/maxf return +0.0 either way,
## which changes the state hash. Use these for every Double min/max ported from Swift; mini/maxi are
## fine for Ints.


static func min_d(x: float, y: float) -> float:
	return y if y < x else x


static func max_d(x: float, y: float) -> float:
	return y if y >= x else x
