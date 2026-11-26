class_name MenuOverlay
extends Control
## Title, pause, faction pick, results, settings and chapter list. Port of MenuViews.swift and
## FactionPick.swift. Drawn over the game, which is frozen behind them. Laid out in points under the menu
## root, which GameApp scales to the screen. Rebuilt whenever the screen or sheet changes.

const CYAN := UI.CYAN
const GOLD := Color(1.0, 0.82, 0.4)
const PANEL_FILL := Color(0.02, 0.04, 0.08, 0.94)

## New Game: what each card says. Names, titles, themes and quotes come from the concept art; the motive
## lines are draft writing for the creator's verdict.
const FACTION_CARDS := [
	{"faction": "foundry", "lead": "caelen", "name": "THE FOUNDRY", "themes": "Science · Control · Redemption",
		"title": "The Creator", "quote": "I built a solution. I didn't expect it to feel like this.",
		"motive": "Wake on the line. Find out what you built.", "colour": Color(0.35, 0.92, 1.0)},
	{"faction": "dawnfaith", "lead": "seraphine", "name": "THE DAWNFAITH", "themes": "Faith · Sacrifice · Renewal",
		"title": "The Oracle", "quote": "The light listens. Even now.",
		"motive": "Walk into the Foundry to see what it knows about the light.", "colour": Color(1.0, 0.82, 0.4)},
	{"faction": "lanternCities", "lead": "nimue", "name": "THE LANTERN CITIES", "themes": "Trade · Survival · Opportunity",
		"title": "The Smuggler", "quote": "The night hides more than you think.",
		"motive": "Slip in by the undercroft and bring your runners home.", "colour": Color(0.78, 0.58, 1.0)},
]

var app: GameApp
## The safe-area insets this overlay is placed within (left, top, right, bottom), in points. Backdrops reach
## past them to the screen's edges.
var safe_insets := Rect2()
## Key -> what it does on the current screen (Return, Escape, digits), standing in for SwiftUI's
## keyboardShortcut. The top sheet's keys win over the screen's.
var _keys: Dictionary = {}
## The screen's main button, where a gamepad starts.
var _primary: Control


func _init(p_app: GameApp) -> void:
	app = p_app
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.screen_changed.connect(_rebuild)
	resized.connect(_rebuild)


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_keys = {}
	_primary = null
	match app.screen:
		GameApp.Screen.TITLE:
			_backdrop(0.72)
			_title_menu()
		GameApp.Screen.PAUSED:
			_backdrop(0.6)
			_pause_menu()
		GameApp.Screen.FACTION_PICK:
			_backdrop(0.82)
			_faction_pick()
		GameApp.Screen.RESULTS:
			_backdrop(0.65)
			_results_screen()
	if app.sheet != GameApp.Sheet.NONE:
		# A sheet's keys replace the screen's underneath it.
		_keys = {}
		var close := func() -> void: app.sheet = GameApp.Sheet.NONE
		UI.on_tap(_backdrop(0.5), close, Callable(), Callable(), false)
		if app.sheet == GameApp.Sheet.SETTINGS:
			_settings_panel(close)
		else:
			_chapter_panel(close)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_first.call_deferred()


## A gamepad needs somewhere to start: the screen's primary button, else the first thing that takes focus.
## The top sheet's controls come last in the tree, so they win.
func _focus_first() -> void:
	var all: Array[Control] = []
	for c in find_children("*", "Control", true, false):
		var k := c as Control
		if k.focus_mode == Control.FOCUS_ALL and k.is_visible_in_tree():
			all.append(k)
	if all.is_empty():
		return
	if app.sheet != GameApp.Sheet.NONE:
		# The sheet's own controls: those inside the last panel built.
		var panel := get_child(get_child_count() - 1)
		for k in all:
			if panel.is_ancestor_of(k) and not k is HSlider:
				k.grab_focus()
				return
	if _primary != null and is_instance_valid(_primary):
		_primary.grab_focus()
	else:
		all[0].grab_focus()


