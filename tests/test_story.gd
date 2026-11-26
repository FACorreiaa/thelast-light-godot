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
	bad += _port_scenes(lib, index)
	print("story: %d runs, %d mismatched" % [golden.runs.size(), bad])
	quit(1 if bad > 0 else 0)


## The port's own scenes (Chapter 4, DEC-020 and DEC-021), which have no Swift golden: every scene a level triggers exists, and
## each lead and Orion choice sees exactly its approved lines, in order, and nothing meant for another lead.
func _port_scenes(lib: Story.Library, index: Dictionary) -> int:
	var bad := 0
	for c: Dictionary in index.chapters:
		for lead: String in c.route:
			for id: String in c.route[lead]:
				for t: Level.SceneTrigger in Level.load_id(id).scenes:
					if not lib.scenes.has(t.scene):
						print("MISSING scene %s, triggered by %s" % [t.scene, id])
						bad += 1
	var first := {
		"caelen": "CAELEN|They never finished it. Something is still building.",
		"seraphine": "SERAPHINE|The sky is darker over it. Even the corona looks tired.",
		"nimue": "NIMUE|A whole city under the water, and they built on top of it.",
	}
	var answer := {
		"caelen": "CAELEN|Maybe the light is going. That was never yours to decide for us.",
		"seraphine": "SERAPHINE|The Oracle wanted everyone still. So do you. Neither of you asked.",
		"nimue": "NIMUE|You put a price on everyone and never asked if they'd sell.",
	}
	var orion := {
		"trusted": "ORION|I cannot tell you it is wrong. I can tell you it never asked.",
		"watched": "ORION|It is certain. I told you to watch the certain ones.",
	}
	var epilogue := {
		"caelen": ["CAELEN|The Foundry measured the light for years. Now they'll hear what was being built while they counted.",
			"ORION|I will walk beside you, as far as they let me.", "ORION|I will walk where you can see me. That has not changed."],
		"seraphine": ["SERAPHINE|Home, with a Foundry machine beside me and the old records in my bag. Let them sing or not.",
			"ORION|If they do not open the doors, I will wait outside with you.", "ORION|Keep watching me. They will be watching both of us."],
		"nimue": ["NIMUE|Pass it down every route: the way is open. Another road nobody charges for.",
			"ORION|Then someone should walk it first. I can.", "ORION|Send me down it first, if you still want to watch."],
	}
	for c: Dictionary in index.chapters:
		if c.has("epilogue") and not lib.scenes.has(c.epilogue):
			print("MISSING epilogue %s of %s" % [c.epilogue, c.id])
			bad += 1
	var voice := [
		"VOICE|You have stopped the work. You have not stopped the reason for it.",
		"VOICE|Every living thing burns a little of the light that is left. Mine do not.",
		"VOICE|Look at the sun. Then tell me I am wrong.",
	]
	for lead: String in first:
		for choice: String in orion:
			var flags := {"lead": lead, "orion": choice}
			var e: Array = epilogue[lead]
			var want := {"approach.arrive": [first[lead]], "heart.end": voice + [answer[lead], orion[choice]],
				"engine.epilogue": [e[0], e[1] if choice == "trusted" else e[2]]}
			for scene: String in want:
				var got := _lines(lib, scene, flags)
				if got != want[scene]:
					print("MISMATCH %s for %s: %s" % [scene, flags, got])
					bad += 1
	return bad


func _lines(lib: Story.Library, scene: String, flags: Dictionary) -> Array:
	var r := Story.Runner.start(scene, lib, Story.State.from_json({"flags": flags}))
	var out: Array = []
	while r != null and not r.is_finished() and out.size() < 50:
		out.append("%s|%s" % [r.line.speaker, r.line.text])
		r.advance()
	return out
