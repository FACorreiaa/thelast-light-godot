class_name Progression
extends RefCounted
## Each hero's ability track (data/progression.json): three abilities unlocked by story progress, one step each.
## A fighter's `step` says how far along it is; step 0 is the kit as tuned, with nothing unlocked.

const PATH := "res://data/progression.json"

static var _default: Progression = null
static var _chapter_of: Dictionary = {}

## kind -> Array of ability dictionaries, in step order.
var _tracks: Dictionary = {}
## "kind.id" -> Specs.AttackSpec, for abilities that bring a swing of their own.
var _slots: Dictionary = {}


static func load_default() -> Progression:
	if _default == null:
		_default = Progression.from_data(JSON.parse_string(FileAccess.get_file_as_string(PATH)))
	return _default


static func from_data(d: Dictionary) -> Progression:
	var p := Progression.new()
	for kind: String in d:
		var list: Array = (d[kind] as Array).duplicate()
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.step) < int(b.step))
		p._tracks[kind] = list
		for a: Dictionary in list:
			if a.has("slot"):
				p._slots["%s.%s" % [kind, a.id]] = Specs.AttackSpec.from_data(a.slot)
	return p


func abilities(kind: String) -> Array:
	return _tracks.get(kind, [])


func ability(kind: String, id: String) -> Dictionary:
	for a: Dictionary in abilities(kind):
		if String(a.id) == id:
			return a
	return {}


func slot(kind: String, id: String) -> Specs.AttackSpec:
	return _slots.get("%s.%s" % [kind, id], null)


## True when `f` has reached the step of its kind's ability `id`.
static func has(f: Fighter, id: String) -> bool:
	if f.step <= 0:
		return false
	var a := load_default().ability(f.kind, id)
	return not a.is_empty() and int(a.step) <= f.step


## The step a level's chapter is played at when nothing was earned: the chapter's place in the run (Chapter 1 is
## 0), at most 3. 0 for a level no chapter lists.
static func chapter_step(level_id: String) -> int:
	if _chapter_of.is_empty():
		var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/index.json"))
		var n := 0
		for c: Dictionary in index.chapters:
			for lead: String in c.route:
				for id: String in c.route[lead]:
					if not _chapter_of.has(id):
						_chapter_of[id] = n
			n += 1
	return mini(int(_chapter_of.get(level_id, 0)), 3)
