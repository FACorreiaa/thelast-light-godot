extends SceneTree
## Replays the Swift golden traces (tests/golden/*.trace) against the GDScript World.
##
##   godot --headless --path . -s res://tests/replay.gd -- [--frame0] [--run=<id>] [--dump=<step>]
##
## --frame0   compare only the state before the first step, for every run
## (default)  feed each trace's recorded inputs, compare the state hash after every step and stop a
##            run at its first mismatch
## --pilot   the GDScript Autopilot drives instead: its input must equal the recorded one each step
## --run=A,B  only these runs; --dump=N writes the canonical state after N steps to
##            user://dump-<id>-<N>.json, in the oracle's `f:<dec>:<hex>` float form, for
##            tools/diff_state.py against `oracle dump <id> <N>`

var _frame0 := false
var _pilot := false
var _only: PackedStringArray = []
var _dump := -1


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--frame0":
			_frame0 = true
		elif a == "--pilot":
			_pilot = true
		elif a.begins_with("--run="):
			_only = a.trim_prefix("--run=").split(",", false)
		elif a.begins_with("--dump="):
			_dump = int(a.trim_prefix("--dump="))
	var runs: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/runs.json"))
	var passed := 0
	var total := 0
	for id: String in runs:
		if not _only.is_empty() and not _only.has(id):
			continue
		total += 1
		if _replay(id):
			passed += 1
	print("replay: %d/%d runs match%s" % [passed, total, " at step 0" if _frame0 else ""])
	quit(0 if passed == total else 1)


## A fresh Tuning per run: the sturdy runs change specs in place.
static func make_world(header: Dictionary) -> World:
	var t := Tuning.load_default()
	if header.sturdy:
		t.caelen.max_hp = 100000.0
		t.seraphine.max_hp = 100000.0
		t.nimue.max_hp = 100000.0
	t.hero_damage_scale = float(header.get("damageScale", 1.0))
	match String(header.get("room", "level")):
		"feel":
			return World.feel_slice(int(header.seed), t)
		"partner":
			return World.partner_slice(int(header.seed), t)
	return World.from_level(Level.load_id(header.level), header.lead, t, int(header.seed))


func _replay(id: String) -> bool:
	var lines := FileAccess.get_file_as_string("res://tests/golden/%s.trace" % id).split("\n", false)
	var header: Dictionary = JSON.parse_string(lines[0])
	var world := make_world(header)
	var h0 := world.state_hash()
	if _dump == 0:
		_write_dump(id, 0, world)
	if h0 != lines[1]:
		print("MISMATCH %s step 0: %s want %s" % [id, h0, lines[1]])
		return false
	if _frame0:
		return true
	var pilot := Autopilot.new()
	pilot.fights = bool(header.fights)
	for n in range(2, lines.size()):
		var f := lines[n].split(" ", false, 3)
		var inp := InputFrame.make(_bits_to_float(int(f[1])), f[2][0] == "1", f[2][1] == "1", f[2][2] == "1",
			f[2][3] == "1", f[2][4] == "1", f[2][5] == "1")
		if _pilot and String(header.get("script", "")) == "":
			var mine := pilot.input_for(world)
			if not mine.equals(inp) or _float_bits(mine.move_x) != int(f[1]):
				print("PILOT %s step %d: got move %s jump %s held %s atk %s dodge %s sp %s, want %s %s" % [id, n - 1,
					mine.move_x, mine.jump, mine.jump_held, mine.attack, mine.dodge, mine.special, inp.move_x, f[2]])
				return false
		var events: Array = world.step(inp)
		var step := n - 1
		if step == _dump:
			_write_dump(id, step, world)
		var got := world.state_hash()
		if got != f[0]:
			print("MISMATCH %s step %d: %s want %s" % [id, step, got, f[0]])
			return false
		var want_events: Array = []
		if f.size() > 3:
			want_events = Canon.from_oracle_json(JSON.parse_string(f[3]))
		if Canon.hash_hex(events) != Canon.hash_hex(want_events):
			print("EVENTS %s step %d:\n  got  %s\n  want %s" % [id, step, _tagged(Canon.of(events)), f[3] if f.size() > 3 else "[]"])
			return false
	print("ok %s (%d steps)" % [id, lines.size() - 2])
	return true


static func _float_bits(x: float) -> int:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	return b.decode_s64(0)


static func _bits_to_float(bits: int) -> float:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_s64(0, bits)
	return b.decode_double(0)


func _write_dump(id: String, step: int, world: World) -> void:
	var path := "user://dump-%s-%d.json" % [id, step]
	var fa := FileAccess.open(path, FileAccess.WRITE)
	fa.store_string(_tagged(Canon.of(world)))
	fa.close()
	print("dumped %s" % ProjectSettings.globalize_path(path))


## Canonical tree as JSON with floats as "f:<decimal>:<hex bits>", like the oracle.
static func _tagged(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			var b := PackedByteArray()
			b.resize(8)
			b.encode_double(0, v)
			b.reverse()
			var hex := b.hex_encode().lstrip("0")
			return "\"f:%s:%s\"" % [str(v), hex if hex != "" else "0"]
		TYPE_STRING:
			return JSON.stringify(v)
		TYPE_ARRAY:
			var parts: PackedStringArray = []
			for x: Variant in v:
				parts.append(_tagged(x))
			return "[" + ",".join(parts) + "]"
		TYPE_DICTIONARY:
			var keys: Array = (v as Dictionary).keys()
			keys.sort()
			var parts: PackedStringArray = []
			for k: String in keys:
				parts.append(JSON.stringify(k) + ":" + _tagged(v[k]))
			return "{" + ",".join(parts) + "}"
	return "\"?\""
