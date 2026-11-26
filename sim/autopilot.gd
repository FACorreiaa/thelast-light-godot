class_name Autopilot
extends RefCounted
## Plays a level by reading its geometry: runs right, jumps the walls and gaps it can clear, and waits
## for platforms and for hazards to switch off. It is how a level is proven finishable in tests, and how
## the app is watched without hands. With `fights` on it also swings at whatever stands in its way.
##
## A mechanical port of Swift `Autopilot.swift`. Fighters read from the world are never mutated here.

var fights: bool
var _jump_held: int = 0


func _init(p_fights: bool = false) -> void:
	fights = p_fights


# Swift `list.min { abs($0.pos.x - me.pos.x) < abs($1.pos.x - me.pos.x) }`: the first among ties.
static func _closest(list: Array[Fighter], me: Fighter) -> Fighter:
	var best: Fighter = null
	for f: Fighter in list:
		if best == null:
			best = f
		elif absf(f.pos.x - me.pos.x) < absf(best.pos.x - me.pos.x):
			best = f
	return best


static func _share(f: Fighter) -> float:
	return f.hp / f.spec.max_hp


## Swift `mutating func input(for:)`.
func input_for(world: World) -> InputFrame:
	var out := _input_for(world)
	# Port-only: on a level with eclipse phases, never walk or dodge onto ground that is gone or will go before
	# the hero is across, whatever the branch above wanted (fighting, a boss, walking).
	var me := world.controlled()
	if me != null and world.eclipse_air_unsafe(me, out.move_x):
		out.move_x = 0.0
		return out
	var clear := world.eclipse_clear(me) if me != null else 0.0
	if clear != 0.0:
		return InputFrame.make(clear, false, out.jump_held)
	var escape := world.eclipse_escape(me) if me != null else 0.0
	if escape != 0.0:
		return InputFrame.make(escape, false, out.jump_held)
	if me != null and me.on_ground and absf(out.move_x) > 0.1 and (world.eclipse_blocks(me, 1.0 if out.move_x > 0.0 else -1.0)
			or world.eclipse_held(me, 1.0 if out.move_x > 0.0 else -1.0)):
		out.move_x = 0.0
		out.dodge = false
		out.jump = false
	return out


