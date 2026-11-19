class_name World
extends RefCounted
## The whole game state. `step` advances it by one sixtieth of a second and is fully deterministic:
## the same seed and the same inputs always give the same events. A port of the Swift `World`
## (game-proto `swift-final`), checked against it frame by frame by state hash.
##
## Swift's World is a value type full of value types. Every place Swift copies a Fighter, Vec2 or
## Box (`let snapshot = fighters`, `var f = fighters[i]`, `let me = fighters[i]`) copies here too.
## Events are dictionaries keyed like the Swift enum: {"case": "hit", "attacker": 1, ...}.

var tuning: Tuning
var arena_lo: float
var arena_hi: float
## Null in the training room, which is one flat floor.
var level: Level = null

var fighters: Array[Fighter] = []
var controlled_id: int = -1
var frame: int = 0
var hit_stop: int = 0
var is_over: bool = false
var wave_number: int = 0
## Where every platform is on this frame, in the same order as `platforms`.
var platform_boxes: Array[Box] = []
var platforms: Array[Level.Platform] = []
var checkpoint_index: int = -1
## Set of collected pickup ids (keys only).
var collected: Dictionary = {}
var is_complete: bool = false
var boss_id: int = -1
## The boss sworn to the first one, in a level with a pair; -1 for none.
var twin_id: int = -1
## Frames one of a sworn pair has lain down while the other stands.
var vow_frames: int = 0
var boss_down_frames: int = 0
## Set of scene ids already announced (keys only).
var fired_scenes: Dictionary = {}
var strikes: Array[Strike] = []
var platform_deltas: Array[Vec2] = []
## Set of lever and plate ids that are on (keys only).
var signals: Dictionary = {}
## Lever id -> frames until it springs back.
var lever_timers: Dictionary = {}
## Gate id -> how far open, 0.0 (shut) to 1.0.
var gate_open: Dictionary = {}
## Gate id -> index into `platforms` of its block.
var gate_platform: Dictionary = {}

## Each wave is an array of [kind: String, x: float] pairs, x a fraction of the arena width.
var waves: Array = []
var wave_live: bool = false
var wave_delay: int = 0
var switch_cooldown: int = 0
var rng: SeededRandom
var next_id: int = 1


## The training room: one flat floor across the arena.
static func training(p_tuning: Tuning, seed: int, lo: float = 0.0, hi: float = 1400.0) -> World:
	var w := World.new()
	w.tuning = p_tuning
	w.arena_lo = lo
	w.arena_hi = hi
	w.rng = SeededRandom.new(seed)
	w.platforms.append(Level.Platform.make(Box.new(lo - 2000.0, -600.0, hi + 2000.0, 0.0)))
	for p in w.platforms:
		w.platform_boxes.append(p.box.copy())
		w.platform_deltas.append(Vec2.zero())
	return w


## Stage 1: Caelen alone in a grey-box room with a training dummy and looping waves.
static func feel_slice(seed: int, p_tuning: Tuning) -> World:
	var w := World.training(p_tuning, seed)
	w.spawn("dummy", 150.0, 0.0, 1.0)
	w.control(w.spawn("caelen", 380.0, 0.0, 1.0))
	w.set_waves([
		[["scrapDrone", 0.92], ["scrapDrone", 0.99]],
		[["forgedSoldier", 0.95]],
		[["scrapDrone", 0.90], ["scrapDrone", 0.97], ["forgedSoldier", 0.99]],
		[["forgedSoldier", 0.94], ["scrapDrone", 0.02], ["scrapDrone", 0.99], ["scrapDrone", 0.86]],
	], 240)
	return w


## Stage 2: the same room with Orion at Caelen's side. The player can switch between them.
static func partner_slice(seed: int, p_tuning: Tuning) -> World:
	var w := feel_slice(seed, p_tuning)
	w.spawn("orion", 290.0, 0.0, 1.0)
	return w


## A world built from level data. `from_checkpoint` and `p_collected` carry progress across a retry.
static func from_level(p_level: Level, hero: String, p_tuning: Tuning, seed: int,
		from_checkpoint: int = -1, p_collected: Dictionary = {}) -> World:
	var w := World.new()
	w.tuning = p_tuning
	w.level = p_level
	w.arena_lo = 0.0
	w.arena_hi = p_level.width
	w.rng = SeededRandom.new(seed)
	# Gates are solid blocks that move; they go after the level's own platforms.
	for p in p_level.platforms:
		w.platforms.append(p)
	for g in p_level.gates:
		w.platforms.append(Level.Platform.make(g.box.copy()))
	for n in p_level.gates.size():
		var g := p_level.gates[n]
		w.gate_platform[g.id] = p_level.platforms.size() + n
		# Nothing is on at the start, so an inverted gate starts open.
		w.gate_open[g.id] = 1.0 if g.inverted else 0.0
	for p in w.platforms:
		w.platform_boxes.append(p.box_at(0) if p_level.eclipse_solid(p, 0) else _eclipsed(p))
	for g in p_level.gates:
		if g.inverted and w.gate_platform.has(g.id):
			w.platform_boxes[int(w.gate_platform[g.id])] = g.box.offset(0.0, g.box.max_y - g.box.min_y + 20.0)
	for _p in w.platforms:
		w.platform_deltas.append(Vec2.zero())
	w.collected = p_collected.duplicate()
	w.checkpoint_index = mini(from_checkpoint, p_level.checkpoints.size() - 1)
	var origin: Vec2 = p_level.checkpoints[w.checkpoint_index] if w.checkpoint_index >= 0 else p_level.start
	w.control(w.spawn(hero, origin.x, origin.y, 1.0))
	if p_level.partner != null:
		var p := p_level.partner
		var joined := p.pos.x <= origin.x + 130.0
		w.spawn(p.kind, origin.x - 50.0 if joined else p.pos.x, origin.y if joined else p.pos.y, 1.0)
		w.fighters[w.fighters.size() - 1].awake = joined
	# After a retry, what was behind the checkpoint stays gone.
	for e in p_level.enemies:
		if w.checkpoint_index < 0 or e.pos.x > origin.x - 100.0 or p_tuning.spec(e.kind).immortal:
			w.spawn(e.kind, e.pos.x, e.pos.y, -1.0)
			w.fighters[w.fighters.size() - 1].awake = p_tuning.spec(e.kind).brain == ""
	if p_level.boss != null:
		w.boss_id = w.spawn(p_level.boss.kind, p_level.boss.pos.x, p_level.boss.pos.y, -1.0)
		w.fighters[w.fighters.size() - 1].awake = false
	if p_level.twin != null:
		w.twin_id = w.spawn(p_level.twin.kind, p_level.twin.pos.x, p_level.twin.pos.y, -1.0)
		w.fighters[w.fighters.size() - 1].awake = false
	return w


# MARK: Lookup


## The fighter the player controls, or null. A live object: read it, do not change it.
func controlled() -> Fighter:
	return fighter(controlled_id)


func boss() -> Fighter:
	return fighter(boss_id) if boss_id >= 0 else null


func twin() -> Fighter:
	return fighter(twin_id) if twin_id >= 0 else null


## The other one of a sworn pair, for either of them; -1 for anyone else.
func sworn_partner(id: int) -> int:
	if boss_id < 0 or twin_id < 0:
		return -1
	if id == boss_id:
		return twin_id
	return boss_id if id == twin_id else -1


func fighter(id: int) -> Fighter:
	for f in fighters:
		if f.id == id:
			return f
	return null


func index_of(id: int) -> int:
	for i in fighters.size():
		if fighters[i].id == id:
			return i
	return -1


# MARK: Setup


## Adds a fighter and returns its id. `p_facing` null faces it toward the middle of the arena;
## `p_spec` null uses the tuning's spec for the kind.
func spawn(kind: String, x: float, y: float = 0.0, p_facing: Variant = null, p_spec: Specs.FighterSpec = null) -> int:
	var id := next_id
	next_id += 1
	var mid := (arena_lo + arena_hi) / 2.0
	var facing: float = float(p_facing) if p_facing != null else (1.0 if x <= mid else -1.0)
	var spec := p_spec if p_spec != null else tuning.spec(kind)
	var f := Fighter.make(id, kind, Fighter.team_of(kind), spec, Vec2.new(x, y), facing)
	if f.spec.lifetime > 0:
		f.expires = f.spec.lifetime
	fighters.append(f)
	return id


func control(id: int) -> void:
	controlled_id = id


func set_waves(p_waves: Array, first_delay: int) -> void:
	waves = p_waves
	wave_delay = first_delay


# MARK: Step


