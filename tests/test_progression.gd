extends SceneTree
## Hero progression (design docs/superpowers/specs/2026-11-26-hero-progression-design.md): each hero's three
## abilities, unlocked by step. Step 0 must be today's game; the replay goldens keep checking that.

var failed := 0
var checks := 0
var t: Tuning


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		print("FAIL ", what)


static func _plat(x0: float, x1: float, top: float) -> Dictionary:
	return {"box": {"minX": x0, "minY": top - 40.0, "maxX": x1, "maxY": top}, "oneWay": false,
		"travel": {"x": 0.0, "y": 0.0}, "period": 0, "eclipse": 0}


## A flat floor; `enemies` are [kind, x] pairs; `partner` places Orion.
static func arena(enemies: Array = [], partner := false) -> Level:
	var placed: Array = []
	for e: Array in enemies:
		placed.append({"kind": e[0], "pos": {"x": float(e[1]), "y": 0.0}})
	return Level.from_data({
		"name": "Progression test", "width": 2000.0, "start": {"x": 400.0, "y": 0.0},
		"platforms": [_plat(-200, 2200, 0)],
		"hazards": [], "levers": [], "plates": [], "gates": [], "checkpoints": [], "pickups": [], "enemies": placed,
		"partner": {"kind": "orion", "pos": {"x": 300.0, "y": 0.0}} if partner else null,
		"boss": null, "twin": null, "scenes": [], "exitX": 1900.0, "killY": -260.0})


static func _ids(list: Array) -> Array:
	return list.map(func(a: Dictionary) -> String: return String(a.id))


func _init() -> void:
	t = Tuning.load_default()
	_data()
	_finishers()
	_riposte()
	_break_guard()
	_counter()
	_interpose()
	_partner_finishers()
	print("progression: %d checks, %d failed" % [checks, failed])
	quit(1 if failed > 0 else 0)


func _data() -> void:
	var p := Progression.load_default()
	check(_ids(p.abilities("caelen")) == ["riposte", "break_guard", "full_arc"], "Caelen's track: %s" % [_ids(p.abilities("caelen"))])
	check(_ids(p.abilities("orion")) == ["follow_through", "answer_for_both", "interpose"], "Orion's track: %s" % [_ids(p.abilities("orion"))])
	check(Progression.chapter_step("awakening") == 0 and Progression.chapter_step("cinder_vault") == 1
		and Progression.chapter_step("oracles_terrace") == 2 and Progression.chapter_step("heart") == 3
		and Progression.chapter_step("nope") == 0, "chapter steps")
	var w := World.from_level(Level.load_id("protocol"), "caelen", t, 1, -1, {}, {"caelen": 2, "orion": 2})
	var heroes := 0
	for f: Fighter in w.fighters:
		if f.team == "hero":
			heroes += 1
			check(f.step == 2, "%s is stamped with step 2 (%d)" % [f.kind, f.step])
	check(heroes > 0, "the level has heroes")
	var bare := World.from_level(Level.load_id("protocol"), "caelen", t, 1)
	check(bare.controlled().step == 0, "no steps given is step 0")
	var me := w.controlled()
	check(Progression.has(me, "break_guard"), "break_guard is had at step 2")
	me.step = 1
	check(not Progression.has(me, "break_guard"), "and not at step 1")
	check(p.slot("caelen", "full_arc").both_sides, "Full Arc cuts both ways")
	var room := World.partner_slice(1, t, {"caelen": 1, "orion": 1})
	for f: Fighter in room.fighters:
		check(f.team != "hero" or f.step == 1, "the Training Room stamps %s" % f.kind)
	var copied := me.copy()
	check(copied.step == me.step, "copy keeps the step")


## Presses attack every frame for `frames` frames as the controlled hero; returns that hero's swing events.
func _swings(w: World, frames: int) -> Array:
	var out: Array = []
	for i in frames:
		for e: Dictionary in w.step(InputFrame.make(0.0, false, false, true)):
			if e.case == "swing" and e.id == w.controlled_id:
				out.append(e.get("slot", e.index))
	return out