func _input_for(world: World) -> InputFrame:
	var me := world.controlled()
	if me == null:
		return InputFrame.neutral()
	var level := world.level
	if level == null:
		return InputFrame.neutral()
	var half := me.spec.width / 2.0
	var inp := InputFrame.make(1.0, false, _jump_held > 0)
	if _jump_held > 0:
		_jump_held -= 1

	var special := _kit_special(me, world)
	if special != null:
		return special
	var boss := world.boss()
	if boss != null:
		# A sworn pair has to fall together: wear down whichever has more left, so neither lies down long alone.
		var pair: Array[Fighter] = []
		if boss.is_alive():
			pair.append(boss)
		var twin := world.twin()
		if twin != null and twin.is_alive():
			pair.append(twin)
		# Swift `max(by:)`: replace only when the kept one orders strictly before the next.
		var target: Fighter = null
		for b: Fighter in pair:
			if target == null:
				target = b
				continue
			var a := target
			var increasing: bool
			if absf(_share(a) - _share(b)) < 0.08:
				increasing = absf(a.pos.x - me.pos.x) > absf(b.pos.x - me.pos.x)
			else:
				increasing = _share(a) < _share(b)
			if increasing:
				target = b
		if target == null:
			return InputFrame.neutral()
		return _boss_input(me, target, world)

	# A long attack about to land from further away, such as a Sentry Core's beam: dodge it.
	var beam := false
	for foe: Fighter in world.fighters:
		if not (foe.team == "enemy" and foe.is_alive() and foe.awake):
			continue
		var attack := foe.current_attack()
		if attack == null:
			continue
		if not (attack.reach > 150.0 and foe.attack_phase() == Fighter.Phase.WINDUP
				and attack.windup - foe.state_frame <= 4):
			continue
		var ahead := (me.pos.x - foe.pos.x) * foe.facing
		if ahead >= 0.0 and ahead <= foe.spec.width / 2.0 + attack.reach + half \
				and me.pos.y < foe.pos.y + attack.y_offset + attack.height \
				and me.pos.y + me.spec.height > foe.pos.y + attack.y_offset:
			beam = true
			break
	if beam and me.on_ground:
		return InputFrame.make(1.0, false, false, false, true)

	if fights:
		var nearby: Array[Fighter] = []
		for f: Fighter in world.fighters:
			if f.team == "enemy" and f.is_alive() and not f.spec.immortal and absf(f.pos.y - me.pos.y) < 70.0:
				nearby.append(f)
		# A shielded machine cannot be hurt: go for the Dogma Frame that shields it.
		var unwarded: Array[Fighter] = []
		for f: Fighter in nearby:
			if not world.is_warded(f.id):
				unwarded.append(f)
		var foe := _closest(unwarded, me)
		if foe != null and absf(foe.pos.x - me.pos.x) < 96.0:
			var dir: float = 1.0 if foe.pos.x >= me.pos.x else -1.0
			if foe.state == Fighter.St.FUSE:
				return InputFrame.make(-dir)
			# Dodges through a shield to get behind it, and through a swing it sees coming.
			var foe_attack := foe.current_attack()
			var swing_coming: bool = foe.attack_phase() == Fighter.Phase.WINDUP \
				and (foe_attack.windup - foe.state_frame <= 5 if foe_attack != null else false)
			var shielded: bool = foe.is_guarding() and (me.pos.x - foe.pos.x) * foe.facing >= 0.0
			if swing_coming or (shielded and world.frame % 40 == 0):
				return InputFrame.make(dir, false, false, false, true)
			return InputFrame.make(dir * 0.02, false, false, world.frame % 8 == 0)
	if not me.on_ground:
		return inp
	var step := _puzzle_input(me, world, level)
	if step != null:
		return step

	# A hazard just ahead that is on, or will be before the hero is through.
	var wait_for_hazard := false
	for h: Level.Hazard in level.hazards:
		var ahead := h.box.min_x - (me.pos.x + half)
		if not (ahead > -(h.box.max_x - h.box.min_x) - me.spec.width and ahead < 50.0):
			continue
		if h.is_on(world.frame) or h.frames_until_on(world.frame) < 45:
			wait_for_hazard = true
			break
	if wait_for_hazard:
		inp.move_x = 0.0
		return inp


	# A wall ahead: jump it if it is low enough, otherwise wait on the lift beside it.
	# Swift zips platforms with their boxes: the shorter of the two bounds the walk.
	var solids := mini(world.platforms.size(), world.platform_boxes.size())
	var wall: Box = null
	for i: int in solids:
		var p: Level.Platform = world.platforms[i]
		var b: Box = world.platform_boxes[i]
		if not p.one_way and b.min_x >= me.pos.x and b.min_x - (me.pos.x + half) < 34.0 \
				and b.max_y > me.pos.y + 1.0 and b.min_y < me.pos.y + me.spec.height:
			wall = b
			break
	if wall != null:
		if wall.max_y - me.pos.y <= 105.0:
			_jump(inp)
		else:
			var lift: Box = null
			for i: int in solids:
				var p: Level.Platform = world.platforms[i]
				var b: Box = world.platform_boxes[i]
				if p.moves() and p.travel.y != 0.0 and absf(b.max_x - wall.min_x) < 80.0:
					lift = b
					break
			if lift != null:
				var riding: bool = world.platforms[me.ground_index].moves() if me.ground_index >= 0 else false
				var centre := (lift.min_x + lift.max_x) / 2.0
				inp.move_x = 0.0 if riding else Sw.max_d(-1.0, Sw.min_d(1.0, (centre - me.pos.x) / 20.0))
		return inp

	# An edge ahead: jump only when there is somewhere to land.
	var probe := me.pos.x + half + 26.0
	var footing := false
	for b: Box in world.platform_boxes:
		if b.min_x <= probe and probe <= b.max_x and absf(b.max_y - me.pos.y) < 2.0:
			footing = true
			break
	if not footing:
		if _surface(me, world, me.pos.x + 70.0, me.pos.x + 165.0, 60.0, 200.0):
			_jump(inp)
		elif not _surface(me, world, me.pos.x + half, me.pos.x + 60.0, 1.0, 400.0):
			inp.move_x = 0.0
	return inp


# The Swift local `surface(from:to:above:below:)`.
func _surface(me: Fighter, world: World, x0: float, x1: float, above: float, below: float) -> bool:
	for b: Box in world.platform_boxes:
		if b.max_x > x0 and b.min_x < x1 and b.max_y <= me.pos.y + above and b.max_y >= me.pos.y - below:
			return true
	return false


