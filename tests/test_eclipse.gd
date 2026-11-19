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


static func _plat(x0: float, x1: float, top: float, eclipse := 0) -> Dictionary:
	return {"box": {"minX": x0, "minY": top - 40.0, "maxX": x1, "maxY": top}, "oneWay": false,
		"travel": {"x": 0.0, "y": 0.0}, "period": 0, "eclipse": eclipse}


## Floors with two gaps: the first bridged only in the light, the second only in shadow.
static func room(period := 240) -> Level:
	return Level.from_data({
		"name": "Eclipse test", "width": 2600.0, "start": {"x": 120.0, "y": 0.0},
		"platforms": [_plat(-200, 600, 0), _plat(600, 800, 0, 1), _plat(800, 1200, 0), _plat(1200, 1400, 0, -1),
			_plat(1400, 2600, 0)],
		"hazards": [], "levers": [], "plates": [], "gates": [], "checkpoints": [], "pickups": [], "enemies": [],
		"partner": null, "boss": null, "twin": null, "scenes": [], "exitX": 2400.0, "killY": -260.0,
		"eclipsePeriod": period, "eclipseWarning": 40})


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

	# The autopilot waits for the ground and crosses both bridges without falling, walking and fighting.
	for fights in [false, true]:
		for period in [240, 300, 360]:
			w = World.from_level(room(period), "caelen", t, 1)
			var pilot := Autopilot.new(fights)
			var fell := false
			for i in 60 * 60:
				if w.is_over or w.is_complete:
					break
				for e: Dictionary in w.step(pilot.input_for(w)):
					if e.case == "fell":
						fell = true
			check(w.is_complete and not fell, "autopilot (fights %s, period %d) crosses: complete %s, fell %s, x %.0f"
				% [fights, period, w.is_complete, fell, w.controlled().pos.x])

	print("eclipse: %d checks, %d failed" % [checks, failed])
	quit(1 if failed > 0 else 0)