func step(input: InputFrame) -> Array:
	if is_over:
		return []
	var ci := index_of(controlled_id)
	if ci >= 0:
		_latch(fighters[ci], input)
	if hit_stop > 0:
		hit_stop -= 1
		return []

	var events: Array = []
	var explosions: Array[int] = []
	if switch_cooldown > 0:
		switch_cooldown -= 1
	if input.switch_hero and switch_cooldown == 0:
		var other := _other_hero()
		if other >= 0:
			_pass_control(other, events)
	for i in platforms.size():
		if platforms[i].moves() and platforms[i].eclipse == 0:
			var nb := platforms[i].box_at(frame + 1)
			platform_deltas[i] = Vec2.new(nb.min_x - platform_boxes[i].min_x, nb.min_y - platform_boxes[i].min_y)
			platform_boxes[i] = nb
	if level != null and level.eclipse_period > 0:
		_eclipse_platforms(events)
	var snapshot: Array[Fighter] = []
	for g in fighters:
		snapshot.append(g.copy())
	var lead_snap: Fighter = null
	for g in snapshot:
		if g.id == controlled_id:
			lead_snap = g
			break
	for i in fighters.size():
		var f := fighters[i].copy()
		var inp := InputFrame.neutral()
		if f.id == controlled_id:
			inp = input
		elif f.is_alive() and not f.awake and f.team == "hero":
			# A companion waiting to be found.
			if lead_snap != null and lead_snap.is_alive() and absf(lead_snap.pos.x - f.pos.x) <= tuning.join_range \
					and absf(lead_snap.pos.y - f.pos.y) <= 120.0:
				f.awake = true
				f.facing = lead_snap.facing
				events.append({"case": "joined", "id": f.id})
		elif f.is_alive() and not f.awake:
			var noticed := false
			for s in snapshot:
				if s.team == "hero" and s.is_alive() and s.awake and absf(s.pos.x - f.pos.x) <= tuning.wake_range \
						and absf(s.pos.y - f.pos.y) <= tuning.wake_height:
					noticed = true
					break
			if noticed:
				f.awake = true
				f.ai_aux = 0
				if f.spec.wake_delay > 0:
					f.ai_cooldown = f.spec.wake_delay
				events.append({"case": "woke", "id": f.id})
			elif f.spec.run_speed > 0.0 and not f.spec.rooted and not f.spec.boss:
				# Paces back and forth until a hero comes close.
				f.patrol_frames += 1
				if f.patrol_frames >= tuning.patrol_turn_frames:
					f.patrol_frames = 0
					f.facing = -f.facing
				inp = InputFrame.make(f.facing * tuning.patrol_speed)
		elif f.is_alive() and f.holding and f.team == "hero":
			# Holding a plate: stays put, facing the way the lead went.
			if lead_snap != null:
				inp = InputFrame.make((1.0 if lead_snap.pos.x >= f.pos.x else -1.0) * 0.02)
		elif f.is_alive() and f.spec.brain != "":
			# A boss sees the whole room, even from the air.
			var sight: float = tuning.enemy_sight_height if f.team == "enemy" and not f.spec.boss else INF
			var foes: Array[Fighter] = []
			var allies: Array[Fighter] = []
			for s in snapshot:
				if s.team != f.team and s.is_alive() and not s.spec.immortal and absf(s.pos.y - f.pos.y) <= sight \
						and (s.team == "enemy" or s.awake):
					foes.append(s)
			# A decoy is nobody's ally: the partner neither follows it nor counts it.
			for s in snapshot:
				if s.team == f.team and s.is_alive() and not s.spec.is_decoy:
					allies.append(s)
			inp = Brains.think(f.spec.brain, f, foes, allies, tuning, rng)
			if f.team == "hero" and level != null:
				_navigate(f, inp, lead_snap)
			_latch(f, inp)
		if _update(f, inp, events):
			explosions.append(f.id)
		_integrate(f, inp, events)
		if f.descending and f.on_ground:
			f.descending = false
			f.enter(Fighter.St.STAGGERED, tuning.protocol_land_open)
			events.append({"case": "bossLanded", "id": f.id})
		fighters[i] = f

	_resolve_commands(events)
	_resolve_specials(events)
	_fade_summons(events)
	_resolve_hits(events)
	_apply_effects(events)
	_update_strikes(events)
	for id in explosions:
		_explode(id, events)
	_puzzle_rules(events)
	_level_rules(events)
	_housekeeping(events)
	_cue_scenes(events)
	frame += 1
	return events


static func _has_event(events: Array, case_name: String, id: int = -1) -> bool:
	for e: Dictionary in events:
		if e["case"] == case_name and (id < 0 or int(e.get("id", -1)) == id):
			return true
	return false


## Announces each story scene once, when what sets it off happens.
func _cue_scenes(events: Array) -> void:
	if level == null or fired_scenes.size() >= level.scenes.size():
		return
	for trigger in level.scenes:
		if fired_scenes.has(trigger.scene):
			continue
		var due := false
		match String(trigger.cue["case"]):
			"start":
				due = true
			"reach":
				var c := controlled()
				due = (c.pos.x if c != null else -INF) >= float(trigger.cue["_0"])
			"partnerJoins":
				due = _has_event(events, "joined")
			"bossWakes":
				due = boss_id >= 0 and _has_event(events, "woke", boss_id)
			"raised":
				due = _has_event(events, "raised")
			"complete":
				due = _has_event(events, "levelComplete")
		if due:
			fired_scenes[trigger.scene] = true
			events.append({"case": "scene", "id": trigger.scene})


## The living hero the player is not controlling, or -1.
func _other_hero() -> int:
	for f in fighters:
		if f.team == "hero" and f.is_alive() and f.awake and not f.spec.is_decoy and f.id != controlled_id:
			return f.id
	return -1


func _pass_control(id: int, events: Array) -> void:
	# Whoever is left standing on a plate stays to hold it.
	var old := index_of(controlled_id)
	if old >= 0 and fighters[old].is_alive() and plate_under(fighters[old]) != null:
		fighters[old].holding = true
		events.append({"case": "holding", "id": fighters[old].id})
	var nw := index_of(id)
	if nw >= 0:
		fighters[nw].holding = false
	controlled_id = id
	switch_cooldown = tuning.switch_cooldown
	events.append({"case": "controlChanged", "id": id})


## Remembers a press for a few frames, so pressing slightly early still counts.
func _latch(f: Fighter, inp: InputFrame) -> void:
	if inp.attack:
		f.attack_buffer = tuning.attack_buffer
	if inp.jump:
		f.jump_buffer = tuning.jump_buffer
	if inp.dodge:
		f.dodge_buffer = tuning.dodge_buffer
	if inp.special:
		f.special_buffer = tuning.special_buffer


# MARK: State machine


## Returns true when the fighter explodes on this frame.
func _update(f: Fighter, inp: InputFrame, events: Array) -> bool:
	var explodes := false
	f.state_frame += 1
	f.since_hit += 1
	if f.dodge_cooldown > 0:
		f.dodge_cooldown -= 1
	if f.invulnerable > 0:
		f.invulnerable -= 1
	if f.special_cooldown > 0:
		f.special_cooldown -= 1
	if f.marked_frames > 0:
		f.marked_frames -= 1
	if f.slow_frames > 0:
		f.slow_frames -= 1

	match f.state:
		Fighter.St.DEAD:
			if f.on_ground:
				f.vel.x = 0.0
		Fighter.St.HITSTUN, Fighter.St.STAGGERED:
			if f.on_ground:
				f.vel.x *= tuning.hitstun_friction
			if f.state_frame >= f.state_duration:
				f.enter(Fighter.St.IDLE)
		Fighter.St.PHASE_SHIFT:
			f.vel.x = 0.0
			if f.state_frame >= f.state_duration:
				f.enter(Fighter.St.IDLE if f.on_ground else Fighter.St.AIR)
		Fighter.St.GUARD_STANCE:
			if f.on_ground:
				f.vel.x = 0.0
			if f.state_frame >= f.state_duration:
				f.enter(Fighter.St.IDLE if f.on_ground else Fighter.St.AIR)
		Fighter.St.FUSE:
			var sd := f.spec.self_destruct
			f.vel.x = inp.move_x * f.spec.run_speed * sd.speed_factor
			if absf(inp.move_x) > 0.01:
				f.facing = 1.0 if inp.move_x > 0.0 else -1.0
			if f.state_frame >= sd.fuse:
				explodes = true
		Fighter.St.DODGE:
			var d := f.spec.dodge
			f.vel.x = f.facing * d.speed
			if f.state_frame >= d.duration:
				f.dodge_cooldown = d.cooldown
				f.vel.x = 0.0
				f.enter(Fighter.St.IDLE if f.on_ground else Fighter.St.AIR)
		Fighter.St.ATTACK:
			var i := f.attack_index
			var a := f.spec.attacks[i]
			if f.on_ground:
				var moving := f.state_frame < a.windup + a.active and not (a.holds_still and f.state_frame < a.windup)
				f.vel.x = f.facing * a.lunge if moving else 0.0
			elif f.flying:
				f.vel.x = 0.0
			if f.state_frame == a.windup and not a.is_strike():
				f.pending_effect = i
			if not f.spec.boss and f.state_frame >= a.chain_from() and f.attack_buffer > 0 \
					and i + 1 < f.spec.attacks.size() and f.on_ground:
				_start_attack(f, i + 1, inp, events)
			elif f.state_frame >= a.windup + a.active and _can_dodge(f):
				_start_dodge(f, inp, events)
			elif f.state_frame >= a.total():
				f.enter(Fighter.St.IDLE if f.on_ground else Fighter.St.AIR)
		Fighter.St.IDLE, Fighter.St.RUN, Fighter.St.AIR:
			if absf(inp.move_x) > 0.01:
				f.facing = 1.0 if inp.move_x > 0.0 else -1.0
			var target := inp.move_x * f.spec.run_speed \
				* (1.0 if f.on_ground or f.spec.hovers or f.flying else tuning.air_control) \
				* (tuning.slow_factor if f.slow_frames > 0 else 1.0)
			var rate: float
			if absf(inp.move_x) <= 0.01:
				rate = tuning.ground_decel if f.on_ground else tuning.air_decel
			elif target * f.vel.x < 0.0:
				rate = tuning.turn_accel
			else:
				rate = tuning.ground_accel if f.on_ground else tuning.air_accel
			# Momentum is for the hand on the stick. Brains steer in small corrections and get exact speed.
			var change: float = rate / Tuning.FRAMES_PER_SECOND if f.id == controlled_id else INF
			f.vel.x += Sw.max_d(-change, Sw.min_d(change, target - f.vel.x))
			if f.special_buffer > 0 and f.special_cooldown == 0 and not f.spec.special.is_empty():
				f.special_buffer = 0
				var sp := f.spec.special
				match String(sp["case"]):
					"command":
						# Marking needs the other fighters, so the world does it after everyone has moved.
						f.wants_command = true
					"adapt":
						if absf(inp.move_x) > 0.01:
							f.facing = 1.0 if inp.move_x > 0.0 else -1.0
						f.special_cooldown = int(sp["cooldown"])
						f.enter(Fighter.St.GUARD_STANCE, int(sp["window"]))
						events.append({"case": "guarded", "id": f.id})
					"heal", "decoy":
						f.wants_special = true
			elif _can_dodge(f):
				_start_dodge(f, inp, events)
			elif f.attack_buffer > 0 and not f.spec.attacks.is_empty():
				var idx := mini(f.next_attack, f.spec.attacks.size() - 1) if f.spec.boss or f.spec.chooses_attacks else 0
				_start_attack(f, idx, inp, events)
			else:
				if f.jump_buffer > 0 and f.spec.jump_speed > 0.0 and (f.on_ground or f.coyote > 0):
					f.jump_buffer = 0
					f.coyote = 0
					f.vel.y = f.spec.jump_speed
					f.on_ground = false
					events.append({"case": "jumped", "id": f.id})
				var nxt: Fighter.St = Fighter.St.AIR if not f.on_ground \
					else (Fighter.St.RUN if absf(inp.move_x) > 0.1 else Fighter.St.IDLE)
				if nxt != f.state:
					f.enter(nxt)

	if f.attack_buffer > 0:
		f.attack_buffer -= 1
	if f.jump_buffer > 0:
		f.jump_buffer -= 1
	if f.dodge_buffer > 0:
		f.dodge_buffer -= 1
	if f.special_buffer > 0:
		f.special_buffer -= 1
	return explodes


