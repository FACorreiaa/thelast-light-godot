class_name GameScene
extends Node2D
## Draws the simulation and feeds it input. It never decides an outcome: it steps `World` at a fixed 60 Hz
## and reacts to the events that come back. Port of GameScene.swift.
##
## The three scenery layers are y-flipped (scale.y = -zoom), so everything under them is in the Swift scene's
## y-up units: positions, paths and rotations carry over unchanged. Render randomness has its own generator;
## world.rng belongs to the simulation.
##
## Command line (after `--`): --demo  --room  --level N  --lead caelen|seraphine|nimue  --snapshot DIR
## --frames N (quit after N rendered frames).

enum Mode { LEVEL, ROOM }

## Asks for the pause menu.
signal pause_requested
## A level was cleared: the results screen's numbers (see `_level_result`).
signal level_completed(result: Dictionary)


const GROUND_Y := 104.0
const CLEAR := Color(0, 0, 0, 0)

var demo := false
var mode := Mode.LEVEL
var world: World
var pilot := Autopilot.new()
var lead := "caelen"
var level_index := 0
var show_debug := false
var screen_shake := true
var story: StoryPresenter
var settings := Settings.new()
## The bot normally loops levels; with this it stops on the results screen like a player would.
var demo_shows_results := false
## Held still behind a menu. Time spent frozen is not simulated afterwards.
var frozen := false:
	set(v):
		frozen = v
		accumulator = 0.0
		# Keys held while a menu was open, and taps queued before it, do not count as new presses.
		if not v:
			input.poll()
		controls.take_presses()
		_pending = {}
		_pause_requested = false
		# Menus sit over a clean picture: no HUD, no on-screen buttons.
		hud.visible = not v
		controls.visible = not v

var far_layer := Node2D.new()
var mid_layer := Node2D.new()
var world_node := Node2D.new()
var overlay := CanvasLayer.new()
var screen := Control.new()
## The HUD and touch controls, in the Swift scene's points with y up.
var ui_layer := Node2D.new()
var controls := TouchControls.new()
var show_touch := false
var vignette := TextureRect.new()
## Darkens the room while the Last Oracle's dusk holds.
var dusk := ColorRect.new()
var hud := Hud.new()
var input := HardwareInput.new()
var nodes: Dictionary = {}  # id -> FighterNode

var accumulator := 0.0
var camera_x := 0.0
var camera_y := 0.0
var platform_nodes: Dictionary = {}  # platform index -> Node2D
## Each gate's lamps, one per lever or plate it needs, by gate id: [[input, SkShape], ...].
var gate_lamps: Dictionary = {}
var lever_nodes: Dictionary = {}  # lever id -> [handle Node2D, ring SkShape]
## Levers that are bells, rung in order: they swing while ringing instead of throwing over.
var bell_ids: Dictionary = {}
var bell_bodies: Dictionary = {}  # lever id -> SkShape
var plate_nodes: Dictionary = {}
## Each lamp's head and the light it throws, by lever id: [head, pool].
var lamp_nodes: Dictionary = {}
var hazard_nodes: Array[SkShape] = []
var checkpoint_nodes: Array[SkShape] = []
var pickup_nodes: Dictionary = {}
## Columns of light, reused frame to frame.
var strike_nodes: Array[SkShape] = []
var shake := 0.0
var run := 0
var kills := 0
var level_frames := 0
var downs := 0
var fx_rng := RandomNumberGenerator.new()

var _levels: Array[String] = []
var _snapshot_dir := ""
var _snapshot_clock := 0.0
var _snapshot_count := 0
var _frame_limit := -1
var _frames_drawn := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	demo = args.has("--demo")
	if args.has("--room"):
		mode = Mode.ROOM
	lead = _arg(args, "--lead", "caelen")
	_snapshot_dir = _arg(args, "--snapshot", "")
	_frame_limit = int(_arg(args, "--frames", "-1"))
	# The on-screen controls show on phones and tablets, or with --touch (the mouse acts as one finger).
	show_touch = (OS.has_feature("mobile") or args.has("--touch")) and not demo
	if story == null:
		story = StoryPresenter.new()
	# --lead and --level are for checking a route or a level without playing up to it.
	var saved := ConfigFile.new()
	saved.load(SaveDir.path("progress.cfg"))
	var saved_lead := String(saved.get_value("progress", "lead", "caelen"))
	lead = _arg(args, "--lead", "caelen" if demo else saved_lead)
	_levels = route(lead)
	var saved_level := _levels.find(String(saved.get_value("progress", "level", "")))
	var asked := _arg(args, "--level", "")
	level_index = clampi(int(asked) if asked != "" else (0 if demo else maxi(saved_level, 0)), 0, _levels.size() - 1)
	world = _make_world(1, -1, {})
	if mode == Mode.LEVEL:
		story.forget(_scene_ids())

	RenderingServer.set_default_clear_color(Palette.SKY)
	Sk.z(far_layer, -30)
	Sk.z(mid_layer, -20)
	add_child(far_layer)
	add_child(mid_layer)
	add_child(world_node)
	add_child(overlay)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(screen)
	vignette.texture = Effects.vignette_texture
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(vignette)
	dusk.color = Color.BLACK
	dusk.modulate.a = 0.0
	dusk.set_anchors_preset(Control.PRESET_FULL_RECT)
	dusk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(dusk)
	add_child(sound)
	# HUD text is drawn in points and scaled; rasterise it at the scaled size so it stays sharp.
	ui_layer.oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	overlay.add_child(ui_layer)
	ui_layer.add_child(hud)
	if show_touch:
		ui_layer.add_child(controls)
	else:
		# Never in the tree on desktop, so nothing else frees it (or the shapes and labels it built).
		tree_exited.connect(controls.free)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_build_scenery()
	_show_hint()
	var hero := world.controlled()
	if hero != null:
		camera_x = hero.pos.x


static func _arg(args: PackedStringArray, flag: String, fallback: String) -> String:
	var i := args.find(flag)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback


## The whole run as the lead plays it: every chapter's levels, in order.
static func route(p_lead: String) -> Array[String]:
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/index.json"))
	var out: Array[String] = []
	for c: Dictionary in index.chapters:
		for id: String in c.route[p_lead]:
			out.append(id)
	return out


func _make_world(seed: int, from_checkpoint: int, collected: Dictionary) -> World:
	var t := Tuning.load_default()
	t.hero_damage_scale = settings.damage_taken()
	if mode == Mode.ROOM:
		return World.partner_slice(seed, t)
	return World.from_level(Level.load_id(_levels[level_index]), lead, t, seed, from_checkpoint, collected)


## Points per pixel for the HUD: the Swift scene's size is in points, about 874 x 402 on a phone.
func _ui_scale() -> float:
	var size := get_viewport_rect().size
	return maxf(0.5, minf(size.y / 402.0, size.x / 700.0))


## The screen's safe area as (left, top, right, bottom) insets in points: clear of a notch or home bar.
func safe_insets() -> Rect2:
	var size := get_viewport_rect().size
	var ui := _ui_scale()
	var safe := Rect2(Vector2.ZERO, size)
	if OS.has_feature("mobile"):
		var area := DisplayServer.get_display_safe_area()
		safe = Rect2(area.position, area.size)
	return Rect2(safe.position.x / ui, safe.position.y / ui, (size.x - safe.end.x) / ui, (size.y - safe.end.y) / ui)


func _layout() -> void:
	var size := get_viewport_rect().size
	var ui := _ui_scale()
	ui_layer.position = Vector2(0, size.y)
	ui_layer.scale = Vector2(ui, -ui)
	var insets := safe_insets()
	hud.layout(size / ui, insets)
	controls.layout(size / ui, insets)


func _to_points(pixel: Vector2) -> Vector2:
	var ui := _ui_scale()
	return Vector2(pixel.x / ui, (get_viewport_rect().size.y - pixel.y) / ui)


