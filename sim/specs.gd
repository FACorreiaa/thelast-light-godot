class_name Specs
extends RefCounted
## Fighter and attack specs, read from data/tuning.json. Never mutated after the world is built.
##
## Attack effects and specials are Swift enums with payloads. They stay dictionaries keyed like
## the export: {"case": "summon", "_0": "scrapDrone", "count": 2}. Godot's JSON reader returns
## every number as float, so the int payload fields are turned back into ints here.

const INT_PAYLOAD := ["count", "active", "warning", "columns", "daze", "slowFrames", "cooldown",
	"stagger", "window", "frames"]


## A Double from the export. The Swift exporter writes non-finite values as "inf", "-inf" or
## "nan" strings; a boss room's exitX is infinity. float("inf") on a String is not infinity.
static func num(v: Variant) -> float:
	if v is String:
		match String(v):
			"inf":
				return INF
			"-inf":
				return -INF
			"nan":
				return NAN
		push_error("Specs.num: not a number: %s" % v)
		return NAN
	return float(v)


static func payload(v: Variant) -> Dictionary:
	if v is String:
		return {"case": v}
	var d: Dictionary = (v as Dictionary).duplicate(true)
	for k: String in d.keys():
		if d[k] is Dictionary:
			d[k] = payload(d[k])
		elif k in INT_PAYLOAD:
			d[k] = int(d[k])
	return d


class IntRange:
	extends RefCounted
	var lower: int
	var upper: int

	func contains(n: int) -> bool:
		return n >= lower and n <= upper

	static func from_data(d: Dictionary) -> IntRange:
		var r := IntRange.new()
		r.lower = int(d.lowerBound)
		r.upper = int(d.upperBound)
		return r


class AttackSpec:
	extends RefCounted
	var windup: int
	var active: int
	var recovery: int
	var damage: float
	var reach: float
	var height: float
	var y_offset: float
	var knockback: float
	var lunge: float
	var hitstun: int
	var hit_stop: int
	var holds_still: bool
	var slow_frames: int
	var both_sides: bool
	## {"case": "strike"} for an ordinary swing.
	var effect: Dictionary

	func total() -> int:
		return windup + active + recovery

	## First frame on which a buffered attack press chains into the next swing.
	func chain_from() -> int:
		return windup + 2

	func is_strike() -> bool:
		return effect["case"] == "strike"

	static func from_data(d: Dictionary) -> AttackSpec:
		var a := AttackSpec.new()
		a.windup = int(d.windup)
		a.active = int(d.active)
		a.recovery = int(d.recovery)
		a.damage = float(d.damage)
		a.reach = float(d.reach)
		a.height = float(d.height)
		a.y_offset = float(d.yOffset)
		a.knockback = float(d.knockback)
		a.lunge = float(d.lunge)
		a.hitstun = int(d.hitstun)
		a.hit_stop = int(d.hitStop)
		a.holds_still = bool(d.holdsStill)
		a.slow_frames = int(d.slowFrames)
		a.both_sides = bool(d.bothSides)
		a.effect = Specs.payload(d.effect)
		return a


class DodgeSpec:
	extends RefCounted
	var duration: int
	var speed: float
	var invulnerable: IntRange
	var cooldown: int

	static func from_data(d: Dictionary) -> DodgeSpec:
		var s := DodgeSpec.new()
		s.duration = int(d.duration)
		s.speed = float(d.speed)
		s.invulnerable = IntRange.from_data(d.invulnerable)
		s.cooldown = int(d.cooldown)
		return s


class SelfDestructSpec:
	extends RefCounted
	var threshold: float
	var fuse: int
	var radius: float
	var damage: float
	var speed_factor: float

	static func from_data(d: Dictionary) -> SelfDestructSpec:
		var s := SelfDestructSpec.new()
		s.threshold = float(d.threshold)
		s.fuse = int(d.fuse)
		s.radius = float(d.radius)
		s.damage = float(d.damage)
		s.speed_factor = float(d.speedFactor)
		return s


class FighterSpec:
	extends RefCounted
	var width: float
	var height: float
	var max_hp: float
	var run_speed: float
	var jump_speed: float
	var attacks: Array[AttackSpec] = []
	var dodge: DodgeSpec
	var parry_window: int
	var hurt_invulnerable: int
	var frontal_block: bool
	var guards_while_swinging: bool
	var poise: bool
	var unflinching: bool
	var self_destruct: SelfDestructSpec
	var immortal: bool
	var rooted: bool
	## Empty when it has none; else {"case": "command" | "adapt" | "heal" | "decoy", ...}.
	var special: Dictionary
	var is_decoy: bool
	var lifetime: int
	var chooses_attacks: bool
	var hovers: bool
	var ward_radius: float
	var phase_thresholds: Array[float] = []
	var flight_phase: int
	## A FighterKind case name, or "".
	var shielded_by: String
	var needs_light: bool
	## An attack index, or -1.
	var riposte: int
	var armored: bool
	var sworn: bool
	var boss: bool
	var wake_delay: int
	## The Swift brain type name ("SoldierBrain"), or "".
	var brain: String

	func special_cooldown() -> int:
		return int(special.get("cooldown", 0))

	static func from_data(d: Dictionary) -> FighterSpec:
		var s := FighterSpec.new()
		s.width = float(d.width)
		s.height = float(d.height)
		s.max_hp = float(d.maxHP)
		s.run_speed = float(d.runSpeed)
		s.jump_speed = float(d.jumpSpeed)
		for a: Dictionary in d.attacks:
			s.attacks.append(AttackSpec.from_data(a))
		s.dodge = DodgeSpec.from_data(d.dodge) if d.dodge != null else null
		s.parry_window = int(d.parryWindow)
		s.hurt_invulnerable = int(d.hurtInvulnerable)
		s.frontal_block = bool(d.frontalBlock)
		s.guards_while_swinging = bool(d.guardsWhileSwinging)
		s.poise = bool(d.poise)
		s.unflinching = bool(d.unflinching)
		s.self_destruct = SelfDestructSpec.from_data(d.selfDestruct) if d.selfDestruct != null else null
		s.immortal = bool(d.immortal)
		s.rooted = bool(d.rooted)
		s.special = Specs.payload(d.special) if d.special != null else {}
		s.is_decoy = bool(d.isDecoy)
		s.lifetime = int(d.lifetime)
		s.chooses_attacks = bool(d.choosesAttacks)
		s.hovers = bool(d.hovers)
		s.ward_radius = float(d.wardRadius)
		for t: float in d.phaseThresholds:
			s.phase_thresholds.append(t)
		s.flight_phase = int(d.flightPhase)
		s.shielded_by = String(d.shieldedBy) if d.shieldedBy != null else ""
		s.needs_light = bool(d.needsLight)
		s.riposte = int(d.riposte) if d.riposte != null else -1
		s.armored = bool(d.armored)
		s.sworn = bool(d.sworn)
		s.boss = bool(d.boss)
		s.wake_delay = int(d.wakeDelay)
		s.brain = String(d.brain) if d.brain != null else ""
		return s