func _finishers() -> void:
	var lv := arena([["dummy", 470], ["dummy", 330]])
	var w := World.from_level(lv, "caelen", t, 1, -1, {}, {"caelen": 3})
	var got := _swings(w, 150)
	check(got.slice(0, 4) == [0, 1, 2, "full_arc"], "Caelen at step 3 chains 0, 1, 2, Full Arc: %s" % [got])
	var at := got.find("full_arc")
	check(at >= 0 and (at + 1 >= got.size() or got[at + 1] is int), "a slot never chains into another slot: %s" % [got])
	var w2 := World.from_level(lv, "caelen", t, 1, -1, {}, {"caelen": 2})
	check(_swings(w2, 150).all(func(x: Variant) -> bool: return x is int), "at step 2 there is no Full Arc")

	# Full Arc's hitbox spans both sides, and the dummy behind is hit by it.
	var w3 := World.from_level(lv, "caelen", t, 1, -1, {}, {"caelen": 3})
	var both := false
	var behind_hit := false
	var me_id := w3.controlled_id
	var arcing := false
	for i in 150:
		for e: Dictionary in w3.step(InputFrame.make(0.0, false, false, true)):
			if e.case == "swing" and e.id == me_id:
				arcing = e.get("slot", "") == "full_arc"
			if arcing and e.case == "hit" and e.attacker == me_id and w3.fighters[w3.index_of(e.target)].pos.x < w3.controlled().pos.x:
				behind_hit = true
		var me := w3.controlled()
		var box := me.hitbox()
		if arcing and box != null:
			both = box.min_x < me.pos.x - me.spec.width / 2.0 and box.max_x > me.pos.x + me.spec.width / 2.0
	check(both, "Full Arc's hitbox spans both sides")
	check(behind_hit, "Full Arc hits the dummy behind")

	# Orion: 0, 1, Follow-Through at step 1; nothing new at step 0.
	var lo := arena([["dummy", 380]], true)
	for st in [1, 0]:
		var wo := World.from_level(lo, "caelen", t, 1, -1, {}, {"caelen": st, "orion": st})
		for f: Fighter in wo.fighters:
			if f.kind == "orion":
				wo.control(f.id)
		var g := _swings(wo, 120)
		if st == 1:
			check(g.slice(0, 3) == [0, 1, "follow_through"], "Orion at step 1 chains 0, 1, Follow-Through: %s" % [g])
		else:
			check(g.all(func(x: Variant) -> bool: return x is int), "Orion at step 0 has no Follow-Through: %s" % [g])


## Caelen and a forged soldier whose slash lands next frame; Caelen presses attack on that frame, so it is parried.
## Returns the world just after the parry, or null if there was none.
func _parried(step: int) -> World:
	var w := World.from_level(arena([["forgedSoldier", 470]]), "caelen", t, 1, -1, {}, {"caelen": step})
	w.step(InputFrame.neutral())
	var s: Fighter = null
	for f: Fighter in w.fighters:
		if f.kind == "forgedSoldier":
			s = f
	s.awake = true
	s.facing = -1.0
	s.pos.x = w.controlled().pos.x + 60.0
	s.enter_attack(0)
	s.state_frame = s.current_attack().windup - 1
	for i in 3:
		for e: Dictionary in w.step(InputFrame.make(0.0, false, false, true)):
			if e.case == "parried" and e.by == w.controlled_id:
				return w
	return null


## The hero's next swing within `frames` frames, pressing attack only from frame `from` on.
func _next_swing(w: World, frames: int, from := 0) -> Variant:
	for i in frames:
		for e: Dictionary in w.step(InputFrame.make(0.0, false, false, i >= from)):
			if e.case == "swing" and e.id == w.controlled_id:
				return e.get("slot", e.index)
	return null


func _riposte() -> void:
	var w := _parried(1)
	check(w != null, "the forced slash is parried")
	if w != null:
		check(str(_next_swing(w, 60)) == "riposte", "at step 1, attacking after a parry is a Riposte")
	var w0 := _parried(0)
	if w0 != null:
		check(_next_swing(w0, 60) is int, "at step 0 it is the next swing of the chain")
	var late := _parried(1)
	if late != null:
		check(_next_swing(late, 120, 60) is int, "60 frames after the parry, the window is gone")