func _input(event: InputEvent) -> void:
	# Behind a menu or a story panel the game takes no new touches; those belong to the panel. Lifting a
	# finger still counts, so a stick held when the menu opened does not stay held.
	var blocked := frozen or (story != null and story.is_active())
	if blocked and ((event is InputEventScreenTouch and event.pressed) or event is InputEventScreenDrag
			or (event is InputEventMouseButton and event.pressed) or event is InputEventMouseMotion):
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		_touch(t.index, t.pressed, _to_points(t.position))
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if show_touch:
			controls.moved(d.index, _to_points(d.position))
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and not OS.has_feature("mobile"):
		var m := event as InputEventMouseButton
		_touch(0, m.pressed, _to_points(m.position))
	elif event is InputEventMouseMotion and show_touch and not OS.has_feature("mobile"):
		controls.moved(0, _to_points((event as InputEventMouseMotion).position))


func _touch(index: int, pressed: bool, point: Vector2) -> void:
	if pressed:
		if hud.action_at(point) == Hud.Action.PAUSE:
			_pause_requested = true
		elif show_touch:
			controls.began(index, point)
	elif show_touch:
		controls.ended(index)


var _pause_requested := false
## Presses waiting for the next simulation step. A rendered frame can run no step (on a 120 Hz screen every
## other one does, since the simulation runs at 60), so a press is kept until a step takes it.
var _pending: Dictionary = {}


## World units are scaled so about the same slice of the level shows on a phone, a tablet and a Mac window.
## A boss room is seen from further back, so the boss fits under the bars at the top.
func _zoom() -> float:
	var size := get_viewport_rect().size
	var boss_room := mode == Mode.LEVEL and world.level != null and world.level.boss != null
	return maxf(0.5, minf(size.y / 402.0, size.x / 700.0)) * (0.7 if boss_room else 1.0)


static func v(p: Vec2) -> Vector2:
	return Vector2(p.x, p.y)


# MARK: Building


func _build_scenery() -> void:
	for layer: Node2D in [far_layer, mid_layer, world_node]:
		for c in layer.get_children():
			c.free()
	nodes = {}
	platform_nodes = {}
	gate_lamps = {}
	lever_nodes = {}
	bell_ids = {}
	bell_bodies = {}
	plate_nodes = {}
	lamp_nodes = {}
	hazard_nodes = []
	checkpoint_nodes = []
	pickup_nodes = {}
	strike_nodes = []
	_build_backdrop()
	Effects.ambient(mid_layer, far_layer, world.arena_hi - world.arena_lo)
	if world.level != null:
		_build(world.level)
	else:
		_build_room_floor()


## A gate and the levers and plates that open it share a colour, so the link reads at a glance.
func _puzzle_colour(input_id: int, level: Level) -> Color:
	var colours := [Palette.CYAN, Palette.GOLD, Palette.VIOLET, Palette.EMBER]
	var n := 0
	for i in level.gates.size():
		if level.gates[i].id == input_id or level.gates[i].opens_with.has(input_id):
			n = i
			break
	return colours[n % colours.size()]


func _shape(p: SkPath, fill := CLEAR, stroke := Color.WHITE, width := 1.0, glow := 0.0, z := 0.0, at := Vector2.ZERO) -> SkShape:
	var s := SkShape.make(p, fill, stroke, width, glow)
	s.position = at
	Sk.z(s, z)
	return s


func _build(level: Level) -> void:
	for i in world.platforms.size():
		var platform := world.platforms[i]
		var box := platform.box
		var w := box.max_x - box.min_x
		var h := box.max_y - box.min_y
		var node := Node2D.new()
		node.add_child(_shape(SkPath.rounded_rect(0, 0, w, h, 3.0 if platform.one_way else 0.0),
			Palette.MID if platform.one_way else Palette.FLOOR,
			Sk.with_alpha(Palette.CYAN, 0.25) if platform.one_way else CLEAR))
		# Eclipse ground (placeholder look): gold-edged in the light, violet-edged in shadow.
		var edge := Palette.GOLD if platform.moves() else Palette.CYAN
		if platform.eclipse != 0:
			edge = Palette.IVORY if platform.eclipse > 0 else Palette.VIOLET
		var edge_h := 2.0 if platform.eclipse == 0 else 4.0
		node.add_child(_shape(SkPath.rect(0, h - edge_h, w, edge_h),
			Sk.with_alpha(edge, 0.55 if platform.eclipse == 0 else 0.95), CLEAR, 1, 1))
		node.position = Vector2(box.min_x, box.min_y)
		Sk.z(node, -3 if platform.one_way else -5)
		world_node.add_child(node)
		platform_nodes[i] = node
	_build_puzzles(level)

	for hazard in level.hazards:
		var b := hazard.box
		var node := _shape(SkPath.rounded_rect(b.min_x, b.min_y, b.max_x - b.min_x, b.max_y - b.min_y, 4),
			Sk.with_alpha(Palette.RED, 0.55), Palette.EMBER, 2, 5, 4)
		world_node.add_child(node)
		hazard_nodes.append(node)
		# The emitters stay visible while the arc is off, so the danger can be read in advance.
		for y: float in [b.min_y, b.max_y]:
			world_node.add_child(_shape(SkPath.rounded_rect(b.min_x - 8, y - 4, b.max_x - b.min_x + 16, 8, 2),
				Palette.BODY, Sk.with_alpha(Palette.RED, 0.7), 1, 0, 5))

	for point in level.checkpoints:
		world_node.add_child(_shape(SkPath.rect(point.x - 2, point.y, 4, 70), Palette.MID, CLEAR, 1, 0, -2))
		var lamp := _shape(SkPath.circle(9), CLEAR, Color.WHITE, 2, 0, -2, Vector2(point.x, point.y + 78))
		world_node.add_child(lamp)
		checkpoint_nodes.append(lamp)

	for pickup in level.pickups:
		if world.collected.has(pickup.id):
			continue
		var shard := _shape(SkPath.rect_of(12, 12, 2), Palette.GOLD if pickup.secret else Palette.CYAN,
			Sk.with_alpha(Palette.WHITE, 0.8), 1, 4, 6, v(pickup.pos))
		shard.rotation = PI / 4.0
		var bob := shard.create_tween().set_loops()
		bob.tween_property(shard, "position:y", 6.0, 0.7).as_relative()
		bob.tween_property(shard, "position:y", -6.0, 0.7).as_relative()
		world_node.add_child(shard)
		pickup_nodes[pickup.id] = shard

	# A boss room has no way out until the boss falls.
	if level.boss != null:
		return
	world_node.add_child(_shape(SkPath.rounded_rect(level.exit_x, 0, 70, 170, 35), Sk.with_alpha(Palette.WHITE, 0.12),
		Palette.GOLD, 3, 8, -2))


