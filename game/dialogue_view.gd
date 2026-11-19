class_name DialogueView
extends Control
## The panel a scene is read in. Port of DialogueView.swift. It sits over the paused game: a tap anywhere
## continues, and a line with answers waits until one is picked. Laid out in points under the menu root.

var story: StoryPresenter
var _dim := ColorRect.new()
var _panel := PanelContainer.new()
var _column := VBoxContainer.new()
var _choice_count := 0


func _init(p_story: StoryPresenter) -> void:
	story = p_story
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.color = Color(0, 0, 0, 0.35)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UI.on_tap(_dim, func() -> void: story.advance())
	add_child(_dim)
	_panel.add_theme_stylebox_override("panel", UI.box(Color(0.02, 0.04, 0.08, 0.94), 12, Sk.with_alpha(UI.CYAN, 0.35), 1, 18))
	_column.add_theme_constant_override("separation", 10)
	_panel.add_child(_column)
	add_child(_panel)
	story.changed.connect(_refresh)
	resized.connect(_place)
	_place()
	_refresh()


## Each speaker in their faction's light.
static func colour_for(speaker: String) -> Color:
	match speaker:
		"CAELEN":
			return Color(1, 1, 1, 0.85)
		"SERAPHINE":
			return Color(1.0, 0.82, 0.4)
		"NIMUE":
			return Color(0.78, 0.58, 1.0)
		"LAMPLIGHTER":
			return Color(1.0, 0.62, 0.3)
		"SWORN SHIELD", "SWORN SPEAR":
			return Color(0.98, 0.82, 0.42)
		"LAST ORACLE":
			return Color(0.93, 0.89, 0.8)
	return UI.CYAN


func _refresh() -> void:
	for c in _column.get_children():
		_column.remove_child(c)
		c.queue_free()
	var r := story.runner
	visible = r != null and not r.is_finished()
	_choice_count = 0
	if not visible:
		return
	var line := r.line
	_column.add_child(UI.label(String(line.speaker), 12, colour_for(line.speaker), "heavy", 2))
	var text := UI.label(String(line.text), 17, Color.WHITE, "medium")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(text)
	var choices := r.choices()
	_choice_count = choices.size()
	if choices.is_empty():
		var more := UI.label("continue  ▸", 12, Color(1, 1, 1, 0.5), "semibold")
		more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_column.add_child(UI.button(more, story.advance))
	else:
		for i in choices.size():
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.add_child(UI.label(str(i + 1), 12, UI.CYAN, "heavy"))
			var t := UI.label(String(choices[i].text), 15, Color.WHITE, "semibold")
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(t)
			var pad := MarginContainer.new()
			pad.add_theme_constant_override("margin_left", 14)
			pad.add_theme_constant_override("margin_right", 14)
			pad.add_child(row)
			pad.custom_minimum_size.y = 44
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			var b := UI.button(pad, story.choose.bind(i), UI.box(Sk.with_alpha(UI.CYAN, 0.1), 8, Sk.with_alpha(UI.CYAN, 0.5)))
			_column.add_child(b)


## Bottom centre, at most 620 points wide, 24 in from the sides and 20 up from the bottom; it grows upward
## to fit the text.
func _place() -> void:
	var w := minf(620.0, size.x - 48.0)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -w / 2.0
	_panel.offset_right = w / 2.0
	_panel.offset_bottom = -20.0
	_panel.offset_top = -20.0


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).keycode
	if _choice_count == 0 and (k == KEY_ENTER or k == KEY_KP_ENTER):
		story.advance()
	elif k >= KEY_1 and k <= KEY_9 and k - KEY_1 < _choice_count:
		story.choose(k - KEY_1)
	else:
		return
	get_viewport().set_input_as_handled()