## Caelen marks the enemy of `kind` in front of him with Command; returns [world, that enemy's index].
func _marked(kind: String, step: int) -> Array:
	var w := World.from_level(arena([[kind, 520]]), "caelen", t, 1, -1, {}, {"caelen": step})
	var at := -1
	for i in 4:
		for e: Dictionary in w.step(InputFrame.make(0.0, false, false, false, false, i == 0)):
			if e.case == "commanded":
				at = w.index_of(e.target)
	return [w, at]


func _break_guard() -> void:
	var m := _marked("forgedSoldier", 2)
	var w: World = m[0]
	check(m[1] >= 0, "Command marks the soldier")
	if m[1] >= 0:
		var s := w.fighters[m[1]]
		s.enter(Fighter.St.IDLE)
		check(not s.is_guarding(), "at step 2 a marked soldier cannot guard")
		# A frontal hit lands: the world's own hit rule, with the soldier standing guard in front of Caelen.
		check(_frontal_hit(w, m[1]) == "hit", "and a frontal hit lands")
		# When the mark runs out, the shield is back.
		w.fighters[w.index_of(s.id)].marked_frames = 1
		# (A hit's hit-stop holds every clock for a few frames.)
		for i in 30:
			if w.fighters[w.index_of(s.id)].marked_frames == 0:
				break
			w.step(InputFrame.neutral())
		var after := w.fighters[w.index_of(s.id)]
		after.enter(Fighter.St.IDLE)
		check(after.marked_frames == 0 and after.is_guarding(), "when the mark runs out the soldier guards again")
		check(_frontal_hit(w, w.index_of(s.id)) == "blocked", "and a frontal hit is blocked again")
	var m1 := _marked("forgedSoldier", 1)
	if m1[1] >= 0:
		var s1: Fighter = (m1[0] as World).fighters[m1[1]]
		s1.enter(Fighter.St.IDLE)
		check(s1.is_guarding() and _frontal_hit(m1[0], m1[1]) == "blocked", "at step 1 a marked soldier still blocks")
	var mb := _marked("lineWarden", 2)
	check(mb[1] >= 0, "Command marks the Line Warden")
	if mb[1] >= 0:
		var b: Fighter = (mb[0] as World).fighters[mb[1]]
		b.enter(Fighter.St.IDLE)
		check(b.spec.boss and b.is_guarding(), "a boss keeps its shield when marked at step 2")
	# The autopilot uses Command on a shielded enemy at step 2.
	var wa := World.from_level(arena([["forgedSoldier", 650]]), "caelen", t, 1, -1, {}, {"caelen": 2})
	var pilot := Autopilot.new(true)
	var commanded := false
	for i in 90:
		for e: Dictionary in wa.step(pilot.input_for(wa)):
			if e.case == "commanded":
				commanded = true
	check(commanded, "the autopilot marks a shielded enemy at step 2")


## Lands Caelen's first swing on fighter `at`, standing idle and facing him from just in front; "hit" or "blocked".
func _frontal_hit(w: World, at: int) -> String:
	var me := w.controlled()
	var s := w.fighters[at]
	s.enter(Fighter.St.IDLE)
	s.facing = -1.0
	me.pos.x = s.pos.x - 70.0
	me.facing = 1.0
	var events: Array = []
	w._land(me.spec.attacks[0], w.index_of(me.id), at, s.pos.copy(), events)
	for e: Dictionary in events:
		if e.case == "hit" or e.case == "blocked":
			return e.case
	return ""


## Orion, controlled, guards with Adapt and a forged soldier's slash lands on the guard. `behind` puts a dummy just
## behind him. Returns [world, Orion's swing events (slot or index) over the next 70 frames, ids his swings hit].
func _absorbed(step: int, behind := false) -> Array:
	var foes := [["forgedSoldier", 470]]
	if behind:
		foes.append(["dummy", 340])
	var w := World.from_level(arena(foes, true), "caelen", t, 1, -1, {}, {"caelen": step, "orion": step})
	var o: Fighter = null
	for f: Fighter in w.fighters:
		if f.kind == "orion":
			o = f
	w.control(o.id)
	o.pos.x = 400.0
	o.facing = 1.0
	w.step(InputFrame.make(0.0, false, false, false, false, true))
	var s: Fighter = null
	for f: Fighter in w.fighters:
		if f.kind == "forgedSoldier":
			s = f
	s.awake = true
	s.facing = -1.0
	s.pos.x = w.controlled().pos.x + 60.0
	s.enter_attack(0)
	s.state_frame = s.current_attack().windup - 1
	var swings: Array = []
	var hits: Array = []
	var absorbed := false
	for i in 70:
		for e: Dictionary in w.step(InputFrame.make(0.0, false, false, absorbed)):
			if e.case == "absorbed" and e.by == o.id:
				absorbed = true
			if e.case == "swing" and e.id == o.id:
				swings.append(e.get("slot", e.index))
			if e.case == "hit" and e.attacker == o.id:
				hits.append(e.target)
	return [w, swings, hits, absorbed]


