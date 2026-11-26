extends SceneTree
## Records Godot golden traces into tests/golden_godot/, for levels the Swift oracle never had (the port is their
## source of truth). Same format as the Swift traces, except the events field is "#<Canon.hash_hex>" instead of
## oracle JSON. The autopilot drives, walking and fighting, with sturdy heroes like the Swift runs.
##
##   godot --headless --path . -s res://tools/record_golden.gd -- [--levels=a,b] [--seeds=1,2] [--chapter-steps]
##
## --chapter-steps records the heroes at their level's chapter step (Progression), as "<run>-step<N>" runs with a
## "steps" header; without it, every run is step 0.
##
## Default: every level with eclipse phases, seed 1 (walking and fighting; boss arenas: seeds 1 and 2, fighting).
## Rewrites runs.json from the traces on disk.
## A re-record changes what "correct" means: commit it on its own, saying why.

const DIR := "res://tests/golden_godot"
const MAX_FRAMES := 60 * 240

var _chapter_steps := false


func _init() -> void:
	var levels: PackedStringArray = []
	var seeds: Array[int] = [1]
	_chapter_steps = OS.get_cmdline_user_args().has("--chapter-steps")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--levels="):
			levels = a.trim_prefix("--levels=").split(",", false)
		elif a.begins_with("--seeds="):
			seeds.clear()
			for s in a.trim_prefix("--seeds=").split(",", false):
				seeds.append(int(s))
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/index.json"))
	if levels.is_empty():
		for id: String in index.levels:
			if Level.load_id(id).eclipse_period > 0:
				levels.append(id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for id in levels:
		if Level.load_id(id).boss != null:
			# A boss arena has nothing to walk past, so its walk and fight runs come out the same: record each seed
			# and the next one, fighting.
			var both := {}
			for seed in seeds:
				both[seed] = true
				both[seed + 1] = true
			for seed: int in both:
				_record(id, seed, true)
		else:
			for seed in seeds:
				for fights in [false, true]:
					_record(id, seed, fights)
	var runs: Array = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".trace"):
			runs.append(f.trim_suffix(".trace"))
	runs.sort()
	var out := FileAccess.open(DIR + "/runs.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(runs, "  ") + "\n")
	out.close()
	print("recorded: %d runs in %s" % [runs.size(), DIR])
	quit()


func _record(level_id: String, seed: int, fights: bool) -> void:
	var run_id := "%s-caelen-s%d-%s" % [level_id, seed, "fight" if fights else "walk"]
	var header := {"complete": false, "damageScale": 1.0, "fights": fights, "frames": 0, "id": run_id,
		"lead": "caelen", "level": level_id, "over": false, "room": "level", "script": "", "seed": seed,
		"sturdy": true}
	var cs := Progression.chapter_step(level_id) if _chapter_steps else 0
	if cs > 0:
		run_id += "-step%d" % cs
		header.id = run_id
		header.steps = {"caelen": cs, "orion": cs}
	var world: World = load("res://tests/replay.gd").make_world(header)
	var pilot := Autopilot.new(fights)
	var lines: PackedStringArray = [world.state_hash()]
	var frames := 0
	while frames < MAX_FRAMES and not world.is_over:
		var inp := pilot.input_for(world)
		var events: Array = world.step(inp)
		var flags := ""
		for b: bool in [inp.jump, inp.jump_held, inp.attack, inp.dodge, inp.special, inp.switch_hero]:
			flags += "1" if b else "0"
		lines.append("%s %d %s #%s" % [world.state_hash(), _float_bits(inp.move_x), flags, Canon.hash_hex(events)])
		frames += 1
	header.frames = frames
	header.complete = world.is_complete
	header.over = world.is_over
	var out := FileAccess.open("%s/%s.trace" % [DIR, run_id], FileAccess.WRITE)
	out.store_string(JSON.stringify(header, "", true) + "\n" + "\n".join(lines) + "\n")
	out.close()
	print("%s: %d frames, complete %s" % [run_id, frames, world.is_complete])


static func _float_bits(x: float) -> int:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	return b.decode_s64(0)
