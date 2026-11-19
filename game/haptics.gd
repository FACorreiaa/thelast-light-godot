class_name Haptics
extends RefCounted
## Taps on a phone: short for light, longer for heavy. Nothing elsewhere.

var enabled := true


func _buzz(ms: int, amplitude: float) -> void:
	if enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, clampf(amplitude, 0.0, 1.0))


func light(intensity := 1.0) -> void:
	_buzz(10, 0.4 * intensity)


func rigid(intensity := 1.0) -> void:
	_buzz(15, 0.7 * intensity)


func heavy() -> void:
	_buzz(30, 1.0)
