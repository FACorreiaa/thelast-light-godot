extends SceneTree
## The app around the game: title, faction pick, story, pause, settings, results and the saved place,
## driven through GameApp's methods as the menus call them. Saves go to user://test-flow/, never the real
## save. Run with --headless.

var _bad := 0
var _checks := 0


func check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_bad += 1
		print("FAIL ", what)


func _init() -> void:
	SaveDir.root = "user://test-flow/"
	for f in ["settings.cfg", "progress.cfg", "story.json"]:
		DirAccess.remove_absolute(SaveDir.path(f))
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


## A finger down at `at`, moved by `drag`, and lifted, as a phone sends it.
func _touch(at: Vector2, drag := Vector2.ZERO) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = at
	down.pressed = true
	Input.parse_input_event(down)
	await _frames(2)
	if drag != Vector2.ZERO:
		for k in range(1, 5):
			var d := InputEventScreenDrag.new()
			d.index = 0
			d.position = at + drag * (k / 4.0)
			d.relative = drag / 4.0
			Input.parse_input_event(d)
			await _frames(1)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = at + drag
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(3)


## A gamepad button pressed and let go.
func _pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var b := InputEventJoypadButton.new()
		b.device = 0
		b.button_index = button
		b.pressed = pressed
		Input.parse_input_event(b)
		await _frames(2)


## The tappable control around the label reading `text`.
func _control(app: GameApp, text: String) -> Control:
	for l: Label in app.menu_root.find_children("*", "Label", true, false):
		if l.text == text and l.is_visible_in_tree():
			var c: Node = l
			while c != null and not (c is Control and (c as Control).mouse_filter == Control.MOUSE_FILTER_STOP):
				c = c.get_parent()
			return c
	return null


## Where on screen, in pixels, the HUD's pause button is.
func _pause_button(app: GameApp) -> Vector2:
	var ui := app.scene._ui_scale()
	var h := app.scene.get_viewport_rect().size.y
	var w := app.scene.get_viewport_rect().size.x
	for y in range(0, int(h / ui), 4):
		for x in range(int(w / ui) - 1, 0, -4):
			if app.scene.hud.action_at(Vector2(x, y)) == Hud.Action.PAUSE:
				return Vector2(x * ui, h - y * ui)
	return Vector2(-1, -1)


