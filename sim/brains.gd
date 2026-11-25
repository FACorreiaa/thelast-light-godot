class_name Brains
extends RefCounted
## Decides what a fighter wants to do this frame. A mechanical port of Swift `Brain.swift`: one static
## function per Swift brain struct, dispatched on the Swift type name held in `spec.brain`.
##
## No Swift brain struct has stored instance properties, so nothing here keeps state between frames:
## everything a brain remembers lives on the fighter (ai_cooldown, ai_aux, ai_aux2, ai_aux3, next_attack).
##
## `me` is Swift `inout` and is mutated in place. `foes` and `allies` are snapshots: read-only here.

## A tiny stick push: enough to turn and face a target without really moving.
const FACING_NUDGE := 0.02
## How far away a decoy still draws an enemy.
const DECOY_LURE := 600.0

# Attack indices, as the Swift `static let`s.
const ACOLYTE_MEND := 0
const ACOLYTE_LIGHT := 1
const DISCIPLE_FLARE := 0
const DISCIPLE_CUT := 1
const WARDEN_CUT := 0
const WARDEN_CROSS_CUT := 1
const WARDEN_THRUST := 2
const WARDEN_CALL := 3
const WARDEN_SPIN := 4
const LAMPLIGHTER_HOOK := 0
const LAMPLIGHTER_DOUSE := 1
const LAMPLIGHTER_EMBER := 2
const LAMPLIGHTER_CALL := 3
const LAMPLIGHTER_SNUFF := 4
# Port-only (the final chapter): the Mason.
const MASON_HAMMER := 0
const MASON_SHIFT := 1
const MASON_QUAKE := 2
const MASON_CALL := 3
## Port-only: the Heart, Chapter 4's boss (placeholder kit).
const HEART_PULSE := 0
const HEART_SHIFT := 1
const HEART_BEAT := 2
const HEART_CALL := 3
const SWORN_SHIELD_BASH := 0
const SWORN_SHIELD_LIGHT := 2
const SWORN_SPEAR_THRUST := 0
const SWORN_SPEAR_LEAP := 1
const SWORN_SPEAR_SWEEP := 2
const ORACLE_STAFF := 0
const ORACLE_FLARE := 1
const ORACLE_SUNFALL := 2
const ORACLE_PROPHECY := 3
const ORACLE_FAITHFUL := 4
const ORACLE_ECLIPSE := 5
const ORACLE_DARK := 6
const CINDER_CANE := 0
const CINDER_LANTERN := 1
const CINDER_DEBTORS := 2
const CINDER_VENTS := 3
const CINDER_SWEEP := 4
const CINDER_WIDE_VENTS := 5
const PROTOCOL_SLAM := 0
const PROTOCOL_CHARGE := 1
const PROTOCOL_SURGE := 2
const PROTOCOL_SUMMON := 3
const PROTOCOL_RAIN := 4
const PROTOCOL_PULSE := 5
const PROTOCOL_BEAM := 6