## Against a boss: keep out of falling light, dodge each attack just before it lands, deal with what it
## summons, and strike only while it is open.
func _boss_input(me: Fighter, boss: Fighter, world: World) -> InputFrame:
	var half := me.spec.width / 2.0
	var dx := boss.pos.x - me.pos.x
	var dir: float = 1.0 if dx >= 0.0 else -1.0
	var gap := absf(dx) - boss.spec.width / 2.0 - me.spec.width / 2.0
	if not boss.awake:
		return InputFrame.make(dir)

	var strike: Strike = null
	for s: Strike in world.strikes:
		if s.box.min_x - 30.0 < me.pos.x + half and me.pos.x - half < s.box.max_x + 30.0:
			strike = s
			break
	if strike != null:
		var away: float = 1.0 if me.pos.x >= strike.box.center().x else -1.0
		var room: float = world.arena_hi - me.pos.x if away > 0.0 else me.pos.x - world.arena_lo
		if room < strike.box.width() + 60.0:
			away = -away
		return InputFrame.make(away)

	# Either of a pair may be about to swing.
	var swinging: Fighter = null
	if boss.is_alive() and boss.attack_phase() == Fighter.Phase.WINDUP:
		swinging = boss
	else:
		var twin := world.twin()
		if twin != null and twin.is_alive() and twin.attack_phase() == Fighter.Phase.WINDUP:
			swinging = twin
	if swinging != null and swinging.id != boss.id:
		var s_attack := swinging.current_attack()
		if s_attack != null and s_attack.is_strike():
			var sdx := swinging.pos.x - me.pos.x
			var in_front: bool = s_attack.both_sides or (me.pos.x - swinging.pos.x) * swinging.facing >= 0.0
			var travel: float = s_attack.lunge * float(s_attack.active) / 60.0 if s_attack.holds_still else 0.0
			var reach := swinging.spec.width / 2.0 + s_attack.reach + travel + half
			if in_front and absf(sdx) <= reach and s_attack.windup - swinging.state_frame <= 4:
				return InputFrame.make(1.0 if sdx >= 0.0 else -1.0, false, false, false, true)
	var b_attack := boss.current_attack()
	if b_attack != null and boss.attack_phase() == Fighter.Phase.WINDUP and b_attack.is_strike():
		var in_front: bool = b_attack.both_sides or (me.pos.x - boss.pos.x) * boss.facing >= 0.0
		var travel: float = b_attack.lunge * float(b_attack.active) / 60.0 if b_attack.holds_still else 0.0
		var reach := boss.spec.width / 2.0 + b_attack.reach + travel + half
		if in_front and absf(dx) <= reach and b_attack.windup - boss.state_frame <= 4:
			return InputFrame.make(dir, false, false, false, true)
		return InputFrame.make(dir if gap > 30.0 else dir * 0.02)

	var minions: Array[Fighter] = []
	for f: Fighter in world.fighters:
		if f.team == "enemy" and f.is_alive() and not f.spec.boss and absf(f.pos.y - me.pos.y) < 70.0:
			minions.append(f)
	var minion := _closest(minions, me)
	if minion != null and absf(minion.pos.x - me.pos.x) < 110.0:
		var toward: float = 1.0 if minion.pos.x >= me.pos.x else -1.0
		if minion.state == Fighter.St.FUSE:
			return InputFrame.make(-toward)
		var m_attack := minion.current_attack()
		var bite_coming: bool = minion.attack_phase() == Fighter.Phase.WINDUP \
			and (m_attack.windup - minion.state_frame <= 5 if m_attack != null else false)
		if bite_coming:
			return InputFrame.make(toward, false, false, false, true)
		return InputFrame.make(toward * 0.02, false, false, world.frame % 8 == 0)

	# A boss that needs light: light the lamp nearest it, or wait by a lit one for it to come.
	if boss.spec.needs_light and world.is_warded(boss.id) and world.level != null:
		var lamp: Level.Lever = null
		for l: Level.Lever in world.level.levers:
			if not (l.glow > 0.0):
				continue
			if lamp == null:
				lamp = l
			elif absf(l.pos.x - boss.pos.x) < absf(lamp.pos.x - boss.pos.x):
				lamp = l
		if lamp != null:
			var ldx := lamp.pos.x - me.pos.x
			if absf(ldx) > 30.0:
				return InputFrame.make(1.0 if ldx > 0.0 else -1.0)
			var lit: bool = world.signals.has(lamp.id)
			return InputFrame.make((dir if lit else (1.0 if ldx >= 0.0 else -1.0)) * 0.02, false, false,
				not lit and world.frame % 8 == 0)

	# Up in the air it cannot be reached: wait near it, out of its way.
	if boss.flying or boss.descending:
		return InputFrame.make(dir if absf(dx) > 170.0 else (-dir if absf(dx) < 110.0 else 0.0))
	if boss.is_open():
		var reach: float = me.spec.attacks[0].reach if not me.spec.attacks.is_empty() else 0.0
		if gap > reach - 12.0:
			return InputFrame.make(dir)
		return InputFrame.make(dir * 0.02, false, false, world.frame % 8 == 0)
	# Between attacks: mark it when Command is ready.
	if me.spec.special.get("case", "") == "command" and me.special_cooldown == 0 and boss.marked_frames == 0 \
			and absf(dx) <= float(me.spec.special["range"]):
		return InputFrame.make(dir * 0.02, false, false, false, false, true)
	return InputFrame.make(dir if gap > 45.0 else (-dir if gap < 25.0 else dir * 0.02))