func _center_of(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _launch() -> GameApp:
	var app: GameApp = load("res://game/game.tscn").instantiate()
	root.add_child(app)
	await _frames(3)
	return app


func _run() -> void:
	# Headless starts with a tiny window; lay out at the project's phone-landscape size so taps land where
	# a player's would.
	print("window was ", root.size)
	root.size = Vector2i(1311, 603)
	await _frames(1)
	var app := await _launch()
	check(app.menu_root.size.x > 800.0, "the menus lay out at phone width: %s" % app.menu_root.size)
	check(app.screen == GameApp.Screen.TITLE, "starts on the title")
	check(not app.has_progress(), "a fresh save has no progress")
	check(app.scene.frozen, "the game is frozen behind the title")

	# Real touches through the menus: one tap acts once, on release, and a drag is not a tap.
	var settings_button := _control(app, "SETTINGS")
	check(settings_button != null, "the title has a settings button")
	if settings_button != null:
		await _touch(_center_of(settings_button))
		await _frames(3)
		check(app.sheet == GameApp.Sheet.SETTINGS, "one tap opens settings and leaves it open")

		var sw: Control = null
		for l: Label in app.menu_root.find_children("*", "Label", true, false):
			if l.text == "Screen shake":
				sw = l.get_parent().get_child(l.get_parent().get_child_count() - 1)
		check(sw != null and app.settings.screen_shake, "settings show the shake switch, on")
		if sw != null:
			await _touch(_center_of(sw))
			check(not app.settings.screen_shake, "one tap on a switch turns it off, once")
			await _touch(_center_of(sw), Vector2(0, 40))
			check(not app.settings.screen_shake, "a drag across a switch does not flip it")
		await _touch(Vector2(4, 4))
		check(app.sheet == GameApp.Sheet.NONE, "a tap outside the panel closes it")
	var chapters_button := _control(app, "CHAPTERS")
	if chapters_button != null:
		await _touch(_center_of(chapters_button))
		check(app.sheet == GameApp.Sheet.CHAPTERS, "one tap opens the chapters")
		var second := _control(app, app.scene.level_names()[1])
		check(second != null, "the chapter list shows the second level")
		if second != null:
			var scroll := app.menu_root.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
			var before := scroll.scroll_vertical
			await _touch(_center_of(second), Vector2(0, -60))
			check(app.screen == GameApp.Screen.TITLE and app.sheet == GameApp.Sheet.CHAPTERS, "scrolling the list starts nothing")
			check(scroll.scroll_vertical > before, "a finger drag scrolls the chapter list (%d -> %d)" % [before, scroll.scroll_vertical])
			scroll.scroll_vertical = 0
			await _frames(2)
			await _touch(_center_of(_control(app, app.scene.level_names()[1])))
			check(app.screen == GameApp.Screen.PLAYING and app.scene.current_level() == 1, "a tap on a level plays it")
	app.screen = GameApp.Screen.TITLE
	await _frames(3)

	# A gamepad alone can get through the menus: focus starts on the main button, the d-pad moves, A acts,
	# B goes back. The ring shows only while the pad is in use.
	check(root.gui_get_focus_owner() == _control(app, "CONTINUE"), "focus starts on the main button")
	var steps := 0
	while root.gui_get_focus_owner() != _control(app, "CHAPTERS") and steps < 4:
		await _pad(JOY_BUTTON_DPAD_DOWN)
		steps += 1
	check(UI.navigating, "a pad press switches to navigating")
	check(steps == 2, "the d-pad walks down the buttons: CONTINUE, NEW GAME, CHAPTERS (%d presses)" % steps)
	await _pad(JOY_BUTTON_A)
	check(app.sheet == GameApp.Sheet.CHAPTERS, "A opens what has focus")
	await _frames(2)
	check(root.gui_get_focus_owner() != null and app.menus.is_ancestor_of(root.gui_get_focus_owner()), "focus moves into the sheet")
	await _pad(JOY_BUTTON_B)
	check(app.sheet == GameApp.Sheet.NONE, "B closes the sheet")
	await _touch(Vector2(4, 4))
	check(not UI.navigating, "a touch hides the focus ring again")

	app.new_game()
	check(app.screen == GameApp.Screen.FACTION_PICK, "new game opens the faction pick")
	app.begin("seraphine")
	check(app.screen == GameApp.Screen.PLAYING and not app.scene.frozen, "choosing a faction plays")
	check(app.scene.lead == "seraphine" and app.scene.current_level() == 0, "seraphine from her opening")
	check(app.story.state.flags.get("lead") == "seraphine", "the story knows the lead")

	# A scene holds the game still until it is read through.
	var ids := app.scene._scene_ids()
	check(not ids.is_empty(), "the opening has scenes")
	if not ids.is_empty():
		check(app.story.begin(ids[0]), "a scene starts")
		var f0 := app.scene.world.frame
		await _frames(10)
		check(app.scene.world.frame == f0, "the world holds still while someone speaks")
		app.pause()
		check(app.screen == GameApp.Screen.PLAYING, "no pause menu over a scene")
		var changes := [0]
		var count := func() -> void: changes[0] += 1
		app.story.changed.connect(count)
		var pause_at := _pause_button(app)
		await _touch(pause_at)
		await _frames(3)
		check(app.screen == GameApp.Screen.PLAYING and not app.scene._pause_requested, "the pause button does nothing over a scene")
		var before: int = changes[0]
		if app.story.is_active() and app.story.runner.choices().is_empty():
			await _touch(Vector2(10, 10))
			check(changes[0] - before == 1, "one tap on the dimmed game moves the scene on one line, not two")
		app.story.changed.disconnect(count)
		var n := 0
		while app.story.is_active() and n < 100:
			if app.story.runner.choices().is_empty():
				app.story.advance()
			else:
				app.story.choose(0)
			n += 1
		check(not app.story.is_active() and app.story.state.seen.has(ids[0]), "the scene ends and is remembered")
		check(not app.story.begin(ids[0]), "a scene seen does not play again")
		await _frames(10)
		check(app.scene.world.frame > f0, "the world moves again after the scene")

	# A choice picked with a pad: the press that picks must not also skip the reply.
	app.story.forget(["awakening.orion"])
	app.story.begin("awakening.orion")
	app.story.advance()
	app.story.advance()
	check(not app.story.runner.choices().is_empty(), "the Orion scene reaches its question")
	UI.navigating = true
	await _frames(3)
	var answer := root.gui_get_focus_owner()
	check(answer != null and app.dialogue.is_ancestor_of(answer), "with a pad the first answer has focus")
	await _pad(JOY_BUTTON_A)
	check(app.story.is_active() and String(app.story.runner.line.text).begins_with("Beside"), "A picks the answer and the reply shows: %s" % (app.story.runner.line.get("text", "(ended)") if app.story.is_active() else "(ended)"))
	app.story.choose(0)
	app.story.advance()
	check(app.story.is_active(), "an advance in the same frame as a choice is ignored")
	while app.story.is_active():
		app.story.advance()
		await _frames(1)
	UI.navigating = false
	await _touch(_pause_button(app))
	await _frames(2)
	check(app.screen == GameApp.Screen.PAUSED and app.scene.frozen, "the pause button pauses, and pausing freezes")
	var f1 := app.scene.world.frame
	await _frames(10)
	check(app.scene.world.frame == f1, "nothing moves while paused")
	# A tap on the menu where the pause button sits must not pause again once play resumes.
	await _touch(_pause_button(app))
	app.resume()
	await _frames(5)
	check(app.screen == GameApp.Screen.PLAYING, "a tap behind the pause menu does not re-pause on resume")
	app.pause()
	await _frames(2)
	await _pad(JOY_BUTTON_START)
	check(app.screen == GameApp.Screen.PLAYING, "Start leaves the pause menu")
	app.pause()
	app.sheet = GameApp.Sheet.SETTINGS
	var s := app.settings.copy()
	s.difficulty = Settings.Difficulty.HARD
	s.volume = 0.25
	app.apply_settings(s)
	check(Settings.load_saved().difficulty == Settings.Difficulty.HARD and is_equal_approx(Settings.load_saved().volume, 0.25), "settings are saved")
	check(is_equal_approx(app.scene.sound.volume, 0.25), "the volume reaches the sound")
	app.restart_level()
	check(is_equal_approx(app.scene.world.tuning.hero_damage_scale, 1.5), "hard difficulty reaches a level started after it")
	check(app.screen == GameApp.Screen.PLAYING and app.sheet == GameApp.Sheet.NONE, "restart resumes and closes the sheet")

	# The results screen, and leaving it for the title: the level counts as done.
	app.result = app.scene._level_result()
	app.screen = GameApp.Screen.RESULTS
	app.quit_to_title()
	check(app.screen == GameApp.Screen.TITLE and app.scene.current_level() == 1, "quitting from results moves on a level")
	check(app.has_progress(), "the title offers Continue")
	var detail := app.continue_detail()
	check(detail.begins_with("Seraphine · "), "continue names the lead and the level: " + detail)

	var list := app.scene.chapter_list()
	var total := 0
	for c: Dictionary in list:
		check(int(c.start) == total, "chapter %s starts where the last ended" % c.id)
		total += (c.names as Array).size()
	var chapters: int = GameScene.chapters().size()
	# A chapter marked hidden (built, writing not approved) is out of every lead's run and the chapter list, and
	# comes back only with the developer override.
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/index.json"))
	for c: Dictionary in index.chapters:
		if not c.get("hidden", false):
			continue
		for lead: String in c.route:
			var run := GameScene.route(lead)
			var full := GameScene.route(lead, true)
			var leaked := (c.route[lead] as Array).filter(func(id: String) -> bool: return run.has(id))
			check(leaked.is_empty() and full.has(c.route[lead][-1]), "%s is hidden from %s's run (leaked %s)" % [c.id, lead, leaked])
		check(list.all(func(e: Dictionary) -> bool: return e.id != c.id), "%s is not in the chapter list" % c.id)
		check(GameScene.chapters(true).any(func(e: Dictionary) -> bool: return e.id == c.id), "%s comes back with --all-chapters" % c.id)
	# The same filter on a made-up list, so it stays checked while no real chapter is hidden.
	var made_up := [{"id": "a"}, {"id": "b", "hidden": true}, {"id": "c", "hidden": false}]
	var id_list := func(l: Array) -> Array: return l.map(func(e: Dictionary) -> String: return e.id)
	check(id_list.call(GameScene.reachable(made_up, false)) == ["a", "c"], "a hidden chapter is left out")
	check(id_list.call(GameScene.reachable(made_up, true)) == ["a", "b", "c"], "--all-chapters keeps a hidden chapter")
	var routed := [{"id": "1", "route": {"nimue": ["a", "b"]}}, {"id": "2", "hidden": true, "route": {"nimue": ["c", "d"]}},
		{"id": "3", "route": {"nimue": ["e"]}}]
	var run := GameScene.route_in(GameScene.reachable(routed, false), "nimue")
	var full := GameScene.route_in(GameScene.reachable(routed, true), "nimue")
	check(run == ["a", "b", "e"] and full == ["a", "b", "c", "d", "e"], "a hidden chapter's levels leave the run: %s" % [run])
	check(GameScene.resume_index(run, full, "b") == 1 and GameScene.resume_index(run, full, "d") == 2
		and GameScene.resume_index(run, full, "zz") == 0, "a save inside a hidden chapter resumes at the next reachable level")
	var tail: Array[String] = ["a", "b"]
	check(GameScene.resume_index(tail, full.slice(0, 4), "c") == 1, "and at the last reachable level when nothing follows")
	check(list.size() == chapters and total == app.scene.level_names().size(), "the chapter list covers the run")
	var last: Dictionary = list[-1]
	app.play_chapter(total - 1)
	# Voice A on screen: on the Heart's level the frame machines' eyes stay dark until the AI speaks, then light.
	# The run's last level is the Heart (Chapter 4, open); if it ever is not, say so rather than skip these checks.
	check(app.scene.world.level.id == "heart", "the run ends on the Heart (%s)" % app.scene.world.level.id)
	if app.scene.world.level.id == "heart":
		var eyes: Array[SkShape] = app.scene.voice_eyes
		check(eyes.size() >= 3 and eyes.all(func(e: SkShape) -> bool: return e.modulate.a < 0.2), "the frame machines start dark")
		app.story.forget(["heart.end"])
		app.story.begin("heart.end")
		await _frames(40)
		check(String(app.story.runner.line.speaker) == "VOICE" and eyes.all(func(e: SkShape) -> bool: return e.modulate.a > 0.5),
			"the frame machines light while the AI speaks")
		while app.story.is_active():
			app.story.advance()
			await _frames(1)
		await _frames(60)
		check(eyes.all(func(e: SkShape) -> bool: return e.modulate.a < 0.3), "and go dark again after")
	app.result = app.scene._level_result()
	check(app.result.is_final and String(app.result.ending) == String(last.ending), "the last level ends the game")
	app.screen = GameApp.Screen.RESULTS
	app.finish_chapter()
	check(String(last.epilogue) != "", "the last chapter has an epilogue")
	if String(last.epilogue) != "":
		# The epilogue plays first, over the still arena, then the way out the player chose.
		check(app.story.is_active() and app.story.runner.scene_id == String(last.epilogue) and app.screen == GameApp.Screen.PLAYING,
			"leaving the last results screen plays the chapter's epilogue")
		# The level is finished behind the epilogue; a press right after its last line must not rebuild it.
		app.scene.world.is_complete = true
		app.scene.world.is_over = true
		var said: Array = []
		while app.story.is_active() and said.size() < 10:
			said.append(String(app.story.runner.line.speaker))
			app.story.advance()
			await _frames(1)
		check(said == ["SERAPHINE", "ORION"], "the epilogue is the lead's line, then Orion's: %s" % [said])
		var level_before := app.scene.current_level()
		var key := InputEventKey.new()
		key.physical_keycode = KEY_J
		key.pressed = true
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		await _frames(2)
		key.pressed = false
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		# The epilogue's own exit may already have run (it polls every 0.1 s) and moved Continue to the chapter's start;
		# the bug this guards against rebuilt the run's first level.
		check(app.scene.current_level() in [level_before, int(last.start)], "a press after the epilogue does not restart the level (%d, was %d)"
			% [app.scene.current_level(), level_before])
		await create_timer(0.3).timeout
	check(app.screen == GameApp.Screen.TITLE and app.scene.current_level() == int(last.start), "after the end, Continue is the last chapter again")

	# A relaunch finds the same place and the same decisions.
	var flags := app.story.state.flags.duplicate()
	var at := app.scene.current_level()
	app.queue_free()
	await _frames(2)
	var again := await _launch()
	check(again.scene.lead == "seraphine" and again.scene.current_level() == at, "the place survives a relaunch")
	check(again.story.state.flags == flags, "the decisions survive a relaunch")
	check(again.settings.difficulty == Settings.Difficulty.HARD, "the settings survive a relaunch")
	again.training_room()
	check(again.scene.mode == GameScene.Mode.ROOM and again.screen == GameApp.Screen.PLAYING, "the training room plays")
	again.queue_free()
	await _frames(2)
	await _progression()
	for f in ["settings.cfg", "progress.cfg", "story.json"]:
		DirAccess.remove_absolute(SaveDir.path(f))
	print("flow: %d checks, %d failed" % [_checks, _bad])
	quit(1 if _bad > 0 else 0)


## Hero progression in the app: steps are earned at the Chapter 1-3 bosses, saved per lead, migrated from old saves,
## reset by a New Game, and kept across a restart.
func _progression() -> void:
	check(GameScene.effective_step(0, "heart", -1) == 3 and GameScene.effective_step(3, "awakening", -1) == 3
		and GameScene.effective_step(3, "heart", 0) == 0, "effective steps: chapter floor, earned kept, --steps wins")
	var app := await _launch()
	app.begin("caelen")
	await _frames(2)
	check(app.scene.earned_step == 0, "a new run starts at step 0")
	var results: Array = []
	app.scene.level_completed.connect(func(r: Dictionary) -> void: results.append(r))
	var protocol := GameScene.route("caelen").find("protocol")
	app.scene.play_level(protocol)
	app.scene._complete_level()
	check(app.scene.earned_step == 1, "beating the Protocol earns step 1 (%d)" % app.scene.earned_step)
	var names: Array = (results[-1].get("unlocks", []) as Array).map(func(u: Dictionary) -> String: return u.name) if not results.is_empty() else []
	check(names == ["Riposte", "Follow-Through"], "the results list the lead's unlock, then Orion's: %s" % [names])
	app.scene.play_level(protocol)
	app.scene._complete_level()
	check((results[-1].get("unlocks", []) as Array).is_empty(), "replaying the Protocol unlocks nothing new")
	var cfg := ConfigFile.new()
	cfg.load(SaveDir.path("progress.cfg"))
	check(int(cfg.get_value("progress", "steps_caelen", -1)) == 1, "the step is saved for the lead")
	# Review Focus 2: a restart keeps the step (Chapter 4 plays at least at step 3).
	app.scene.play_level(GameScene.route("caelen").find("heart"))
	app.scene._restart(false)
	check(app.scene.world.controlled().step == 3, "a restart keeps the step (%d)" % app.scene.world.controlled().step)
	app.scene.steps_override = 0
	app.scene._restart(false)
	check(app.scene.world.controlled().step == 0, "--steps overrides it")
	app.scene.steps_override = -1
	# A New Game resets the lead's step.
	app.begin("caelen")
	await _frames(2)
	cfg.load(SaveDir.path("progress.cfg"))
	check(app.scene.earned_step == 0 and int(cfg.get_value("progress", "steps_caelen", -1)) == 0, "a New Game resets the step")
	app.queue_free()
	await _frames(2)
	# Review Focus 3: an old save on a Chapter 4 level, with no steps key, plays at step 3.
	var old := ConfigFile.new()
	old.set_value("progress", "lead", "caelen")
	old.set_value("progress", "level", "masons_span")
	old.save(SaveDir.path("progress.cfg"))
	var later := await _launch()
	check(later.scene.earned_step == 3, "an old Chapter 4 save migrates to step 3 (%d)" % later.scene.earned_step)
	later.queue_free()
	await _frames(2)
