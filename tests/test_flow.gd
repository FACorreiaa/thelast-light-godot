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


func _launch() -> GameApp:
	var app: GameApp = load("res://game/game.tscn").instantiate()
	root.add_child(app)
	await _frames(3)
	return app


func _run() -> void:
	var app := await _launch()
	check(app.screen == GameApp.Screen.TITLE, "starts on the title")
	check(not app.has_progress(), "a fresh save has no progress")
	check(app.scene.frozen, "the game is frozen behind the title")

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

	app.pause()
	check(app.screen == GameApp.Screen.PAUSED and app.scene.frozen, "pause freezes")
	var f1 := app.scene.world.frame
	await _frames(10)
	check(app.scene.world.frame == f1, "nothing moves while paused")
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
	check(list.size() == 3 and total == app.scene.level_names().size(), "the chapter list covers the run")
	var last: Dictionary = list[-1]
	app.play_chapter(total - 1)
	app.result = app.scene._level_result()
	check(app.result.is_final and String(app.result.ending) == String(last.ending), "the last level ends the game")
	app.screen = GameApp.Screen.RESULTS
	app.finish_chapter()
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
	for f in ["settings.cfg", "progress.cfg", "story.json"]:
		DirAccess.remove_absolute(SaveDir.path(f))
	print("flow: %d checks, %d failed" % [_checks, _bad])
	quit(1 if _bad > 0 else 0)