# The Swift closure `needed`: a shut gate this plate opens still stands ahead of the lead.
func _plate_needed(id: int, level: Level, lead_x: float) -> bool:
	for g: Level.Gate in level.gates:
		if not g.inverted and g.opens_with.has(id) and g.box.min_x > lead_x - 10.0:
			return true
	return false


# The Swift closure `blocking`: all this plate does is hold shut an inverted gate ahead of the lead.
func _plate_blocking(id: int, level: Level, world: World, lead_x: float) -> bool:
	for g: Level.Gate in level.gates:
		if g.inverted and g.opens_with.has(id) and g.box.min_x > lead_x - 10.0 \
				and float(world.gate_open.get(g.id, 1.0)) < 1.0:
			return true
	return false


# Swift `InputFrame(switchHero: world.frame % 20 == 0)`.
static func _switch(world: World) -> InputFrame:
	return InputFrame.make(0.0, false, false, false, false, false, world.frame % 20 == 0)


## Puzzles: throw a lever on the way past when its gate lies ahead (a timed one only once the gate's other
## inputs are on, so the clock isn't wasted); have Orion hold a plate a gate ahead needs (take him there,
## then hand control back); and wait for an opening gate rather than jump at it. Null for "nothing to do".
func _puzzle_input(me: Fighter, world: World, level: Level) -> InputFrame:
	var ahead: Array[Level.Gate] = []
	for g: Level.Gate in level.gates:
		if g.box.min_x > me.pos.x - 10.0 and float(world.gate_open.get(g.id, 1.0)) < 1.0:
			ahead.append(g)

	# Port-only, eclipse levels only (Swift's levels keep Swift's pilot): with the lead down, Orion walks on alone;
	# switching to no one would wait for ever.
	var lead_alive := true
	if level.eclipse_period > 0:
		lead_alive = false
		for f: Fighter in world.fighters:
			if f.team == "hero" and f.kind != "orion" and not f.spec.is_decoy and f.is_alive():
				lead_alive = true
				break
	if me.kind == "orion" and lead_alive:
		var lead_x := me.pos.x
		for f: Fighter in world.fighters:
			if f.team == "hero" and f.kind != "orion" and not f.spec.is_decoy and f.is_alive():
				lead_x = f.pos.x
				break
		# A plate is worth holding while a shut gate it opens still stands ahead of the lead, and worth
		# leaving once all it does is hold shut an inverted gate ahead of the lead.
		var under := world.plate_under(me)
		if under != null:
			if _plate_blocking(under.id, level, world, lead_x) and not _plate_needed(under.id, level, lead_x):
				return InputFrame.make(-1.0 if lead_x >= me.pos.x else 1.0)
			return _switch(world)
		var wanted: Level.Plate = null
		for g: Level.Gate in ahead:
			if not (g.box.min_x - me.pos.x < 700.0):
				continue
			for id: int in g.opens_with:
				for pl: Level.Plate in level.plates:
					if pl.id == id and not world.signals.has(id) and _plate_needed(id, level, lead_x):
						wanted = pl
						break
				if wanted != null:
					break
			if wanted != null:
				break
		if wanted == null:
			return _switch(world)
		var pdx := (wanted.x0 + wanted.x1) / 2.0 - me.pos.x
		return InputFrame.make(1.0 if pdx > 0.0 else -1.0)

	for lever: Level.Lever in level.levers:
		if not (not world.signals.has(lever.id) and absf(lever.pos.x - me.pos.x) < 34.0
				and absf(lever.pos.y - me.pos.y) < 10.0):
			continue
		var lever_gate: Level.Gate = null
		for g: Level.Gate in ahead:
			if g.opens_with.has(lever.id):
				lever_gate = g
				break
		if lever_gate == null:
			continue
		# A bell rings only after the one before it.
		if lever_gate.in_order:
			# First input not yet on; -1 stands for Swift nil, which never equals a lever id.
			var next_bell := -1
			var found := false
			for input: int in lever_gate.opens_with:
				if not world.signals.has(input):
					next_bell = input
					found = true
					break
			if not found or next_bell != lever.id:
				continue
		var others_on := true
		for input: int in lever_gate.opens_with:
			var ok: bool = input == lever.id or world.signals.has(input)
			if not ok:
				for l: Level.Lever in level.levers:
					if l.id == input:
						ok = true
						break
			if not ok:
				others_on = false
				break
		if lever.hold_frames == 0 or others_on:
			var ldir: float = 1.0 if lever.pos.x >= me.pos.x else -1.0
			return InputFrame.make(ldir * 0.02, false, false, world.frame % 8 == 0)

	var gate: Level.Gate = null
	for g: Level.Gate in ahead:
		if not (g.box.min_x - me.pos.x < (1000.0 if g.in_order else 260.0) and g.box.min_y <= me.pos.y + 1.0
				and g.box.max_y > me.pos.y + 1.0):
			continue
		if gate == null:
			gate = g
		elif g.box.min_x < gate.box.min_x:
			gate = g
	if gate == null:
		return null
	if world.wants_open(gate):
		return InputFrame.neutral() if gate.box.min_x - (me.pos.x + me.spec.width / 2.0) < 40.0 else null
	if gate.inverted:
		# Shut because a plate is down: hand over to whoever holds it, to step off.
		var held := false
		for id: int in gate.opens_with:
			var is_plate := false
			for pl: Level.Plate in level.plates:
				if pl.id == id:
					is_plate = true
					break
			if is_plate and world.signals.has(id):
				held = true
				break
		return _switch(world) if held else null
	var missing := -1
	var any_missing := false
	for input: int in gate.opens_with:
		if not world.signals.has(input):
			missing = input
			any_missing = true
			break
	if not any_missing:
		return null
	var missing_is_plate := false
	for pl: Level.Plate in level.plates:
		if pl.id == missing:
			missing_is_plate = true
			break
	if missing_is_plate:
		# Hand over to Orion to put him on it.
		var orion := false
		for f: Fighter in world.fighters:
			if f.kind == "orion" and f.is_alive() and f.awake:
				orion = true
				break
		return _switch(world) if orion else null
	for lever: Level.Lever in level.levers:
		if lever.id == missing:
			var dx := lever.pos.x - me.pos.x
			var dir: float = 1.0 if dx >= 0.0 else -1.0
			if absf(dx) > 34.0:
				return InputFrame.make(dir)
			return InputFrame.make(dir * 0.02, false, false, world.frame % 8 == 0)
	return null


## Seraphine heals when someone is low; Nimue leaves a decoy when crowded. Caelen's Command is used in
## the fights themselves. Null for "no special this frame".
func _kit_special(me: Fighter, world: World) -> InputFrame:
	if not (me.special_cooldown == 0 and me.is_actionable()):
		return null
	match me.spec.special.get("case", ""):
		"heal":
			var low := false
			for f: Fighter in world.fighters:
				if f.team == "hero" and f.is_alive() and f.awake and not f.spec.is_decoy \
						and f.hp < f.spec.max_hp * 0.5:
					low = true
					break
			return InputFrame.make(0.0, false, false, false, false, true) if low else null
		"decoy":
			var crowd := 0
			for f: Fighter in world.fighters:
				if f.team == "enemy" and f.is_alive() and f.awake and not f.spec.immortal \
						and absf(f.pos.x - me.pos.x) < 160.0:
					crowd += 1
			return InputFrame.make(0.0, false, false, false, false, true) if crowd >= 2 else null
		_:
			return null


func _jump(inp: InputFrame) -> void:
	inp.jump = true
	inp.jump_held = true
	_jump_held = 30

