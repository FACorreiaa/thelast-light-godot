class_name Strike
extends RefCounted
## Something that warns, then is live for a few frames, then is gone: a column of light, a burning
## patch, a snare. Strikes hurt heroes only, and each hero at most once.

## StrikeKind case name: "light", "fire", "snare" or "dark".
var kind: String = "light"
var box: Box
var slow_frames: int = 0
var warning: int
var active: int
var damage: float
var age: int = 0
## Set of hero ids already caught (keys only).
var hit: Dictionary = {}


static func make(b: Box, p_warning: int, p_active: int, p_damage: float) -> Strike:
	var s := Strike.new()
	s.box = b
	s.warning = p_warning
	s.active = p_active
	s.damage = p_damage
	return s


func is_warning() -> bool:
	return age < warning


func is_active() -> bool:
	return age >= warning and age < warning + active


func is_done() -> bool:
	return age >= warning + active


func to_canon() -> Dictionary:
	return {"kind": kind, "box": box, "slowFrames": slow_frames, "warning": warning, "active": active,
		"damage": damage, "age": age, "hit": Canon.int_set(hit)}
