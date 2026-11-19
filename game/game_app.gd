class_name GameApp
extends Node
## The scene, the story and the menus around them. Port of `Game` and `GameView` in LastLightApp.swift.
## The menus call these methods; the scene asks for the pause menu through `pause_requested`.
##
## Command line (after `--`), besides GameScene's: --menu paused|factions|settings|chapters|results|chapter
## opens that menu, for checking it by screenshot. --demo, --level, --room and --scene skip the title.

signal screen_changed

enum Screen { TITLE, PLAYING, PAUSED, FACTION_PICK, RESULTS }
enum Sheet { NONE, SETTINGS, CHAPTERS }

var scene := GameScene.new()
var story := StoryPresenter.new()
var settings := Settings.load_saved()
var screen := Screen.TITLE:
	set(v):
		screen = v
		scene.frozen = v != Screen.PLAYING
		screen_changed.emit()
var sheet := Sheet.NONE:
	set(v):
		sheet = v
		screen_changed.emit()
## The results screen's numbers while screen is RESULTS (GameScene._level_result).
var result: Dictionary = {}

## Menus and dialogue, laid out in points (about 874 x 402 on a phone) and scaled to the screen.
var menu_layer := CanvasLayer.new()
var menu_root := Control.new()
var dialogue: DialogueView
var menus: MenuOverlay


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_add_pad_to_ui_actions()
	scene.story = story
	add_child(scene)
	scene.apply_settings(settings)
	menu_layer.layer = 10
	add_child(menu_layer)
	menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Glyphs are rasterised at their size times the menu's scale (3x on a phone), not scaled up blurry.
	menu_root.oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	menu_layer.add_child(menu_root)
	dialogue = DialogueView.new(story)
	menu_root.add_child(dialogue)
	menus = MenuOverlay.new(self)
	menu_root.add_child(menus)
	get_viewport().size_changed.connect(_layout)
	_layout()

	# Launch arguments used for checking a level skip the title.
	var direct := args.has("--demo") or args.has("--level") or args.has("--room") or args.has("--scene")
	screen = Screen.PLAYING if direct else Screen.TITLE
	scene.pause_requested.connect(pause)
	scene.demo_shows_results = args.has("--results")
	scene.level_completed.connect(_on_level_completed)
	var i := args.find("--scene")
	if i >= 0 and i + 1 < args.size():
		story.forget([args[i + 1]])
		story.begin(args[i + 1])
		for _n in (int(args[i + 2]) if i + 2 < args.size() else 0):
			story.advance()
	i = args.find("--menu")
	if i >= 0 and i + 1 < args.size():
		match args[i + 1]:
			"paused":
				screen = Screen.PAUSED
			"factions":
				screen = Screen.FACTION_PICK
			"settings":
				sheet = Sheet.SETTINGS
			"chapters":
				sheet = Sheet.CHAPTERS
			"results", "chapter":
				var end := args[i + 1] == "chapter"
				var c: Dictionary = scene.chapter_list()[0]
				result = {"name": "The Protocol" if end else "The Machine Hall", "index": 3 if end else 2,
					"chapter_number": 1, "chapter_title": c.title, "ending": c.ending if end else "", "chapter_start": 0,
					"is_final": false, "seconds": 263.0, "defeated": 14, "downs": 1, "found": 3, "hidden": 5}
				screen = Screen.RESULTS


## Godot's default ui_accept and ui_cancel are keyboard only; a gamepad's A and B join them, so menus work
## with a pad alone (the d-pad and left stick are already in ui_up/down/left/right).
static func _add_pad_to_ui_actions() -> void:
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var e := InputEventJoypadButton.new()
		e.device = -1
		e.button_index = pair[1]
		if not InputMap.action_has_event(pair[0], e):
			InputMap.action_add_event(pair[0], e)


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var ui := maxf(0.5, minf(size.y / 402.0, size.x / 700.0))
	menu_root.scale = Vector2(ui, ui)
	menu_root.position = Vector2.ZERO
	menu_root.size = size / ui
	if menus != null:
		# Menus keep their content inside the safe area, as SwiftUI does; their backdrops still fill the screen.
		var inset := scene.safe_insets()
		menus.safe_insets = inset
		menus.offset_left = inset.position.x
		menus.offset_top = inset.position.y
		menus.offset_right = -inset.size.x
		menus.offset_bottom = -inset.size.y


func _on_level_completed(p_result: Dictionary) -> void:
	# A moment for the clear sound and the last effects before the screen comes up.
	await get_tree().create_timer(1.2).timeout
	# A closing scene plays first.
	while story.is_active():
		await get_tree().create_timer(0.2).timeout
	if screen != Screen.PLAYING:
		return
	if scene.demo_shows_results:
		printerr("RESULTS ", p_result)
	result = p_result
	screen = Screen.RESULTS


func apply_settings(p_settings: Settings) -> void:
	settings = p_settings.copy()
	settings.save()
	scene.apply_settings(settings)


## The title offers Continue once a level past the first was reached or a story scene was played.
func has_progress() -> bool:
	return scene.current_level() > 0 or not story.state.seen.is_empty()


## Who is leading and where, for the Continue button.
func continue_detail() -> String:
	var names := scene.level_names()
	var name := scene.lead.capitalize()
	var at := scene.current_level()
	return "%s · %s" % [name, names[at]] if at >= 0 and at < names.size() else name


func continue_game() -> void:
	sheet = Sheet.NONE
	scene.play_level(scene.current_level())
	screen = Screen.PLAYING


func new_game() -> void:
	sheet = Sheet.NONE
	screen = Screen.FACTION_PICK


## Starts a new run as this faction's lead: every story choice is forgotten.
func begin(p_lead: String) -> void:
	sheet = Sheet.NONE
	story.reset_all(p_lead)
	scene.begin_as(p_lead)
	screen = Screen.PLAYING


func play_chapter(index: int) -> void:
	sheet = Sheet.NONE
	scene.play_level(index)
	screen = Screen.PLAYING


func training_room() -> void:
	sheet = Sheet.NONE
	scene.play_training_room()
	screen = Screen.PLAYING


func pause() -> void:
	if screen != Screen.PLAYING or story.is_active():
		return
	screen = Screen.PAUSED


func resume() -> void:
	sheet = Sheet.NONE
	screen = Screen.PLAYING


func retry_from_checkpoint() -> void:
	scene.retry()
	resume()


func restart_level() -> void:
	scene.restart_level()
	resume()


## From the results screen: on to the next level.
func next_level() -> void:
	scene.advance()
	screen = Screen.PLAYING


## From the chapter's last results screen: back to the start of the chapter.
func replay_chapter() -> void:
	if screen != Screen.RESULTS:
		return
	scene.play_level(int(result.chapter_start))
	screen = Screen.PLAYING


## Back to the title after a chapter. Continue then starts the next chapter, or the last one again.
func finish_chapter() -> void:
	if screen != Screen.RESULTS:
		quit_to_title()
		return
	if result.is_final:
		scene.play_level(int(result.chapter_start))
	quit_to_title()


func quit_to_title() -> void:
	sheet = Sheet.NONE
	# Leaving a results screen still counts the level as done, so Continue goes to the next one.
	if screen == Screen.RESULTS and not result.is_final:
		scene.play_level(int(result.index) + 1)
	screen = Screen.TITLE