func _can_dodge(f: Fighter) -> bool:
	return f.dodge_buffer > 0 and f.spec.dodge != null and f.dodge_cooldown == 0 and f.on_ground


func _start_attack(f: Fighter, index: int, inp: InputFrame, events: Array) -> void:
	if absf(inp.move_x) > 0.01:
		f.facing = 1.0 if inp.move_x > 0.0 else -1.0
	f.attack_buffer = 0
	f.hit_ids = {}
	f.swing_scale = 1.0
	f.enter_attack(index)
	events.append({"case": "swing", "id": f.id, "index": index})


func _start_dodge(f: Fighter, inp: InputFrame, events: Array) -> void:
	if absf(inp.move_x) > 0.01:
		f.facing = 1.0 if inp.move_x > 0.0 else -1.0
	f.dodge_buffer = 0
	f.enter(Fighter.St.DODGE)
	events.append({"case": "dodged", "id": f.id})


func _integrate(f: Fighter, inp: InputFrame, events: Array) -> void:
	var dt := 1.0 / Tuning.FRAMES_PER_SECOND
	var half := f.spec.width / 2.0
	var height := f.spec.height

	# A moving platform carries whoever stands on it.
	if f.on_ground and f.ground_index >= 0:
		f.pos.x += platform_deltas[f.ground_index].x
		f.pos.y += platform_deltas[f.ground_index].y
	if f.flying and f.is_alive():
		f.vel.y = Sw.max_d(-320.0, Sw.min_d(320.0, (tuning.protocol_flight_height - f.pos.y) * 4.0))
	elif f.state == Fighter.St.DODGE or (f.spec.hovers and f.is_alive()):
		f.vel.y = 0.0
	elif not f.on_ground:
		var cut := f.vel.y > 0.0 and f.id == controlled_id and not inp.jump_held
		f.vel.y = Sw.max_d(f.vel.y - tuning.gravity * (tuning.jump_cut_gravity if cut else 1.0) * dt, -tuning.max_fall_speed)

	# Machines do not walk off an edge by themselves. A hit can still knock them off.
	var blocked := false
	if f.team == "enemy" and f.on_ground and f.vel.x != 0.0 and f.state != Fighter.St.HITSTUN and f.state != Fighter.St.DEAD:
		var probe := f.pos.x + (1.0 if f.vel.x > 0.0 else -1.0) * (half + 6.0)
		if not has_ground(probe, f.pos.y):
			f.vel.x = 0.0
			blocked = true

	# Port-only: a hero's lunge or dodge stops at the edge of eclipse ground that is gone or about to go,
	# instead of carrying them over the gap. Ordinary pits keep Swift's rule.
	if f.team == "hero" and f.vel.x != 0.0 and (f.state == Fighter.St.ATTACK or f.state == Fighter.St.DODGE) \
			and level != null and level.eclipse_period > 0:
		var edge := f.pos.x + (1.0 if f.vel.x > 0.0 else -1.0) * (half + 6.0)
		if _eclipse_edge_unsafe(f, edge):
			f.vel.x = 0.0

	# Sideways, stopped by walls.
	var from_x := f.pos.x
	f.pos.x += f.vel.x * dt
	for i in platform_boxes.size():
		if platforms[i].one_way:
			continue
		var b := platform_boxes[i]
		if not (f.pos.y < b.max_y - 0.5 and f.pos.y + height > b.min_y + 0.5 and f.pos.x + half > b.min_x and f.pos.x - half < b.max_x):
			continue
		var from_left := from_x <= b.min_x or (from_x < b.max_x and from_x < (b.min_x + b.max_x) / 2.0)
		f.pos.x = b.min_x - half if from_left else b.max_x + half
		f.vel.x = 0.0
		blocked = true
	var clamped := Sw.min_d(Sw.max_d(f.pos.x, arena_lo + half), arena_hi - half)
	if clamped != f.pos.x:
		f.pos.x = clamped
		blocked = true
	if blocked and not f.awake:
		f.facing = -f.facing
		f.patrol_frames = 0

	# Up and down: land on the highest surface crossed, bump the head on solid undersides.
	var from_y := f.pos.y
	f.pos.y += f.vel.y * dt
	var support := -1
	var support_top := -INF
	for i in platform_boxes.size():
		var b := platform_boxes[i]
		if not (f.pos.x + half > b.min_x + 0.5 and f.pos.x - half < b.max_x - 0.5):
			continue
		if f.vel.y <= 0.0 and from_y >= b.max_y - 0.5 and f.pos.y <= b.max_y + 0.01:
			if b.max_y > support_top or (b.max_y == support_top and platforms[i].moves()):
				support = i
				support_top = b.max_y
		elif not platforms[i].one_way and f.vel.y > 0.0 and from_y + height <= b.min_y + 0.5 and f.pos.y + height >= b.min_y:
			f.pos.y = b.min_y - height
			f.vel.y = 0.0
	if support >= 0:
		f.pos.y = support_top
		f.vel.y = 0.0
		f.ground_index = support
		if not f.on_ground:
			f.on_ground = true
			events.append({"case": "landed", "id": f.id})
		# Eclipse ground is not safe: a respawn there could land on nothing (port-only; Swift has none).
		if f.team == "hero" and f.is_alive() and not platforms[support].moves() and not _over_eclipse(f):
			f.last_safe = f.pos.copy()
	else:
		f.on_ground = false
		f.ground_index = -1
	if f.on_ground:
		f.coyote = tuning.coyote_frames
	elif f.coyote > 0:
		f.coyote -= 1


