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
	return w.platform_boxes[i].min_y > -50000.0


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
	w = World.from_level(room(), "caelen", t, 1)
	hero = w.controlled()
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
	for id: String in (JSON.parse_string(FileAccess.get_file_as_string("res://data/index.json")).levels as Array):
		var lv := Level.load_id(id)
		if lv.eclipse_period <= 0 or not _shifts(lv, t):
			continue
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

	# Every level with eclipse phases, every lead, walking and fighting, a few seeds: it finishes, and no one on
	# the heroes' side drops through a gap where eclipse ground was, except after a hit since they last stood
	# (a knockback throws anyone over any pit, on the ground or in the air). Ordinary pits keep Swift's rules and are not counted.
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/index.json"))
	for id: String in index.levels:
		var level := Level.load_id(id)
		if level.eclipse_period <= 0:
			continue
		for lead in ["caelen", "seraphine", "nimue"]:
			for fights in [false, true]:
				for seed in [1, 2, 3]:
					w = World.from_level(level, lead, t, seed)
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
							if f.team != "hero":
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
