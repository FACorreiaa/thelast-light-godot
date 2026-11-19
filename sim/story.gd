class_name Story
extends RefCounted
## The branching dialogue. Port of Story.swift: scenes of lines by name, decisions recorded as flags, and a
## runner that plays one scene. The data is data/story/<chapter id>.json, unchanged from the Swift app.


## What the player has decided and seen. It is the part of the save the story reads and writes.
class State:
	extends RefCounted
	## Decisions, by name: "orion": "trusted".
	var flags: Dictionary = {}
	## Scenes already played, so they do not repeat on a retry. Used as a set.
	var seen: Dictionary = {}

	func meets(conditions: Variant) -> bool:
		if conditions == null:
			return true
		for k: String in conditions:
			if flags.get(k) != conditions[k]:
				return false
		return true

	func copy() -> State:
		var s := State.new()
		s.flags = flags.duplicate()
		s.seen = seen.duplicate()
		return s

	func to_json() -> Dictionary:
		var seen_list: Array = seen.keys()
		seen_list.sort()
		return {"flags": flags, "seen": seen_list}

	static func from_json(d: Dictionary) -> State:
		var s := State.new()
		for k: String in d.get("flags", {}):
			s.flags[k] = String(d.flags[k])
		for id: String in d.get("seen", []):
			s.seen[id] = true
		return s


## Every scene of the game: scene id -> {"start": name, "lines": {name: line}}. Lines and choices stay as the
## JSON dictionaries (speaker, text, next, choices, set, requires, otherwise).
class Library:
	extends RefCounted
	var scenes: Dictionary = {}

	static func load_chapters(chapter_ids: Array) -> Library:
		var lib := Library.new()
		for id: String in chapter_ids:
			var path := "res://data/story/%s.json" % id
			if not FileAccess.file_exists(path):
				continue
			var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			for scene_id: String in d.scenes:
				if not lib.scenes.has(scene_id):
					lib.scenes[scene_id] = d.scenes[scene_id]
		return lib

	## Mistakes a writer can make in the data: a line that points nowhere, a scene with no way through.
	func problems() -> Array[String]:
		var found: Array[String] = []
		var ids: Array = scenes.keys()
		ids.sort()
		for id: String in ids:
			var scene: Dictionary = scenes[id]
			var lines: Dictionary = scene.lines
			if not lines.has(scene.start):
				found.append("%s: start '%s' does not exist" % [id, scene.start])
			var names: Array = lines.keys()
			names.sort()
			for name: String in names:
				var line: Dictionary = lines[name]
				var targets: Array = [line.get("next"), line.get("otherwise")]
				for c: Dictionary in line.get("choices", []):
					targets.append(c.get("next"))
				for t: Variant in targets:
					if t != null and not lines.has(t):
						found.append("%s.%s: points to '%s', which does not exist" % [id, name, t])
				if line.get("requires") != null and line.get("otherwise") == null:
					found.append("%s.%s: has a condition but nowhere to go when it fails" % [id, name])
				if line.has("choices") and (line.choices as Array).is_empty():
					found.append("%s.%s: empty list of choices" % [id, name])
		return found


## Plays one scene: gives the current line, takes "continue" or a choice, and records decisions.
class Runner:
	extends RefCounted
	var scene_id: String
	var state: State
	## The current line, or {} when the scene is over.
	var line: Dictionary = {}
	var _scene: Dictionary

	## Null when the library has no such scene.
	static func start(p_scene_id: String, library: Library, p_state: State) -> Runner:
		if not library.scenes.has(p_scene_id):
			return null
		var r := Runner.new()
		r.scene_id = p_scene_id
		r._scene = library.scenes[p_scene_id]
		r.state = p_state.copy()
		r._go(r._scene.start)
		return r

	func is_finished() -> bool:
		return line.is_empty()

	## The answers on offer for the current line; empty when the line only needs "continue".
	func choices() -> Array:
		var out: Array = []
		for c: Dictionary in line.get("choices", []):
			if state.meets(c.get("requires")):
				out.append(c)
		return out

	## Moves past a line that has no choices.
	func advance() -> void:
		if line.is_empty() or not choices().is_empty():
			return
		_go(line.get("next"))

	func choose(index: int) -> void:
		var offered := choices()
		if index < 0 or index >= offered.size():
			return
		var c: Dictionary = offered[index]
		var set_flags: Variant = c.get("set")
		if set_flags != null:
			for k: String in set_flags:
				state.flags[k] = set_flags[k]
		_go(c.get("next"))

	func _go(name: Variant) -> void:
		var target: Variant = name
		var lines: Dictionary = _scene.lines
		# Skip lines whose conditions are not met. The hop limit stops a loop written into the data.
		for _i in 64:
			if target == null or not lines.has(target):
				break
			var nxt: Dictionary = lines[target]
			if state.meets(nxt.get("requires")):
				var set_flags: Variant = nxt.get("set")
				if set_flags != null:
					for k: String in set_flags:
						state.flags[k] = set_flags[k]
				line = nxt
				return
			target = nxt.get("otherwise")
		line = {}
		state.seen[scene_id] = true