func _counter() -> void:
	var r1 := _absorbed(1)
	check(r1[3], "Orion's guard absorbs the slash")
	var sw: Array = r1[1]
	check(not sw.is_empty() and str(sw[0]) == "counter", "at step 1 the counter is its own swing: %s" % [sw])
	check(sw.size() < 2 or str(sw[1]) != "follow_through", "and it never chains into Follow-Through: %s" % [sw])
	var r0 := _absorbed(0)
	var sw0: Array = r0[1]
	check(not sw0.is_empty() and sw0[0] is int, "at step 0 the counter is the kit's last swing, as today: %s" % [sw0])
	var r2 := _absorbed(2, true)
	var w2: World = r2[0]
	var hit_behind := false
	for id: int in r2[2]:
		var at := w2.index_of(id)
		if at >= 0 and w2.fighters[at].kind == "dummy":
			hit_behind = true
	check(hit_behind, "at step 2 the counter hits the dummy behind him")
	var r1b := _absorbed(1, true)
	var w1b: World = r1b[0]
	var behind1 := false
	for id: int in r1b[2]:
		var at := w1b.index_of(id)
		if at >= 0 and w1b.fighters[at].kind == "dummy":
			behind1 = true
	check(not behind1, "at step 1 it does not")


## Caelen at 400 and Orion `gap` px left of him, Orion controlled; Orion dodges right toward Caelen (Adapt ready
## unless `spent`). Returns [world, orion, caelen, invulnerable at some dodge frame].
func _dodge_to_lead(step: int, gap: float, spent := false) -> Array:
	var w := World.from_level(arena([], true), "caelen", t, 1, -1, {}, {"caelen": step, "orion": step})
	var c := w.controlled()
	var o: Fighter = null
	for f: Fighter in w.fighters:
		if f.kind == "orion":
			o = f
	w.control(o.id)
	c.pos.x = 400.0
	o.pos.x = 400.0 - gap
	if spent:
		o.special_cooldown = 300
	var invulnerable := false
	w.step(InputFrame.make(1.0, false, false, false, true))
	for i in 20:
		var me := w.fighters[w.index_of(o.id)]
		if me.is_dodge_invulnerable():
			invulnerable = true
		if me.state != Fighter.St.DODGE:
			break
		w.step(InputFrame.neutral())
	return [w, w.fighters[w.index_of(o.id)], w.fighters[w.index_of(c.id)], invulnerable]


## With Orion guarding for Caelen, a forged soldier's slash lands on Caelen. Orion is moved `orion_dx` from Caelen.
## Returns [caelen hp before, after, absorbed events by Orion, counter swings by Orion].
func _slash_at_lead(orion_dx: float) -> Array:
	var r := _dodge_to_lead(3, 120.0)
	var w: World = r[0]
	var o: Fighter = r[1]
	var c: Fighter = r[2]
	w.fighters[w.index_of(o.id)].pos.x = c.pos.x + orion_dx
	w.control(c.id)
	var sid := w.spawn("forgedSoldier", c.pos.x + 60.0, 0.0, -1.0)
	var s := w.fighters[w.index_of(sid)]
	s.awake = true
	s.enter_attack(0)
	s.state_frame = s.current_attack().windup - 1
	var before := c.hp
	var guarding := w.fighters[w.index_of(o.id)].state == Fighter.St.GUARD_STANCE
	var absorbed := 0
	var counters := 0
	for i in 12:
		for e: Dictionary in w.step(InputFrame.neutral()):
			if e.case == "absorbed" and e.by == o.id:
				absorbed += 1
			if e.case == "swing" and e.id == o.id and e.get("slot", "") == "counter":
				counters += 1
	return [before, w.fighters[w.index_of(c.id)].hp, absorbed, counters, guarding]