## Gets the AI partner over the level: it jumps the walls and gaps it can clear, waits for hazards,
## and does not step into a pit. What it cannot cross it skips by regrouping.
func _navigate(f: Fighter, inp: InputFrame, leader: Fighter) -> void:
	if level == null or not f.on_ground or not f.is_actionable():
		return
	var half := f.spec.width / 2.0
	var y := f.pos.y

	# Port-only: standing on eclipse ground that is about to go, get off it first.
	var escape := eclipse_escape(f)
	if escape != 0.0:
		inp.move_x = escape
		inp.attack = false
		inp.dodge = false
		return

	# The leader is on a floor just above: try to jump up to it.
	if leader != null and leader.on_ground and leader.pos.y - y > 40.0 and absf(leader.pos.x - f.pos.x) < 140.0 \
			and f.spec.jump_speed > 0.0:
		inp.jump = true
		return
	if not absf(inp.move_x) > 0.1:
		return
	var dir := 1.0 if inp.move_x > 0.0 else -1.0

	for h in level.hazards:
		var near := h.box.min_x - (f.pos.x + half) if dir > 0.0 else (f.pos.x - half) - h.box.max_x
		if not (near > -(h.box.max_x - h.box.min_x) - f.spec.width and near < 50.0):
			continue
		if h.is_on(frame) or h.frames_until_on(frame) < 45:
			inp.move_x = 0.0
			return

	# Port-only: eclipse ground that is gone or will go before the partner is across.
	if eclipse_blocks(f, dir):
		inp.move_x = 0.0
		return

	for i in platform_boxes.size():
		var b := platform_boxes[i]
		if platforms[i].one_way or not (b.max_y > y + 1.0) or not (b.min_y < y + f.spec.height):
			continue
		var gap := b.min_x - (f.pos.x + half) if dir > 0.0 else (f.pos.x - half) - b.max_x
		if not (gap >= -1.0 and gap < 34.0):
			continue
		if b.max_y - y <= 105.0 and f.spec.jump_speed > 0.0:
			inp.jump = true
		else:
			inp.move_x = 0.0
		return

	if not has_ground(f.pos.x + dir * (half + 26.0), y):
		if _surface(f, dir, y, 70.0, 165.0, 60.0, 200.0) and f.spec.jump_speed > 0.0:
			inp.jump = true
		elif not _surface(f, dir, y, half, 60.0, 1.0, 400.0):
			inp.move_x = 0.0


func _surface(f: Fighter, dir: float, y: float, near: float, far: float, above: float, below: float) -> bool:
	var x0 := Sw.min_d(f.pos.x + dir * near, f.pos.x + dir * far)
	var x1 := Sw.max_d(f.pos.x + dir * near, f.pos.x + dir * far)
	for b in platform_boxes:
		if b.max_x > x0 and b.min_x < x1 and b.max_y <= y + above and b.max_y >= y - below:
			return true
	return false


## Puts a partner that was left behind next to the leader.
func _regroup_partner(events: Array) -> void:
	var lc := controlled()
	if lc == null or not lc.is_alive() or not lc.on_ground or lc.last_safe == null:
		return
	var lead := lc.copy()
	var spot := lead.last_safe
	for i in fighters.size():
		if not (fighters[i].team == "hero" and fighters[i].id != controlled_id and fighters[i].is_alive()
				and fighters[i].awake and not fighters[i].spec.is_decoy):
			continue
		var f := fighters[i].copy()
		var apart := absf(f.pos.y - lead.pos.y) > tuning.partner_stranded_height and f.on_ground
		f.stranded_frames = f.stranded_frames + 1 if apart else 0
		# A partner holding a plate is only fetched once the lead has gone well on.
		var kill := level.kill_y if level != null else -INF
		var lost := absf(f.pos.x - lead.pos.x) > tuning.partner_regroup_distance \
			or (not f.holding and f.stranded_frames >= tuning.partner_stranded_frames) or f.pos.y < kill + 40.0
		if lost:
			f.holding = false
			f.pos = spot.copy()
			f.vel = Vec2.zero()
			f.on_ground = false
			f.ground_index = -1
			f.stranded_frames = 0
			if f.state != Fighter.St.HITSTUN:
				f.enter(Fighter.St.IDLE)
			f.invulnerable = maxi(f.invulnerable, 30)
			events.append({"case": "regrouped", "id": f.id, "at": Vec2.new(spot.x, spot.y + f.spec.height / 2.0)})
		fighters[i] = f


# MARK: Puzzles


## Levers thrown by heroes' swings and springing back; plates under heroes; gates sliding toward what
## their inputs ask. A gate will not shut on someone standing in its way.
func _puzzle_rules(events: Array) -> void:
	if level == null:
		return
	for lever in level.levers:
		if lever_timers.has(lever.id):
			var left: int = lever_timers[lever.id]
			if left <= 1:
				lever_timers.erase(lever.id)
				signals.erase(lever.id)
				events.append({"case": "lever", "id": lever.id, "on": false})
			else:
				lever_timers[lever.id] = left - 1
		var tag := -1000 - lever.id
		var bells: Array[Level.Gate] = []
		for g in level.gates:
			if g.in_order and g.opens_with.has(lever.id):
				bells.append(g)
		for i in fighters.size():
			if not (fighters[i].team == "hero" and fighters[i].is_alive() and not fighters[i].spec.is_decoy):
				continue
			var box := fighters[i].hitbox()
			if box == null or not box.intersects(lever.box()) or fighters[i].hit_ids.has(tag):
				continue
			# Only the lead rings a bell.
			if not bells.is_empty() and fighters[i].id != controlled_id:
				continue
			fighters[i].hit_ids[tag] = true
			if not signals.has(lever.id):
				var out_of_order: Level.Gate = null
				for g in bells:
					var at := g.opens_with.find(lever.id)
					if at >= 0 and at > 0 and not signals.has(g.opens_with[at - 1]):
						out_of_order = g
						break
				if out_of_order != null:
					# Out of order: the bells of that gate fall silent.
					for id in out_of_order.opens_with:
						if signals.has(id):
							signals.erase(id)
							lever_timers.erase(id)
							events.append({"case": "lever", "id": id, "on": false})
					events.append({"case": "discord", "gate": out_of_order.id})
					continue
				signals[lever.id] = true
				events.append({"case": "lever", "id": lever.id, "on": true})
			if lever.hold_frames > 0:
				lever_timers[lever.id] = lever.hold_frames
	for i in fighters.size():
		if fighters[i].spec.needs_light:
			fighters[i].in_light = is_lit(fighters[i])
	for plate in level.plates:
		var down := false
		for f in fighters:
			if f.team == "hero" and f.is_alive():
				var p := plate_under(f)
				if p != null and p.id == plate.id:
					down = true
					break
		if down != signals.has(plate.id):
			if down:
				signals[plate.id] = true
			else:
				signals.erase(plate.id)
			events.append({"case": "plate", "id": plate.id, "down": down})
	for gate in level.gates:
		if not gate_platform.has(gate.id) or not gate_open.has(gate.id):
			continue
		var p: int = gate_platform[gate.id]
		var open: float = gate_open[gate.id]
		var target := 1.0 if wants_open(gate) else 0.0
		if open == target:
			platform_deltas[p] = Vec2.zero()
			continue
		# Someone under it holds a closing gate up.
		if target < open:
			var under := false
			for f in fighters:
				if f.is_alive() and f.hurtbox().intersects(gate.box):
					under = true
					break
			if under:
				platform_deltas[p] = Vec2.zero()
				continue
		if open == 0.0 or open == 1.0:
			events.append({"case": "gate", "id": gate.id, "opening": target > open})
		var nxt := Sw.min_d(1.0, open + tuning.gate_speed) if target > open else Sw.max_d(0.0, open - tuning.gate_speed)
		gate_open[gate.id] = nxt
		var lift := nxt * (gate.box.max_y - gate.box.min_y + 20.0)
		var moved := gate.box.offset(0.0, lift)
		platform_deltas[p] = Vec2.new(0.0, moved.min_y - platform_boxes[p].min_y)
		platform_boxes[p] = moved


# MARK: Boss effects


