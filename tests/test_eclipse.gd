extends SceneTree
## Eclipse phases (the final chapter's mechanic, DEC-017): ground solid only in the light or only in shadow, swapping
## on the level's rhythm. Port-only; Swift's levels have none, which the replay goldens keep checking.

var failed := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		print("FAIL ", what)


static func _plat(x0: float, x1: float, top: float, eclipse := 0, one_way := false) -> Dictionary:
	return {"box": {"minX": x0, "minY": top - (14.0 if one_way else 40.0), "maxX": x1, "maxY": top}, "oneWay": one_way,
		"travel": {"x": 0.0, "y": 0.0}, "period": 0, "eclipse": eclipse}


## Floors with two gaps: the first bridged only in the light, the second only in shadow. With `crowd`, Orion
## follows and a Scrap Drone waits just past each bridge, so the bridges are crossed mid-fight.
static func room(period := 240, crowd := false) -> Level:
	var d := room_data(period)
	if crowd:
		d.partner = {"kind": "orion", "pos": {"x": 60.0, "y": 0.0}}
		d.enemies = [{"kind": "scrapDrone", "pos": {"x": 560.0, "y": 0.0}},
			{"kind": "scrapDrone", "pos": {"x": 1160.0, "y": 0.0}}]
	return Level.from_data(d)


static func room_data(period: int) -> Dictionary:
	return ({
		"name": "Eclipse test", "width": 2600.0, "start": {"x": 120.0, "y": 0.0},
		"platforms": [_plat(-200, 600, 0), _plat(600, 800, 0, 1), _plat(800, 1200, 0), _plat(1200, 1400, 0, -1),
			_plat(1400, 2600, 0)],
		"hazards": [], "levers": [], "plates": [], "gates": [], "checkpoints": [], "pickups": [], "enemies": [],
		"partner": null, "boss": null, "twin": null, "scenes": [], "exitX": 2400.0, "killY": -260.0,
		"eclipsePeriod": period, "eclipseWarning": 40})


## True when anyone placed in the level (boss, twin, enemies) has an attack with a shift effect.
static func _shifts(lv: Level, t: Tuning) -> bool:
	var kinds: Array = []
	for pl: Level.Placement in lv.enemies:
		kinds.append(pl.kind)
	for pl: Level.Placement in [lv.boss, lv.twin]:
		if pl != null:
			kinds.append(pl.kind)
	for k: String in kinds:
		for a: Specs.AttackSpec in t.spec(k).attacks:
			if a.effect is Dictionary and String(a.effect.get("case", "")) == "shift":
				return true
	return false


static func _there(w: World, i: int) -> bool:
	return w.eclipse_there(i)