func _input(event: InputEvent) -> void:
	UI.note_input(event)
	if not is_visible_in_tree() or not (event is InputEventJoypadButton) or not event.pressed:
		return
	var b := (event as InputEventJoypadButton).button_index
	# B goes back, as Escape does; Start also leaves the pause menu.
	if (b == JOY_BUTTON_B or (b == JOY_BUTTON_START and app.screen == GameApp.Screen.PAUSED)) and _keys.has(KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		(_keys[KEY_ESCAPE] as Callable).call()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).keycode
	if k == KEY_KP_ENTER:
		k = KEY_ENTER
	if _keys.has(k):
		get_viewport().set_input_as_handled()
		(_keys[k] as Callable).call()


# MARK: Pieces


func _backdrop(opacity: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, opacity)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.offset_left = -safe_insets.position.x
	r.offset_top = -safe_insets.position.y
	r.offset_right = safe_insets.size.x
	r.offset_bottom = safe_insets.size.y
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


## Puts `c` in the middle of the screen at `width` points wide; it grows from the centre to fit its height.
func _center(c: Control, width: float) -> Control:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH
	c.offset_left = -width / 2.0
	c.offset_right = width / 2.0
	c.offset_top = 0
	c.offset_bottom = 0
	add_child(c)
	return c


## SwiftUI `.padding(.horizontal, 48).frame(maxWidth: 900)`: the width a two-column screen gets.
func _wide(max_width: float, pad: float) -> float:
	return minf(max_width, size.x) - pad * 2.0


func _menu_button(title: String, action: Callable, primary := false, shortcut := KEY_NONE) -> Control:
	var l := UI.label(title, 15, Color.BLACK if primary else Color.WHITE, "bold", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size.y = 46
	var style := UI.box(CYAN if primary else Sk.with_alpha(CYAN, 0.08), 8, Color(0, 0, 0, 0) if primary else Sk.with_alpha(CYAN, 0.45))
	var b := UI.button(l, action, style)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if shortcut != KEY_NONE:
		_keys[shortcut] = action
	if primary:
		_primary = b
	return b


func _text_button(title: String, action: Callable, min_size: Vector2, align := HORIZONTAL_ALIGNMENT_CENTER) -> Control:
	var l := UI.label(title, 14, Color(1, 1, 1, 0.8), "semibold")
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = min_size
	return UI.button(l, action)


static func _vbox(spacing: float) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(spacing))
	return v


static func _hbox(spacing: float) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(spacing))
	return h


static func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## A title too long for its column shrinks (SwiftUI minimumScaleFactor(0.6), lineLimit(1)).
static func _fit(l: Label, width: float) -> void:
	var font_size := l.get_theme_font_size("font_size")
	var font := l.get_theme_font("font")
	var w := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if w > width and width > 0.0:
		l.add_theme_font_size_override("font_size", int(maxf(font_size * 0.6, floorf(font_size * width / w))))


## The rounded frame the settings and chapters panels sit in, with a title and Done.
func _panel_frame(title: String, close: Callable, content: Array[Control]) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(PANEL_FILL, 14, Sk.with_alpha(CYAN, 0.35), 1, 20))
	var v := _vbox(14)
	var head := _hbox(0)
	var t := UI.label(title, 13, CYAN, "heavy", 3)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(t)
	head.add_child(_spacer())
	head.add_child(_text_button("Done", close, Vector2(44, 44)))
	_keys[KEY_ESCAPE] = close
	v.add_child(head)
	for c in content:
		v.add_child(c)
	panel.add_child(v)
	# Swallow taps on the panel so they do not reach the backdrop, which closes it.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_center(panel, minf(440.0, size.x - 32.0))


# MARK: Screens