## Summons and light called down by attacks whose active frames began this frame.
func _apply_effects(events: Array) -> void:
	var count := fighters.size()
	for i in count:
		if fighters[i].pending_effect < 0:
			continue
		var index := fighters[i].pending_effect
		fighters[i].pending_effect = -1
		var me := fighters[i].copy()
		var e := me.spec.attacks[index].effect
		match String(e["case"]):
			"summon":
				var kind: String = e["_0"]
				# A boss counts everyone fighting beside it; anyone else counts only what it calls.
				var living := 0
				for f in fighters:
					if me.spec.boss:
						if f.team == me.team and f.is_alive() and not f.spec.boss and not f.spec.immortal:
							living += 1
					elif f.kind == kind and f.is_alive() and absf(f.pos.x - me.pos.x) < 800.0:
						living += 1
				var cap := tuning.protocol_max_minions if me.spec.boss else tuning.max_summoned
				for n in maxi(0, mini(int(e["count"]), cap - living)):
					var side := -1.0 if n % 2 == 0 else 1.0
					@warning_ignore("integer_division")
					var x := me.pos.x + side * (me.spec.width / 2.0 + 60.0 + float(n / 2) * 60.0)
					# Boss rooms have their floor at 0; elsewhere they appear on the summoner's floor.
					var y := 0.0 if me.spec.boss else me.pos.y
					var id := spawn(kind, Sw.min_d(Sw.max_d(x, arena_lo + 40.0), arena_hi - 40.0), y, -side)
					var s := index_of(id)
					if s >= 0:
						fighters[s].on_ground = me.on_ground
					events.append({"case": "spawned", "id": id, "kind": kind})
			"lob":
				_lobbed(e["_0"], me, events)
			"eruption":
				for x in _strike_columns(me, int(e["columns"]), float(e["width"])):
					var w := float(e["width"])
					var strike := Strike.make(Box.new(x - w / 2.0, -4.0, x + w / 2.0, float(e["height"])),
						int(e["warning"]), int(e["active"]), float(e["damage"]))
					strike.kind = e["kind"]
					strikes.append(strike)
			"mend":
				var amount := float(e["amount"])
				var rng_x := float(e["range"])
				for t in fighters.size():
					var g := fighters[t]
					if t != i and g.team == me.team and g.is_alive() and not g.spec.immortal \
							and absf(g.pos.x - me.pos.x) <= rng_x and absf(g.pos.y - me.pos.y) <= 220.0:
						var gained := Sw.min_d(amount, g.spec.max_hp - g.hp)
						if not gained > 0.0:
							continue
						g.hp += gained
						events.append({"case": "healed", "id": g.id, "amount": gained})
			"flare":
				_dazzle(me, float(e["radius"]), int(e["daze"]), true, events)
			"eclipse":
				_dazzle(me, float(e["radius"]), int(e["daze"]), false, events)
			"douse":
				var reach := float(e["range"])
				if level != null:
					for lamp in level.levers:
						if lamp.glow > 0.0 and signals.has(lamp.id) and absf(lamp.pos.x - me.pos.x) <= reach:
							signals.erase(lamp.id)
							lever_timers.erase(lamp.id)
							events.append({"case": "lever", "id": lamp.id, "on": false})
			"prophecy":
				var w := float(e["width"])
				var warning := int(e["warning"])
				for h in fighters:
					if h.team != me.team and h.is_alive() and h.awake and not h.spec.is_decoy:
						# Where they will be when it lands, if they keep going.
						var ahead := h.pos.x + h.vel.x * float(warning) / Tuning.FRAMES_PER_SECOND
						var x := Sw.min_d(Sw.max_d(ahead, arena_lo + w / 2.0), arena_hi - w / 2.0)
						var strike := Strike.make(Box.new(x - w / 2.0, -4.0, x + w / 2.0, float(e["height"])),
							warning, int(e["active"]), float(e["damage"]))
						strike.kind = "light"
						strikes.append(strike)
			"rain":
				var w := float(e["width"])
				for x in _strike_columns(me, int(e["columns"]), w):
					strikes.append(Strike.make(Box.new(x - w / 2.0, -50.0, x + w / 2.0, 600.0),
						int(e["warning"]), int(e["active"]), float(e["damage"])))


## Column positions for rain and eruptions: one over each foe, the rest spread over the room.
## Draws from the RNG exactly as Swift's loop does, and returns at most `columns` of them.
func _strike_columns(me: Fighter, columns: int, width: float) -> Array[float]:
	var xs: Array[float] = []
	for f in fighters:
		if f.team != me.team and f.is_alive() and f.awake:
			xs.append(f.pos.x)
	var tries := 0
	while xs.size() < columns and tries < 40:
		tries += 1
		var x := rng.double_closed(arena_lo + width, arena_hi - width)
		var clear := true
		for o in xs:
			if not absf(o - x) > width * 1.5:
				clear = false
				break
		if clear:
			xs.append(x)
	return xs.slice(0, columns)


## A flare (dazes those looking at it) or an eclipse (dazes those looking away).
func _dazzle(me: Fighter, radius: float, frames: int, looking_at: bool, events: Array) -> void:
	var centre := Vec2.new(me.pos.x, me.pos.y + me.spec.height / 2.0)
	events.append({"case": "flared" if looking_at else "eclipsed", "id": me.id, "at": centre, "radius": radius})
	for t in fighters.size():
		var h := fighters[t]
		if not (h.team != me.team and h.is_alive() and not h.spec.is_decoy and not h.is_dodge_invulnerable()):
			continue
		var dx := me.pos.x - h.pos.x
		var dy := centre.y - (h.pos.y + h.spec.height / 2.0)
		if not dx * dx + dy * dy <= radius * radius:
			continue
		# Standing right on it counts as looking at it.
		var facing := dx * h.facing > 0.0 or absf(dx) < 8.0
		if facing != looking_at:
			continue
		h.vel.x = 0.0
		h.enter(Fighter.St.HITSTUN, frames)
		events.append({"case": "dazed", "id": h.id})


## Lands a thrown thing under the nearest hero in range, or as far as it carries toward them.
func _lobbed(lob: Dictionary, me: Fighter, events: Array) -> void:
	var target: Fighter = null
	for f in fighters:
		if f.team != me.team and f.is_alive() and f.awake:
			if target == null or absf(f.pos.x - me.pos.x) < absf(target.pos.x - me.pos.x):
				target = f
	var reach := float(lob["range"])
	var x := me.pos.x + me.facing * reach
	var y := me.pos.y
	if target != null and absf(target.pos.x - me.pos.x) <= reach:
		x = target.pos.x
		y = target.pos.y
	# The highest floor at or below that point.
	var found := false
	var floor_y := 0.0
	for b in platform_boxes:
		if b.min_x <= x and x <= b.max_x and b.max_y <= y + 1.0:
			if not found or floor_y < b.max_y:
				floor_y = b.max_y
				found = true
	if not found:
		return
	var w := float(lob["width"])
	var strike := Strike.make(Box.new(x - w / 2.0, floor_y - 4.0, x + w / 2.0, floor_y + float(lob["height"])),
		int(lob["warning"]), int(lob["active"]), float(lob["damage"]))
	strike.kind = lob["kind"]
	strike.slow_frames = int(lob["slowFrames"])
	strikes.append(strike)
	events.append({"case": "lobbed", "id": me.id, "kind": lob["kind"], "at": Vec2.new(x, floor_y)})


func _update_strikes(events: Array) -> void:
	if strikes.is_empty():
		return
	for s in strikes:
		s.age += 1
		if s.age == s.warning:
			events.append({"case": "struck", "at": Vec2.new(s.box.center().x, s.box.min_y + 4.0),
				"width": s.box.width(), "kind": s.kind})
		if not s.is_active():
			continue
		for t in fighters.size():
			if not (fighters[t].team == "hero" and fighters[t].is_alive() and fighters[t].awake and not s.hit.has(fighters[t].id)):
				continue
			var f := fighters[t].copy()
			if not s.box.intersects(f.hurtbox()):
				continue
			s.hit[f.id] = true
			if f.is_dodge_invulnerable():
				events.append({"case": "evaded", "id": f.id})
				continue
			if f.invulnerable > 0:
				continue
			if f.state == Fighter.St.GUARD_STANCE:
				events.append({"case": "absorbed", "by": f.id, "attacker": boss_id, "at": f.hurtbox().center()})
				continue
			if s.slow_frames > 0:
				fighters[t].slow_frames = s.slow_frames
				events.append({"case": "slowed", "id": f.id})
			if not s.damage > 0.0:
				continue
			var push := 1.0 if f.pos.x >= s.box.center().x else -1.0
			_hurt(t, s.damage, boss_id, f.hurtbox().center(), push * 220.0, 16, events)
			hit_stop = maxi(hit_stop, tuning.hero_hurt_hit_stop)
	var kept: Array[Strike] = []
	for s in strikes:
		if not s.is_done():
			kept.append(s)
	strikes = kept


# MARK: Specials


## Caelen's Command: marks the nearest enemy in front, or the nearest at all when none is in front.
func _resolve_commands(events: Array) -> void:
	for i in fighters.size():
		if not fighters[i].wants_command:
			continue
		fighters[i].wants_command = false
		var me := fighters[i].copy()
		if me.spec.special.get("case", "") != "command":
			continue
		var sp := me.spec.special
		var reach := float(sp["range"])
		var near: Array[int] = []
		for t in fighters.size():
			var f := fighters[t]
			if f.team != me.team and f.is_alive() and not f.spec.immortal and absf(f.pos.x - me.pos.x) <= reach \
					and absf(f.pos.y - me.pos.y) <= 220.0:
				near.append(t)
		var ahead: Array[int] = []
		for t in near:
			if (fighters[t].pos.x - me.pos.x) * me.facing >= 0.0:
				ahead.append(t)
		var pool := near if ahead.is_empty() else ahead
		var pick := -1
		for t in pool:
			if pick < 0 or absf(fighters[t].pos.x - me.pos.x) < absf(fighters[pick].pos.x - me.pos.x):
				pick = t
		# With nobody to mark the ability is not spent.
		if pick < 0:
			continue
		for t in fighters.size():
			if fighters[t].team != me.team:
				fighters[t].marked_frames = 0
		fighters[pick].marked_frames = int(sp["frames"])
		fighters[pick].mark_scale = float(sp["damageScale"])
		fighters[i].special_cooldown = int(sp["cooldown"])
		events.append({"case": "commanded", "by": me.id, "target": fighters[pick].id})


