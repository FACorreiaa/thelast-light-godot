class_name UI
extends RefCounted
## Shared pieces for the menus and the dialogue panel, standing in for SwiftUI's system font, rounded
## backgrounds and plain buttons. Sizes are in points; the menu root is scaled to the screen.

const CYAN := Color(0.35, 0.92, 1.0)
static var _fonts: Dictionary = {}

## Whether the player is moving through menus with a gamepad or the arrow keys, not pointing. The focus ring
## shows only then; a tap or click hides it again.
static var navigating := false:
	set(v):
		if navigating == v:
			return
		navigating = v
		relay.navigating_changed.emit()
## Holds the signal, since a static var cannot be a signal of its own.
static var relay := _Relay.new()


class _Relay:
	extends RefCounted
	signal navigating_changed


## Tracks how the player is driving the menus. MenuOverlay feeds it every input event.
static func note_input(e: InputEvent) -> void:
	if e is InputEventJoypadButton or (e is InputEventJoypadMotion and absf((e as InputEventJoypadMotion).axis_value) > 0.5):
		navigating = true
	elif e is InputEventKey and e.pressed and (e.is_action("ui_up") or e.is_action("ui_down") or e.is_action("ui_left") \
			or e.is_action("ui_right") or e.is_action("ui_focus_next") or e.is_action("ui_focus_prev")):
		navigating = true
	elif e is InputEventMouseButton or e is InputEventScreenTouch:
		navigating = false


## The ring drawn around whatever has focus while navigating.
static func _ring() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.set_border_width_all(2)
	s.border_color = CYAN
	s.set_corner_radius_all(10)
	s.corner_detail = 8
	s.anti_aliasing = true
	s.expand_margin_left = 3
	s.expand_margin_right = 3
	s.expand_margin_top = 3
	s.expand_margin_bottom = 3
	return s


## Lets a gamepad or the keyboard reach `c`: focusable, a ring while it has focus and the player is
## navigating, and `ui_accept` (A, Enter, Space) acts.
static func focusable(c: Control, action: Callable) -> void:
	c.focus_mode = Control.FOCUS_ALL
	var ring := _ring()
	c.draw.connect(func() -> void:
		if navigating and c.has_focus():
			c.draw_style_box(ring, Rect2(Vector2.ZERO, c.size)))
	c.focus_entered.connect(c.queue_redraw)
	c.focus_exited.connect(c.queue_redraw)
	relay.navigating_changed.connect(func() -> void:
		if is_instance_valid(c) and c.has_focus():
			c.queue_redraw())
	c.gui_input.connect(func(e: InputEvent) -> void:
		if e.is_action_pressed("ui_accept") and not e.is_echo():
			c.accept_event()
			action.call())


## The system font at a SwiftUI weight ("regular", "medium", "semibold", "bold", "heavy"), with optional
## tracking in points.
static func font(weight := "regular", tracking := 0.0, italic := false) -> Font:
	var key := "%s/%s/%s" % [weight, tracking, italic]
	if not _fonts.has(key):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["SF Pro Text", ".AppleSystemUIFont", "Helvetica Neue", "Segoe UI", "Arial"])
		f.font_weight = {"medium": 500, "semibold": 600, "bold": 700, "heavy": 800, "black": 900}.get(weight, 400)
		f.font_italic = italic
		if tracking == 0.0:
			_fonts[key] = f
		else:
			var v := FontVariation.new()
			v.base_font = f
			v.spacing_glyph = int(round(tracking))
			_fonts[key] = v
	return _fonts[key]


static func label(text: String, size: float, color: Color, weight := "regular", tracking := 0.0, italic := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight, tracking, italic))
	l.add_theme_font_size_override("font_size", int(round(size)))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func box(fill: Color, radius: float, border := Color(0, 0, 0, 0), border_width := 1, pad := 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.corner_detail = 8
	s.bg_color = fill
	s.set_corner_radius_all(int(round(radius)))
	s.border_color = border
	if border.a > 0.0:
		s.set_border_width_all(border_width)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	s.anti_aliasing = true
	return s


## Makes `c` act on a tap, as a SwiftUI button does: on release inside it, not on touch-down, and not when the
## finger moved off or dragged. Only mouse buttons are read: on a phone Godot turns each touch into one
## (input_devices/pointing/emulate_mouse_from_touch, on by default), and reading the touch as well would act
## twice. `down(bool)` is told when the press starts and ends, for a pressed look. With `drag(Vector2)`, a
## press that turns into a drag passes its movement on, and so does the mouse wheel, so a list made of these
## still scrolls.
static func on_tap(c: Control, action: Callable, down := Callable(), drag := Callable(), focus := true) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	if focus:
		focusable(c, action)
	var state := {"down": false, "dragging": false, "at": Vector2.ZERO}
	var lift := func() -> void:
		if state.down and down.is_valid():
			down.call(false)
		state.down = false
	c.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			var m := e as InputEventMouseButton
			if m.button_index == MOUSE_BUTTON_LEFT:
				c.accept_event()
				if m.pressed:
					state.down = true
					state.dragging = false
					state.at = m.position
					if down.is_valid():
						down.call(true)
				else:
					var tapped: bool = state.down and Rect2(Vector2.ZERO, c.size).has_point(m.position)
					lift.call()
					state.dragging = false
					if tapped:
						action.call()
			elif drag.is_valid() and m.pressed and m.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				c.accept_event()
				drag.call(Vector2(0, WHEEL_STEP if m.button_index == MOUSE_BUTTON_WHEEL_UP else -WHEEL_STEP) * m.factor)
		elif e is InputEventMouseMotion and (state.down or state.dragging):
			var mm := e as InputEventMouseMotion
			if state.down and mm.position.distance_to(state.at) > TAP_SLOP:
				lift.call()
				if drag.is_valid():
					state.dragging = true
					# The movement so far, so the list keeps up with the finger.
					drag.call(mm.position - state.at)
					return
			if state.dragging:
				c.accept_event()
				drag.call(mm.relative))
	c.mouse_exited.connect(func() -> void:
		if state.down:
			lift.call())


## Points one wheel notch scrolls.
const WHEEL_STEP := 40.0


## How far, in points, a finger may move before a tap becomes a drag.
const TAP_SLOP := 10.0


## A plain button around `content`: a container, so wrapped text inside it lays out at the width it is given.
## No chrome of its own unless `normal` is given; dims slightly while pressed.
static func button(content: Control, on_press: Callable, normal: StyleBox = null, drag := Callable()) -> PanelContainer:
	var b := PanelContainer.new()
	b.add_theme_stylebox_override("panel", normal if normal != null else StyleBoxEmpty.new())
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in content.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(content)
	on_tap(b, on_press, func(pressed: bool) -> void: b.modulate = Color(1, 1, 1, 0.7) if pressed else Color.WHITE, drag)
	return b
