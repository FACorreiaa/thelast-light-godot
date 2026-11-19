extends SceneTree
## Replays tests/golden/story.json (oracle story): every scene under several starting flags and choice
## policies. The GDScript Story runner must show the same lines and choices and end in the same state.


func _init() -> void:
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/story.json"))
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/index.json"))
	var ids: Array = index.chapters.map(func(c: Dictionary) -> String: return c.id)
	var lib := Story.Library.load_chapters(ids)
	var bad := 0
	var problems := lib.problems()
	if problems != Array(golden.problems, TYPE_STRING, "", null):
		print("problems differ: ", problems, " want ", golden.problems)
		bad += 1
	for run: Dictionary in golden.runs:
		var start := Story.State.from_json({"flags": run.startFlags})
		var r := Story.Runner.start(run.scene, lib, start)
		var steps: Array = []
		var n := 0
		while r != null and not r.is_finished() and n < 200:
			var offered := r.choices()
			var texts: Array = offered.map(func(c: Dictionary) -> String: return c.text)
			steps.append("%s|%s|%s" % [r.line.speaker, r.line.text, "/".join(PackedStringArray(texts))])
			if offered.is_empty():
				r.advance()
			else:
				r.choose((n + int(run.policy)) % offered.size())
			n += 1
		var got := r.state.to_json() if r != null else {}
		if steps != run.steps or got.get("flags") != run.flags or got.get("seen") != run.seen:
			if bad < 5:
				print("MISMATCH %s start %d policy %d" % [run.scene, run.start, run.policy])
			bad += 1
	print("story: %d runs, %d mismatched" % [golden.runs.size(), bad])
	quit(1 if bad > 0 else 0)