func _title_menu() -> void:
	var row := _hbox(40)
	var left := _vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	var name := UI.label("THE LAST LIGHT", 40, Color.WHITE, "black", 5)
	var width := _wide(900, 48)
	_fit(name, width - 240 - 40)
	left.add_child(name)
	var c := app.scene.chapter_at(app.scene.current_level())
	left.add_child(UI.label("CHAPTER %d  ·  %s" % [c.number, String(c.title).to_upper()], 13, CYAN, "heavy", 3))
	row.add_child(left)

	var right := _vbox(10)
	right.custom_minimum_size.x = 240
	if app.has_progress():
		right.add_child(_menu_button("CONTINUE", app.continue_game, true, KEY_ENTER))
		var detail := UI.label(app.continue_detail(), 12, Color(1, 1, 1, 0.55), "medium")
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right.add_child(detail)
		right.add_child(_menu_button("NEW GAME", app.new_game))
	else:
		right.add_child(_menu_button("BEGIN", app.new_game, true, KEY_ENTER))
	right.add_child(_menu_button("CHAPTERS", func() -> void: app.sheet = GameApp.Sheet.CHAPTERS))
	right.add_child(_menu_button("SETTINGS", func() -> void: app.sheet = GameApp.Sheet.SETTINGS))
	row.add_child(right)
	_center(row, width)


func _pause_menu() -> void:
	var v := _vbox(10)
	var t := UI.label("PAUSED", 13, CYAN, "heavy", 4)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.custom_minimum_size.y = 15 + 6
	v.add_child(t)
	v.add_child(_menu_button("RESUME", app.resume, true, KEY_ESCAPE))
	v.add_child(_menu_button("RETRY FROM CHECKPOINT", app.retry_from_checkpoint))
	v.add_child(_menu_button("RESTART LEVEL", app.restart_level))
	var pair := _hbox(10)
	pair.add_child(_menu_button("CHAPTERS", func() -> void: app.sheet = GameApp.Sheet.CHAPTERS))
	pair.add_child(_menu_button("SETTINGS", func() -> void: app.sheet = GameApp.Sheet.SETTINGS))
	v.add_child(pair)
	v.add_child(_menu_button("QUIT TO TITLE", app.quit_to_title))
	_center(v, 320)


func _settings_panel(close: Callable) -> void:
	var rows: Array[Control] = []
	var sound := _vbox(6)
	sound.add_child(UI.label("Sound", 14, Color.WHITE, "semibold"))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = app.settings.volume
	slider.custom_minimum_size.y = 28
	slider.focus_mode = Control.FOCUS_ALL
	var ring := UI._ring()
	slider.draw.connect(func() -> void:
		if UI.navigating and slider.has_focus():
			slider.draw_style_box(ring, Rect2(Vector2(0, 2), slider.size - Vector2(0, 4))))
	slider.focus_entered.connect(slider.queue_redraw)
	slider.focus_exited.connect(slider.queue_redraw)
	var empty := StyleBoxEmpty.new()
	slider.add_theme_stylebox_override("focus", empty)
	var track := UI.box(Color(1, 1, 1, 0.18), 2)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	slider.add_theme_stylebox_override("slider", track)
	var fill := UI.box(CYAN, 2)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_icon_override("grabber", _knob(22))
	slider.add_theme_icon_override("grabber_highlight", _knob(22))
	slider.value_changed.connect(func(v: float) -> void: _change(func(s: Settings) -> void: s.volume = v))
	sound.add_child(slider)
	rows.append(sound)
	if OS.has_feature("mobile"):
		rows.append(_toggle("Vibration", app.settings.haptics, func(s: Settings, on: bool) -> void: s.haptics = on))

	var diff := _vbox(6)
	diff.add_child(UI.label("Difficulty", 14, Color.WHITE, "semibold"))
	diff.add_child(_segmented(Settings.DIFFICULTY_NAMES, app.settings.difficulty,
		func(i: int) -> void: _change(func(s: Settings) -> void: s.difficulty = i as Settings.Difficulty)))
	var note := UI.label("Changes how hard enemies hit. Takes effect when a level starts.", 12, Color(1, 1, 1, 0.5))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diff.add_child(note)
	rows.append(diff)
	rows.append(_toggle("Screen shake", app.settings.screen_shake, func(s: Settings, on: bool) -> void: s.screen_shake = on))
	rows.append(_toggle("Debug overlay", app.settings.debug_overlay, func(s: Settings, on: bool) -> void: s.debug_overlay = on))
	_panel_frame("SETTINGS", close, rows)


