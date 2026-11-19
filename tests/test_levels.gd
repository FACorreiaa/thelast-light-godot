extends SceneTree
## Swift's level guarantees (LevelTests.swift), now owned by the port: they are the oracle for levels that have no
## Swift golden. Every level can be finished by the autopilot while fighting, every lead's route can be finished,
## and every level can be finished without falling, touching every checkpoint. Heroes get health to spare, so this
## is about routes, not fights.
##   godot --headless --path . -s res://tests/test_levels.gd [-- --level ID]

const FRAMES := 60 * 240

var failed := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		print("FAIL ", what)


func _traverse(level_id: String, seed: int, fights: bool, lead: String) -> Dictionary:
	var t := Tuning.load_default()
	t.caelen.max_hp = 100000.0
	t.seraphine.max_hp = 100000.0
	t.nimue.max_hp = 100000.0
	var world := World.from_level(Level.load_id(level_id), lead, t, seed)
	var pilot := Autopilot.new(fights)
	var events: Array = []
	for i in FRAMES:
		if world.is_over:
			break
		events.append_array(world.step(pilot.input_for(world)))
	return {"world": world, "events": events}


func _x(world: World) -> String:
	return "%.0f" % world.controlled().pos.x


func _init() -> void:
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/index.json"))
	var only := ""
	var args := OS.get_cmdline_user_args()
	if args.has("--level"):
		only = args[args.find("--level") + 1]
	var levels: Array = []
	for l in index.levels:
		var id: String = l if l is String else l.id
		if only == "" or id == only:
			levels.append(id)

	for id: String in levels:
		for seed in [1, 2, 3]:
			var r := _traverse(id, seed, true, "caelen")
			check(r.world.is_complete, "%s seed %d (fighting) stopped at x %s" % [id, seed, _x(r.world)])
		var walk := _traverse(id, 1, false, "caelen")
		var w: World = walk.world
		check(w.is_complete, "%s (walking) stopped at x %s" % [id, _x(w)])
		var fell: Array = (walk.events as Array).filter(func(e): return e.case == "fell" and e.id == w.controlled_id)
		check(fell.is_empty(), "%s: the hero fell" % id)
		var cps: int = (walk.events as Array).filter(func(e): return e.case == "checkpoint").size()
		check(cps == w.level.checkpoints.size(), "%s: %d of %d checkpoints" % [id, cps, w.level.checkpoints.size()])

	for chapter: Dictionary in index.chapters:
		for lead: String in chapter.route:
			for id: String in chapter.route[lead]:
				if only != "" and id != only:
					continue
				var r := _traverse(id, 1, true, lead)
				check(r.world.is_complete, "%s in %s stopped at x %s" % [lead, id, _x(r.world)])

	print("levels: %d checks, %d failed" % [checks, failed])
	quit(1 if failed > 0 else 0)