func _build_puzzles(level: Level) -> void:
	for gate in level.gates:
		if not world.gate_platform.has(gate.id) or not platform_nodes.has(world.gate_platform[gate.id]):
			continue
		var node: Node2D = platform_nodes[world.gate_platform[gate.id]]
		for c in node.get_children():
			c.free()
		var colour := _puzzle_colour(gate.id, level)
		var w := gate.box.max_x - gate.box.min_x
		var h := gate.box.max_y - gate.box.min_y
		node.add_child(_shape(SkPath.rounded_rect(0, 0, w, h, 3), Palette.BODY, Sk.with_alpha(colour, 0.8), 2))
		var y := 24.0
		while y < h - 10.0:
			node.add_child(_shape(SkPath.rect(4, y, w - 8, 2), Sk.with_alpha(colour, 0.35), CLEAR))
			y += 28.0
		var lamps: Array = []
		for n in gate.opens_with.size():
			var lamp := _shape(SkPath.circle(4), CLEAR, Color.WHITE, 1.5, 0, 0, Vector2(w / 2.0, h - 14.0 - float(n) * 13.0))
			node.add_child(lamp)
			lamps.append([gate.opens_with[n], lamp])
		gate_lamps[gate.id] = lamps
		Sk.z(node, -1)
	for lever in level.levers:
		if not lever.glow > 0.0:
			continue
		world_node.add_child(_shape(SkPath.rect(lever.pos.x - 3, lever.pos.y, 6, 120), Palette.MID, CLEAR, 1, 0, -2))
		var head := _shape(SkPath.rounded_rect(-9, -12, 18, 24, 4), CLEAR, Color.WHITE, 2, 0, -1,
			Vector2(lever.pos.x, lever.pos.y + 128))
		world_node.add_child(head)
		var pool := _shape(SkPath.ellipse(-lever.glow, -130, lever.glow * 2.0, 260),
			Sk.with_alpha(Palette.EMBER, 0.12), CLEAR, 1, 0, -4, Vector2(lever.pos.x, lever.pos.y + 70))
		pool.material = Effects.additive
		world_node.add_child(pool)
		# The burn-down ring reads round the lamp's head.
		var ring := _shape(null, CLEAR, Palette.EMBER, 3, 3)
		head.add_child(ring)
		lever_nodes[lever.id] = [Node2D.new(), ring]
		lamp_nodes[lever.id] = [head, pool]
	var hours := ["I", "II", "III", "IV", "V", "VI"]
	for gate in level.gates:
		if not gate.in_order:
			continue
		var colour := _puzzle_colour(gate.id, level)
		for n in gate.opens_with.size():
			var id: int = gate.opens_with[n]
			var lever: Level.Lever = null
			for l in level.levers:
				if l.id == id:
					lever = l
					break
			if lever == null:
				continue
			bell_ids[id] = true
			var frame_node := Node2D.new()
			frame_node.position = v(lever.pos)
			Sk.z(frame_node, -1)
			world_node.add_child(frame_node)
			for x: float in [-24.0, 21.0]:
				frame_node.add_child(_shape(SkPath.rect(x, 0, 3, 96), Palette.MID, CLEAR))
			frame_node.add_child(_shape(SkPath.rounded_rect(-28, 94, 56, 5, 2), Palette.BODY, Sk.with_alpha(colour, 0.7)))
			# The bell's hour, plain above the beam: the order to ring them in.
			var hour := SkLabel.make(hours[mini(n, hours.size() - 1)], 15, colour, "demibold")
			hour.position = Vector2(0, 106)
			frame_node.add_child(hour)
			var bell := Node2D.new()
			bell.position = Vector2(0, 92)
			var shape := SkPath.new().move_to(Vector2(-6, 0)).line_to(Vector2(6, 0)) \
				.add_quad(Vector2(18, -40), Vector2(14, -6)).line_to(Vector2(-18, -40)) \
				.add_quad(Vector2(-6, 0), Vector2(-14, -6)).close()
			var body := _shape(shape, Palette.BODY, colour, 2)
			bell.add_child(body)
			bell.add_child(_shape(SkPath.circle(4), colour, CLEAR, 1, 0, 0, Vector2(0, -42)))
			frame_node.add_child(bell)
			var ring := _shape(null, CLEAR, colour, 3, 3, 0, Vector2(0, 72))
			frame_node.add_child(ring)
			lever_nodes[id] = [bell, ring]
			bell_bodies[id] = body
	for lever in level.levers:
		if lever.glow != 0.0 or bell_ids.has(lever.id):
			continue
		var colour := _puzzle_colour(lever.id, level)
		var base := _shape(SkPath.rounded_rect(-12, 0, 24, 10, 2), Palette.BODY, Sk.with_alpha(colour, 0.8), 1, 0, -1, v(lever.pos))
		world_node.add_child(base)
		var handle := Node2D.new()
		handle.position = Vector2(0, 8)
		handle.add_child(_shape(SkPath.rounded_rect(-2, 0, 4, 40, 2), Palette.STEEL, CLEAR))
		handle.add_child(_shape(SkPath.circle(6), colour, CLEAR, 1, 4, 0, Vector2(0, 42)))
		base.add_child(handle)
		# A timed lever shows its clock running down as a ring round the base.
		var ring := _shape(null, CLEAR, colour, 3, 3, 0, Vector2(0, 5))
		base.add_child(ring)
		lever_nodes[lever.id] = [handle, ring]
	for plate in level.plates:
		var node := _shape(SkPath.rounded_rect(plate.x0, plate.top - 2, plate.x1 - plate.x0, 6, 2), CLEAR,
			_puzzle_colour(plate.id, level), 2, 0, 2)
		world_node.add_child(node)
		plate_nodes[plate.id] = node


func _build_backdrop() -> void:
	var width := world.arena_hi - world.arena_lo
	# Far: tall cathedral windows glowing faintly.
	var x := -200.0
	while x < width + 400.0:
		far_layer.add_child(_shape(SkPath.rounded_rect(x, 60, 46, 300, 23), Palette.FAR, Sk.with_alpha(Palette.CYAN, 0.12), 2))
		x += 150.0
	# Mid: pillars and pipework.
	x = -100.0
	while x < width + 300.0:
		mid_layer.add_child(_shape(SkPath.rect(x, -10, 54, 520), Palette.MID, CLEAR))
		mid_layer.add_child(_shape(SkPath.rect(x + 25, 40, 3, 150), Sk.with_alpha(Palette.CYAN, 0.35), CLEAR, 1, 2))
		x += 310.0


func _build_room_floor() -> void:
	var lo := world.arena_lo
	var width := world.arena_hi - lo
	world_node.add_child(_shape(SkPath.rect(lo - 600, -300, width + 1200, 300), Palette.FLOOR, CLEAR, 1, 0, -5))
	world_node.add_child(_shape(SkPath.rect(lo - 600, -2, width + 1200, 2), Sk.with_alpha(Palette.CYAN, 0.5), CLEAR, 1, 1, -4))
	for bound: float in [lo, world.arena_hi]:
		world_node.add_child(_shape(SkPath.rect(bound - 2, 0, 4, 420), Sk.with_alpha(Palette.CYAN, 0.25), CLEAR, 1, 3, -4))


# MARK: Loop


func _process(delta: float) -> void:
	accumulator += minf(delta, 0.1)
	if frozen:
		_draw_frame()
		_after_frame(delta)
		return
	var reading := input.poll()
	if (reading.pause or _pause_requested) and not story.is_active():
		_pause_requested = false
		pause_requested.emit()
		return
	# While someone is speaking the game holds still. Attack or jump moves the scene on.
	if story.is_active():
		if reading.attack or reading.jump:
			story.advance()
		controls.take_presses()
		_pending = {}
		accumulator = 0.0
		_draw_frame()
		_after_frame(delta)
		return
	if reading.mode:
		_toggle_mode()
	if reading.debug:
		show_debug = not show_debug
	if reading.restart:
		_restart(true)
	elif world.is_over and (reading.attack or reading.jump or demo):
		_restart(false)

	var presses := controls.take_presses()
	if world.is_over and not presses.is_empty() and not reading.restart:
		_restart(false)
		presses = {}
	if reading.restart:
		_pending = {}
	for pad: int in presses:
		_pending[pad] = true
	for pair: Array in [[reading.jump, TouchControls.Pad.JUMP], [reading.attack, TouchControls.Pad.ATTACK],
			[reading.dodge, TouchControls.Pad.DODGE], [reading.special, TouchControls.Pad.SPECIAL],
			[reading.switch_hero, TouchControls.Pad.SWITCH_HERO]]:
		if pair[0]:
			_pending[pair[1]] = true
	var inp := InputFrame.make(reading.move_x if reading.move_x != 0.0 else controls.move_x,
		_pending.has(TouchControls.Pad.JUMP), reading.jump_held or controls.jump_held,
		_pending.has(TouchControls.Pad.ATTACK), _pending.has(TouchControls.Pad.DODGE),
		_pending.has(TouchControls.Pad.SPECIAL), _pending.has(TouchControls.Pad.SWITCH_HERO))
	var step := 1.0 / Tuning.FRAMES_PER_SECOND
	var steps := 0
	while accumulator >= step and steps < 4 and not story.is_active():
		var frame_input := inp if not demo else (pilot.input_for(world) if mode == Mode.LEVEL else DemoBot.input_for(world))
		if mode == Mode.LEVEL and not world.is_over:
			level_frames += 1
		_react(world.step(frame_input))
		# A press belongs to one simulation frame only.
		inp = InputFrame.make(inp.move_x, false, inp.jump_held, false, false, false, false)
		_pending = {}
		accumulator -= step
		steps += 1
	if steps == 4:
		accumulator = 0.0
	sound.advance()
	_draw_frame()
	_after_frame(delta)