## Changes a copy of the settings and hands it to the game, which saves it.
func _change(edit: Callable) -> void:
	var s := app.settings.copy()
	edit.call(s)
	app.apply_settings(s)


func _toggle(title: String, on: bool, edit: Callable) -> Control:
	var row := _hbox(0)
	row.custom_minimum_size.y = 36
	var l := UI.label(title, 14, Color.WHITE, "semibold")
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	row.add_child(l)
	row.add_child(_spacer())
	var sw := Switch.new(on)
	sw.toggled.connect(func(v: bool) -> void: _change(func(s: Settings) -> void: edit.call(s, v)))
	row.add_child(sw)
	return row


## A segmented picker, as SwiftUI's on a dark background: a rounded track, the chosen segment raised.
func _segmented(names: Array, chosen: int, pick: Callable) -> Control:
	var track := PanelContainer.new()
	var ts := UI.box(Color(1, 1, 1, 0.1), 8)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		ts.set_content_margin(side, 2)
	track.add_theme_stylebox_override("panel", ts)
	var row := _hbox(2)
	var segments: Array[PanelContainer] = []
	var labels: Array[Label] = []
	# As iOS draws it: the chosen segment a white pill with dark text.
	var paint := func(sel: int) -> void:
		for j in segments.size():
			segments[j].add_theme_stylebox_override("panel", UI.box(Color.WHITE, 7) if j == sel else StyleBoxEmpty.new())
			labels[j].add_theme_color_override("font_color", Color.BLACK if j == sel else Color(1, 1, 1, 0.85))
	for i in names.size():
		var l := UI.label(String(names[i]), 13, Color.WHITE, "semibold")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.custom_minimum_size.y = 28
		labels.append(l)
		var b := UI.button(l, func() -> void:
			paint.call(i)
			pick.call(i), StyleBoxEmpty.new())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segments.append(b)
		row.add_child(b)
	paint.call(chosen)
	track.add_child(row)
	return track


