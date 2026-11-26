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