func _after_frame(delta: float) -> void:
	_frames_drawn += 1
	if _snapshot_dir != "":
		_snapshot_clock += delta
		if _snapshot_clock >= 2.0:
			_snapshot_clock = 0.0
			_snapshot_count += 1
			DirAccess.make_dir_recursive_absolute(_snapshot_dir)
			var img := get_viewport().get_texture().get_image()
			img.save_png(_snapshot_dir.path_join("shot%03d.png" % _snapshot_count))
	if _frame_limit >= 0 and _frames_drawn >= _frame_limit:
		get_tree().quit(0)


func _draw_frame() -> void:
	var seen := {}
	for f in world.fighters:
		seen[f.id] = true
		var node: FighterNode = nodes.get(f.id)
		if node == null:
			node = FighterNode.new(f.kind)
			Sk.z(node, 10 if f.team == "hero" else 5)
			world_node.add_child(node)
			nodes[f.id] = node
		node.sync(f, world.frame, f.id == world.controlled_id, f.team == "enemy" and world.is_warded(f.id))
		# A companion that has not joined yet stands dark.
		if f.team == "hero" and not f.awake:
			node.modulate.a = 0.4
		else:
			node.modulate.a = 1.0
	for id: int in nodes.keys():
		if not seen.has(id):
			var gone: FighterNode = nodes[id]
			if is_instance_valid(gone):
				gone.queue_free()
			nodes.erase(id)

	var size := get_viewport_rect().size
	var zoom := _zoom()
	var hero := world.controlled()
	if hero != null:
		var half := size.x / zoom / 2.0
		var low := world.arena_lo + half - 60.0
		var high := world.arena_hi - half + 60.0
		var target := minf(maxf(hero.pos.x + hero.facing * 40.0, low), maxf(low, high))
		camera_x += (target - camera_x) * 0.12
		# The camera only climbs once the hero is well off the floor, and never chases a fall into a pit.
		var lift := maxf(-40.0, hero.pos.y - 70.0)
		# Rise with a boss that takes to the air, so it stays in view.
		var boss := world.boss()
		if boss != null and boss.is_alive() and not boss.on_ground:
			lift = maxf(lift, 60.0)
		camera_y += (lift - camera_y) * 0.08
		var partner: Fighter = null
		for f in world.fighters:
			if f.team == "hero" and f.id != hero.id and f.awake and not f.spec.is_decoy:
				partner = f
				break
		var sp := hero.spec.special
		hud.set_special([special_name(sp), hero.special_cooldown] if not sp.is_empty() else [])
		controls.set_special(not sp.is_empty() and hero.special_cooldown == 0)
		hud.set_heroes([hero.kind.to_upper(), hero.hp / hero.spec.max_hp],
			[partner.kind.to_upper(), partner.hp / partner.spec.max_hp] if partner != null else [])
	_draw_level()
	# The Oracle's dusk darkens the room; in the ending it lifts halfway.
	var dusk_target := 0.0
	var b := world.boss()
	if b != null and b.kind == "lastOracle" and b.is_alive():
		dusk_target = 0.4 if b.phase == 2 else (0.18 if b.phase >= 3 else 0.0)
	dusk.modulate.a += (dusk_target - dusk.modulate.a) * 0.04
	if b != null and b.awake and b.is_alive():
		var title := boss_title(b.kind)
		var phases: Array = title[1]
		var phase := " · " + String(phases[mini(b.phase - 2, phases.size() - 1)]) if b.phase >= 2 else ""
		var twin := world.twin()
		if twin != null:
			# A sworn pair: one bar each; the name says when one is down and about to be raised.
			var rising := " · RISING" if world.vow_frames > 0 else ""
			hud.set_boss([title[0] + rising, b.hp / b.spec.max_hp, _open(b)], [twin.hp / twin.spec.max_hp, _open(twin)])
		else:
			hud.set_boss([title[0] + phase, b.hp / b.spec.max_hp, b.is_open() and not b.is_guarding() and not world.is_warded(b.id)])
	elif world.twin() != null and world.twin().awake and world.twin().is_alive():
		var twin := world.twin()
		hud.set_boss([boss_title(twin.kind)[0] + (" · RISING" if world.vow_frames > 0 else ""), 0.0, false],
			[twin.hp / twin.spec.max_hp, twin.is_open()])
	else:
		hud.set_boss([])

	shake *= 0.86
	var jolt := Vector2.ZERO
	if shake >= 0.3 and screen_shake:
		jolt = Vector2(fx_rng.randf_range(-shake, shake), fx_rng.randf_range(-shake, shake))
	for layer_def: Array in [[world_node, 1.0, 0.0], [mid_layer, 0.55, 20.0], [far_layer, 0.25, 10.0]]:
		var layer: Node2D = layer_def[0]
		var depth: float = layer_def[1]
		var drop: float = layer_def[2]
		var px := size.x / 2.0 - (camera_x * depth + (0.0 if depth == 1.0 else size.x / zoom / 2.0)) * zoom + jolt.x * depth
		var py := (GROUND_Y - drop - camera_y * depth) * zoom + jolt.y * depth
		layer.position = Vector2(px, size.y - py)
		layer.scale = Vector2(zoom, -zoom)

	if world.level != null:
		hud.set_status("%s   ◆ %d/%d" % [world.level.name.to_upper(), world.collected.size(), world.level.pickups.size()])
	else:
		hud.set_status("TRAINING" if world.wave_number == 0 else "WAVE %d   KILLS %d" % [world.wave_number, kills])
	hud.set_debug(_debug_text() if show_debug else "")


static func _open(f: Fighter) -> bool:
	return f.is_alive() and f.is_open() and not f.is_guarding()


static func special_name(sp: Dictionary) -> String:
	return {"command": "COMMAND", "adapt": "ADAPT", "heal": "LIGHT LISTENS", "decoy": "LANTERN TRICK"}.get(sp.get("case", ""), "")


func _debug_text() -> String:
	var f := world.controlled()
	if f == null:
		return ""
	var ground := ("ground" + (" #%d" % f.ground_index if f.ground_index >= 0 else "")) if f.on_ground else "air"
	var text := "pos %6.0f %5.0f\nvel %6.0f %5.0f\n%s  coyote %d\n%s f%d\nhitstop %d  frame %d" % [
		f.pos.x, f.pos.y, f.vel.x, f.vel.y, ground, f.coyote, str(f.state_canon()), f.state_frame, world.hit_stop, world.frame]
	var b := world.boss()
	if b != null:
		text += "\nboss %.0f p%d  %s f%d  %s" % [b.hp, b.phase, str(b.state_canon()), b.state_frame, "open" if b.is_open() else "armoured"]
	return text


