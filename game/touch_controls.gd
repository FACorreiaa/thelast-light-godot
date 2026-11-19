class_name TouchControls
extends Node2D
## A floating stick on the left half of the screen and buttons on the right. Port of TouchControls.swift.
## Lives on the y-flipped UI layer: positions are in the Swift scene's points with y up. A touch is known by
## Godot's touch index.

enum Pad { ATTACK, DODGE, JUMP, SWITCH_HERO, SPECIAL }

const STICK_RANGE := 46.0
const DEAD_ZONE := 8.0

var move_x := 0.0
var jump_held := false
## Presses since the last time they were taken.
var _pressed: Dictionary = {}
var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_rest := Vector2.ZERO
var _button_touches: Dictionary = {}  # touch index -> Pad
var _stick_base := SkShape.make(SkPath.circle(52), Sk.with_alpha(Palette.WHITE, 0.04), Sk.with_alpha(Palette.WHITE, 0.22), 2)
var _stick_knob := SkShape.make(SkPath.circle(24), Sk.with_alpha(Palette.WHITE, 0.25), Color(0, 0, 0, 0))
var _buttons: Dictionary = {}  # Pad -> SkShape
var _radius: Dictionary = {}  # Pad -> float
var _size := Vector2.ZERO


func _init() -> void:
	Sk.z(self, 100)
	add_child(_stick_base)
	add_child(_stick_knob)
	for spec: Array in [[Pad.ATTACK, 42.0, "⚔︎"], [Pad.DODGE, 32.0, "»"], [Pad.JUMP, 32.0, "▲"],
			[Pad.SWITCH_HERO, 26.0, "⇄"], [Pad.SPECIAL, 28.0, "✦"]]:
		var r: float = spec[1]
		var node := SkShape.make(SkPath.circle(r), Sk.with_alpha(Palette.WHITE, 0.06), Sk.with_alpha(Palette.WHITE, 0.3), 2)
		var label := SkLabel.make(spec[2], r * 0.8, Sk.with_alpha(Palette.WHITE, 0.6), "bold")
		label.v_align = SkLabel.V.CENTER
		node.add_child(label)
		add_child(node)
		_buttons[spec[0]] = node
		_radius[spec[0]] = r


func layout(size: Vector2, insets: Rect2) -> void:
	_size = size
	var left := maxf(insets.position.x, 16)
	var right := maxf(insets.size.x, 16)
	var bottom := maxf(insets.size.y, 12)
	_stick_rest = Vector2(left + 86, bottom + 84)
	if _stick_touch < 0:
		_show_stick(_stick_rest, _stick_rest)
	var edge := size.x - right
	_buttons[Pad.ATTACK].position = Vector2(edge - 62, bottom + 66)
	_buttons[Pad.JUMP].position = Vector2(edge - 158, bottom + 50)
	_buttons[Pad.DODGE].position = Vector2(edge - 82, bottom + 156)
	_buttons[Pad.SWITCH_HERO].position = Vector2(edge - 176, bottom + 138)
	_buttons[Pad.SPECIAL].position = Vector2(edge - 238, bottom + 92)


## The special button glows when the ability is ready and dims while it cools down.
func set_special(ready: bool) -> void:
	var node: SkShape = _buttons[Pad.SPECIAL]
	node.stroke_color = Palette.GOLD if ready else Sk.with_alpha(Palette.WHITE, 0.12)
	node.alpha = 1.0 if ready else 0.45


func take_presses() -> Dictionary:
	var out := _pressed
	_pressed = {}
	return out


func began(touch: int, point: Vector2) -> void:
	var button := _button_at(point)
	if button >= 0:
		_button_touches[touch] = button
		_pressed[button] = true
		if button == Pad.JUMP:
			jump_held = true
		_highlight(button, true)
	elif point.x < _size.x / 2.0 and _stick_touch < 0:
		_stick_touch = touch
		_stick_origin = point
		_show_stick(point, point)


func moved(touch: int, point: Vector2) -> void:
	if touch != _stick_touch:
		return
	var dx := point.x - _stick_origin.x
	var dy := point.y - _stick_origin.y
	# The base follows a thumb that drags past its edge, so reversing direction is always quick.
	if absf(dx) > STICK_RANGE:
		_stick_origin.x = point.x - (STICK_RANGE if dx > 0.0 else -STICK_RANGE)
	var x := point.x - _stick_origin.x
	move_x = 0.0 if absf(x) < DEAD_ZONE else clampf(x / STICK_RANGE, -1.0, 1.0)
	var clamped_y := clampf(dy, -STICK_RANGE, STICK_RANGE)
	_show_stick(_stick_origin, Vector2(_stick_origin.x + x, _stick_origin.y + clamped_y))


func ended(touch: int) -> void:
	if touch == _stick_touch:
		_stick_touch = -1
		move_x = 0.0
		_show_stick(_stick_rest, _stick_rest)
	if _button_touches.has(touch):
		var button: int = _button_touches[touch]
		_button_touches.erase(touch)
		if button == Pad.JUMP:
			jump_held = _button_touches.values().has(Pad.JUMP)
		_highlight(button, _button_touches.values().has(button))


## Generous targets: the nearest button within 1.5 times its radius. -1 for none.
func _button_at(point: Vector2) -> int:
	var best := -1
	var best_d := INF
	for b: int in _buttons.keys():
		var d := point.distance_to(_buttons[b].position)
		if d <= _radius[b] * 1.5 and d < best_d:
			best = b
			best_d = d
	return best


func _show_stick(base: Vector2, knob: Vector2) -> void:
	_stick_base.position = base
	_stick_knob.position = knob


func _highlight(button: int, on: bool) -> void:
	_buttons[button].fill_color = Sk.with_alpha(Palette.WHITE, 0.28 if on else 0.06)
