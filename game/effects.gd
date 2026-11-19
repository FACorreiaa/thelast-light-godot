class_name Effects
extends RefCounted
## Visual effects made from code: particle bursts, dust, drifting embers, light shafts, screen flashes and the
## vignette. Every texture is drawn once at launch, so there are no image files. Port of Effects.swift.
##
## Particles use local coordinates under the y-flipped world layer, so angles and gravity are in the Swift
## scene's y-up units, and they ride with the layer as SpriteKit's targetNode = worldNode did.

## A soft white dot, bright in the middle and fading to nothing. Particles and glows are tinted copies.
static var dot: Texture2D = _radial(64, [[0.0, 1.0], [0.35, 0.55], [1.0, 0.0]], false)
## Dark corners, clear middle.
static var vignette_texture: Texture2D = _radial(256, [[0.0, 0.0], [0.55, 0.0], [1.0, 0.62]], true)
static var additive: CanvasItemMaterial = _blend(CanvasItemMaterial.BLEND_MODE_ADD)


static func _blend(mode: CanvasItemMaterial.BlendMode) -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = mode
	return m


static func _radial(size: int, stops: Array, dark: bool) -> Texture2D:
	var g := Gradient.new()
	var shade := 0.0 if dark else 1.0
	g.offsets = PackedFloat32Array(stops.map(func(s: Array) -> float: return s[0]))
	g.colors = PackedColorArray(stops.map(func(s: Array) -> Color: return Color(shade, shade, shade, s[1])))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = size
	t.height = size
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	# The dark version reaches into the corners; the dot stays inside its circle.
	t.fill_to = Vector2(0.5 + 0.5 * (1.42 if dark else 1.0), 0.5)
	return t


# MARK: Bursts


## A one-off spray of glowing particles. They stay where they were made even if the camera moves.
static func burst(parent: Node2D, at: Vector2, color: Color, count: int, speed := 220.0, life := 0.35,
		size := 10.0, angle := 0.0, spread := TAU, gravity := 0.0, width := 0.0, add := true, z := 20.0) -> void:
	if count <= 0:
		return
	var e := CPUParticles2D.new()
	e.texture = dot
	e.amount = count
	e.one_shot = true
	e.explosiveness = clampf(1.0 - (1.0 / 40.0) / life, 0.0, 1.0)
	e.lifetime = life
	e.lifetime_randomness = 0.25
	e.local_coords = true
	e.direction = Vector2(cos(angle), sin(angle))
	e.spread = rad_to_deg(spread / 2.0)
	e.gravity = Vector2(0, gravity)
	e.initial_velocity_min = speed * 0.6
	e.initial_velocity_max = speed * 1.4
	e.scale_amount_min = (size - size / 4.0) / 64.0
	e.scale_amount_max = (size + size / 4.0) / 64.0
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0.4))
	e.scale_amount_curve = shrink
	var fade := Gradient.new()
	fade.colors = PackedColorArray([color, Sk.with_alpha(color, 0.0)])
	e.color_ramp = fade
	if width > 0.0:
		e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		e.emission_rect_extents = Vector2(width / 2.0, 0.01)
	if add:
		e.material = additive
	e.position = at
	Sk.z(e, z)
	parent.add_child(e)
	e.emitting = true
	parent.get_tree().create_timer(life * 1.6 + 0.1).timeout.connect(e.queue_free)


## Grey puffs at the feet: a jump, a landing, a dodge.
static func dust(parent: Node2D, at: Vector2, amount := 8, spread := 26.0) -> void:
	burst(parent, at, Color(0.55, 0.55, 0.55), amount, 60, 0.45, 22, PI / 2.0, PI * 0.9, 40, spread, false, 4)


## Fire and smoke.
static func explosion(parent: Node2D, at: Vector2, radius: float) -> void:
	burst(parent, at, Palette.EMBER, 40, radius * 2.6, 0.4, 20)
	burst(parent, at, Palette.GOLD, 14, radius * 1.2, 0.25, 26)
	burst(parent, at, Color(0.18, 0.18, 0.18), 16, 70, 0.9, 46, PI / 2.0, PI, 60, radius * 0.5, false, 18)


## A machine coming apart: embers that fall.
static func break_apart(parent: Node2D, at: Vector2, size: float) -> void:
	burst(parent, at, Palette.RED, 18 + int(size / 6.0), 160, 0.6, 9, 0.0, TAU, -420, size * 0.4)
	burst(parent, at, Palette.EMBER, 10, 90, 0.8, 7, PI / 2.0, PI, -200)


## Light rising out of a column as it burns.
static func column(parent: Node2D, at: Vector2, width: float) -> void:
	burst(parent, at, Palette.WHITE, 26, 420, 0.35, 12, PI / 2.0, 0.25, 0, width * 0.8)
	burst(parent, at, Palette.RED, 14, 140, 0.3, 14, PI / 2.0, PI * 0.8, 0, width)