func _draw_level() -> void:
	var level := world.level
	if level == null:
		return
	_draw_strikes()
	_draw_puzzles(level)
	for i: int in platform_nodes.keys():
		var p := world.platforms[i]
		if p.eclipse != 0:
			_draw_eclipse_ground(i, p, level)
		elif p.moves():
			var box := world.platform_boxes[i]
			platform_nodes[i].position = Vector2(box.min_x, box.min_y)
	for i in level.hazards.size():
		var hazard := level.hazards[i]
		var node := hazard_nodes[i]
		if hazard.is_on(world.frame):
			node.alpha = 1.0 if world.frame % 6 < 3 else 0.75
		elif hazard.is_warning(world.frame):
			node.alpha = 0.35 if world.frame % 10 < 5 else 0.1
		else:
			node.alpha = 0.04
	for i in checkpoint_nodes.size():
		var lit := i <= world.checkpoint_index
		var lamp := checkpoint_nodes[i]
		lamp.fill_color = Palette.CYAN if lit else Palette.BODY
		lamp.stroke_color = Sk.with_alpha(Palette.CYAN, 1.0 if lit else 0.35)
		lamp.glow_width = 6.0 if lit else 0.0


## Eclipse ground that is not there shows as a faint outline where it will form; ground about to go flickers.
func _draw_eclipse_ground(i: int, p: Level.Platform, level: Level) -> void:
	var node: Node2D = platform_nodes[i]
	var box := p.box_at(world.frame)
	node.position = Vector2(box.min_x, box.min_y)
	var there := world.platform_boxes[i].min_y > -50000.0
	if not there:
		node.modulate.a = 0.3
	elif level.frames_to_eclipse_swap(world.frame) <= level.eclipse_warning:
		node.modulate.a = 1.0 if world.frame % 8 < 4 else 0.45
	else:
		node.modulate.a = 1.0


func _draw_puzzles(level: Level) -> void:
	for gate in level.gates:
		if world.gate_platform.has(gate.id) and platform_nodes.has(world.gate_platform[gate.id]):
			var box := world.platform_boxes[world.gate_platform[gate.id]]
			platform_nodes[world.gate_platform[gate.id]].position = Vector2(box.min_x, box.min_y)
		var colour := _puzzle_colour(gate.id, level)
		for pair: Array in gate_lamps.get(gate.id, []):
			var on := world.signals.has(pair[0])
			var lamp: SkShape = pair[1]
			lamp.fill_color = colour if on else Palette.BODY
			lamp.stroke_color = Sk.with_alpha(colour, 1.0 if on else 0.5)
			lamp.glow_width = 4.0 if on else 0.0
	for lever in level.levers:
		if not lever_nodes.has(lever.id):
			continue
		var handle: Node2D = lever_nodes[lever.id][0]
		var ring: SkShape = lever_nodes[lever.id][1]
		var on := world.signals.has(lever.id)
		if bell_ids.has(lever.id):
			# A ringing bell swings and glows; a silent one hangs still and dark.
			var swing := 0.32 * sin(float(world.frame) * 0.16) if on else 0.0
			handle.rotation += (swing - handle.rotation) * 0.25
			var body: SkShape = bell_bodies[lever.id]
			body.fill_color = _puzzle_colour(lever.id, level) if on else Palette.BODY
			body.glow_width = 3.0 if on else 0.0
		else:
			var target := -0.6 if on else 0.6
			handle.rotation += (target - handle.rotation) * 0.3
		if world.lever_timers.has(lever.id) and lever.hold_frames > 0:
			var left: int = world.lever_timers[lever.id]
			var t := float(left) / float(lever.hold_frames)
			# CGPath dashing [113 t, 200] round a radius-18 circle: the first t of the way round.
			ring.path = SkPath.new().add_arc(Vector2.ZERO, 18, 0.0, minf(TAU, 113.0 * t / 18.0), false) if t > 0.0 else null
			ring.visible = true
			# The last second flickers.
			@warning_ignore("integer_division")
			ring.alpha = 0.3 if left < 60 and (left / 5) % 2 == 0 else 1.0
		else:
			ring.visible = false
	for id: int in lamp_nodes.keys():
		var on := world.signals.has(id)
		var head: SkShape = lamp_nodes[id][0]
		var pool: SkShape = lamp_nodes[id][1]
		head.fill_color = Palette.EMBER if on else Palette.BODY
		head.stroke_color = Sk.with_alpha(Palette.EMBER, 1.0 if on else 0.4)
		head.glow_width = 8.0 if on else 0.0
		pool.visible = on
		pool.alpha = 0.9 + 0.1 * sin(float(world.frame) * 0.2)
	for plate in level.plates:
		if not plate_nodes.has(plate.id):
			continue
		var node: SkShape = plate_nodes[plate.id]
		var down := world.signals.has(plate.id)
		var colour := _puzzle_colour(plate.id, level)
		node.fill_color = colour if down else Sk.with_alpha(colour, 0.15)
		node.glow_width = 5.0 if down else 0.0


## Faint and widening while a column warns, white-hot while it burns.
func _draw_strikes() -> void:
	while strike_nodes.size() < world.strikes.size():
		var node := SkShape.new()
		Sk.z(node, 8)
		node.line_width = 2
		world_node.add_child(node)
		strike_nodes.append(node)
	for i in strike_nodes.size():
		var node := strike_nodes[i]
		if i >= world.strikes.size():
			node.visible = false
			continue
		var s := world.strikes[i]
		node.visible = true
		if s.kind != "light":
			_draw_ground_strike(node, s)
			continue
		node.path = SkPath.rect(s.box.min_x, -20, s.box.width(), 620)
		if s.is_active():
			node.fill_color = Sk.with_alpha(Palette.WHITE, 0.85)
			node.stroke_color = Palette.RED
			node.glow_width = 12
		else:
			var t := float(s.age) / float(maxi(s.warning, 1))
			@warning_ignore("integer_division")
			var blink := s.warning - s.age <= 14 and (s.age / 3) % 2 == 0
			node.fill_color = Sk.with_alpha(Palette.RED, 0.4 if blink else 0.06 + 0.2 * t)
			node.stroke_color = Sk.with_alpha(Palette.RED, 0.3 + 0.6 * t)
			node.glow_width = 0


## A burning patch or a snare on the ground: an outline while it warns, then lit while it is live.
func _draw_ground_strike(node: SkShape, s: Strike) -> void:
	var color := Palette.EMBER if s.kind == "fire" else Palette.VIOLET
	var x0 := s.box.min_x
	var y0 := s.box.min_y + 4.0
	var w := s.box.width()
	var h := s.box.max_y - s.box.min_y - 4.0
	if (s.kind == "fire" or s.kind == "dark") and s.is_active():
		# Flames: a jagged top that moves.
		var p := SkPath.new().move_to(Vector2(x0, y0))
		var peaks := maxi(3, int(w / 14.0))
		for n in peaks + 1:
			var x := x0 + w * float(n) / float(peaks)
			var flicker := sin(float(s.age + n * 7) * 0.5) * 0.35 + 0.65
			p.line_to(Vector2(x, y0 + h * (flicker if n % 2 == 0 else flicker * 0.45)))
		p.line_to(Vector2(x0 + w, y0)).close()
		node.path = p
		# The Oracle's dark is a black flame edged in violet.
		node.fill_color = Sk.with_alpha(Palette.BODY, 0.92) if s.kind == "dark" else Sk.with_alpha(color, 0.7)
		node.stroke_color = Palette.VIOLET if s.kind == "dark" else Palette.GOLD
		node.glow_width = 8
	elif s.kind == "snare" and s.is_active():
		# Threads pinned to the ground.
		var p := SkPath.new()
		var strands := 4
		for n in strands + 1:
			var x := x0 + w * float(n) / float(strands)
			p.move_to(Vector2(x, y0)).line_to(Vector2(x0 + w / 2.0, y0 + h))
		p.move_to(Vector2(x0, y0 + 2)).line_to(Vector2(x0 + w, y0 + 2))
		node.path = p
		node.fill_color = CLEAR
		node.stroke_color = Sk.with_alpha(color, 0.85)
		node.glow_width = 3
	else:
		var t := float(s.age) / float(maxi(s.warning, 1))
		@warning_ignore("integer_division")
		var blink := s.warning - s.age <= 14 and (s.age / 3) % 2 == 0
		node.path = SkPath.rounded_rect(x0, y0, w, 6, 3)
		node.fill_color = Sk.with_alpha(color, 0.6 if blink else 0.1 + 0.3 * t)
		node.stroke_color = Sk.with_alpha(color, 0.4 + 0.5 * t)
		node.glow_width = 0


