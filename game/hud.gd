class_name Hud
extends Control
## Placeholder HUD until HUD.swift is ported: the announcements, messages and hints the scene sends, drawn
## plainly so the slice can be played. Same method names as the Swift HUD.

var _announce := Label.new()
var _message := Label.new()
var _hint := Label.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for l: Label in [_announce, _message, _hint]:
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_override("font", SkLabel.font_for("heavy"))
		add_child(l)
	_announce.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_announce.add_theme_font_size_override("font_size", 34)
	_announce.add_theme_color_override("font_color", Palette.WHITE)
	_announce.offset_top = 60
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 30)
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Sk.with_alpha(Palette.WHITE, 0.7))
	_hint.offset_bottom = -16


func announce(text: String) -> void:
	_announce.text = text
	_announce.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(1.4)
	t.tween_property(_announce, "modulate:a", 0.0, 0.5)


func show_message(text: String) -> void:
	_message.text = text


func hide_message() -> void:
	_message.text = ""


func show_hint(text: String) -> void:
	_hint.text = text
	_hint.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(5.0)
	t.tween_property(_hint, "modulate:a", 0.0, 1.0)


func flash_damage() -> void:
	pass


func set_heroes(_lead: Array, _partner: Array) -> void:
	pass
