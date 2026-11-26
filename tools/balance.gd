extends SceneTree
## Boss balance with and without progression: every boss level, every lead, at step 0 and at the level's chapter
## step (Progression), with real health and damage. The autopilot fights. Prints a markdown table.
##
##   godot --headless --path . -s res://tools/balance.gd -- [--seeds=10] [--levels=a,b]
##
## "Lowest HP" is the lead's health at the end of the closest win; a fight whose lowest HP more than doubles from
## step 0 to the chapter step is flagged for a retune proposal (the creator decides).

const BOSSES := ["protocol", "wardens_gate", "lamp_row", "cinder_vault", "cloister_gate", "oracles_terrace",
	"masons_span", "heart"]
const MAX_FRAMES := 60 * 240


func _init() -> void:
	var seeds := 10
	var levels: Array = BOSSES
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = int(a.trim_prefix("--seeds="))
		elif a.begins_with("--levels="):
			levels = Array(a.trim_prefix("--levels=").split(",", false))
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/index.json"))
	print("| Level | Lead | Step | Wins | Lowest HP | Mean frames | Flag |")
	print("|---|---|---|---|---|---|---|")
	for id: String in levels:
		var cs := Progression.chapter_step(id)
		for lead: String in ["caelen", "seraphine", "nimue"]:
			if not _in_route(index, lead, id):
				continue
			var base := {}
			for st: int in ([0] if cs == 0 else [0, cs]):
				var r := _measure(id, lead, st, seeds)
				var flag := ""
				if st > 0 and int(base.wins) > 0 and int(r.wins) > 0 and float(r.lowest) > 2.0 * maxf(float(base.lowest), 1.0):
					flag = "retune?"
				if st == 0:
					base = r
				print("| %s | %s | %d | %d/%d | %.0f | %.0f | %s |" % [id, lead, st, r.wins, seeds, r.lowest, r.frames, flag])
	quit()


static func _in_route(index: Dictionary, lead: String, id: String) -> bool:
	for c: Dictionary in index.chapters:
		if (c.route[lead] as Array).has(id):
			return true
	return false


## Wins, the lead's lowest final health over wins (-1 with none), and mean frames over wins.
static func _measure(id: String, lead: String, step: int, seeds: int) -> Dictionary:
	var wins := 0
	var lowest := INF
	var frames := 0
	for seed in range(1, seeds + 1):
		var t := Tuning.load_default()
		var w := World.from_level(Level.load_id(id), lead, t, seed, -1, {}, {lead: step, "orion": step})
		var pilot := Autopilot.new(true)
		var n := 0
		while n < MAX_FRAMES and not w.is_over and not w.is_complete:
			w.step(pilot.input_for(w))
			n += 1
		if w.is_complete:
			wins += 1
			frames += n
			var hp := 0.0
			for f: Fighter in w.fighters:
				if f.kind == lead:
					hp = f.hp
			lowest = minf(lowest, hp)
	return {"wins": wins, "lowest": lowest if wins > 0 else -1.0, "frames": float(frames) / maxf(1.0, float(wins))}