# MARK: Restarting


## A retry after falling in battle resumes from the last checkpoint; anything else starts over.
func _restart(fresh: bool) -> void:
	run += 1
	var seed := run + 1
	if mode == Mode.ROOM:
		kills = 0
		world = _make_world(seed, -1, {})
	else:
		# Clearing a level moves on to the next one; the last one loops back to the first.
		if not fresh and world.is_complete:
			level_index = (level_index + 1) % _levels.size()
		var resume := not fresh and world.level != null and not world.is_complete
		if not resume:
			kills = 0
			level_frames = 0
			downs = 0
		world = _make_world(seed, world.checkpoint_index if resume else -1, world.collected.duplicate() if resume else {})
		pilot = Autopilot.new()
		# A level started over plays its scenes again; a retry from a checkpoint does not.
		if not resume:
			story.forget(_scene_ids())
		_save_progress()
	for node: FighterNode in nodes.values():
		if is_instance_valid(node):
			node.queue_free()
	nodes = {}
	hud.hide_message()
	_build_scenery()
	var hero := world.controlled()
	if hero != null:
		camera_x = hero.pos.x
		camera_y = maxf(-40.0, hero.pos.y - 70.0)
	if mode == Mode.LEVEL and world.checkpoint_index < 0:
		hud.announce(world.level.name.to_upper())


# MARK: Menus


func _scene_ids() -> Array:
	return world.level.scenes.map(func(t: Level.SceneTrigger) -> String: return t.scene) if world.level != null else []


## The saved place: the lead and the level by id, so adding a chapter never moves it.
func _save_progress() -> void:
	if demo:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "lead", lead)
	cfg.set_value("progress", "level", _levels[level_index])
	cfg.save(SaveDir.path("progress.cfg"))


func current_level() -> int:
	return level_index


func level_names() -> Array[String]:
	var out: Array[String] = []
	for id in _levels:
		out.append(Level.load_id(id).name)
	return out


## Each chapter with the run index of its first level and its level names:
## [{id, number, title, ending, start, names}], for the chapter list.
func chapter_list() -> Array:
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/index.json"))
	var out: Array = []
	var start := 0
	for c: Dictionary in index.chapters:
		var names: Array[String] = []
		for id: String in c.route[lead]:
			names.append(Level.load_id(id).name)
		out.append({"id": c.id, "number": int(c.number), "title": c.title, "ending": c.ending, "start": start, "names": names})
		start += names.size()
	return out


## The chapter the level at `index` belongs to, with where it starts in the run.
func chapter_at(index: int) -> Dictionary:
	var list := chapter_list()
	for c: Dictionary in list:
		if index < int(c.start) + (c.names as Array).size():
			return c
	return list[-1]


## What the results screen shows after a level (LevelResult.swift).
func _level_result() -> Dictionary:
	var c := chapter_at(level_index)
	var ends_chapter := level_index + 1 == int(c.start) + (c.names as Array).size()
	return {"name": world.level.name, "index": level_index, "chapter_number": c.number, "chapter_title": c.title,
		"ending": c.ending if ends_chapter else "", "chapter_start": c.start, "is_final": level_index + 1 == _levels.size(),
		"seconds": float(level_frames) / Tuning.FRAMES_PER_SECOND, "defeated": kills, "downs": downs,
		"found": world.collected.size(), "hidden": world.level.pickups.size()}


func apply_settings(p_settings: Settings) -> void:
	settings = p_settings.copy()
	sound.volume = settings.volume
	haptics.enabled = settings.haptics
	screen_shake = settings.screen_shake
	show_debug = settings.debug_overlay


## A new run as this faction's lead, from their opening.
func begin_as(p_lead: String) -> void:
	lead = p_lead
	_levels = route(lead)
	play_level(0)


func play_level(index: int) -> void:
	mode = Mode.LEVEL
	level_index = clampi(index, 0, _levels.size() - 1)
	_restart(true)
	_show_hint()


func play_training_room() -> void:
	mode = Mode.ROOM
	_restart(true)
	_show_hint()
	hud.announce("TRAINING ROOM")


## Back to the last checkpoint, as after a fall in battle.
func retry() -> void:
	_restart(world.is_complete)


## From the results screen: the next level.
func advance() -> void:
	_restart(false)


func restart_level() -> void:
	_restart(true)


## Steps through every level and then the training room.
func _toggle_mode() -> void:
	if mode == Mode.ROOM:
		mode = Mode.LEVEL
		level_index = 0
	elif level_index + 1 < _levels.size():
		level_index += 1
	else:
		mode = Mode.ROOM
	_restart(true)
	_show_hint()
	if mode == Mode.ROOM:
		hud.announce("TRAINING ROOM")


func _show_hint() -> void:
	if demo:
		hud.show_hint("DEMO")
	elif OS.has_feature("mobile"):
		hud.show_hint("Reach the gate.  Dodge passes through arcs.  ⇄ switches hero." if mode == Mode.LEVEL
			else "Parry: attack just as the red flash comes.  Dodge passes through.  ⇄ switches hero.")
	else:
		hud.show_hint("A/D move   Space jump   J attack   K dodge   I special   L switch   R restart   Esc pause")


## What the screen calls each boss, its phases after the first, and the tip shown when it wakes.
static func boss_title(kind: String) -> Array:
	match kind:
		"cinderKing":
			return ["THE CINDER KING", ["THE DEBT", "THE PRICE"], "Step out of the fire.  While his Ratborn live, he can't be hurt."]
		"lamplighter":
			return ["THE LAMPLIGHTER", ["LIGHTS OUT"], "Nothing touches him in the dark.  Strike a lamp, then strike him in its light."]
		"swornShield", "swornSpear":
			return ["THE SWORN", ["RISING"], "If one falls alone, the other raises it.  Bring them down together."]
		"lineWarden":
			return ["THE LINE WARDEN", ["OVERDRIVE"], "Its guard faces forward.  Get behind it, or parry to break its stance."]
		"lastOracle":
			return ["THE LAST ORACLE", ["THE DUSK", "THE ENDING"], "Gold light: look away.  Dark light: face her."]
	return ["THE PROTOCOL", ["ASCENSION", "EXECUTION"], "Strike only when the core opens.  Jump the surge.  Dodge the charge."]


# MARK: Events