static func _knob(d: int) -> Texture2D:
	var img := Image.create(d * 2, d * 2, false, Image.FORMAT_RGBA8)
	var r := float(d)
	for y in d * 2:
		for x in d * 2:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			img.set_pixel(x, y, Color(1, 1, 1, clampf(r - 1.0 - dist, 0.0, 1.0)))
	img.resize(d, d, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


func _chapter_panel(close: Callable) -> void:
	var scroll := ScrollContainer.new()
	# The rows take the finger, so they move the list themselves when it drags.
	var scroll_by := func(delta: Vector2) -> void: scroll.scroll_vertical -= int(round(delta.y))
	var list := _vbox(8)
	for entry: Dictionary in app.scene.chapter_list():
		var head := UI.label("CHAPTER %d  ·  %s" % [entry.number, String(entry.title).to_upper()], 11, Color(1, 1, 1, 0.5), "heavy", 2)
		if int(entry.start) != 0:
			var pad := MarginContainer.new()
			pad.add_theme_constant_override("margin_top", 6)
			pad.add_child(head)
			list.add_child(pad)
		else:
			list.add_child(head)
		var names: Array = entry.names
		for i in names.size():
			var note := "opening" if int(entry.start) == 0 and i == 0 else ""
			list.add_child(_chapter_row(str(i + 1), names[i], note, app.play_chapter.bind(int(entry.start) + i), scroll_by))
	list.add_child(_chapter_row("·", "Training Room", "waves", app.training_room, scroll_by))
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# SwiftUI's indicator is hidden at rest; the list still scrolls by drag or wheel.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	scroll.custom_minimum_size.y = minf(260.0, size.y - 136.0)
	scroll.add_child(list)
	_panel_frame("CHAPTERS", close, [scroll] as Array[Control])


func _chapter_row(number: String, name: String, note: String, action: Callable, drag: Callable) -> Control:
	var row := _hbox(12)
	var n := UI.label(number, 13, GOLD, "heavy")
	n.custom_minimum_size.x = 18
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.size_flags_vertical = Control.SIZE_FILL
	row.add_child(n)
	var t := UI.label(name, 15, Color.WHITE, "semibold")
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.size_flags_vertical = Control.SIZE_FILL
	row.add_child(t)
	row.add_child(_spacer())
	if note != "":
		var nl := UI.label(note, 12, Color(1, 1, 1, 0.45), "medium")
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nl.size_flags_vertical = Control.SIZE_FILL
		row.add_child(nl)
	row.custom_minimum_size.y = 44
	var style := UI.box(Sk.with_alpha(CYAN, 0.07), 8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	return UI.button(row, action, style, drag)


func _results_screen() -> void:
	var r := app.result
	var is_last := String(r.ending) != ""
	var row := _hbox(40)
	var left := _vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(UI.label("CHAPTER %d COMPLETE" % r.chapter_number if is_last else "LEVEL CLEAR", 13, GOLD if is_last else CYAN, "heavy", 3))
	var width := _wide(900, 48)
	var name := UI.label(String(r.chapter_title) if is_last else String(r.name), 34, Color.WHITE, "black")
	_fit(name, width - 240 - 40)
	left.add_child(name)
	if is_last:
		var ending := UI.label(String(r.ending), 14, Color(1, 1, 1, 0.7))
		ending.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_top", 2)
		pad.add_child(ending)
		left.add_child(pad)
	# Abilities this chapter's boss unlocked (Progression): one card each, the lead's first.
	for u: Dictionary in r.get("unlocks", []):
		var card := _vbox(2)
		var cpad := MarginContainer.new()
		cpad.add_theme_constant_override("margin_top", 6)
		card.add_child(UI.label("NEW ABILITY", 11, GOLD, "heavy", 3))
		card.add_child(UI.label(String(u.name), 20, Color.WHITE, "black"))
		var line := UI.label(String(u.card), 13, Color(1, 1, 1, 0.75))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(line)
		card.add_child(UI.label(String(u.button).to_upper(), 11, CYAN, "heavy", 2))
		cpad.add_child(card)
		left.add_child(cpad)
	var stats := _hbox(22)
	var total := int(round(float(r.seconds)))
	stats.add_child(_stat("TIME", "%d:%02d" % [total / 60, total % 60]))
	stats.add_child(_stat("DEFEATED", str(r.defeated)))
	if int(r.hidden) > 0:
		stats.add_child(_stat("FOUND", "%d/%d" % [r.found, r.hidden]))
	stats.add_child(_stat("DOWNED", str(r.downs)))
	var spad := MarginContainer.new()
	spad.add_theme_constant_override("margin_top", 10)
	spad.add_child(stats)
	left.add_child(spad)
	row.add_child(left)

	var right := _vbox(10)
	right.custom_minimum_size.x = 240
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	if is_last and not r.is_final:
		right.add_child(_menu_button("NEXT CHAPTER", app.next_level, true, KEY_ENTER))
		right.add_child(_menu_button("PLAY AGAIN", app.replay_chapter))
		right.add_child(_menu_button("BACK TO TITLE", app.finish_chapter))
	elif is_last:
		right.add_child(_menu_button("BACK TO TITLE", app.finish_chapter, true, KEY_ENTER))
		right.add_child(_menu_button("PLAY AGAIN", app.replay_chapter))
	else:
		right.add_child(_menu_button("CONTINUE", app.next_level, true, KEY_ENTER))
		right.add_child(_menu_button("REPLAY LEVEL", app.restart_level))
		right.add_child(_menu_button("QUIT TO TITLE", app.quit_to_title))
	row.add_child(right)
	_center(row, width)


func _stat(label: String, value: String) -> Control:
	var v := _vbox(3)
	var val := UI.label(value, 22, Color.WHITE, "bold")
	val.add_theme_font_override("font", _mono_digits(UI.font("bold")))
	v.add_child(val)
	v.add_child(UI.label(label, 11, Color(1, 1, 1, 0.5), "heavy", 1.5))
	return v


## SwiftUI `.monospacedDigit()`: tabular figures.
static func _mono_digits(base: Font) -> Font:
	var f := FontVariation.new()
	f.base_font = base
	f.opentype_features = {"tnum": 1}
	return f


func _faction_pick() -> void:
	var v := _vbox(12)
	var head := _hbox(0)
	head.add_child(_text_button("Back", func() -> void: app.screen = GameApp.Screen.TITLE, Vector2(44, 36), HORIZONTAL_ALIGNMENT_LEFT))
	_keys[KEY_ESCAPE] = func() -> void: app.screen = GameApp.Screen.TITLE
	head.add_child(_spacer())
	var titles := _vbox(2)
	var t := UI.label("CHOOSE A FACTION", 13, Color.WHITE, "heavy", 3)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titles.add_child(t)
	var sub := UI.label("Three ways into the Foundry.", 12, Color(1, 1, 1, 0.55))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titles.add_child(sub)
	head.add_child(titles)
	head.add_child(_spacer())
	var balance := Control.new()
	balance.custom_minimum_size = Vector2(44, 1)
	head.add_child(balance)
	v.add_child(head)

	var cards := _hbox(12)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The portrait takes what height the card has spare, between 56 and 112 points (SwiftUI: minHeight 56,
	# idealHeight 112, lowest layout priority). Start at the most and give back whatever overflows.
	var portraits: Array[Control] = []
	for i in FACTION_CARDS.size():
		var card: Dictionary = FACTION_CARDS[i]
		var choose := app.begin.bind(String(card.lead))
		var c := _faction_card(card, choose, 112.0)
		portraits.append(c.find_children("*", "TextureRect", true, false)[0])
		cards.add_child(c)
		_keys[KEY_1 + i] = choose
	v.add_child(cards)
	var w := minf(940.0, size.x) - 40.0
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.anchor_top = 0.0
	v.anchor_bottom = 1.0
	v.offset_left = -w / 2.0
	v.offset_right = w / 2.0
	v.offset_top = 12
	v.offset_bottom = -12
	add_child(v)
	_fit_portraits.call_deferred(v, portraits)


func _fit_portraits(v: Control, portraits: Array[Control]) -> void:
	var over := v.get_combined_minimum_size().y - v.size.y
	if over <= 0.0:
		return
	for p in portraits:
		p.custom_minimum_size.y = maxf(56.0, 112.0 - over)


func _faction_card(card: Dictionary, choose: Callable, portrait_h: float) -> Control:
	var colour: Color = card.colour
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	box.add_child(CardBack.new(Sk.with_alpha(colour, 0.16), Color(0, 0, 0, 0.55), Sk.with_alpha(colour, 0.5), 12))
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	var v := _vbox(6)
	v.add_child(UI.label(String(card.name), 11, colour, "heavy", 2))
	v.add_child(UI.label(String(card.themes), 10, Color(1, 1, 1, 0.5), "medium"))
	var portrait := Portrait.new(String(card.lead))
	portrait.custom_minimum_size.y = portrait_h
	v.add_child(portrait)
	v.add_child(UI.label(String(card.lead).capitalize(), 22, Color.WHITE, "black"))
	v.add_child(UI.label(String(card.title).to_upper(), 10, Sk.with_alpha(colour, 0.85), "heavy", 2))
	var quote := UI.label("“%s”" % card.quote, 12, Color(1, 1, 1, 0.8), "regular", 0.0, true)
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(quote)
	var motive := UI.label(String(card.motive), 12, Color(1, 1, 1, 0.6), "medium")
	motive.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(motive)
	pad.add_child(v)
	box.add_child(pad)
	for c in box.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A card dips slightly when pressed, and chooses on release.
	box.resized.connect(func() -> void: box.pivot_offset = box.size / 2.0)
	UI.on_tap(box, choose, func(pressed: bool) -> void:
		box.create_tween().tween_property(box, "scale", Vector2(0.97, 0.97) if pressed else Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT))
	return box


# MARK: Parts


## A rounded card with a top-to-bottom gradient and a hairline border.
class CardBack:
	extends Control
	var top: Color
	var bottom: Color
	var border: Color
	var radius: float

	func _init(p_top: Color, p_bottom: Color, p_border: Color, p_radius: float) -> void:
		top = p_top
		bottom = p_bottom
		border = p_border
		radius = p_radius
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var pts := PackedVector2Array()
		var r := minf(radius, minf(size.x, size.y) / 2.0)
		var corners := [Vector2(size.x - r, r), Vector2(size.x - r, size.y - r), Vector2(r, size.y - r), Vector2(r, r)]
		for c in 4:
			for k in 9:
				var a := -PI / 2.0 + (c + k / 8.0) * PI / 2.0
				pts.append(corners[c] + Vector2(cos(a), sin(a)) * r)
		var cols := PackedColorArray()
		for p in pts:
			cols.append(top.lerp(bottom, p.y / maxf(size.y, 1.0)))
		draw_polygon(pts, cols)
		var ring := pts.duplicate()
		ring.append(pts[0])
		draw_polyline(ring, border, 1.0, true)


## SwiftUI Toggle on a dark background: a capsule, cyan when on, with a white knob.
class Switch:
	extends Control
	signal toggled(on: bool)
	var on: bool

	func _init(p_on: bool) -> void:
		on = p_on
		custom_minimum_size = Vector2(51, 31)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		UI.on_tap(self, func() -> void:
			on = not on
			queue_redraw()
			toggled.emit(on))

	func _draw() -> void:
		var h := size.y
		var track := StyleBoxFlat.new()
		track.bg_color = MenuOverlay.CYAN if on else Color(1, 1, 1, 0.16)
		track.set_corner_radius_all(int(h / 2.0))
		track.corner_detail = 12
		track.anti_aliasing = true
		draw_style_box(track, Rect2(Vector2.ZERO, size))
		var x := size.x - h / 2.0 if on else h / 2.0
		draw_circle(Vector2(x, h / 2.0), h / 2.0 - 2.0, Color.WHITE, true, -1.0, true)


## The lead standing in the card: the same figure as in the game, idling, in its own small world. Drawn
## into a viewport at the card's real pixel size, so it stays sharp under the menu's scale.
class Portrait:
	extends TextureRect
	var world: World
	var node: FighterNode
	var holder := Node2D.new()
	var id: int
	var viewport := SubViewport.new()

	func _init(kind: String) -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_SCALE
		world = World.training(Tuning.load_default(), 1, 0.0, 400.0)
		id = world.spawn(kind, 200.0, 0.0, 1)
		world.control(id)
		viewport.transparent_bg = true
		viewport.msaa_2d = Viewport.MSAA_2X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		node = FighterNode.new(kind)
		holder.add_child(node)
		viewport.add_child(holder)
		texture = viewport.get_texture()

	func _process(_delta: float) -> void:
		var k := get_global_transform_with_canvas().get_scale().x
		var px := Vector2i(maxi(1, int(round(size.x * k))), maxi(1, int(round(size.y * k))))
		if viewport.size != px:
			viewport.size = px
		world.step(InputFrame.neutral())
		var f := world.fighter(id)
		if f == null:
			return
		node.sync(f, world.frame)
		node.position = Vector2.ZERO
		# Centred, feet near the bottom, with room above for a crown or hair. The world is y-up.
		var s := minf(1.1, (size.y - 16.0) / (f.spec.height + 34.0)) * k
		holder.scale = Vector2(s, -s)
		holder.position = Vector2(size.x / 2.0, size.y - 8.0) * k
