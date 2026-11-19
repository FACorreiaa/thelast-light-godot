class_name UI
extends RefCounted
## Shared pieces for the menus and the dialogue panel, standing in for SwiftUI's system font, rounded
## backgrounds and plain buttons. Sizes are in points; the menu root is scaled to the screen.

const CYAN := Color(0.35, 0.92, 1.0)
static var _fonts: Dictionary = {}


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


## A plain button around `content`: a container, so wrapped text inside it lays out at the width it is given.
## No chrome of its own unless `normal` is given; a faint highlight on hover; acts on press.
static func button(content: Control, on_press: Callable, normal: StyleBox = null) -> PanelContainer:
	var b := PanelContainer.new()
	b.add_theme_stylebox_override("panel", normal if normal != null else StyleBoxEmpty.new())
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in content.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(content)
	b.mouse_entered.connect(func() -> void: b.modulate = Color(1.15, 1.15, 1.15))
	b.mouse_exited.connect(func() -> void: b.modulate = Color.WHITE)
	b.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and e.pressed) \
				or (e is InputEventScreenTouch and e.pressed):
			b.accept_event()
			on_press.call())
	return b