func _react(events: Array) -> void:
	for e: Dictionary in events:
		var c: String = e["case"]
		match c:
			"hit":
				var target: int = e["target"]
				var damage: float = e["damage"]
				if nodes.has(target):
					nodes[target].flash()
				var tf := world.fighter(target)
				var hero_hurt := tf != null and tf.team == "hero"
				_sparks(e["at"], Palette.RED if hero_hurt else Palette.CYAN, 10 if hero_hurt else int(4.0 + damage / 3.0))
				sound.play("hurt" if hero_hurt else ("heavyHit" if damage >= 20.0 else "hit"))
				if hero_hurt:
					shake = maxf(shake, 9)
					haptics.heavy()
					hud.flash_damage()
				else:
					shake = maxf(shake, 6.0 if damage >= 20.0 else 2.0)
					haptics.light(1.0 if damage >= 20.0 else 0.6)
			"blocked":
				_sparks(e["at"], Palette.STEEL, 4)
				_popup("BLOCKED", e["at"], Palette.STEEL, 13)
				sound.play("blocked")
				haptics.rigid(0.5)
			"parried":
				Effects.flash(screen, Palette.WHITE, 0.14)
				_ring(e["at"], 70, Palette.WHITE)
				_sparks(e["at"], Palette.WHITE, 14)
				_popup("PARRY", e["at"], Palette.CYAN, 20)
				sound.play("parry")
				_flash_node(e["attacker"])
				shake = maxf(shake, 5)
				haptics.rigid()
			"exploded":
				var at: Vec2 = e["at"]
				_ring(at, e["radius"], Palette.EMBER)
				Effects.explosion(world_node, v(at), e["radius"])
				sound.play("explosion")
				shake = maxf(shake, 10)
				if nodes.has(e["id"]):
					nodes[e["id"]].vanish()
				haptics.heavy()
			"fuseLit":
				sound.play("fuse")
				var f := world.fighter(e["id"])
				if f != null:
					_popup("!", Vec2.new(f.pos.x, f.pos.y + 60.0), Palette.RED, 22)
			"died":
				var f := world.fighter(e["id"])
				if f != null and f.team == "enemy":
					kills += 1
					# A drone that exploded is already gone; the boss has its own ending.
					var node: FighterNode = nodes.get(f.id)
					if node != null and not node.gone and not f.spec.boss:
						Effects.break_apart(world_node, Vector2(f.pos.x, f.pos.y + f.spec.height / 2.0), f.spec.height)
			"waveStarted":
				hud.announce("WAVE %d" % int(e["number"]))
			"waveCleared":
				hud.announce("CLEAR")
			"controlChanged":
				var f := world.fighter(e["id"])
				if f != null:
					_ring(_mid(f), 60, Palette.CYAN)
				haptics.light()
			"revived":
				var f := world.fighter(e["id"])
				if f != null:
					_ring(_mid(f), 80, Palette.WHITE)
					_popup("BACK UP", _top(f), Palette.CYAN, 14)
			"heroDown":
				sound.play("down")
				downs += 1
				hud.show_message("DOWN" if demo else "DOWN\ntap to try again")
			"fell":
				sound.play("fall")
				shake = maxf(shake, 8)
				haptics.heavy()
				hud.flash_damage()
			"respawned":
				var f := world.fighter(e["id"])
				if f != null:
					_ring(_mid(f), 60, Palette.WHITE)
			"checkpoint":
				var cp := world.level.checkpoints[int(e["index"])]
				Effects.motes(world_node, Vector2(cp.x, cp.y + 20.0), Palette.CYAN, 26, 40)
				_ring(Vec2.new(cp.x, cp.y + 78.0), 50, Palette.CYAN)
				_popup("CHECKPOINT", Vec2.new(cp.x, cp.y + 90.0), Palette.CYAN, 13)
				sound.play("checkpoint")
				haptics.light()
			"collected":
				var secret: bool = e["secret"]
				var at: Vec2 = e["at"]
				var colour := Palette.GOLD if secret else Palette.CYAN
				Effects.motes(world_node, v(at), colour)
				if pickup_nodes.has(e["id"]):
					pickup_nodes[e["id"]].queue_free()
					pickup_nodes.erase(e["id"])
				_sparks(at, colour, 8)
				if secret:
					_popup("SECRET", at, Palette.GOLD, 14)
				sound.play("secret" if secret else "pickup")
				haptics.light(0.7)
			"woke":
				if e["id"] == world.boss_id:
					var boss := world.boss()
					var title := boss_title(boss.kind if boss != null else "theProtocol")
					hud.announce(title[0])
					sound.play("bossWake")
					hud.show_hint(title[2])
					shake = maxf(shake, 10)
					haptics.heavy()
				else:
					var f := world.fighter(e["id"])
					if f != null:
						_popup("!", _top(f), Palette.RED, 16)
			"joined":
				var f := world.fighter(e["id"])
				sound.play("join")
				if f != null:
					Effects.motes(world_node, v(f.pos), Palette.CYAN, 22, 30)
					_ring(_mid(f), 90, Palette.CYAN)
					_popup("%s JOINS" % f.kind.to_upper(), _top(f), Palette.CYAN, 16)
				haptics.rigid()
			"bossDefeated":
				Effects.flash(screen, Palette.WHITE, 0.4, 0.6)
				var f := world.fighter(e["id"])
				if f != null:
					Effects.explosion(world_node, v(_mid(f)), 140)
					Effects.break_apart(world_node, v(_mid(f)), f.spec.height)
				# The other of a sworn pair, already down, goes with it.
				var other := world.fighter(world.sworn_partner(e["id"]))
				if other != null:
					Effects.break_apart(world_node, v(_mid(other)), other.spec.height)
					_sparks(_mid(other), Palette.GOLD, 20)
				if f != null:
					_sparks(_mid(f), Palette.GOLD, 30)
					_ring(_mid(f), 220, Palette.GOLD)
					_ring(_mid(f), 120, Palette.WHITE)
				shake = maxf(shake, 16)
				sound.play("bossDown")
				haptics.heavy()
			"regrouped":
				_ring(e["at"], 50, Palette.CYAN)
			"levelComplete":
				sound.play("clear")
				haptics.rigid()
				var total := world.level.pickups.size() if world.level != null else 0
				var next := "tap to continue" if level_index + 1 < _levels.size() else "tap to start over"
				if (demo and not demo_shows_results) or level_completed.get_connections().is_empty():
					hud.show_message("CLEAR" if demo else "CLEAR   ◆ %d/%d\n%s" % [world.collected.size(), total, next])
				else:
					level_completed.emit(_level_result())
			"swing":
				var id: int = e["id"]
				if id == world.boss_id:
					sound.play("warning")
				else:
					var f := world.fighter(id)
					if f != null:
						var heavy: bool = f.team == "enemy" or int(e["index"]) == f.spec.attacks.size() - 1
						sound.play("heavySwing" if heavy else "swing", 1.0 if f.id == world.controlled_id else 0.5)
			"jumped":
				_dust(e["id"], 6)
				if e["id"] == world.controlled_id:
					sound.play("jump")
			"landed":
				_dust(e["id"], 10, 34)
				if e["id"] == world.controlled_id:
					sound.play("land")
			"dodged":
				_dust(e["id"], 9, 40)
				sound.play("dodge", 1.0 if e["id"] == world.controlled_id else 0.5)
			"commanded":
				var f := world.fighter(e["target"])
				if f != null:
					_ring(_mid(f), 80, Palette.GOLD)
					_popup("MARKED", _top(f), Palette.GOLD, 14)
				sound.play("checkpoint")
				haptics.rigid(0.7)
			"guarded":
				var f := world.fighter(e["id"])
				if f != null:
					_ring(_mid(f), 46, Palette.CYAN)
				sound.play("dodge")
			"absorbed":
				Effects.flash(screen, Palette.CYAN, 0.12)
				_ring(e["at"], 80, Palette.CYAN)
				_sparks(e["at"], Palette.CYAN, 14)
				_popup("ADAPT", e["at"], Palette.CYAN, 20)
				_flash_node(e["attacker"])
				shake = maxf(shake, 5)
				sound.play("parry")
				haptics.rigid()
			"slowed":
				var f := world.fighter(e["id"])
				if f != null:
					_popup("SLOWED", _top(f), Palette.EMBER, 14)
			"scene":
				# The demo bot does not read.
				if not demo:
					story.begin(e["id"])
			"flared", "eclipsed":
				var colour := Palette.GOLD if c == "flared" else Palette.VIOLET
				_ring(e["at"], e["radius"], colour)
				Effects.burst(world_node, v(e["at"]), colour, 26, 260, 0.35, 10)
				sound.play("bossWake", 0.35)
			"lever":
				var id: int = e["id"]
				var on: bool = e["on"]
				for lever in world.level.levers:
					if lever.id == id:
						# A lamp sparks at its head; a bell at its mouth; a lever at its knob.
						var y := 128.0 if lever.glow > 0.0 else (52.0 if bell_ids.has(id) else 44.0)
						_sparks(Vec2.new(lever.pos.x, lever.pos.y + y), Palette.GOLD if on else Palette.STEEL, 10 if on else 4)
						break
				sound.play("checkpoint" if on else "blocked", 0.6 if on else 0.4)
				if on:
					haptics.rigid(0.6)
			"plate":
				sound.play("blocked", 0.5 if e["down"] else 0.3)
			"gate":
				if world.gate_platform.has(e["id"]):
					var box := world.platform_boxes[world.gate_platform[e["id"]]]
					Effects.dust(world_node, Vector2(box.center().x, box.min_y), 5, 20)
				shake = maxf(shake, 3.0 if e["opening"] else 2.0)
				sound.play("heavyHit", 0.35)
			"eclipse":
				# The light and shadow swap: a low pulse and a tremor.
				shake = maxf(shake, 2.0)
				sound.play("heavyHit", 0.25)
				haptics.rigid(0.4)
			"discord":
				# Out of turn: every bell of that gate falls silent with a jangle.
				for g in world.level.gates:
					if g.id != e["gate"]:
						continue
					for lever in world.level.levers:
						if g.opens_with.has(lever.id):
							_sparks(Vec2.new(lever.pos.x, lever.pos.y + 60.0), Palette.RED, 6)
					var hero := world.controlled()
					if hero != null:
						_popup("OUT OF TURN", Vec2.new(hero.pos.x, hero.pos.y + hero.spec.height + 16.0), Palette.RED, 14)
				shake = maxf(shake, 5)
				sound.play("blocked")
				haptics.heavy()
			"raised":
				var f := world.fighter(e["id"])
				var r := world.fighter(e["by"])
				if f != null and r != null:
					Effects.motes(world_node, v(f.pos), Palette.GOLD, 40, 60)
					_ring(_mid(f), 110, Palette.GOLD)
					_sparks(_top(r, 0.0), Palette.GOLD, 12)
				hud.announce("RAISED")
				Effects.flash(screen, Palette.GOLD, 0.25, 0.4)
				shake = maxf(shake, 10)
				sound.play("bossWake")
				haptics.heavy()
			"holding":
				var f := world.fighter(e["id"])
				if f != null:
					_popup("HOLDING", _top(f, 14.0), Palette.CYAN, 13)
			"dazed":
				var f := world.fighter(e["id"])
				if f != null:
					_popup("DAZED", _top(f, 14.0), Palette.GOLD, 14)
					if e["id"] == world.controlled_id:
						Effects.flash(screen, Palette.WHITE, 0.55, 0.5)
						haptics.heavy()
			"healed":
				var f := world.fighter(e["id"])
				if f != null:
					Effects.motes(world_node, Vector2(f.pos.x, f.pos.y + 10.0), Palette.GOLD, 18, 24)
					_ring(_mid(f), 60, Palette.GOLD)
					_popup("+%d" % int(round(float(e["amount"]))), _top(f, 10.0), Palette.GOLD, 14)
				sound.play("checkpoint", 0.7)
			"decoyPlaced":
				var at: Vec2 = e["at"]
				Effects.burst(world_node, Vector2(at.x, at.y + 40.0), Palette.VIOLET, 18, 120, 0.4, 12)
				sound.play("dodge")
			"decoyGone":
				var at: Vec2 = e["at"]
				Effects.burst(world_node, v(at), Palette.LANTERN, 22, 180, 0.4, 12)
				Effects.dust(world_node, Vector2(at.x, at.y - 30.0), 8)
				sound.play("fuse", 0.6)
			"bossPhase":
				Effects.flash(screen, Palette.GOLD, 0.3, 0.4)
				var b := world.boss()
				if b != null:
					Effects.motes(world_node, Vector2(b.pos.x, b.pos.y + 40.0), Palette.GOLD, 40, 140)
				var phases: Array = boss_title(b.kind if b != null else "theProtocol")[1]
				hud.announce(phases[mini(maxi(int(e["phase"]) - 2, 0), phases.size() - 1)])
				shake = maxf(shake, 12)
				sound.play("bossWake")
				haptics.heavy()
			"bossLanded":
				var f := world.fighter(e["id"])
				if f != null:
					# The boss hitting the floor from the air.
					Effects.dust(world_node, v(f.pos), 34, f.spec.width * 1.4)
					Effects.flash(screen, Palette.EMBER, 0.12)
					var feet := Vec2.new(f.pos.x, f.pos.y + 10.0)
					_ring(feet, 170, Palette.RED)
					_sparks(feet, Palette.EMBER, 22)
					_popup("OPEN", _top(f, 0.0), Palette.GOLD, 20)
				shake = maxf(shake, 14)
				sound.play("explosion")
				haptics.heavy()
			"struck":
				var at: Vec2 = e["at"]
				var width: float = e["width"]
				match String(e["kind"]):
					"light":
						Effects.column(world_node, v(at), width)
						_sparks(Vec2.new(at.x, at.y + 10.0), Palette.WHITE, 10)
						shake = maxf(shake, 4)
						sound.play("heavyHit", 0.7)
					"fire":
						_sparks(Vec2.new(at.x, at.y + 8.0), Palette.EMBER, 14)
						Effects.dust(world_node, v(at), 6, width / 2.0)
						shake = maxf(shake, 2)
						sound.play("explosion", 0.35)
					"snare":
						_sparks(Vec2.new(at.x, at.y + 4.0), Palette.VIOLET, 6)
						sound.play("warning", 0.4)
					"dark":
						_sparks(Vec2.new(at.x, at.y + 8.0), Palette.VIOLET, 12)
						Effects.dust(world_node, v(at), 6, width / 2.0)
						shake = maxf(shake, 3)
						sound.play("explosion", 0.35)
			"lobbed":
				var f := world.fighter(e["id"])
				var at: Vec2 = e["at"]
				if f != null:
					var from := Vector2(f.pos.x + f.facing * 14.0, f.pos.y + f.spec.height * 0.55)
					Effects.lob(world_node, from, Vector2(at.x, at.y + 6.0), Palette.EMBER if e["kind"] == "fire" else Palette.VIOLET)
				sound.play("dodge", 0.6)
			"faded":
				Effects.motes(world_node, v(e["at"]), Palette.VIOLET, 8)
			"spawned":
				var f := world.fighter(e["id"])
				if world.boss_id >= 0 and f != null:
					_ring(_mid(f), 50, Palette.RED)
			"evaded":
				pass
			_:
				push_error("GameScene: no reaction for event %s" % c)