## Seraphine's heal and Nimue's decoy, and the decoys' clocks.
func _resolve_specials(events: Array) -> void:
	var new_decoys: Array = []
	for i in fighters.size():
		if not fighters[i].wants_special:
			continue
		fighters[i].wants_special = false
		var me := fighters[i].copy()
		var sp := me.spec.special
		match String(sp.get("case", "")):
			"heal":
				fighters[i].special_cooldown = int(sp["cooldown"])
				var amount := float(sp["amount"])
				var reach := float(sp["range"])
				for t in fighters.size():
					var g := fighters[t]
					if g.team == me.team and g.is_alive() and g.awake and not g.spec.is_decoy \
							and absf(g.pos.x - me.pos.x) <= reach and absf(g.pos.y - me.pos.y) <= 220.0:
						var gained := Sw.min_d(amount, g.spec.max_hp - g.hp)
						if not gained > 0.0:
							continue
						g.hp += gained
						events.append({"case": "healed", "id": g.id, "amount": gained})
			"decoy":
				fighters[i].special_cooldown = int(sp["cooldown"])
				new_decoys.append([i, int(sp["frames"])])
	for pair: Array in new_decoys:
		var me := fighters[int(pair[0])].copy()
		# One at a time: a new decoy replaces the old one.
		for d in fighters:
			if d.spec.is_decoy:
				d.expires = 1
		var id := spawn("decoy", me.pos.x, me.pos.y, me.facing)
		var di := index_of(id)
		if di >= 0:
			fighters[di].expires = int(pair[1]) + 1
			fighters[di].awake = true
			fighters[di].on_ground = me.on_ground
		events.append({"case": "decoyPlaced", "id": id, "at": me.pos.copy()})
	for d in fighters:
		if d.spec.is_decoy:
			d.expires -= 1
			if d.expires <= 0 or not d.is_alive():
				events.append({"case": "decoyGone", "id": d.id, "at": d.hurtbox().center()})
	var kept: Array[Fighter] = []
	for f in fighters:
		if not (f.spec.is_decoy and (f.expires <= 0 or not f.is_alive())):
			kept.append(f)
	fighters = kept


## Things that last only a while, such as a Night Weaver's images, fade when their time is up.
func _fade_summons(events: Array) -> void:
	for f in fighters:
		if f.spec.lifetime > 0 and not f.spec.is_decoy and f.is_alive():
			f.expires -= 1
			if f.expires <= 0:
				events.append({"case": "faded", "id": f.id, "at": f.hurtbox().center()})
	var kept: Array[Fighter] = []
	for f in fighters:
		if not (f.spec.lifetime > 0 and not f.spec.is_decoy and f.is_alive() and f.expires <= 0):
			kept.append(f)
	fighters = kept


# MARK: Hits


func _resolve_hits(events: Array) -> void:
	for a in fighters.size():
		var box := fighters[a].hitbox()
		var attack := fighters[a].current_attack()
		if box == null or attack == null:
			continue
		for t in fighters.size():
			if t == a:
				continue
			var tf := fighters[t]
			if not (tf.team != fighters[a].team and tf.is_alive() and (tf.awake or tf.team == "enemy")
					and not fighters[a].hit_ids.has(tf.id) and box.intersects(tf.hurtbox())):
				continue
			fighters[a].hit_ids[tf.id] = true
			var hb := fighters[t].hurtbox()
			var contact := Vec2.new(
				(Sw.max_d(box.min_x, hb.min_x) + Sw.min_d(box.max_x, hb.max_x)) / 2.0,
				(Sw.max_d(box.min_y, hb.min_y) + Sw.min_d(box.max_y, hb.max_y)) / 2.0)
			_land(attack, a, t, contact, events)
			# A parry staggers the attacker and ends its swing.
			if fighters[a].hitbox() == null:
				break


func _land(attack: Specs.AttackSpec, a: int, t: int, contact: Vec2, events: Array) -> void:
	var attacker := fighters[a].copy()
	var target := fighters[t].copy()

	if target.is_dodge_invulnerable():
		events.append({"case": "evaded", "id": target.id})
		return
	if target.invulnerable > 0:
		return

	if target.state == Fighter.St.GUARD_STANCE and target.spec.special.get("case", "") == "adapt":
		# The hit is taken on the guard: the attacker reels and the counter starts at once.
		var sp := target.spec.special
		fighters[a].enter(Fighter.St.STAGGERED, int(sp["stagger"]))
		fighters[a].vel.x = -attacker.facing * 120.0
		var me := target.copy()
		me.facing = 1.0 if attacker.pos.x >= me.pos.x else -1.0
		me.hit_ids = {}
		me.attack_buffer = 0
		me.enter_attack(me.spec.attacks.size() - 1)
		me.swing_scale = float(sp["counterScale"])
		me.invulnerable = maxi(me.invulnerable, me.spec.attacks[me.spec.attacks.size() - 1].total() if not me.spec.attacks.is_empty() else 0)
		fighters[t] = me
		hit_stop = maxi(hit_stop, tuning.parry_hit_stop)
		events.append({"case": "absorbed", "by": target.id, "attacker": attacker.id, "at": contact})
		events.append({"case": "swing", "id": target.id, "index": target.spec.attacks.size() - 1})
		return

	if target.is_parrying() and attacker.team == "enemy":
		fighters[a].enter(Fighter.St.STAGGERED, tuning.parry_stagger)
		fighters[a].vel.x = -attacker.facing * 120.0
		hit_stop = maxi(hit_stop, tuning.parry_hit_stop)
		events.append({"case": "parried", "by": target.id, "attacker": attacker.id, "at": contact})
		return

	var from_front := (attacker.pos.x - target.pos.x) * target.facing >= 0.0
	if not target.is_open() or (target.is_guarding() and from_front) or is_warded(target.id):
		events.append({"case": "blocked", "attacker": attacker.id, "target": target.id, "at": contact})
		if target.spec.riposte >= 0 and target.is_guarding() and from_front and target.is_actionable():
			var g := fighters[t].copy()
			_start_attack(g, target.spec.riposte, InputFrame.neutral(), events)
			fighters[t] = g
		return

	var push: float = attacker.facing if attacker.pos.x == target.pos.x else (1.0 if target.pos.x > attacker.pos.x else -1.0)
	var ai := attacker.team == "hero" and attacker.id != controlled_id
	_hurt(t, attack.damage * attacker.swing_scale * (tuning.partner_damage_scale if ai else 1.0), attacker.id, contact,
		push * attack.knockback, attack.hitstun, events)
	hit_stop = maxi(hit_stop, tuning.hero_hurt_hit_stop if target.team == "hero" else attack.hit_stop)
	if attack.slow_frames > 0 and fighters[t].is_alive():
		fighters[t].slow_frames = attack.slow_frames
		events.append({"case": "slowed", "id": target.id})


func _hurt(t: int, base: float, attacker_id: int, contact: Vec2, push: float, hitstun: int, events: Array) -> void:
	var f := fighters[t].copy()
	var damage := base * (tuning.stagger_damage_bonus if f.state == Fighter.St.STAGGERED else 1.0) \
		* (f.mark_scale if f.marked_frames > 0 else 1.0) * (tuning.hero_damage_scale if f.team == "hero" else 1.0)
	f.hp = Sw.max_d(1.0, f.hp - damage) if f.spec.immortal else f.hp - damage
	f.since_hit = 0
	events.append({"case": "hit", "attacker": attacker_id, "target": f.id, "damage": damage, "at": contact})

	# A boss cannot be hurt past a phase threshold: it stops there and changes phase.
	if f.spec.boss and f.phase <= f.spec.phase_thresholds.size():
		var floor_hp := f.spec.max_hp * f.spec.phase_thresholds[f.phase - 1]
		if f.hp <= floor_hp:
			f.hp = floor_hp
			f.phase += 1
			f.flying = f.spec.flight_phase > 0 and f.phase == f.spec.flight_phase
			f.descending = false
			f.ai_aux2 = 0
			f.ai_cooldown = 0
			f.vel.x = 0.0
			f.enter(Fighter.St.PHASE_SHIFT, tuning.boss_phase_shift_frames)
			f.invulnerable = tuning.boss_phase_shift_frames
			events.append({"case": "bossPhase", "id": f.id, "phase": f.phase})
			fighters[t] = f
			return

	if f.hp <= 0.0:
		f.hp = 0.0
		f.vel.x = push
		f.enter(Fighter.St.DEAD)
		events.append({"case": "died", "id": f.id})
		var partner_stands := false
		var pid := sworn_partner(f.id)
		if pid >= 0:
			var pf := fighter(pid)
			partner_stands = pf != null and pf.is_alive()
		if f.spec.boss and not partner_stands:
			events.append({"case": "bossDefeated", "id": f.id})
	else:
		if f.spec.self_destruct != null and f.state != Fighter.St.FUSE and f.hp <= f.spec.max_hp * f.spec.self_destruct.threshold:
			f.enter(Fighter.St.FUSE)
			events.append({"case": "fuseLit", "id": f.id})
		elif f.state == Fighter.St.FUSE or f.state == Fighter.St.STAGGERED or f.spec.rooted or f.spec.armored \
				or f.spec.unflinching:
			pass  # Keeps doing what it was doing.
		elif f.spec.poise and f.state == Fighter.St.ATTACK:
			pass  # Finishes its swing.
		else:
			f.vel.x = push
			f.enter(Fighter.St.HITSTUN, hitstun)
		f.invulnerable = f.spec.hurt_invulnerable
	fighters[t] = f