## Motes that drift up and away, for checkpoints and pickups.
static func motes(parent: Node2D, at: Vector2, color: Color, count := 14, width := 30.0) -> void:
	burst(parent, at, color, count, 50, 0.9, 8, PI / 2.0, 0.6, 60, width)


# MARK: Atmosphere


## Embers that float up through the Foundry, and dust in the far light. Already drifting when a level opens.
static func ambient(mid: Node2D, far: Node2D, width: float) -> void:
	var embers := _drift(Palette.EMBER, width / 260.0, 9.0, 3.0, PI / 2.0, 0.5, 34, 18, 0.75, 0.08, 0.1, 0.06)
	embers.gravity = Vector2(4, 0)
	embers.position = Vector2(width / 2.0, -30)
	embers.emission_rect_extents = Vector2((width + 400.0) / 2.0, 20)
	embers.preprocess = 10.0
	Sk.z(embers, 2)
	mid.add_child(embers)

	var motes := _drift(Palette.CYAN, width / 500.0, 14.0, 0.0, 0.0, TAU, 6, 4, 0.35, 0.02, 0.07, 0.04)
	motes.position = Vector2(width / 2.0, 200)
	motes.emission_rect_extents = Vector2((width + 400.0) / 2.0, 180)
	motes.preprocess = 14.0
	Sk.z(motes, 1)
	far.add_child(motes)

	# Slanted light falling from the high windows.
	var x := -100.0
	while x < width + 300.0:
		var shaft := Sprite2D.new()
		shaft.texture = dot
		shaft.scale = Vector2(110.0 / 64.0, 820.0 / 64.0)
		shaft.modulate = Sk.with_alpha(Palette.CYAN, 0.07)
		shaft.material = additive
		shaft.position = Vector2(x, 230)
		shaft.rotation = -0.32
		Sk.z(shaft, 0.5)
		far.add_child(shaft)
		x += 450.0


static func _drift(color: Color, rate: float, life: float, life_range: float, angle: float, angle_range: float,
		speed: float, speed_range: float, alpha: float, alpha_speed: float, scale: float, scale_range: float) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.texture = dot
	e.material = additive
	e.local_coords = true
	e.amount = maxi(1, int(rate * life))
	e.lifetime = life
	e.lifetime_randomness = life_range / life / 2.0 if life > 0.0 else 0.0
	e.direction = Vector2(cos(angle), sin(angle))
	e.spread = rad_to_deg(angle_range / 2.0)
	e.gravity = Vector2.ZERO
	e.initial_velocity_min = speed - speed_range / 2.0
	e.initial_velocity_max = speed + speed_range / 2.0
	e.scale_amount_min = scale - scale_range / 2.0
	e.scale_amount_max = scale + scale_range / 2.0
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	# Alpha falls by alpha_speed per second from its start, as SpriteKit's particleAlphaSpeed does.
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Sk.with_alpha(color, alpha), Sk.with_alpha(color, maxf(0.0, alpha - alpha_speed * life))])
	e.color_ramp = fade
	return e


# MARK: Screen


## A brief wash of colour over the whole screen. `overlay` is a Control covering the screen.
static func flash(overlay: Control, color: Color, alpha: float, duration := 0.18) -> void:
	var wash := ColorRect.new()
	wash.color = color
	wash.modulate.a = alpha
	wash.material = additive
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(wash)
	Sk.fade_out_and_free(wash, duration)


## Something thrown: a lit ember arcing from the thrower to where it lands, with a short trail.
static func lob(parent: Node2D, from: Vector2, to: Vector2, color: Color, duration := 0.5) -> void:
	var ball := SkShape.make(SkPath.circle(4), color, color, 1.0, 5)
	Sk.z(ball, 9)
	ball.position = from
	parent.add_child(ball)
	var peak := maxf(from.y, to.y) + 70.0 + absf(to.x - from.x) * 0.15
	var control := Vector2((from.x + to.x) / 2.0, peak)
	var fly := func(t: float) -> void:
		var u := 1.0 - t
		ball.position = from * u * u + control * 2.0 * u * t + to * t * t
	var tw := ball.create_tween()
	tw.tween_method(fly, 0.0, 1.0, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(ball.queue_free)
	var steps := int(duration / 0.03)
	var trail := ball.create_tween().set_loops(steps)
	trail.tween_callback(func() -> void:
		var mote := SkShape.make(SkPath.circle(2), Sk.with_alpha(color, 0.6), Color(0, 0, 0, 0))
		mote.position = ball.position
		Sk.z(mote, 8)
		parent.add_child(mote)
		Sk.fade_out_and_free(mote, 0.25, 0.3))
	trail.tween_interval(0.03)


## A soft glow sprite, for lights on fighters.
static func glow(color: Color, size: float, alpha: float) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = dot
	g.scale = Vector2(size, size) / 64.0
	g.modulate = Sk.with_alpha(color, alpha)
	g.material = additive
	return g