func _interpose() -> void:
	var r := _dodge_to_lead(3, 120.0)
	var o: Fighter = r[1]
	check(r[3], "Interpose is a real dodge: invulnerable on its way")
	check(o.state == Fighter.St.GUARD_STANCE and o.special_cooldown > 0, "and it ends in Adapt's guard, spending Adapt (%s, cooldown %d)" % [Fighter.STATE_NAMES[o.state], o.special_cooldown])
	var plain := _dodge_to_lead(3, 120.0, true)
	check((plain[1] as Fighter).state != Fighter.St.GUARD_STANCE, "without Adapt ready the dodge is plain")
	var r2 := _dodge_to_lead(2, 120.0)
	check((r2[1] as Fighter).state != Fighter.St.GUARD_STANCE, "at step 2 the dodge is plain")
	var near := _slash_at_lead(-50.0)
	check(near[1] == near[0], "a slash meant for Caelen lands on Orion's guard (hp %.0f -> %.0f)" % [near[0], near[1]])
	check(near[4] and near[2] == 1 and near[3] == 1, "absorbed once, countered once, on the Interpose guard (guarding %s, %d, %d)" % [near[4], near[2], near[3]])
	var far := _slash_at_lead(-140.0)
	check(far[1] < far[0], "an interposer 140 px away does not take it (hp %.0f -> %.0f)" % [far[0], far[1]])

	# The partner brain interposes when a slash is coming at the lead; below step 3 it draws the same random numbers.
	var w := World.from_level(arena([], true), "caelen", t, 1, -1, {}, {"caelen": 3, "orion": 3})
	var c := w.controlled()
	var orion: Fighter = null
	for f: Fighter in w.fighters:
		if f.kind == "orion":
			orion = f
	c.pos.x = 400.0
	orion.pos.x = 300.0
	var sid := w.spawn("forgedSoldier", 460.0, 0.0, -1.0)
	var foe := w.fighters[w.index_of(sid)]
	foe.awake = true
	foe.enter_attack(0)
	# The slash lands 20 frames from now: after Orion's 16-frame dodge, so he is guarding when it does.
	foe.state_frame = foe.current_attack().windup - 20
	var foes: Array[Fighter] = [foe]
	var allies: Array[Fighter] = [c, orion]
	var got := Brains.partner(orion.copy(), foes, allies, t, SeededRandom.new(7))
	check(got.dodge and got.move_x > 0.0, "the partner brain dodges toward a threatened lead at step 3")
	# 8 frames out it would arrive after the hit: no Interpose.
	foe.state_frame = foe.current_attack().windup - 8
	var late := Brains.partner(orion.copy(), foes, allies, t, SeededRandom.new(7))
	check(not (late.dodge and late.move_x > 0.0), "too late to arrive in time, it does not interpose")
	var outs: Array = []
	for st in [0, 2]:
		var me := orion.copy()
		me.step = st
		var rng := SeededRandom.new(7)
		var inp := Brains.partner(me, foes, allies, t, rng)
		outs.append([rng.state, inp.move_x, inp.dodge, inp.special])
	check(outs[0] == outs[1], "below step 3 the partner brain is unchanged, random draws included: %s" % [outs])


## The AI partner finishes its chain once a finisher is unlocked; at step 0 it fights as today.
func _partner_finishers() -> void:
	# A dummy the brains treat as a foe: mortal and sturdy, in a tuning of this test's own.
	var tt := Tuning.load_default()
	tt.dummy.immortal = false
	tt.dummy.max_hp = 100000.0
	for st in [1, 0]:
		var w := World.from_level(arena([["dummy", 230]], true), "caelen", tt, 1, -1, {}, {"caelen": st, "orion": st})
		var oid := -1
		for f: Fighter in w.fighters:
			if f.kind == "orion":
				oid = f.id
		var finishers := 0
		for i in 600:
			for e: Dictionary in w.step(InputFrame.neutral()):
				if e.case == "swing" and e.id == oid and e.get("slot", "") == "follow_through":
					finishers += 1
		if st == 1:
			check(finishers > 0, "AI Orion at step 1 reaches Follow-Through (%d)" % finishers)
		else:
			check(finishers == 0, "AI Orion at step 0 has none")