static func think(brain: String, me: Fighter, foes: Array[Fighter], allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	match brain:
		"DroneBrain":
			return drone(me, foes, allies, tuning, rng)
		"SoldierBrain":
			return soldier(me, foes, allies, tuning, rng)
		"SentryBrain":
			return sentry(me, foes, allies, tuning, rng)
		"DogmaBrain":
			return dogma(me, foes, allies, tuning, rng)
		"RatbornBrain":
			return ratborn(me, foes, allies, tuning, rng)
		"GunnerBrain":
			return gunner(me, foes, allies, tuning, rng)
		"BruteBrain":
			return brute(me, foes, allies, tuning, rng)
		"WeaverBrain":
			return weaver(me, foes, allies, tuning, rng)
		"ZealotBrain":
			return zealot(me, foes, allies, tuning, rng)
		"AcolyteBrain":
			return acolyte(me, foes, allies, tuning, rng)
		"SolarGuardBrain":
			return solar_guard(me, foes, allies, tuning, rng)
		"DiscipleBrain":
			return disciple(me, foes, allies, tuning, rng)
		"WardenBrain":
			return warden(me, foes, allies, tuning, rng)
		"LamplighterBrain":
			return lamplighter(me, foes, allies, tuning, rng)
		"MasonBrain":
			return mason(me, foes, allies, tuning, rng)
		"HeartBrain":
			return heart(me, foes, allies, tuning, rng)
		"SwornShieldBrain":
			return sworn_shield(me, foes, allies, tuning, rng)
		"SwornSpearBrain":
			return sworn_spear(me, foes, allies, tuning, rng)
		"OracleBrain":
			return oracle(me, foes, allies, tuning, rng)
		"CinderKingBrain":
			return cinder_king(me, foes, allies, tuning, rng)
		"ProtocolBrain":
			return protocol(me, foes, allies, tuning, rng)
		"PartnerBrain":
			return partner(me, foes, allies, tuning, rng)
	assert(false, "unknown brain: %s" % brain)
	return InputFrame.neutral()


# Swift `InputFrame(moveX:attack:)`.
static func _mv(move_x: float, attack: bool = false) -> InputFrame:
	return InputFrame.make(move_x, false, false, attack)


# Swift `list.min { abs($0.pos.x - me.pos.x) < abs($1.pos.x - me.pos.x) }`: the first among ties.
static func _closest(list: Array[Fighter], me: Fighter) -> Fighter:
	var best: Fighter = null
	for f: Fighter in list:
		if best == null:
			best = f
		elif absf(f.pos.x - me.pos.x) < absf(best.pos.x - me.pos.x):
			best = f
	return best


static func _nearest(foes: Array[Fighter], me: Fighter) -> Fighter:
	# A decoy in sight is too tempting to ignore.
	var decoys: Array[Fighter] = []
	for f: Fighter in foes:
		if f.spec.is_decoy and absf(f.pos.x - me.pos.x) <= DECOY_LURE:
			decoys.append(f)
	var decoy := _closest(decoys, me)
	if decoy != null:
		return decoy
	return _closest(foes, me)


static func _strike_distance(me: Fighter, target: Fighter) -> float:
	if me.spec.attacks.is_empty():
		return 0.0
	var attack: Specs.AttackSpec = me.spec.attacks[0]
	return me.spec.width / 2.0 + attack.reach + target.spec.width / 2.0 - 6.0


## Scrap Drone: rushes in, bites, and chases the hero once its fuse is lit.
static func drone(me: Fighter, foes: Array[Fighter], _allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	if me.state == Fighter.St.FUSE:
		return _mv(dir)

	# The bite lunges forward, so it can start from further out than its reach.
	var strike_range := _strike_distance(me, target) + 40.0
	if absf(dx) > strike_range:
		return _mv(dir)
	if me.ai_cooldown == 0 and me.is_actionable():
		me.ai_cooldown = rng.int_closed(tuning.drone_attack_gap.lower, tuning.drone_attack_gap.upper)
		return _mv(dir * FACING_NUDGE, true)
	return _mv(dir * FACING_NUDGE)


## Forged Soldier: walks the hero down behind its shield and is slow to turn around.
static func soldier(me: Fighter, foes: Array[Fighter], _allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1

	if dir != me.facing and me.is_actionable():
		me.ai_aux += 1
		if me.ai_aux < tuning.soldier_turn_delay:
			return InputFrame.neutral()
	me.ai_aux = 0

	if absf(dx) > _strike_distance(me, target):
		return _mv(dir)
	if me.ai_cooldown == 0 and me.is_actionable():
		me.ai_cooldown = rng.int_closed(tuning.soldier_attack_gap.lower, tuning.soldier_attack_gap.upper)
		return _mv(dir * FACING_NUDGE, true)
	return _mv(dir * FACING_NUDGE)


## Sentry Core: holds its distance, turns to face its target, and fires when the target is level with it.
static func sentry(me: Fighter, foes: Array[Fighter], _allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	if absf(dx) < tuning.sentry_near:
		return _mv(-dir)
	if absf(dx) > tuning.sentry_far:
		return _mv(dir)
	if me.ai_cooldown == 0 and me.is_actionable():
		me.ai_cooldown = rng.int_closed(tuning.sentry_attack_gap.lower, tuning.sentry_attack_gap.upper)
		return _mv(dir * FACING_NUDGE, true)
	return _mv(dir * FACING_NUDGE)


## Dogma Frame: walks beside the nearest other machine so its shield covers it. It never attacks.
static func dogma(me: Fighter, _foes: Array[Fighter], allies: Array[Fighter], tuning: Tuning,
		_rng: SeededRandom) -> InputFrame:
	var others: Array[Fighter] = []
	for a: Fighter in allies:
		if a.id != me.id and not a.spec.immortal and a.spec.ward_radius == 0.0:
			others.append(a)
	var ward := _nearest(others, me)
	if ward == null:
		return InputFrame.neutral()
	var dx := ward.pos.x - me.pos.x
	if absf(dx) <= tuning.dogma_follow_distance:
		return InputFrame.neutral()
	return _mv(1.0 if dx > 0.0 else -1.0)


## Ratborn: rushes in, bites, then backs off for a moment, and now and then breaks off its approach.
static func ratborn(me: Fighter, foes: Array[Fighter], _allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	# Backing off, after a bite or a feint.
	if me.ai_aux > 0:
		me.ai_aux -= 1
		return _mv(-dir)
	var strike_range := _strike_distance(me, target) + 40.0
	if absf(dx) > strike_range:
		if rng.double_half_open(0.0, 1.0) < tuning.ratborn_feint_chance:
			me.ai_aux = 20
			return InputFrame.make(-dir, true)
		return _mv(dir)
	if me.ai_cooldown == 0 and me.is_actionable():
		me.ai_cooldown = rng.int_closed(tuning.ratborn_attack_gap.lower, tuning.ratborn_attack_gap.upper)
		# Starts backing off once the bite is over.
		me.ai_aux2 = 1
		return _mv(dir * FACING_NUDGE, true)
	if me.ai_aux2 == 1 and me.is_actionable():
		me.ai_aux2 = 0
		me.ai_aux = rng.int_closed(tuning.ratborn_retreat.lower, tuning.ratborn_retreat.upper)
	return _mv(dir * FACING_NUDGE)


## Lantern Gunner: holds a throwing distance and lobs lanterns at the hero.
static func gunner(me: Fighter, foes: Array[Fighter], _allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	if absf(dx) < tuning.gunner_near:
		return _mv(-dir)
	if absf(dx) > tuning.gunner_far:
		return _mv(dir)
	if me.ai_cooldown == 0 and me.is_actionable():
		me.ai_cooldown = rng.int_closed(tuning.gunner_attack_gap.lower, tuning.gunner_attack_gap.upper)
		return _mv(dir * FACING_NUDGE, true)
	return _mv(dir * FACING_NUDGE)


## Smuggler Brute: lumbers in, slow to turn. Up close it often slams, which reaches behind it too.
static func brute(me: Fighter, foes: Array[Fighter], _allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	# Anyone behind it is close enough to slam without turning.
	var behind: bool = dir != me.facing and absf(dx) < me.spec.width / 2.0 + me.spec.attacks[1].reach
	if dir != me.facing and me.is_actionable() and not behind:
		me.ai_aux += 1
		if me.ai_aux < tuning.brute_turn_delay:
			return InputFrame.neutral()
	me.ai_aux = 0
	if not behind and absf(dx) > _strike_distance(me, target):
		return _mv(dir)
	if me.ai_cooldown == 0 and me.is_actionable():
		me.ai_cooldown = rng.int_closed(tuning.brute_attack_gap.lower, tuning.brute_attack_gap.upper)
		me.next_attack = 1 if (behind or rng.double_half_open(0.0, 1.0) < tuning.brute_slam_chance) else 0
		return _mv(0.0 if behind else dir * FACING_NUDGE, true)
	return _mv(0.0 if behind else dir * FACING_NUDGE)


## Night Weaver: keeps away, sends images when it has none, and otherwise lays snares in the hero's path.
static func weaver(me: Fighter, foes: Array[Fighter], allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	if absf(dx) < tuning.weaver_near:
		return _mv(-dir)
	if absf(dx) > tuning.weaver_far:
		return _mv(dir)
	if me.ai_cooldown == 0 and me.is_actionable():
		me.ai_cooldown = rng.int_closed(tuning.weaver_attack_gap.lower, tuning.weaver_attack_gap.upper)
		var images := 0
		for a: Fighter in allies:
			if a.kind == "weaverImage" and a.is_alive():
				images += 1
		me.next_attack = 0 if images == 0 else 1
		return _mv(dir * FACING_NUDGE, true)
	return _mv(dir * FACING_NUDGE)


## Zealot: runs straight in and cuts three times. Once hurt below half, it hardly pauses between flurries.
static func zealot(me: Fighter, foes: Array[Fighter], _allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	# Mid-flurry it keeps pressing, so each cut chains into the next.
	if me.state == Fighter.St.ATTACK:
		return _mv(0.0, me.attack_index + 1 < me.spec.attacks.size())
	if not me.is_actionable():
		return InputFrame.neutral()
	# The pause runs between flurries, not during them.
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	if absf(dx) > _strike_distance(me, target) + 60.0:
		return _mv(dir)
	if me.ai_cooldown != 0:
		return _mv(dir * FACING_NUDGE)
	var gap := rng.int_closed(tuning.zealot_attack_gap.lower, tuning.zealot_attack_gap.upper)
	me.ai_cooldown = int(float(gap) * tuning.zealot_fervour_scale) if me.hp < me.spec.max_hp / 2.0 else gap
	return _mv(dir * FACING_NUDGE, true)


## Radiant Acolyte: keeps its distance. Mends a hurt ally in reach before anything else; otherwise calls
## light down.
static func acolyte(me: Fighter, foes: Array[Fighter], allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	if not me.is_actionable():
		return InputFrame.neutral()
	if absf(dx) < tuning.acolyte_near:
		return _mv(-dir)
	if absf(dx) > tuning.acolyte_far:
		return _mv(dir)
	if me.ai_cooldown != 0:
		return _mv(dir * FACING_NUDGE)
	var effect: Dictionary = me.spec.attacks[ACOLYTE_MEND].effect
	if effect["case"] != "mend":
		return InputFrame.neutral()
	var mend_range: float = float(effect["range"])
	var hurt := false
	for a: Fighter in allies:
		if a.id != me.id and a.is_alive() and absf(a.pos.x - me.pos.x) <= mend_range \
				and a.hp < a.spec.max_hp * tuning.acolyte_mend_below:
			hurt = true
			break
	me.next_attack = ACOLYTE_MEND if hurt else ACOLYTE_LIGHT
	me.ai_cooldown = rng.int_closed(tuning.acolyte_attack_gap.lower, tuning.acolyte_attack_gap.upper)
	return _mv(dir * FACING_NUDGE, true)


## Solar Guard: walks the hero down behind its shield, slow to turn. Its bash answers blows on the shield
## by itself.
static func solar_guard(me: Fighter, foes: Array[Fighter], _allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	if not me.is_actionable():
		return InputFrame.neutral()
	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	if dir != me.facing:
		me.ai_aux += 1
		if me.ai_aux < tuning.guard_turn_delay:
			return InputFrame.neutral()
	me.ai_aux = 0
	if absf(dx) > _strike_distance(me, target):
		return _mv(dir)
	if me.ai_cooldown != 0:
		return _mv(dir * FACING_NUDGE)
	me.ai_cooldown = rng.int_closed(tuning.guard_attack_gap.lower, tuning.guard_attack_gap.upper)
	me.next_attack = 0
	return _mv(dir * FACING_NUDGE, true)


## Halo Disciple: drifts above the fight at a little distance. Flares when a hero is in reach of it; cuts
## down at a hero right below.
static func disciple(me: Fighter, foes: Array[Fighter], _allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	if not me.is_actionable():
		return InputFrame.neutral()
	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	var reach: float
	var effect: Dictionary = me.spec.attacks[DISCIPLE_FLARE].effect
	if effect["case"] == "flare":
		reach = float(effect["radius"])
	else:
		reach = 0.0
	if me.ai_cooldown == 0:
		if absf(dx) < tuning.disciple_near:
			me.next_attack = DISCIPLE_CUT
		elif absf(dx) < reach * 0.8:
			me.next_attack = DISCIPLE_FLARE
		else:
			return _mv(dir)
		me.ai_cooldown = rng.int_closed(tuning.disciple_attack_gap.lower, tuning.disciple_attack_gap.upper)
		return _mv(dir * FACING_NUDGE, true)
	# Between attacks it keeps to the edge of the fight, facing in.
	if absf(dx) < tuning.disciple_near:
		return _mv(-dir)
	if absf(dx) > tuning.disciple_far:
		return _mv(dir)
	return _mv(dir * FACING_NUDGE)


## The Line Warden. Faces the hero behind its guard and turns slowly, so getting behind it is the way in.
## Two cuts up close, a thrust from further off. In overdrive it turns faster and, when alone, calls a
## soldier.
static func warden(me: Fighter, foes: Array[Fighter], allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	if not me.is_actionable():
		return InputFrame.neutral()
	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	# Anyone lingering close behind it gets the spin.
	var spin_reach := me.spec.width / 2.0 + me.spec.attacks[WARDEN_SPIN].reach
	var behind := false
	for f: Fighter in foes:
		if (f.pos.x - me.pos.x) * me.facing < 0.0 and absf(f.pos.x - me.pos.x) < spin_reach:
			behind = true
			break
	@warning_ignore("integer_division")
	var half_gap: int = tuning.warden_attack_gap.lower / 2
	if behind and me.ai_cooldown < half_gap:
		me.ai_aux3 += 1
		if me.ai_aux3 >= tuning.warden_spin_after:
			me.ai_aux3 = 0
			me.ai_cooldown = rng.int_closed(tuning.warden_attack_gap.lower, tuning.warden_attack_gap.upper)
			me.next_attack = WARDEN_SPIN
			return _mv(0.0, true)
	elif not behind:
		me.ai_aux3 = 0
	if dir != me.facing:
		me.ai_aux += 1
		if me.ai_aux < (tuning.warden_fast_turn_delay if me.phase >= 2 else tuning.warden_turn_delay):
			return InputFrame.neutral()
	me.ai_aux = 0

	var gap := absf(dx) - me.spec.width / 2.0 - target.spec.width / 2.0
	var close: bool = gap < me.spec.attacks[WARDEN_CUT].reach - 10.0
	if me.ai_cooldown != 0:
		return _mv(dir * FACING_NUDGE if close else dir)

	me.ai_cooldown = rng.int_closed(tuning.warden_attack_gap.lower, tuning.warden_attack_gap.upper)
	var alone := true
	for a: Fighter in allies:
		if a.id != me.id and a.is_alive() and a.kind == "forgedSoldier":
			alone = false
			break
	if me.phase >= 2 and alone and me.ai_aux2 == 0:
		# Calls once per overdrive, and again only after the soldier falls and it has fought a while.
		me.ai_aux2 = 6
		me.next_attack = WARDEN_CALL
	elif close:
		if me.ai_aux2 > 0 and alone:
			me.ai_aux2 -= 1
		# A cut, often followed straight away by the cross-cut.
		me.next_attack = WARDEN_CROSS_CUT if (me.next_attack == WARDEN_CUT and rng.coin()) else WARDEN_CUT
	elif gap < 320.0 and rng.double_half_open(0.0, 1.0) < tuning.warden_thrust_chance:
		me.next_attack = WARDEN_THRUST
	else:
		return _mv(dir)
	return _mv(dir * FACING_NUDGE, true)


## The Lamplighter. Walks the hero down to hook them, throws embers from afar, and puts out any lamp he
## finds himself standing by, after which he needs a while before he can again: that is the hero's window.
## Overdrive: he snuffs the whole row now and then, and calls Ratborn when none are left.
static func lamplighter(me: Fighter, foes: Array[Fighter], allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	if me.ai_aux2 > 0:
		me.ai_aux2 -= 1
	if not me.is_actionable():
		return InputFrame.neutral()
	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	var gap := absf(dx) - me.spec.width / 2.0 - target.spec.width / 2.0

	# Caught in the light: put it out first, whatever he was doing.
	if me.in_light and me.ai_aux2 == 0:
		me.ai_aux2 = tuning.lamplighter_douse_rest
		me.ai_cooldown = rng.int_closed(tuning.lamplighter_attack_gap.lower, tuning.lamplighter_attack_gap.upper)
		me.next_attack = LAMPLIGHTER_DOUSE
		return _mv(dir * FACING_NUDGE, true)

	var close: bool = gap < me.spec.attacks[LAMPLIGHTER_HOOK].reach - 10.0
	if me.ai_cooldown != 0:
		return _mv(dir * FACING_NUDGE if close else dir)
	me.ai_cooldown = rng.int_closed(tuning.lamplighter_attack_gap.lower, tuning.lamplighter_attack_gap.upper)

	if me.phase >= 2:
		var alone := true
		for a: Fighter in allies:
			if a.id != me.id and a.is_alive() and a.kind == "ratborn":
				alone = false
				break
		if alone and me.ai_aux3 == 0:
			me.ai_aux3 = 5
			me.next_attack = LAMPLIGHTER_CALL
			return _mv(dir * FACING_NUDGE, true)
		if me.ai_aux3 > 0:
			me.ai_aux3 -= 1
		if me.ai_aux2 == 0 and rng.double_half_open(0.0, 1.0) < 0.3:
			me.ai_aux2 = tuning.lamplighter_douse_rest
			me.next_attack = LAMPLIGHTER_SNUFF
			return _mv(dir * FACING_NUDGE, true)
	if close:
		me.next_attack = LAMPLIGHTER_HOOK
	elif gap > tuning.lamplighter_ember_from \
			and rng.double_half_open(0.0, 1.0) < tuning.lamplighter_ember_chance:
		me.next_attack = LAMPLIGHTER_EMBER
	else:
		return _mv(dir)
	return _mv(dir * FACING_NUDGE, true)


## Port-only: the Mason (DRAFT-012, PROPOSED). Walks the hero down to hammer them. Every few attacks he
## shifts the eclipse (the next swap comes at once) and follows with a quake: columns under each hero, lower
## than a ledge's top, so the ledges that stand after the swap are the shelter. From afar he quakes now and
## then. Overdrive: calls help when none is left beside him.
static func mason(me: Fighter, foes: Array[Fighter], allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	if not me.is_actionable():
		return InputFrame.neutral()
	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	var gap := absf(dx) - me.spec.width / 2.0 - target.spec.width / 2.0
	var close: bool = gap < me.spec.attacks[MASON_HAMMER].reach - 10.0
	if me.ai_cooldown != 0:
		return _mv(dir * FACING_NUDGE if close else dir)
	me.ai_cooldown = rng.int_closed(tuning.mason_attack_gap.lower, tuning.mason_attack_gap.upper)

	# The quake that follows a shift.
	if me.ai_aux2 > 0:
		me.ai_aux2 = 0
		me.next_attack = MASON_QUAKE
		return _mv(dir * FACING_NUDGE, true)
	if me.phase >= 2:
		var alone := true
		for a: Fighter in allies:
			if a.id != me.id and a.is_alive():
				alone = false
				break
		if alone and me.ai_aux3 == 0:
			me.ai_aux3 = 5
			me.next_attack = MASON_CALL
			return _mv(dir * FACING_NUDGE, true)
		if me.ai_aux3 > 0:
			me.ai_aux3 -= 1
	me.ai_aux += 1
	if me.ai_aux >= tuning.mason_shift_every:
		me.ai_aux = 0
		me.ai_aux2 = 1
		me.next_attack = MASON_SHIFT
		return _mv(dir * FACING_NUDGE, true)
	if close:
		me.next_attack = MASON_HAMMER
	elif gap > tuning.mason_quake_from and rng.double_half_open(0.0, 1.0) < tuning.mason_quake_chance:
		me.next_attack = MASON_QUAKE
	else:
		me.ai_aux -= 1
		return _mv(dir)
	return _mv(dir * FACING_NUDGE, true)


## Port-only: the Heart never moves; it only turns to face. (1) A steady beat: a fixed pause between attacks, a pulse
## around it up close and floor strikes below the ledges' tops further off. (2) It shifts the rhythm every few
## attacks, a beat following each shift, and calls help when alone. (3) No more help; shifts come more often, so
## the swaps come faster and out of step.
static func heart(me: Fighter, foes: Array[Fighter], allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	if not me.is_actionable():
		return InputFrame.neutral()
	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	var gap := absf(dx) - me.spec.width / 2.0 - target.spec.width / 2.0
	if me.ai_cooldown != 0:
		return _mv(dir * FACING_NUDGE)
	if me.phase <= 1:
		me.ai_cooldown = tuning.heart_beat_gap
	else:
		me.ai_cooldown = rng.int_closed(tuning.heart_attack_gap.lower, tuning.heart_attack_gap.upper)

	# The beat that follows a shift.
	if me.ai_aux2 > 0:
		me.ai_aux2 = 0
		me.next_attack = HEART_BEAT
		return _mv(dir * FACING_NUDGE, true)
	if me.phase == 2:
		var alone := true
		for a: Fighter in allies:
			if a.id != me.id and a.is_alive():
				alone = false
				break
		if alone and me.ai_aux3 == 0:
			me.ai_aux3 = 5
			me.next_attack = HEART_CALL
			return _mv(dir * FACING_NUDGE, true)
		if me.ai_aux3 > 0:
			me.ai_aux3 -= 1
	if me.phase >= 2:
		me.ai_aux += 1
		var every := tuning.heart_final_shift_every if me.phase >= 3 else tuning.heart_shift_every
		if me.ai_aux >= every:
			me.ai_aux = 0
			me.ai_aux2 = 1
			me.next_attack = HEART_SHIFT
			return _mv(dir * FACING_NUDGE, true)
	var close: bool = gap < me.spec.attacks[HEART_PULSE].reach - 10.0 and absf(target.pos.y - me.pos.y) < 120.0
	me.next_attack = HEART_PULSE if close else HEART_BEAT
	return _mv(dir * FACING_NUDGE, true)


## Pause before a sworn fighter's next attack: shorter while the other lies down.
static func _sworn_gap(me: Fighter, allies: Array[Fighter], gap_range: Specs.IntRange, tuning: Tuning,
		rng: SeededRandom) -> int:
	var gap := rng.int_closed(gap_range.lower, gap_range.upper)
	var alone := true
	for a: Fighter in allies:
		if a.id != me.id and a.spec.sworn:
			alone = false
			break
	return int(float(gap) * tuning.sworn_fury_scale) if alone else gap


## The Sworn Shield. Slow to turn, so a hero behind it has a moment. Bashes anyone in reach; calls light
## down on anyone who keeps away.
static func sworn_shield(me: Fighter, foes: Array[Fighter], allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	if not me.is_actionable():
		return InputFrame.neutral()
	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	if dir != me.facing:
		me.ai_aux += 1
		if me.ai_aux < tuning.guard_turn_delay:
			return InputFrame.neutral()
	me.ai_aux = 0
	var gap := absf(dx) - me.spec.width / 2.0 - target.spec.width / 2.0
	var close: bool = gap < me.spec.attacks[SWORN_SHIELD_BASH].reach - 10.0
	if me.ai_cooldown != 0:
		return _mv(dir * FACING_NUDGE if close else dir)
	if close:
		me.next_attack = SWORN_SHIELD_BASH
	elif gap > tuning.sworn_light_from:
		me.next_attack = SWORN_SHIELD_LIGHT
	else:
		return _mv(dir)
	me.ai_cooldown = _sworn_gap(me, allies, tuning.sworn_shield_attack_gap, tuning, rng)
	return _mv(dir * FACING_NUDGE, true)


## The Sworn Spear. Keeps its target at the end of its spear: thrusts from there, leaps in from far off,
## and sweeps round both sides when someone gets inside its reach, or gives ground when it cannot.
static func sworn_spear(me: Fighter, foes: Array[Fighter], allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	if not me.is_actionable():
		return InputFrame.neutral()
	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	var gap := absf(dx) - me.spec.width / 2.0 - target.spec.width / 2.0
	var inside: bool = gap < tuning.sworn_spear_keep
	var in_reach: bool = gap < me.spec.attacks[SWORN_SPEAR_THRUST].reach - 10.0
	if me.ai_cooldown != 0:
		if inside:
			return _mv(-dir)
		return _mv(dir * FACING_NUDGE if in_reach else dir)
	if inside:
		me.next_attack = SWORN_SPEAR_SWEEP
	elif in_reach:
		me.next_attack = SWORN_SPEAR_THRUST
	elif gap > tuning.sworn_leap_from:
		me.next_attack = SWORN_SPEAR_LEAP
	else:
		return _mv(dir)
	me.ai_cooldown = _sworn_gap(me, allies, tuning.sworn_spear_attack_gap, tuning, rng)
	return _mv(dir * FACING_NUDGE, true)


## The Last Oracle. Walks the hero down. Up close, her staff or her gaze; at mid range, her gaze; far off,
## a prophecy laid where the hero is heading or something from the ground.
## Dawn: the gaze is a flare; sunfall. Dusk: Zealots when none are left; the gaze is an eclipse; the dark
## rises from the floor. The Ending: flare and eclipse alternate; everything comes faster.
static func oracle(me: Fighter, foes: Array[Fighter], allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	if not me.is_actionable():
		return InputFrame.neutral()
	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	if dir != me.facing:
		me.ai_aux += 1
		if me.ai_aux < tuning.oracle_turn_delay:
			return InputFrame.neutral()
	me.ai_aux = 0

	var gap := absf(dx) - me.spec.width / 2.0 - target.spec.width / 2.0
	var close: bool = gap < me.spec.attacks[ORACLE_STAFF].reach - 10.0
	var far: bool = gap > tuning.oracle_far
	if me.ai_cooldown != 0:
		return _mv(dir if gap > 40.0 else dir * FACING_NUDGE)

	var wait := float(rng.int_closed(tuning.oracle_attack_gap.lower, tuning.oracle_attack_gap.upper))
	me.ai_cooldown = int(wait * (tuning.oracle_ending_gap_scale if me.phase >= 3 else 1.0))
	var roll := rng.double_half_open(0.0, 1.0)
	var faithful_left := false
	for a: Fighter in allies:
		if a.kind == "zealot" and a.is_alive():
			faithful_left = true
			break
	var last := me.next_attack
	# Her light and her dark, in this phase.
	var gaze: int
	if me.phase == 1:
		gaze = ORACLE_FLARE
	elif me.phase == 2:
		gaze = ORACLE_ECLIPSE
	else:
		gaze = ORACLE_ECLIPSE if last == ORACLE_FLARE else ORACLE_FLARE
	var ground: int = ORACLE_SUNFALL if me.phase == 1 else ORACLE_DARK

	if me.phase == 2 and not faithful_left and last != ORACLE_FAITHFUL:
		me.next_attack = ORACLE_FAITHFUL
	elif close:
		me.next_attack = ORACLE_STAFF if roll < tuning.oracle_close_chance else gaze
	elif far:
		me.next_attack = ORACLE_PROPHECY if roll < 0.5 else ground
	elif roll < 0.45:
		me.next_attack = gaze
	else:
		# Mid range with nothing to throw: close in first.
		me.ai_cooldown = 10
		return _mv(dir)
	return _mv(dir * FACING_NUDGE, true)


## The Cinder King, in three phases.
## Offer: walks the hero down; cane up close, lanterns from further off.
## Debt: calls Ratborn whenever none are left, who shield him; between calls, fire from the floor and lanterns.
## Price: no more debtors. Faster, a sweep on both sides up close, wide eruptions from afar.
static func cinder_king(me: Fighter, foes: Array[Fighter], allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	if not me.is_actionable():
		return InputFrame.neutral()
	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	if dir != me.facing:
		me.ai_aux += 1
		if me.ai_aux < tuning.cinder_turn_delay:
			return InputFrame.neutral()
	me.ai_aux = 0

	var gap := absf(dx) - me.spec.width / 2.0 - target.spec.width / 2.0
	var close: bool = gap < me.spec.attacks[CINDER_CANE].reach - 10.0
	var debtors_left := false
	for a: Fighter in allies:
		if a.kind == "ratborn" and a.is_alive():
			debtors_left = true
			break
	# While his debtors fight he keeps back and lets them.
	var approach: float
	if me.phase == 2 and debtors_left:
		approach = -dir if gap < 220.0 else 0.0
	else:
		approach = dir if gap > 40.0 else dir * 0.02
	if me.ai_cooldown != 0:
		return _mv(approach)

	var wait := float(rng.int_closed(tuning.cinder_attack_gap.lower, tuning.cinder_attack_gap.upper))
	me.ai_cooldown = int(wait * (tuning.cinder_price_gap_scale if me.phase >= 3 else 1.0))
	var roll := rng.double_half_open(0.0, 1.0)
	match me.phase:
		1:
			me.next_attack = CINDER_CANE if (close and roll < tuning.cinder_close_chance) else CINDER_LANTERN
		2:
			if not debtors_left:
				me.next_attack = CINDER_DEBTORS
			else:
				me.next_attack = CINDER_CANE if close else (CINDER_VENTS if roll < 0.5 else CINDER_LANTERN)
		_:
			if close:
				me.next_attack = CINDER_SWEEP if roll < tuning.cinder_close_chance else CINDER_CANE
			else:
				me.next_attack = CINDER_WIDE_VENTS if roll < 0.5 else CINDER_LANTERN
	return _mv(dir * FACING_NUDGE, true)


## The Protocol, in three phases.
## Judgement: turns slowly, walks the hero down, and picks one of three attacks, each with a long warning.
## Ascension: takes to the air, summons drones and calls down light, then crashes down open; and again.
## Execution: back on the ground for good, faster, with a pulse on both sides and a beam across the room.
static func protocol(me: Fighter, foes: Array[Fighter], allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var target := _nearest(foes, me)
	if target == null:
		return InputFrame.neutral()
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	if not (me.is_actionable() and not me.descending):
		return InputFrame.neutral()
	if me.flying:
		return _protocol_fly(me, target, allies, tuning, rng)

	var dx := target.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	if dir != me.facing:
		me.ai_aux += 1
		if me.ai_aux < tuning.protocol_turn_delay:
			return InputFrame.neutral()
	me.ai_aux = 0

	var gap := absf(dx) - me.spec.width / 2.0 - target.spec.width / 2.0
	if me.ai_cooldown != 0:
		return _mv(dir if gap > 50.0 else dir * FACING_NUDGE)

	if me.phase == 2 and me.ai_aux2 >= tuning.protocol_ground_actions:
		me.ai_aux2 = 0
		me.flying = true
		me.ai_cooldown = tuning.protocol_takeoff_pause
		return InputFrame.neutral()
	var wait := float(rng.int_closed(tuning.protocol_attack_gap.lower, tuning.protocol_attack_gap.upper))
	me.ai_cooldown = int(wait * (tuning.protocol_execution_gap_scale if me.phase >= 3 else 1.0))
	me.ai_aux2 += 1
	var close: bool = gap < me.spec.attacks[PROTOCOL_SLAM].reach - 15.0
	if me.phase >= 3:
		var choices: Array[int]
		if close:
			choices = [PROTOCOL_SLAM, PROTOCOL_SLAM, PROTOCOL_PULSE]
		else:
			choices = [PROTOCOL_CHARGE, PROTOCOL_SURGE, PROTOCOL_PULSE, PROTOCOL_BEAM]
		me.next_attack = choices[rng.int_half_open(0, choices.size())]
	elif close and rng.double_half_open(0.0, 1.0) < tuning.protocol_slam_chance:
		# Up close it mostly slams, but not always, so standing at its feet is never one pattern.
		me.next_attack = PROTOCOL_SLAM
	else:
		me.next_attack = PROTOCOL_CHARGE if rng.coin() else PROTOCOL_SURGE
	return _mv(dir * FACING_NUDGE, true)


## In the air it drifts over the hero, and after a few attacks drops back down.
static func _protocol_fly(me: Fighter, target: Fighter, allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	var move := Sw.max_d(-1.0, Sw.min_d(1.0, (target.pos.x - me.pos.x) / 120.0))
	if not (me.ai_cooldown == 0 and absf(me.pos.y - tuning.protocol_flight_height) < 20.0):
		return _mv(move)
	if me.ai_aux2 >= tuning.protocol_air_actions:
		me.ai_aux2 = 0
		me.flying = false
		me.descending = true
		return InputFrame.neutral()
	me.ai_aux2 += 1
	me.ai_cooldown = rng.int_closed(tuning.protocol_air_gap.lower, tuning.protocol_air_gap.upper)
	var minions := 0
	for a: Fighter in allies:
		if a.id != me.id and not a.spec.immortal:
			minions += 1
	me.next_attack = PROTOCOL_SUMMON if (minions < tuning.protocol_max_minions and rng.coin()) else PROTOCOL_RAIN
	return _mv(move * FACING_NUDGE, true)


## The hero the player is not controlling: stays near the leader, fights what is near the leader, and gets
## out of the way of attacks it can see coming, most of the time.
static func partner(me: Fighter, foes: Array[Fighter], allies: Array[Fighter], tuning: Tuning,
		rng: SeededRandom) -> InputFrame:
	if me.ai_cooldown > 0:
		me.ai_cooldown -= 1
	var leader: Fighter = null
	for a: Fighter in allies:
		if a.id != me.id:
			leader = a
			break
	var special_case: String = me.spec.special.get("case", "")

	# Threats first.
	var threatened := false
	for foe: Fighter in foes:
		var fdx := foe.pos.x - me.pos.x
		var away: float = -1.0 if fdx >= 0.0 else 1.0
		if foe.state == Fighter.St.FUSE and absf(fdx) < 170.0:
			return _mv(away)
		var attack := foe.current_attack()
		if attack == null:
			continue
		if not (foe.attack_phase() == Fighter.Phase.WINDUP and attack.is_strike()
				and attack.windup - foe.state_frame <= 6
				and absf(fdx) < me.spec.width / 2.0 + foe.spec.width / 2.0 + attack.reach + 50.0
					+ (attack.lunge * float(attack.active) / 60.0 if attack.holds_still else 0.0)):
			continue
		threatened = true
		# Decide once per incoming attack whether it sees this one coming.
		if me.ai_aux != foe.id:
			me.ai_aux = foe.id
			if special_case == "adapt" and me.special_cooldown == 0 and me.is_actionable() \
					and rng.double_half_open(0.0, 1.0) < tuning.partner_guard_chance:
				return InputFrame.make(-away * FACING_NUDGE, false, false, false, false, true)
			if rng.double_half_open(0.0, 1.0) < tuning.partner_dodge_chance:
				# Against a shield it dodges through, to come out behind it.
				return InputFrame.make(-away if foe.spec.frontal_block else away, false, false, false, true)
	if not threatened:
		me.ai_aux = 0

	# Under AI, Seraphine heals when either of them is badly hurt.
	if special_case == "heal" and me.special_cooldown == 0 and me.is_actionable():
		var heal_range: float = float(me.spec.special["range"])
		var hurt: bool = me.hp < me.spec.max_hp * 0.5
		if not hurt:
			for a: Fighter in allies:
				if a.id != me.id and absf(a.pos.x - me.pos.x) <= heal_range and a.hp < a.spec.max_hp * 0.5:
					hurt = true
					break
		if hurt:
			return InputFrame.make(0.0, false, false, false, false, true)
	# Under AI, Nimue leaves a decoy when she is crowded.
	if special_case == "decoy" and me.special_cooldown == 0 and me.is_actionable():
		var crowd := 0
		for f: Fighter in foes:
			if not f.spec.is_decoy and absf(f.pos.x - me.pos.x) < 160.0:
				crowd += 1
		if crowd >= 2:
			return InputFrame.make(0.0, false, false, false, false, true)

	# Fight what is near the leader, or near itself when it is alone.
	var anchor: Fighter = leader if leader != null else me
	var in_reach: Array[Fighter] = []
	for f: Fighter in foes:
		if absf(f.pos.x - anchor.pos.x) <= tuning.partner_engage_range:
			in_reach.append(f)
	# The leader's mark comes before whatever happens to be nearest.
	var target: Fighter = null
	for f: Fighter in in_reach:
		if f.marked_frames > 0:
			target = f
			break
	if target == null:
		for f: Fighter in in_reach:
			if f.spec.ward_radius > 0.0:
				target = f
				break
	if target == null:
		# Something it can reach before something flying overhead.
		var grounded: Array[Fighter] = []
		for f: Fighter in in_reach:
			if not f.flying:
				grounded.append(f)
		target = _closest(in_reach if grounded.is_empty() else grounded, me)
	if target != null:
		# Under AI, Caelen marks a tough enemy when nothing is marked yet.
		if special_case == "command" and me.special_cooldown == 0 and me.is_actionable():
			var command_range: float = float(me.spec.special["range"])
			var any_marked := false
			for f: Fighter in foes:
				if f.marked_frames > 0:
					any_marked = true
					break
			if not any_marked and target.hp >= 60.0 and absf(target.pos.x - me.pos.x) <= command_range:
				var toward: float = 1.0 if target.pos.x >= me.pos.x else -1.0
				return InputFrame.make(toward * FACING_NUDGE, false, false, false, false, true)
		var dx := target.pos.x - me.pos.x
		var dir: float = 1.0 if dx >= 0.0 else -1.0
		# Hitting a raised shield does nothing, so it stands just out of reach and waits for an opening.
		var shielded: bool = target.is_guarding() and (me.pos.x - target.pos.x) * target.facing >= 0.0
		if shielded and not target.spec.attacks.is_empty():
			var swing: Specs.AttackSpec = target.spec.attacks[0]
			var standoff := target.spec.width / 2.0 + swing.reach + me.spec.width / 2.0 + 24.0
			if absf(dx) < standoff:
				return _mv(-dir)
			if absf(dx) > standoff + 30.0:
				return _mv(dir)
			return _mv(dir * FACING_NUDGE)
		if absf(dx) > _strike_distance(me, target):
			return _mv(dir)
		if me.ai_cooldown == 0:
			me.ai_cooldown = rng.int_closed(tuning.partner_attack_gap.lower, tuning.partner_attack_gap.upper)
			return _mv(dir * FACING_NUDGE, true)
		return _mv(dir * FACING_NUDGE)

	# Nothing to fight: fall in behind the leader.
	if leader == null:
		return InputFrame.neutral()
	var ldx := leader.pos.x - leader.facing * tuning.partner_follow_distance - me.pos.x
	if absf(ldx) < 30.0:
		return InputFrame.neutral()
	return _mv(Sw.max_d(-1.0, Sw.min_d(1.0, ldx / 60.0)))