func _mid(f: Fighter) -> Vec2:
	return Vec2.new(f.pos.x, f.pos.y + f.spec.height / 2.0)


func _top(f: Fighter, above := 0.0) -> Vec2:
	return Vec2.new(f.pos.x, f.pos.y + f.spec.height + above)


func _flash_node(id: int) -> void:
	if nodes.has(id):
		nodes[id].flash()


func _sparks(point: Vec2, color: Color, count: int) -> void:
	Effects.burst(world_node, v(point), color, count * 2, 260, 0.28, 9)


## Dust at a hero's feet.
func _dust(id: int, amount: int, spread := 26.0) -> void:
	var f := world.fighter(id)
	if f == null or f.team != "hero" or not f.awake:
		return
	Effects.dust(world_node, v(f.pos), amount, spread)


func _ring(point: Vec2, radius: float, color: Color) -> void:
	var ring := _shape(SkPath.circle(radius), Sk.with_alpha(color, 0.18), color, 4, 4, 19, v(point))
	ring.scale = Vector2(0.25, 0.25)
	world_node.add_child(ring)
	var t := ring.create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector2.ONE, 0.18)
	t.tween_property(ring, "modulate:a", 0.0, 0.26)
	t.chain().tween_callback(ring.queue_free)


func _popup(text: String, point: Vec2, color: Color, size: float) -> void:
	var label := SkLabel.make(text, size, color, "heavy")
	label.position = Vector2(point.x, point.y + 30.0)
	Sk.z(label, 25)
	world_node.add_child(label)
	var t := label.create_tween().set_parallel(true)
	t.tween_property(label, "position:y", 34.0, 0.5).as_relative()
	t.tween_property(label, "modulate:a", 0.0, 0.25).set_delay(0.25)
	t.chain().tween_callback(label.queue_free)


var sound := Sound.new()
var haptics := Haptics.new()