func _explode(id: int, events: Array) -> void:
	var i := index_of(id)
	if i < 0 or fighters[i].state != Fighter.St.FUSE or fighters[i].spec.self_destruct == null:
		return
	var sd := fighters[i].spec.self_destruct
	var source := fighters[i].copy()
	var centre := Vec2.new(source.pos.x, source.pos.y + source.spec.height / 2.0)
	fighters[i].hp = 0.0
	fighters[i].enter(Fighter.St.DEAD)
	# It is gone at once, so it does not linger as a corpse.
	fighters[i].state_frame = tuning.corpse_frames
	events.append({"case": "exploded", "id": id, "at": centre, "radius": sd.radius})
	events.append({"case": "died", "id": id})

	for t in fighters.size():
		if not (fighters[t].team != source.team and fighters[t].is_alive()):
			continue
		var target := fighters[t].copy()
		if target.team == "hero" and not target.awake:
			continue
		var box := target.hurtbox()
		var dx := Sw.max_d(Sw.max_d(box.min_x - centre.x, 0.0), centre.x - box.max_x)
		var dy := Sw.max_d(Sw.max_d(box.min_y - centre.y, 0.0), centre.y - box.max_y)
		if not dx * dx + dy * dy <= sd.radius * sd.radius:
			continue
		if target.is_dodge_invulnerable():
			events.append({"case": "evaded", "id": target.id})
			continue
		if target.invulnerable > 0:
			continue
		if target.state == Fighter.St.GUARD_STANCE:
			events.append({"case": "absorbed", "by": target.id, "attacker": id, "at": box.center()})
			continue
		var push := 1.0 if target.pos.x >= centre.x else -1.0
		_hurt(t, sd.damage, id, box.center(), push * 300.0, 18, events)
		hit_stop = maxi(hit_stop, tuning.hero_hurt_hit_stop)


# MARK: Level rules


## Pits, hazards, checkpoints, pickups and the exit. Does nothing in the training room.
func _level_rules(events: Array) -> void:
	if level == null:
		return
	_regroup_partner(events)
	_sworn_rules(events)

	for i in fighters.size():
		if not fighters[i].pos.y < level.kill_y:
			continue
		var f := fighters[i].copy()
		_fall(f, events)
		fighters[i] = f

	for hazard in level.hazards:
		if not hazard.is_on(frame):
			continue
		for i in fighters.size():
			if not (fighters[i].team == "hero" and fighters[i].is_alive() and fighters[i].awake and not fighters[i].spec.is_decoy):
				continue
			var f := fighters[i].copy()
			if not (f.invulnerable == 0 and not f.is_dodge_invulnerable() and hazard.box.intersects(f.hurtbox())):
				continue
			var push := 1.0 if f.pos.x >= hazard.box.center().x else -1.0
			_hurt(i, hazard.damage, -1, f.hurtbox().center(), push * 260.0, 16, events)
			hit_stop = maxi(hit_stop, tuning.hero_hurt_hit_stop)

	for i in fighters.size():
		if not (fighters[i].team == "hero" and fighters[i].is_alive() and not fighters[i].spec.is_decoy):
			continue
		var reach := tuning.pickup_reach
		var box := fighters[i].hurtbox()
		for p in level.pickups:
			if not collected.has(p.id) and p.pos.x >= box.min_x - reach and p.pos.x <= box.max_x + reach \
					and p.pos.y >= box.min_y - reach and p.pos.y <= box.max_y + reach:
				collected[p.id] = true
				events.append({"case": "collected", "id": p.id, "secret": p.secret, "at": p.pos.copy()})

	var ci := index_of(controlled_id)
	if ci < 0 or not fighters[ci].is_alive():
		return
	var hero := fighters[ci].copy()
	for n in level.checkpoints.size():
		var c := level.checkpoints[n]
		if n > checkpoint_index and absf(hero.pos.x - c.x) < 40.0 and absf(hero.pos.y - c.y) < 120.0:
			checkpoint_index = n
			fighters[ci].hp = Sw.min_d(hero.spec.max_hp, hero.hp + tuning.checkpoint_heal)
			events.append({"case": "checkpoint", "index": n})
	var tw := twin()
	var twin_down := true if tw == null else not tw.is_alive()
	var b := index_of(boss_id) if boss_id >= 0 else -1
	if b >= 0 and not fighters[b].is_alive() and twin_down:
		boss_down_frames += 1
		if boss_down_frames >= tuning.boss_victory_frames:
			is_complete = true
			is_over = true
			events.append({"case": "levelComplete"})
	elif hero.on_ground and hero.pos.x >= level.exit_x:
		is_complete = true
		is_over = true
		events.append({"case": "levelComplete"})


## One fighter below the level's floor. Swift's `defer` writes it back however it returns.
func _fall(f: Fighter, events: Array) -> void:
	f.vel = Vec2.zero()
	f.pos.y = level.kill_y
	if not f.is_alive():
		return
	# A decoy that falls is simply gone.
	if f.spec.is_decoy:
		f.hp = 0.0
		return
	if f.team == "enemy":
		f.hp = 0.0
		f.enter(Fighter.St.DEAD)
		f.state_frame = tuning.corpse_frames
		events.append({"case": "died", "id": f.id})
		return
	events.append({"case": "fell", "id": f.id})
	f.hp -= tuning.fall_damage
	if f.hp <= 0.0:
		f.hp = 0.0
		f.enter(Fighter.St.DEAD)
		events.append({"case": "died", "id": f.id})
	else:
		if f.last_safe != null:
			f.pos = f.last_safe.copy()
		else:
			f.pos = (level.checkpoints[checkpoint_index] if checkpoint_index >= 0 else level.start).copy()
		f.on_ground = false
		f.ground_index = -1
		f.enter(Fighter.St.IDLE)
		f.invulnerable = maxi(f.spec.hurt_invulnerable, 60)
		events.append({"case": "respawned", "id": f.id})


## A sworn pair wakes together, and one left down alone too long is raised by the other.
func _sworn_rules(events: Array) -> void:
	var a := index_of(boss_id) if boss_id >= 0 else -1
	var b := index_of(twin_id) if twin_id >= 0 else -1
	if a < 0 or b < 0:
		return
	for pair: Array in [[a, b], [b, a]]:
		var me: int = pair[0]
		var other: int = pair[1]
		if fighters[me].awake and not fighters[other].awake:
			fighters[other].awake = true
			fighters[other].ai_cooldown = fighters[other].spec.wake_delay
			events.append({"case": "woke", "id": fighters[other].id})
	var down: Array[int] = []
	for n in [a, b]:
		if not fighters[n].is_alive():
			down.append(n)
	if down.size() != 1:
		vow_frames = 0
		return
	var fallen := down[0]
	vow_frames += 1
	if vow_frames < tuning.sworn_rise_frames:
		return
	vow_frames = 0
	var raiser := b if fallen == a else a
	var f := fighters[fallen].copy()
	f.hp = f.spec.max_hp * tuning.sworn_rise_share
	f.vel = Vec2.zero()
	f.ai_cooldown = f.spec.wake_delay
	f.enter(Fighter.St.PHASE_SHIFT, tuning.boss_phase_shift_frames)
	f.invulnerable = tuning.boss_phase_shift_frames
	fighters[fallen] = f
	events.append({"case": "raised", "id": f.id, "by": fighters[raiser].id})


# MARK: Waves and endings


func _housekeeping(events: Array) -> void:
	if is_complete:
		return
	var corpse_frames := tuning.corpse_frames
	var kept: Array[Fighter] = []
	for f in fighters:
		if not (f.team == "enemy" and f.state == Fighter.St.DEAD and f.state_frame >= corpse_frames and not f.spec.boss):
			kept.append(f)
	fighters = kept
	for f in fighters:
		if f.spec.immortal and f.since_hit > tuning.dummy_regen_frames:
			f.hp = f.spec.max_hp

	var hero := controlled()
	if hero != null and not hero.is_alive():
		var other := _other_hero()
		if other >= 0:
			_pass_control(other, events)
		else:
			is_over = true
			events.append({"case": "heroDown"})
			return

	if waves.is_empty():
		return
	var remaining := false
	for f in fighters:
		if f.team == "enemy" and f.is_alive() and not f.spec.immortal:
			remaining = true
			break
	if wave_live and not remaining:
		wave_live = false
		wave_delay = tuning.wave_delay
		events.append({"case": "waveCleared", "number": wave_number})
		for f in fighters:
			if f.team != "hero":
				continue
			if f.is_alive():
				f.hp = Sw.min_d(f.spec.max_hp, f.hp + tuning.wave_clear_heal)
			else:
				f.hp = f.spec.max_hp * tuning.revive_fraction
				f.enter(Fighter.St.IDLE)
				f.invulnerable = f.spec.hurt_invulnerable
				events.append({"case": "revived", "id": f.id})
	elif not wave_live and not remaining:
		if wave_delay > 0:
			wave_delay -= 1
		else:
			var wave: Array = waves[wave_number % waves.size()]
			wave_number += 1
			wave_live = true
			events.append({"case": "waveStarted", "number": wave_number})
			var width := arena_hi - arena_lo
			for s: Array in wave:
				var id := spawn(String(s[0]), arena_lo + float(s[1]) * width)
				var h := controlled()
				var i := index_of(id)
				if h != null and i >= 0:
					fighters[i].facing = 1.0 if h.pos.x >= fighters[i].pos.x else -1.0
				events.append({"case": "spawned", "id": id, "kind": String(s[0])})


