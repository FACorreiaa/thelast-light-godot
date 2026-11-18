class_name Level
extends RefCounted
## Everything a level is made of, read from data/levels/<id>.json. Pure data.

var id: String
var name: String
var width: float
var start: Vec2
var platforms: Array[Platform] = []
var hazards: Array[Hazard] = []
var levers: Array[Lever] = []
var plates: Array[Plate] = []
var gates: Array[Gate] = []
var checkpoints: Array[Vec2] = []
var pickups: Array[Pickup] = []
var enemies: Array[Placement] = []
var partner: Placement
var boss: Placement
var twin: Placement
var scenes: Array[SceneTrigger] = []
var exit_x: float
var kill_y: float


static func load_id(level_id: String) -> Level:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/%s.json" % level_id))
	var l := from_data(d)
	l.id = level_id
	return l


static func from_data(d: Dictionary) -> Level:
	var l := Level.new()
	l.name = d.name
	l.width = float(d.width)
	l.start = Vec2.from_data(d.start)
	for p: Dictionary in d.platforms:
		l.platforms.append(Platform.from_data(p))
	for h: Dictionary in d.hazards:
		l.hazards.append(Hazard.from_data(h))
	for v: Dictionary in d.levers:
		l.levers.append(Lever.from_data(v))
	for p: Dictionary in d.plates:
		l.plates.append(Plate.from_data(p))
	for g: Dictionary in d.gates:
		l.gates.append(Gate.from_data(g))
	for c: Dictionary in d.checkpoints:
		l.checkpoints.append(Vec2.from_data(c))
	for p: Dictionary in d.pickups:
		l.pickups.append(Pickup.from_data(p))
	for e: Dictionary in d.enemies:
		l.enemies.append(Placement.from_data(e))
	l.partner = Placement.from_data(d.partner) if d.partner != null else null
	l.boss = Placement.from_data(d.boss) if d.boss != null else null
	l.twin = Placement.from_data(d.twin) if d.twin != null else null
	for s: Dictionary in d.scenes:
		l.scenes.append(SceneTrigger.from_data(s))
	l.exit_x = float(d.exitX)
	l.kill_y = float(d.killY)
	return l


class Platform:
	extends RefCounted
	var box: Box
	var one_way: bool
	var travel: Vec2
	## Frames for a full there-and-back trip. Zero means it does not move.
	var period: int

	static func make(b: Box) -> Platform:
		var p := Platform.new()
		p.box = b
		p.one_way = false
		p.travel = Vec2.zero()
		p.period = 0
		return p

	func moves() -> bool:
		return period > 0 and not (travel.x == 0.0 and travel.y == 0.0)

	## Where it is on a given frame. The motion eases in and out at both ends.
	func box_at(frame: int) -> Box:
		if not moves():
			return box.copy()
		var phase := float(frame % period) / float(period)
		var t := phase * 2.0 if phase < 0.5 else (1.0 - phase) * 2.0
		var eased := t * t * (3.0 - 2.0 * t)
		return box.offset(travel.x * eased, travel.y * eased)

	static func from_data(d: Dictionary) -> Platform:
		var p := Platform.new()
		p.box = Box.from_data(d.box)
		p.one_way = bool(d.oneWay)
		p.travel = Vec2.from_data(d.travel)
		p.period = int(d.period)
		return p


class Hazard:
	extends RefCounted
	var box: Box
	var damage: float
	var period: int
	var on_frames: int
	var phase: int
	var warning: int

	func is_on(frame: int) -> bool:
		return period == 0 or (frame + phase) % period < on_frames

	func is_warning(frame: int) -> bool:
		return period > 0 and not is_on(frame) and (frame + phase) % period >= period - warning

	func frames_until_on(frame: int) -> int:
		return 0 if is_on(frame) else period - (frame + phase) % period

	static func from_data(d: Dictionary) -> Hazard:
		var h := Hazard.new()
		h.box = Box.from_data(d.box)
		h.damage = float(d.damage)
		h.period = int(d.period)
		h.on_frames = int(d.onFrames)
		h.phase = int(d.phase)
		h.warning = int(d.warning)
		return h


class Lever:
	extends RefCounted
	var id: int
	var pos: Vec2
	var hold_frames: int
	## A lamp's reach either side while it is lit. Zero for a plain lever.
	var glow: float

	func box() -> Box:
		return Box.new(pos.x - 14.0, pos.y, pos.x + 14.0, pos.y + 56.0)

	static func from_data(d: Dictionary) -> Lever:
		var v := Lever.new()
		v.id = int(d.id)
		v.pos = Vec2.from_data(d.pos)
		v.hold_frames = int(d.holdFrames)
		v.glow = float(d.glow)
		return v


class Plate:
	extends RefCounted
	var id: int
	var x0: float
	var x1: float
	var top: float

	static func from_data(d: Dictionary) -> Plate:
		var p := Plate.new()
		p.id = int(d.id)
		p.x0 = float(d.x0)
		p.x1 = float(d.x1)
		p.top = float(d.top)
		return p


class Gate:
	extends RefCounted
	var id: int
	var box: Box
	var opens_with: Array[int] = []
	var inverted: bool
	## Its levers are bells, rung in the order listed.
	var in_order: bool

	static func from_data(d: Dictionary) -> Gate:
		var g := Gate.new()
		g.id = int(d.id)
		g.box = Box.from_data(d.box)
		for n: float in d.opensWith:
			g.opens_with.append(int(n))
		g.inverted = bool(d.inverted)
		g.in_order = bool(d.inOrder)
		return g


class Pickup:
	extends RefCounted
	var id: int
	var pos: Vec2
	var secret: bool

	static func from_data(d: Dictionary) -> Pickup:
		var p := Pickup.new()
		p.id = int(d.id)
		p.pos = Vec2.from_data(d.pos)
		p.secret = bool(d.secret)
		return p


class Placement:
	extends RefCounted
	var kind: String
	var pos: Vec2

	static func from_data(d: Dictionary) -> Placement:
		var p := Placement.new()
		p.kind = d.kind
		p.pos = Vec2.from_data(d.pos)
		return p


class SceneTrigger:
	extends RefCounted
	var scene: String
	## {"case": "start" | "reach" | "partnerJoins" | "bossWakes" | "raised" | "complete"}; reach has "_0".
	var cue: Dictionary

	static func from_data(d: Dictionary) -> SceneTrigger:
		var s := SceneTrigger.new()
		s.scene = d.scene
		s.cue = Specs.payload(d.cue)
		return s
