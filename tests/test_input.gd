extends SceneTree
## A press must reach the simulation even when the frame it lands on runs no simulation step. The sim runs at
## 60 Hz; on a 120 Hz screen (iPhone Pro, ProMotion Mac) every other rendered frame runs none.

var failed := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		print("FAIL ", what)


func _init() -> void:
	SaveDir.root = "user://test-input/"
	root.size = Vector2i(1311, 603)
	var app: GameApp = load("res://game/game.tscn").instantiate()
	root.add_child(app)
	_run.call_deferred(app)


## Rendered frames at `hz`, driven by hand so the frame timing is exact.
func _frames(scene: GameScene, n: int, hz: float) -> void:
	for i in n:
		scene._process(1.0 / hz)


## Did the hero leave the ground within the next half second?
func _jumped(scene: GameScene, hz: float) -> bool:
	for i in int(hz / 2.0):
		scene._process(1.0 / hz)
		if not scene.world.controlled().on_ground:
			return true
	return false


func _settle(scene: GameScene) -> void:
	_frames(scene, 120, 60.0)
	scene.accumulator = 0.0


func _run(app: GameApp) -> void:
	for i in 3:
		await process_frame
	app.training_room()
	var scene := app.scene
	scene.set_process(false)
	await process_frame
	var jump_at: Vector2 = scene.controls._buttons[TouchControls.Pad.JUMP].position

	for hz in [60.0, 120.0]:
		# A tap: down and up between two rendered frames, landing on a frame with no simulation step.
		_settle(scene)
		check(scene.world.controlled().on_ground, "%d Hz: the hero starts on the ground" % hz)
		scene.controls.began(5, jump_at)
		scene.controls.ended(5)
		check(_jumped(scene, hz), "%d Hz: a quick tap on the jump button jumps" % hz)

		# A key press, held, whose first rendered frame runs no simulation step.
		_settle(scene)
		var e := InputEventKey.new()
		e.physical_keycode = KEY_SPACE
		e.pressed = true
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		var ok := _jumped(scene, hz)
		e.pressed = false
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		check(ok, "%d Hz: Space jumps" % hz)

	# Many taps at 120 Hz, at every phase of the frame: every one must jump.
	var landed := 0
	for n in 20:
		_settle(scene)
		_frames(scene, n % 2, 120.0)
		scene.controls.began(5, jump_at)
		scene.controls.ended(5)
		if _jumped(scene, 120.0):
			landed += 1
	check(landed == 20, "120 Hz: 20 of 20 taps jump (got %d)" % landed)

	print("input: %d checks, %d failed" % [checks, failed])
	quit(1 if failed > 0 else 0)