# MARK: Queries


## True while a fighter stands in the glow of a lit lamp.
func is_lit(f: Fighter) -> bool:
	if level == null:
		return false
	for lv in level.levers:
		if lv.glow > 0.0 and signals.has(lv.id) and absf(lv.pos.x - f.pos.x) <= lv.glow:
			return true
	return false


## The plate a fighter is standing on, or null.
func plate_under(f: Fighter) -> Level.Plate:
	if not f.on_ground or level == null:
		return null
	for p in level.plates:
		if f.pos.x >= p.x0 and f.pos.x <= p.x1 and absf(f.pos.y - p.top) < 2.0:
			return p
	return null


## Port-only (no Swift counterpart): true when eclipse ground starting just ahead of `f`, moving `dir`, is gone
## now or will go before `f` has walked across it at its run speed. Always false on a level without eclipse
## phases. Assumes eclipse ground of opposite phases never touches (that needs a jump, not a wait).
func eclipse_blocks(f: Fighter, dir: float) -> bool:
	if level == null or level.eclipse_period <= 0:
		return false
	var half := f.spec.width / 2.0
	var left := level.frames_to_eclipse_swap(frame)
	for i in platforms.size():
		var p: Level.Platform = platforms[i]
		if p.eclipse == 0:
			continue
		var b := p.box_at(frame)
		var ahead := b.min_x - (f.pos.x + half) if dir > 0.0 else (f.pos.x - half) - b.max_x
		# Behind, too far ahead, or at another height: not in the way.
		var behind := f.pos.x > b.max_x if dir > 0.0 else f.pos.x < b.min_x
		if behind or ahead > 60.0 or absf(b.max_y - f.pos.y) > 40.0:
			continue
		if not level.eclipse_solid(p, frame):
			return true
		# Already standing over it: getting off in time is eclipse_escape's job.
		if (f.pos.x >= b.min_x) if dir > 0.0 else (f.pos.x <= b.max_x):
			continue
		var cross := (b.max_x - b.min_x + f.spec.width + Sw.max_d(ahead, 0.0)) / Sw.max_d(f.spec.run_speed, 1.0)
		return float(left) < cross * Tuning.FRAMES_PER_SECOND + ECLIPSE_MARGIN
	return false


## Port-only: true when `x`, just past `f`'s front, lies over eclipse ground that `f` is not already standing on
## and that is gone or will go within ECLIPSE_MARGIN frames.
func _eclipse_edge_unsafe(f: Fighter, x: float) -> bool:
	var half := f.spec.width / 2.0
	var soon := float(level.frames_to_eclipse_swap(frame)) < ECLIPSE_MARGIN
	for i in platforms.size():
		var p: Level.Platform = platforms[i]
		if p.eclipse == 0:
			continue
		var b := p.box_at(frame)
		if not (b.min_x <= x and x <= b.max_x and absf(b.max_y - f.pos.y) < 8.0):
			continue
		var gone := platform_boxes[i].min_y < -50000.0
		if gone:
			return true
		# Standing on it already: getting off in time is eclipse_escape's job.
		if soon and not (f.pos.x + half > b.min_x and f.pos.x - half < b.max_x):
			return true
	return false


## Frames of slack eclipse_blocks wants before a swap: enough to cross and, if a swing starts on the way, for
## eclipse_escape (which allows 12 frames less) to still get clear.
const ECLIPSE_MARGIN := 48.0


## Port-only: true when any part of `f`'s width is over eclipse ground at its feet. Always false on a level
## without eclipse phases, so Swift's levels keep their safe spots.
func _over_eclipse(f: Fighter) -> bool:
	if level == null or level.eclipse_period <= 0:
		return false
	var half := f.spec.width / 2.0
	for p: Level.Platform in platforms:
		if p.eclipse != 0 and f.pos.x + half > p.box.min_x and f.pos.x - half < p.box.max_x \
				and absf(p.box.max_y - f.pos.y) < 2.0:
			return true
	return false


## Port-only: when any part of `f` stands on eclipse ground that will go before it could walk clear, the way to
## the nearer end (-1 or 1); otherwise 0. Always 0 on a level without eclipse phases. Its slack is a little less
## than eclipse_blocks wants for stepping on, so a hero who stepped on in time never turns back halfway.
func eclipse_escape(f: Fighter) -> float:
	if level == null or level.eclipse_period <= 0 or not f.on_ground:
		return 0.0
	var half := f.spec.width / 2.0
	var left := float(level.frames_to_eclipse_swap(frame))
	for i in platforms.size():
		if platforms[i].eclipse == 0:
			continue
		var b := platform_boxes[i]
		if not (f.pos.x + half > b.min_x and f.pos.x - half < b.max_x and absf(b.max_y - f.pos.y) < 2.0):
			continue
		var to_left := Sw.max_d(0.0, f.pos.x + half - b.min_x + 2.0)
		var to_right := Sw.max_d(0.0, b.max_x - (f.pos.x - half) + 2.0)
		var dir := -1.0 if to_left < to_right else 1.0
		var frames := Sw.min_d(to_left, to_right) / Sw.max_d(f.spec.run_speed, 1.0) * Tuning.FRAMES_PER_SECOND
		if left < frames + ECLIPSE_MARGIN - 12.0:
			return dir
	return 0.0


## Where an eclipsed platform's box waits while it is not there: far below everything, so nothing touches it.
static func _eclipsed(p: Level.Platform) -> Box:
	return p.box.offset(0.0, -100000.0)


## Eclipse phases: ground that is solid only in the light or only in shadow comes and goes as they swap. Like a
## gate, ground will not form around someone standing in its space; it waits until they are clear.
func _eclipse_platforms(events: Array) -> void:
	var light_now := level.eclipse_light(frame)
	var light_next := level.eclipse_light(frame + 1)
	if light_now != light_next:
		events.append({"case": "eclipse", "light": light_next})
	for i in platforms.size():
		var p: Level.Platform = platforms[i]
		if p.eclipse == 0:
			continue
		var there := platform_boxes[i].min_y > -50000.0
		var want := level.eclipse_solid(p, frame + 1)
		if want == there and not p.moves():
			continue
		if not want:
			platform_boxes[i] = _eclipsed(p)
			platform_deltas[i] = Vec2.zero()
			continue
		var nb := p.box_at(frame + 1)
		if there:
			platform_deltas[i] = Vec2.new(nb.min_x - platform_boxes[i].min_x, nb.min_y - platform_boxes[i].min_y)
		else:
			var blocked := false
			for f in fighters:
				if f.is_alive() and f.hurtbox().intersects(nb):
					blocked = true
					break
			if blocked:
				continue
			platform_deltas[i] = Vec2.zero()
		platform_boxes[i] = nb


## True when a gate's levers and plates would have it open.
func wants_open(gate: Level.Gate) -> bool:
	var all := true
	for id in gate.opens_with:
		if not signals.has(id):
			all = false
			break
	return not all if gate.inverted else all


func has_ground(x: float, y: float) -> bool:
	for b in platform_boxes:
		if b.min_x <= x and x <= b.max_x and b.max_y <= y + 1.0 and b.max_y >= y - 8.0:
			return true
	return false


## True while this fighter cannot be hurt because something shields it.
func is_warded(id: int) -> bool:
	var f := fighter(id)
	if f != null and f.is_alive() and f.spec.needs_light and not is_lit(f):
		return true
	if f != null and f.is_alive() and f.spec.shielded_by != "":
		for g in fighters:
			if g.kind == f.spec.shielded_by and g.is_alive() and absf(g.pos.x - f.pos.x) <= tuning.debtor_shield_range:
				return true
		return false
	if f == null or not f.is_alive() or f.spec.ward_radius != 0.0 or f.spec.boss:
		return false
	for g in fighters:
		if g.spec.ward_radius > 0.0 and g.is_alive() and g.awake and g.team == f.team \
				and absf(g.pos.x - f.pos.x) <= g.spec.ward_radius and absf(g.pos.y - f.pos.y) <= tuning.ward_height:
			return true
	return false


# MARK: Canonical state


func to_canon() -> Dictionary:
	return {
		"fighters": fighters, "controlledID": controlled_id, "frame": frame, "hitStop": hit_stop,
		"isOver": is_over, "waveNumber": wave_number, "platformBoxes": platform_boxes,
		"checkpointIndex": checkpoint_index, "collected": Canon.int_set(collected),
		"isComplete": is_complete, "bossID": boss_id if boss_id >= 0 else null,
		"twinID": twin_id if twin_id >= 0 else null, "vowFrames": vow_frames,
		"bossDownFrames": boss_down_frames, "firedScenes": Canon.string_set(fired_scenes),
		"strikes": strikes, "platformDeltas": platform_deltas, "signals": Canon.int_set(signals),
		"leverTimers": lever_timers, "gateOpen": gate_open, "waveLive": wave_live,
		"waveDelay": wave_delay, "switchCooldown": switch_cooldown, "rng": rng, "nextID": next_id,
	}


func state_hash() -> String:
	return Canon.hash_hex(self)
