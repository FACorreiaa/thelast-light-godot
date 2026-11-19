class_name HardwareInput
extends RefCounted
## Keyboard and controller, polled once per rendered frame. Port of GameInput.swift.
## Keyboard: A/D or arrows move, Space jumps, J attacks, K dodges, I uses the special, L switches hero, R restarts,
## Esc pauses, M changes between the level and the training room, P shows or hides the debug overlay.

class Reading:
	var move_x := 0.0
	var jump_held := false
	var jump := false
	var attack := false
	var dodge := false
	var special := false
	var switch_hero := false
	var restart := false
	var pause := false
	var mode := false
	var debug := false

var _was_down: Dictionary = {}


static func _key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)


func poll() -> Reading:
	var down: Dictionary = {}
	var r := Reading.new()
	if _key(KEY_A) or _key(KEY_LEFT):
		r.move_x -= 1.0
	if _key(KEY_D) or _key(KEY_RIGHT):
		r.move_x += 1.0
	if _key(KEY_SPACE) or _key(KEY_W) or _key(KEY_UP):
		down["jump"] = true
	if _key(KEY_J):
		down["attack"] = true
	if _key(KEY_K) or _key(KEY_SHIFT):
		down["dodge"] = true
	if _key(KEY_I) or _key(KEY_E):
		down["special"] = true
	if _key(KEY_L) or _key(KEY_TAB):
		down["switch"] = true
	if _key(KEY_R):
		down["restart"] = true
	if _key(KEY_ESCAPE):
		down["pause"] = true
	if _key(KEY_M):
		down["mode"] = true
	if _key(KEY_P):
		down["debug"] = true

	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		var pad: int = pads[0]
		var stick := Input.get_joy_axis(pad, JOY_AXIS_LEFT_X)
		var dpad := (1.0 if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT) else 0.0) \
			- (1.0 if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT) else 0.0)
		var x := stick if absf(stick) > absf(dpad) else dpad
		if absf(x) > 0.2:
			r.move_x = x
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_A):
			down["jump"] = true
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_X):
			down["attack"] = true
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_B) or Input.is_joy_button_pressed(pad, JOY_BUTTON_RIGHT_SHOULDER):
			down["dodge"] = true
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_Y):
			down["switch"] = true
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_LEFT_SHOULDER) or Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) > 0.5:
			down["special"] = true
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_START):
			down["pause"] = true

	r.move_x = clampf(r.move_x, -1.0, 1.0)
	r.jump_held = down.has("jump")
	r.jump = _pressed(down, "jump")
	r.attack = _pressed(down, "attack")
	r.dodge = _pressed(down, "dodge")
	r.special = _pressed(down, "special")
	r.switch_hero = _pressed(down, "switch")
	r.restart = _pressed(down, "restart")
	r.pause = _pressed(down, "pause")
	r.mode = _pressed(down, "mode")
	r.debug = _pressed(down, "debug")
	_was_down = down
	return r


func _pressed(down: Dictionary, name: String) -> bool:
	return down.has(name) and not _was_down.has(name)