func _init() -> void:
	var t := Tuning.load_default()
	var w := World.from_level(room(), "caelen", t, 1)
	check(_there(w, 1) and not _there(w, 3), "in the light the light bridge is there and the shadow bridge is not")

	# Swaps every half period, with an event each time.
	var swaps := 0
	var lights: Array = []
	for i in 480:
		for e: Dictionary in w.step(InputFrame.neutral()):
			if e.case == "eclipse":
				swaps += 1
				lights.append(e.light)
	check(swaps == 4 and lights == [false, true, false, true], "four swaps in two cycles, shadow first: %s" % [lights])

	# Standing on the light bridge when the shadow comes: the hero falls.
	w = World.from_level(room(), "caelen", t, 1)
	var hero := w.controlled()
	hero.pos.x = 700.0
	for i in 110:
		w.step(InputFrame.neutral())
	hero = w.controlled()
	check(hero.on_ground and hero.pos.y == 0.0, "on the light bridge during the light: standing")
	for i in 40:
		w.step(InputFrame.neutral())
	hero = w.controlled()
	check(hero.pos.y < -20.0, "when the shadow comes the light bridge goes and the hero falls (y %.0f)" % hero.pos.y)

	# Ground does not form around someone standing in its space.
	var low := Level.from_data({
		"name": "Eclipse low", "width": 1600.0, "start": {"x": 120.0, "y": 0.0},
		"platforms": [_plat(-200, 1600, 0), _plat(300, 400, 30, -1)],
		"hazards": [], "levers": [], "plates": [], "gates": [], "checkpoints": [], "pickups": [], "enemies": [],
		"partner": null, "boss": null, "twin": null, "scenes": [], "exitX": 1500.0, "killY": -260.0,
		"eclipsePeriod": 240, "eclipseWarning": 40})
	w = World.from_level(low, "caelen", t, 1)
	hero = w.controlled()
	hero.pos.x = 350.0
	for i in 130:
		w.step(InputFrame.neutral())
	check(not _there(w, 1), "shadow ground waits while the hero stands where it would form")
	for i in 30:
		w.step(InputFrame.make(1.0))
	hero = w.controlled()
	check(hero.pos.x > 420.0 and _there(w, 1), "and forms once the hero is clear (x %.0f)" % hero.pos.x)

	# Orion reaches the light bridge 30 frames before it goes, with the lead parked across it: he waits.
	w = World.from_level(room(240, true), "caelen", t, 1)
	for f: Fighter in w.fighters:
		if f.team == "enemy":
			f.hp = 0.0
	w.controlled().pos.x = 1000.0
	var orion: Fighter = null
	for f: Fighter in w.fighters:
		if f.team == "hero" and f.id != w.controlled_id:
			orion = f
	orion.pos.x = 560.0
	w.frame = 90
	var dropped := false
	for i in 320:
		w.step(InputFrame.neutral())
		orion = w.fighter(orion.id)
		if orion.pos.y < -20.0:
			dropped = true
	check(orion != null and not dropped and orion.pos.x > 800.0,
		"Orion waits for the bridge and crosses after (dropped %s, x %.0f)" % [dropped, orion.pos.x])

	# Shift: the next swap is pulled forward to the warning, never pushed back, and the swap then comes on time.
	var arena := Level.from_data({
		"name": "Eclipse arena", "width": 1800.0, "start": {"x": 300.0, "y": 0.0},
		"platforms": [_plat(-200, 2000, 0), _plat(600, 800, 96, 1, true), _plat(1000, 1200, 96, -1, true)],
		"hazards": [], "levers": [], "plates": [], "gates": [], "checkpoints": [], "pickups": [], "enemies": [],
		"partner": null, "boss": null, "twin": null, "scenes": [], "exitX": 1700.0, "killY": -260.0,
		"eclipsePeriod": 300, "eclipseWarning": 40})
	w = World.from_level(arena, "caelen", t, 1)
	for i in 10:
		w.step(InputFrame.neutral())
	var ev: Array = []
	w._shift_eclipse(40, ev)
	check(w.eclipse_swap_in() == 40 and ev.size() == 1 and ev[0].case == "shift", "shift pulls the swap to 40 frames (%d)" % w.eclipse_swap_in())
	for i in 30:
		w.step(InputFrame.neutral())
	w._shift_eclipse(40, ev)
	check(w.eclipse_swap_in() == 10, "a shift never pushes a closer swap away (%d)" % w.eclipse_swap_in())
	var swapped_at := -1
	for i in 20:
		for e: Dictionary in w.step(InputFrame.neutral()):
			if e.case == "eclipse" and swapped_at < 0:
				swapped_at = i
	check(swapped_at == 9, "and the swap comes when it said (step %d)" % swapped_at)
	check(w.to_canon().has("eclipseOffset"), "the offset is part of the state once it moves")

	# One-way eclipse ledges form over someone standing under them, and a shift drops a hero on a ledge to the
	# floor without a fall.
	w = World.from_level(arena, "caelen", t, 1)
	hero = w.controlled()
	hero.pos.x = 1100.0
	var shadow_ledge := 2
	for i in 160:
		w.step(InputFrame.neutral())
	check(_there(w, shadow_ledge), "the shadow ledge forms with a hero under it")
	w = World.from_level(arena, "caelen", t, 1)
	hero = w.controlled()
	hero.pos = Vec2.new(700.0, 96.0)
	for i in 20:
		w.step(InputFrame.neutral())
	hero = w.controlled()
	check(hero.on_ground and hero.pos.y == 96.0, "a hero stands on the light ledge (y %.0f)" % hero.pos.y)
	w._shift_eclipse(30, ev)
	var fell_events := 0
	for i in 90:
		for e: Dictionary in w.step(InputFrame.neutral()):
			if e.case == "fell":
				fell_events += 1
	hero = w.controlled()
	check(hero.on_ground and hero.pos.y == 0.0 and fell_events == 0 and hero.hp == hero.spec.max_hp,
		"after the shift they land on the floor, unhurt (y %.0f, falls %d, hp %.0f)" % [hero.pos.y, fell_events, hero.hp])

	# A floor strike below a ledge's top misses a hero on the ledge and hits one on the floor.
	for on_ledge in [true, false]:
		w = World.from_level(arena, "caelen", t, 1)
		hero = w.controlled()
		hero.pos = Vec2.new(700.0, 96.0 if on_ledge else 0.0)
		for i in 5:
			w.step(InputFrame.neutral())
		w.strikes.append(Strike.make(Box.new(640.0, -4.0, 760.0, 90.0), 10, 30, 10.0))
		for i in 60:
			w.step(InputFrame.neutral())
		hero = w.controlled()
		var hit: bool = hero.hp < hero.spec.max_hp
		check(hit != on_ledge, "a floor strike %s a hero %s" % ["misses" if on_ledge else "hits", "on the ledge" if on_ledge else "on the floor"])

	# Fairness: a level where anything can shift the rhythm has solid floor under every piece of eclipse ground.
	var covered: Array = []
	for id: String in (JSON.parse_string(FileAccess.get_file_as_string("res://data/index.json")).levels as Array):
		var lv := Level.load_id(id)
		if lv.eclipse_period <= 0 or not _shifts(lv, t):
			continue
		covered.append(id)
		var bare: Array = []
		for p: Level.Platform in lv.platforms:
			if p.eclipse == 0:
				continue
			var under := false
			for q: Level.Platform in lv.platforms:
				if q.eclipse == 0 and not q.one_way and q.box.min_x <= p.box.min_x and q.box.max_x >= p.box.max_x \
						and q.box.max_y < p.box.max_y and p.box.max_y - q.box.max_y <= 200.0:
					under = true
			if not under:
				bare.append("%.0f-%.0f" % [p.box.min_x, p.box.max_x])
		check(bare.is_empty(), "%s shifts the rhythm, so all its eclipse ground has floor under it: bare %s" % [id, bare])
	print("fairness covered: ", covered)

	# Eclipse pieces never touch end to end, whatever their phases. The walking rules treat each piece as its own
	# span: two pieces of one phase side by side made a walker rock at the seam and fall, and opposite phases
	# side by side could only be crossed by a jump.
	var touching: Array = []
	for id: String in (JSON.parse_string(FileAccess.get_file_as_string("res://data/index.json")).levels as Array):
		var lv := Level.load_id(id)
		for a: Level.Platform in lv.platforms:
			for b: Level.Platform in lv.platforms:
				if a == b or a.eclipse == 0 or b.eclipse == 0:
					continue
				if absf(a.box.max_x - b.box.min_x) < 1.0 and a.box.min_y < b.box.max_y and b.box.min_y < a.box.max_y:
					touching.append("%s %.0f" % [id, a.box.max_x])
	check(touching.is_empty(), "no two pieces of eclipse ground touch end to end: %s" % [touching])
	check(covered.has("masons_span"), "the fairness check covers the Mason's Span (%s)" % [covered])

	# Every boss on an eclipse level shows its whole kit in a fight: it shifts the rhythm, raises floor strikes,
	# calls help and reaches its last phase, for every lead. The Heart also keeps each phase's signature: no shifts
	# in its steady first phase, help called only in the second, and shifts coming faster in the third than the second.
	for id: String in (JSON.parse_string(FileAccess.get_file_as_string("res://data/index.json")).levels as Array):
		var lv := Level.load_id(id)
		if lv.eclipse_period <= 0 or lv.boss == null:
			continue
		var last_phase := t.spec(lv.boss.kind).phase_thresholds.size() + 1
		for lead in ["caelen", "seraphine", "nimue"]:
			for seed in [1, 2, 3]:
				w = World.from_level(lv, lead, t, seed)
				var pilot := Autopilot.new(true)
				var seen := {"shift": 0, "spawned": 0, "strike": 0}
				var shifts := [0, 0, 0, 0]
				var calls := [0, 0, 0, 0]
				var frames := [0, 0, 0, 0]
				var phase := 1
				while w.frame < 12000 and not w.is_over:
					var before := w.strikes.size()
					var now := w.boss().phase if w.boss() != null and w.boss().awake and w.boss().is_alive() else 0
					frames[mini(now, 3)] += 1
					for e: Dictionary in w.step(pilot.input_for(w)):
						if seen.has(e.case):
							seen[e.case] += 1
						if e.case == "shift":
							shifts[mini(now, 3)] += 1
						elif e.case == "spawned":
							calls[mini(now, 3)] += 1
					if w.strikes.size() > before:
						seen.strike += 1
					if w.boss() != null:
						phase = maxi(phase, w.boss().phase)
				var ok: bool = w.is_complete and phase >= last_phase and seen.shift > 0 and seen.spawned > 0 and seen.strike > 0
				if lv.boss.kind == "heart":
					# The phase pattern. That phase 3 shifts more often is checked directly below: one fight's
					# counts are too few to compare rates.
					ok = ok and shifts[1] == 0 and calls[2] > 0 and calls[3] == 0 and frames[3] > 0
				check(ok, "%s (%s, seed %d): complete %s, phase %d/%d, seen %s, shifts by phase %s, calls %s, frames %s"
					% [id, lead, seed, w.is_complete, phase, last_phase, seen, shifts, calls, frames])
	check(covered.has("heart"), "the fairness check covers the Heart (%s)" % [covered])

	# The Heart's third phase shifts the rhythm more often than its second: more of its attacks are shifts (calls
	# for help, which only the second phase makes, left out of the count). The hero is kept out of harm's way.
	var heart_rate := {}
	for ph in [2, 3]:
		w = World.from_level(Level.load_id("heart"), "caelen", t, 1)
		var hid := w.boss().id
		var n_shift := 0
		var n_attack := 0
		for i in 3000:
			var h := w.controlled()
			h.invulnerable = 10
			h.pos = Vec2.new(700.0, 0.0)
			var b := w.fighter(hid)
			b.awake = true
			b.phase = ph
			b.hp = b.spec.max_hp * (0.5 if ph == 2 else 0.2)
			var was := b.state
			w.step(InputFrame.neutral())
			b = w.fighter(hid)
			if b.state == Fighter.St.ATTACK and was != Fighter.St.ATTACK:
				var effect: Variant = b.current_attack().effect
				var kind := String(effect.get("case", "")) if effect is Dictionary else String(effect)
				if kind == "shift":
					n_shift += 1
				if kind != "summon":
					n_attack += 1
		heart_rate[ph] = [n_shift, n_attack]
	var r2: float = float(heart_rate[2][0]) / maxf(float(heart_rate[2][1]), 1.0)
	var r3: float = float(heart_rate[3][0]) / maxf(float(heart_rate[3][1]), 1.0)
	check(heart_rate[2][0] > 0 and r3 > r2 + 0.05,
		"the Heart shifts more often in its third phase than its second (shifts/attacks %s)" % [heart_rate])
	print("heart shifts/attacks: ", heart_rate)

	# An odd period: the light lasts half (rounded down), and the countdown always reaches the real swap.
	var odd := room(301)
	var bad := 0
	for f in 903:
		var n := odd.frames_to_eclipse_swap(f)
		if n < 1 or odd.eclipse_light(f) != odd.eclipse_light(f + n - 1) or odd.eclipse_light(f) == odd.eclipse_light(f + n):
			bad += 1
	check(bad == 0, "odd period: the countdown lands on every swap (%d frames wrong)" % bad)

	# The autopilot waits for the ground and crosses both bridges without falling, walking and fighting, and
	# with Orion following and drones to fight beside the bridges nobody falls either.
	for crowd in [false, true]:
		for fights in [false, true]:
			for period in [240, 301, 360]:
				w = World.from_level(room(period, crowd), "caelen", t, 1)
				var pilot := Autopilot.new(fights)
				var fell: Array = []
				for i in 60 * 90:
					if w.is_over or w.is_complete:
						break
					for e: Dictionary in w.step(pilot.input_for(w)):
						if e.case == "fell" or (e.case == "died" and w.fighter(e.id) != null and w.fighter(e.id).team == "hero"):
							fell.append(e.id)
					for f: Fighter in w.fighters:
						if f.team == "hero" and f.pos.y < -20.0 and not fell.has("drop %d" % f.id):
							fell.append("drop %d" % f.id)
				check(w.is_complete and fell.is_empty(), "autopilot (crowd %s, fights %s, period %d) crosses: complete %s, fell %s, x %.0f"
					% [crowd, fights, period, w.is_complete, fell, w.controlled().pos.x])

	# Moving eclipse ground: while there it moves on its path and carries whoever stands on it; when gone it is
	# parked; it comes back where its path has reached by then, not where it left.
	var ferry := Level.from_data({
		"name": "Eclipse ferry", "width": 2000.0, "start": {"x": 120.0, "y": 0.0},
		"platforms": [_plat(-200, 2000, 0), {"box": {"minX": 300.0, "minY": 82.0, "maxX": 420.0, "maxY": 96.0},
			"oneWay": true, "travel": {"x": 300.0, "y": 0.0}, "period": 200, "eclipse": 1}],
		"hazards": [], "levers": [], "plates": [], "gates": [], "checkpoints": [], "pickups": [], "enemies": [],
		"partner": null, "boss": null, "twin": null, "scenes": [], "exitX": 1900.0, "killY": -260.0,
		"eclipsePeriod": 300, "eclipseWarning": 40})
	w = World.from_level(ferry, "caelen", t, 1)
	w.controlled().pos = Vec2.new(360.0, 96.0)
	for i in 5:
		w.step(InputFrame.neutral())
	var rider_start := w.controlled().pos.x
	var box_start := w.platform_boxes[1].min_x
	for i in 60:
		w.step(InputFrame.neutral())
	hero = w.controlled()
	var moved := w.platform_boxes[1].min_x - box_start
	check(hero.on_ground and hero.pos.y == 96.0 and moved > 50.0 and absf((hero.pos.x - rider_start) - moved) < 0.01,
		"moving eclipse ground carries its rider (box %.1f, rider %.1f, y %.0f)" % [moved, hero.pos.x - rider_start, hero.pos.y])
	while w.eclipse_light():
		w.step(InputFrame.neutral())
	w.step(InputFrame.neutral())
	hero = w.controlled()
	check(not _there(w, 1) and hero.pos.y < 96.0, "when the shadow comes it goes, and the rider drops (y %.0f)" % hero.pos.y)
	while not w.eclipse_light():
		w.step(InputFrame.neutral())
	w.step(InputFrame.neutral())
	var want := ferry.platforms[1].box_at(w.frame)
	check(_there(w, 1) and absf(w.platform_boxes[1].min_x - want.min_x) < 0.01,
		"and comes back where its path has reached (%.1f, path %.1f)" % [w.platform_boxes[1].min_x, want.min_x])

	# A tall eclipse wall is a phase gate: shut in its phase, open in the other, with no gate code. Ground that
	# should be there but is held off by someone standing in its space sends them out; ground gone by the rhythm
	# does not, so its space can be walked through.
	var gated := Level.from_data({
		"name": "Eclipse gate", "width": 2000.0, "start": {"x": 400.0, "y": 0.0},
		"platforms": [_plat(-200, 2000, 0), {"box": {"minX": 600.0, "minY": 0.0, "maxX": 640.0, "maxY": 200.0},
			"oneWay": false, "travel": {"x": 0.0, "y": 0.0}, "period": 0, "eclipse": 1}],
		"hazards": [], "levers": [], "plates": [], "gates": [], "checkpoints": [], "pickups": [], "enemies": [],
		"partner": null, "boss": null, "twin": null, "scenes": [], "exitX": 1900.0, "killY": -260.0,
		"eclipsePeriod": 300, "eclipseWarning": 40})
	w = World.from_level(gated, "caelen", t, 1)
	hero = w.controlled()
	for i in 140:
		w.step(InputFrame.make(1.0, false, false))
	hero = w.controlled()
	check(hero.pos.x < 600.0, "a light wall stops a walker in the light (x %.0f)" % hero.pos.x)
	for i in 100:
		w.step(InputFrame.make(1.0, false, false))
	hero = w.controlled()
	check(hero.pos.x > 700.0, "and lets them through in shadow (x %.0f)" % hero.pos.x)
	w = World.from_level(gated, "caelen", t, 1)
	hero = w.controlled()
	for i in 160:
		w.step(InputFrame.neutral())
	w.controlled().pos.x = 620.0
	w.step(InputFrame.neutral())
	check(w.eclipse_clear(w.controlled()) == 0.0, "no one is sent out of a wall's space while it is gone by the rhythm")
	for i in 150:
		w.step(InputFrame.neutral())
	check(not _there(w, 1) and w.eclipse_clear(w.controlled()) != 0.0,
		"the wall waits for whoever stands in its space in the light, and sends them out (there %s)" % _there(w, 1))
	var waited := 0
	while not _there(w, 1) and waited < 120:
		w.step(InputFrame.make(w.eclipse_clear(w.controlled()), false, false))
		waited += 1
	hero = w.controlled()
	check(_there(w, 1) and (hero.pos.x < 600.0 or hero.pos.x > 640.0),
		"and forms once they are out (%d frames, x %.0f)" % [waited, hero.pos.x])

	# Ground waits only for heroes: an enemy loitering in a gone wall's space does not hold it off, and is shoved out.
	w = World.from_level(gated, "caelen", t, 1)
	for i in 160:
		w.step(InputFrame.neutral())
	var drone := w.spawn("scrapDrone", 620.0, 0.0, 1.0)
	# Pinned in the wall's space through the swap back to light (frame 300), so it cannot simply wander out first.
	while w.frame < 302:
		w.fighter(drone).pos.x = 620.0
		w.step(InputFrame.neutral())
	check(_there(w, 1), "an enemy pinned in a wall's space at the swap does not hold it off")
	for i in 30:
		w.step(InputFrame.neutral())
	var d := w.fighter(drone)
	check(_there(w, 1) and d != null and (d.pos.x < 600.0 or d.pos.x > 640.0),
		"an enemy in a wall's space does not hold it off (there %s, x %.0f)" % [_there(w, 1), d.pos.x if d else 0.0])

	# Walkers wait at the edge of ground held off by someone else, so two cannot take turns keeping it away.
	var paired := Level.from_data({
		"name": "Eclipse gate pair", "width": 2000.0, "start": {"x": 400.0, "y": 0.0},
		"platforms": [_plat(-200, 2000, 0), {"box": {"minX": 600.0, "minY": 0.0, "maxX": 640.0, "maxY": 200.0},
			"oneWay": false, "travel": {"x": 0.0, "y": 0.0}, "period": 0, "eclipse": 1}],
		"hazards": [], "levers": [], "plates": [], "gates": [], "checkpoints": [], "pickups": [], "enemies": [],
		"partner": {"kind": "orion", "pos": {"x": 300.0, "y": 0.0}}, "boss": null, "twin": null, "scenes": [],
		"exitX": 1900.0, "killY": -260.0, "eclipsePeriod": 300, "eclipseWarning": 40})
	w = World.from_level(paired, "caelen", t, 1)
	for i in 299:
		w.step(InputFrame.neutral())
	w.fighter(2).pos.x = 620.0
	w.controlled().pos.x = 600.0 - w.controlled().hurtbox().width() / 2.0 - 4.0 - (w.controlled().hurtbox().center().x - w.controlled().pos.x)
	for i in 2:
		w.step(InputFrame.neutral())
	check(not _there(w, 1) and w.eclipse_held(w.controlled(), 1.0) and not w.eclipse_held(w.controlled(), -1.0),
		"a walker at the edge of ground someone else holds off waits for it (there %s)" % _there(w, 1))

	# Lower eclipse ground: no walking or dodging off a ledge onto ground that will go before the drop and the
	# crossing are done.
	var drop := Level.from_data({
		"name": "Eclipse drop", "width": 2000.0, "start": {"x": 470.0, "y": 300.0},
		"platforms": [_plat(-200, 500, 300), _plat(500, 600, 230, 1), _plat(600, 2000, 230)],
		"hazards": [], "levers": [], "plates": [], "gates": [], "checkpoints": [], "pickups": [], "enemies": [],
		"partner": null, "boss": null, "twin": null, "scenes": [], "exitX": 1900.0, "killY": -260.0,
		"eclipsePeriod": 300, "eclipseWarning": 40})
	w = World.from_level(drop, "caelen", t, 1)
	for i in 10:
		w.step(InputFrame.neutral())
	check(not w.eclipse_blocks(w.controlled(), 1.0), "early in the light a drop onto light ground is open")
	for i in 100:
		w.step(InputFrame.neutral())
	check(w.eclipse_blocks(w.controlled(), 1.0), "late in the light it is shut (%d to the swap)" % w.eclipse_swap_in())
	w.controlled().facing = 1.0
	for i in 30:
		w.step(InputFrame.make(0.0, false, false, false, i == 0))
	hero = w.controlled()
	check(hero.pos.y == 300.0 and hero.pos.x < 500.0 + hero.spec.width,
		"and a dodge stops at the ledge's edge (x %.0f, y %.0f)" % [hero.pos.x, hero.pos.y])

	# The edge stop is for lunges and dodges on the ground. An attack swung in the air keeps the jump's carry, even
	# over eclipse ground close to its swap: stopping it mid-air dropped the hero back onto a bridge about to go.
	var air := Level.from_data({
		"name": "Eclipse air attack", "width": 2000.0, "start": {"x": 300.0, "y": 0.0},
		"platforms": [_plat(-200, 500, 0), _plat(500, 740, 0, 1), _plat(740, 2000, 0)],
		"hazards": [], "levers": [], "plates": [], "gates": [], "checkpoints": [], "pickups": [], "enemies": [],
		"partner": null, "boss": null, "twin": null, "scenes": [], "exitX": 1900.0, "killY": -260.0,
		"eclipsePeriod": 300, "eclipseWarning": 40})
	var stalled := -1
	var swung := 0
	for start in [0, 20, 40, 60, 80, 100]:
		w = World.from_level(air, "caelen", t, 1)
		w.controlled().pos.x = 380.0 + start
		for i in 150 - 70:
			w.step(InputFrame.neutral())
		for i in 60:
			var before := w.controlled().pos.x
			w.step(InputFrame.make(1.0, i == 0, i < 12, i == 4))
			hero = w.controlled()
			if not hero.on_ground and hero.state == Fighter.St.ATTACK:
				swung += 1
				if hero.pos.x <= before and stalled < 0:
					stalled = start
	check(swung > 0 and stalled < 0, "an attack in the air keeps the jump's carry near a swap (stalled from %d, %d air-attack frames)" % [stalled, swung])

	# Every level with eclipse phases, every lead, walking and fighting, a few seeds: it finishes, and no one on
	# the heroes' side drops through a gap where eclipse ground was, except after a hit since they last stood
	# (a knockback throws anyone over any pit, on the ground or in the air). Ordinary pits keep Swift's rules and are not counted.
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/index.json"))
	for id: String in index.levels:
		var level := Level.load_id(id)
		# Boss arenas have floor under all their eclipse ground (the fairness check), so nothing can drop through;
		# the kit check above already plays each of their fights to the end.
		if level.eclipse_period <= 0 or level.boss != null:
			continue
		for lead in ["caelen", "seraphine", "nimue"]:
			for fights in [false, true]:
				for seed in [1, 2, 3]:
					var cs := Progression.chapter_step(id)
					w = World.from_level(level, lead, t, seed, -1, {}, {lead: cs, "orion": cs})
					var pilot := Autopilot.new(fights)
					var drops: Array = []
					var below := {}
					var grounded := {}
					for i in 60 * 180:
						if w.is_over or w.is_complete:
							break
						for f: Fighter in w.fighters:
							if f.team == "hero" and f.on_ground and f.state != Fighter.St.HITSTUN:
								grounded[f.id] = f.state
							elif f.team == "hero" and f.state == Fighter.St.HITSTUN:
								grounded[f.id] = Fighter.St.HITSTUN
						w.step(pilot.input_for(w))
						for f: Fighter in w.fighters:
							# A decoy is a lure, not a hero falling.
							if f.team != "hero" or f.spec.is_decoy:
								continue
							var under := f.pos.y < -20.0
							if under and not below.get(f.id, false) and grounded.get(f.id, -1) != Fighter.St.HITSTUN:
								for p: Level.Platform in level.platforms:
									if p.eclipse != 0 and f.pos.x > p.box.min_x and f.pos.x < p.box.max_x:
										drops.append("%s %d at %.0f" % [Fighter.STATE_NAMES[grounded.get(f.id, 0)], f.id, f.pos.x])
							below[f.id] = under
					check(w.is_complete and drops.is_empty(), "%s (%s, fights %s, seed %d): complete %s, eclipse drops %s"
						% [id, lead, fights, seed, w.is_complete, drops])

	print("eclipse: %d checks, %d failed" % [checks, failed])
	quit(1 if failed > 0 else 0)
