class_name FighterNode
extends Node2D
## Placeholder figure for one fighter, drawn from shapes. Origin is the centre of the feet, facing right.
## Port of FighterNode.swift; art made later replaces this class without touching the simulation.
##
## Lives under the y-flipped world layer: coordinates, rotations and xScale = -1 for facing all read as
## in the Swift code. It only reads the Fighter it is given, never keeps or changes it.

var kind: String
var figure := Node2D.new()
var body_parts: Array[SkShape] = []
var legs: Array[SkShape] = []
var weapon_pivot := Node2D.new()
var weapon: SkShape
var eye: SkShape
var shield: SkShape
## A Halo Disciple's halo, which swells as its flare gathers.
var halo: SkShape
var core: SkShape
## The Protocol shows where its next attack will land.
var zone := SkShape.new()
var zone_attack := -1
## Shown over an enemy carrying Caelen's mark.
var mark := SkShape.new()
## Shown around a machine a Dogma Frame is shielding.
var ward := SkShape.new()
var aura: SkShape
var thrusters: Array[SkShape] = []
## The look of The Protocol's last phase has been applied.
var execution_look := false
var flash_frames := 0
## One arc per swing, even while hit-stop holds the same frame on screen.
var arc_drawn := false
var rim: Color
var base_fill := Palette.BODY
var marker := SkShape.new()
var gone := false
var eye_glow: Sprite2D
var core_glow: Sprite2D
var last_ghost_frame := -1
## Where the eye sits, for its glow (SpriteKit read it from eye.frame).
var _eye_centre := Vector2.ZERO

const CLEAR := Color(0, 0, 0, 0)


func _init(p_kind: String) -> void:
	kind = p_kind
	match kind:
		"seraphine":
			rim = Palette.GOLD
		"nimue", "decoy":
			rim = Palette.VIOLET
		# The Lantern Cities' people are lit by their lanterns, not by machine red.
		"ratborn", "lanternGunner", "smugglerBrute", "nightWeaver", "weaverImage", "cinderKing", "lamplighter":
			rim = Palette.EMBER
		# The Dawnfaith's believers carry their own light: gold, not machine red.
		"zealot", "radiantAcolyte", "solarGuard", "haloDisciple", "lastOracle", "swornShield", "swornSpear":
			rim = Palette.GOLD
		_:
			rim = Palette.CYAN if Fighter.team_of(kind) == "hero" else (Palette.STEEL if kind == "dummy" else Palette.RED)
	if kind == "orion":
		base_fill = Palette.PLATE
	if kind == "seraphine" or kind == "lastOracle":
		base_fill = Palette.IVORY
	add_child(figure)
	_build_marker()
	_build_mark()
	_build_ward()
	var builder := "_build_" + kind.to_snake_case()
	if has_method(builder):
		call(builder)
	else:
		_build_placeholder()
	_add_glows()


# MARK: Building


func part(p: SkPath, z: float = 0.0) -> SkShape:
	var node := SkShape.make(p, base_fill, Sk.with_alpha(rim, 0.45), 1.5)
	Sk.z(node, z)
	figure.add_child(node)
	body_parts.append(node)
	return node


func leg(x: float, hip_y: float, length: float, width: float) -> void:
	var node := part(SkPath.rect(-width / 2.0, -length, width, length), -1)
	node.position = Vector2(x, hip_y)
	legs.append(node)


func light(node: SkShape, color: Color, glow: float) -> void:
	node.fill_color = color
	node.stroke_color = color
	node.glow_width = glow
	Sk.z(node, 2)


## A lit shape added to the figure at `at`.
func lit(p: SkPath, color: Color, glow: float, at := Vector2.ZERO) -> SkShape:
	var node := SkShape.make(p)
	node.position = at
	light(node, color, glow)
	figure.add_child(node)
	return node


func blade(length: float, color: Color, pivot: Vector2) -> void:
	var node := SkShape.make(SkPath.line(Vector2.ZERO, Vector2(0, length)), CLEAR, color, 3, 3)
	node.round_cap = true
	weapon_pivot.position = pivot
	Sk.z(weapon_pivot, 3)
	weapon_pivot.add_child(node)
	figure.add_child(weapon_pivot)
	weapon = node


## Stands in for a figure not yet ported: a body-sized box with an eye, so every level still draws.
func _build_placeholder() -> void:
	var w := 30.0
	var h := 60.0
	part(SkPath.rounded_rect(-w / 2.0, 0, w, h, 4))
	eye = lit(SkPath.circle(3), rim, 3, Vector2(w / 4.0, h - 12.0))


func _build_caelen() -> void:
	leg(-6, 32, 32, 8)
	leg(6, 32, 32, 8)
	part(SkPath.polygon([Vector2(-11, 64), Vector2(12, 64), Vector2(13, 30), Vector2(8, 16), Vector2(-26, 12), Vector2(-15, 40)]))
	part(SkPath.ellipse(-8, 64, 20, 20), 1)
	lit(SkPath.rect(2, 58, 9, 3), Palette.CYAN, 2)
	eye = lit(SkPath.circle(1.8), Palette.CYAN, 2, Vector2(8, 75))
	blade(60, Palette.CYAN, Vector2(6, 54))


## Orion: pale plating, cyan eye and chest core, a torn cloak, a short blade.
func _build_orion() -> void:
	leg(-6, 34, 34, 7)
	leg(6, 34, 34, 7)
	part(SkPath.polygon([Vector2(-9, 68), Vector2(4, 68), Vector2(-4, 40), Vector2(-20, 20), Vector2(-24, 34), Vector2(-16, 52)]), -1)
	part(SkPath.rounded_rect(-10, 32, 20, 36, 6))
	part(SkPath.ellipse(-8, 68, 18, 18), 1)
	lit(SkPath.circle(3.5), Palette.CYAN, 3, Vector2(4, 54))
	eye = lit(SkPath.circle(2.4), Palette.CYAN, 3, Vector2(6, 78))
	blade(44, Palette.CYAN, Vector2(6, 52))


## A small arrow over the hero the player is controlling.
func _build_marker() -> void:
	marker.path = SkPath.polygon([Vector2(-7, 8), Vector2(7, 8), Vector2(0, 0)])
	marker.fill_color = Palette.CYAN
	marker.stroke_color = CLEAR
	marker.glow_width = 2
	Sk.z(marker, 6)
	marker.visible = false
	add_child(marker)


func _build_mark() -> void:
	mark.path = SkPath.polygon([Vector2(0, 10), Vector2(9, 0), Vector2(0, -10), Vector2(-9, 0)])
	mark.fill_color = CLEAR
	mark.stroke_color = Palette.GOLD
	mark.line_width = 2.5
	mark.glow_width = 4
	Sk.z(mark, 7)
	mark.visible = false
	add_child(mark)


func _build_ward() -> void:
	ward.fill_color = Sk.with_alpha(Palette.EMBER, 0.08)
	ward.stroke_color = Palette.EMBER
	ward.line_width = 2
	ward.glow_width = 3
	Sk.z(ward, 6)
	ward.visible = false
	add_child(ward)


func _build_dummy() -> void:
	part(SkPath.rect(-4, 0, 8, 70))
	part(SkPath.rect(-20, 50, 40, 8))
	part(SkPath.ellipse(-11, 68, 22, 22))


func _build_scrap_drone() -> void:
	for x: float in [-16.0, -6.0, 6.0, 16.0]:
		leg(x, 14, 14, 4)
	part(SkPath.ellipse(-22, 8, 44, 28))
	eye = lit(SkPath.circle(6), Palette.RED, 4, Vector2(9, 22))


func _build_forged_soldier() -> void:
	leg(-8, 40, 40, 11)
	leg(8, 40, 40, 11)
	part(SkPath.rounded_rect(-17, 38, 34, 44, 5))
	part(SkPath.rounded_rect(-9, 82, 20, 18, 4), 1)
	eye = lit(SkPath.rect(1, 90, 10, 3), Palette.RED, 3)
	blade(74, Palette.RED, Vector2(4, 70))
	var plate := SkShape.make(SkPath.rounded_rect(15, 16, 9, 70, 3), Palette.BODY, Palette.STEEL, 2)
	Sk.z(plate, 4)
	figure.add_child(plate)
	shield = plate


# MARK: Glows and ghosts


## Soft light around the eyes, and behind The Protocol's core.
func _add_glows() -> void:
	if eye != null and kind != "dummy":
		var size := 110.0 if kind == "theProtocol" else (70.0 if kind == "dogmaFrame" else 38.0)
		var color := Palette.EMBER if kind == "dogmaFrame" else rim
		eye_glow = Effects.glow(color, size, 0.45)
		eye_glow.position = _centre_of(eye)
		Sk.z(eye_glow, 1.5)
		figure.add_child(eye_glow)
	if core != null:
		core_glow = Effects.glow(Palette.GOLD, 190, 0)
		core_glow.position = core.position
		Sk.z(core_glow, 2.5)
		figure.add_child(core_glow)


## The centre of a shape's path in the figure, as SpriteKit's node.frame.mid gave it.
func _centre_of(s: SkShape) -> Vector2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for pts in s.path.subpaths:
		for p in pts:
			lo = lo.min(p)
			hi = hi.max(p)
	return s.transform * ((lo + hi) / 2.0)


## A fading copy of the figure, left behind by a dodge or a charge.
func _leave_ghost(frame: int) -> void:
	if frame == last_ghost_frame or frame % 3 != 0 or get_parent() == null:
		return
	last_ghost_frame = frame
	var copy: Node2D = SkShape.clone_tree(figure)
	_tint_ghost(copy)
	var ghost := Node2D.new()
	ghost.position = position
	ghost.scale = Vector2(scale.x, 1)
	ghost.z_index = z_index - 2
	ghost.modulate.a = 0.5
	ghost.add_child(copy)
	get_parent().add_child(ghost)
	Sk.fade_out_and_free(ghost, 0.22)


func _tint_ghost(node: Node) -> void:
	if node is SkShape and (node as SkShape).fill_color.a > 0.0:
		(node as SkShape).fill_color = Sk.with_alpha(rim, 0.35)
		(node as SkShape).stroke_color = Sk.with_alpha(rim, 0.6)
	for c in node.get_children():
		_tint_ghost(c)


# MARK: Per-frame


func flash() -> void:
	flash_frames = 4


## Used when the fighter vanishes at once, as a drone does when it explodes.
func vanish() -> void:
	gone = true
	queue_free()


func sync(f: Fighter, frame: int, controlled := false, warded := false) -> void:
	if gone:
		return
	var fr := float(frame)
	ward.visible = warded
	if warded and ward.path == null:
		var w := f.spec.width + 22.0
		var h := f.spec.height + 18.0
		ward.path = SkPath.rounded_rect(-w / 2.0, -6, w, h, 12)
	ward.alpha = 0.6 + 0.3 * sin(fr * 0.15)
	if aura != null:
		aura.visible = f.is_alive() and f.awake
	marker.visible = controlled and f.is_alive()
	marker.position = Vector2(0, f.spec.height + 12.0 + 2.0 * sin(fr * 0.12))
	position = Vector2(f.pos.x, f.pos.y)
	if halo != null:
		# The flare gathers on the halo through its windup, the cue to look away.
		# Gold for a flare (look away), violet for an eclipse (look at it).
		var gather := 0.0
		var dark := false
		var a := f.current_attack()
		if a != null and f.attack_phase() == Fighter.Phase.WINDUP:
			match String(a.effect.get("case", "")):
				"flare":
					gather = float(f.state_frame) / float(maxi(a.windup, 1))
				"eclipse":
					gather = float(f.state_frame) / float(maxi(a.windup, 1))
					dark = true
		halo.scale = Vector2.ONE * (1.0 + gather * 0.9)
		halo.glow_width = 3.0 + gather * 14.0
		halo.line_width = 3.0 + gather * 3.0
		halo.stroke_color = Palette.VIOLET if dark else Palette.GOLD
		halo.fill_color = Sk.with_alpha(Palette.BODY, 0.85 * gather) if dark else CLEAR
	mark.visible = f.marked_frames != 0 and f.is_alive()
	mark.position = Vector2(0, f.spec.height + 22.0)
	mark.rotation = fr * 0.05
	# The mark blinks as it runs out.
	@warning_ignore("integer_division")
	mark.alpha = 0.3 if f.marked_frames < 90 and (frame / 6) % 2 == 0 else 1.0
	scale.x = 1.0 if f.facing >= 0.0 else -1.0

	var tilt := 0.0
	var stretch := Vector2.ONE
	var opacity := 1.0
	var offset := Vector2.ZERO
	var tint: Variant = null

	match f.state:
		Fighter.St.IDLE:
			stretch.y = 1.0 + 0.015 * sin(fr * 0.08)
		Fighter.St.RUN:
			tilt = -0.08
		Fighter.St.AIR:
			stretch = Vector2(0.94, 1.06) if f.vel.y > 0.0 else Vector2(1.04, 0.97)
		Fighter.St.ATTACK:
			var lean := 0.5 if kind == "theProtocol" else 1.0
			tilt = (0.06 if f.attack_phase() == Fighter.Phase.WINDUP else -0.1) * lean
		Fighter.St.DODGE:
			stretch = Vector2(1.3, 0.8)
			opacity = 0.55
		Fighter.St.HITSTUN:
			tilt = 0.3
		Fighter.St.PHASE_SHIFT:
			# Changing form: it shudders and flashes gold.
			stretch = Vector2(1.0 + 0.03 * sin(fr * 0.9), 1.02)
			@warning_ignore("integer_division")
			if (frame / 4) % 2 == 0:
				tint = Palette.GOLD
		Fighter.St.GUARD_STANCE:
			# Braced: low, wide, lit.
			stretch = Vector2(1.12, 0.92)
			tint = Palette.CYAN
		Fighter.St.STAGGERED:
			tilt = (0.06 if kind == "theProtocol" else 0.18) + 0.06 * sin(fr * 0.5)
			tint = Palette.EMBER
		Fighter.St.FUSE:
			# Blinks faster as the fuse runs down.
			@warning_ignore("integer_division")
			var period := maxi(4, 16 - f.state_frame / 5)
			@warning_ignore("integer_division")
			if (f.state_frame / (period / 2)) % 2 == 0:
				tint = Palette.RED
			var pulse := 1.0 + 0.12 * sin(float(f.state_frame) * 0.6)
			stretch = Vector2(pulse, pulse)
		Fighter.St.DEAD:
			if kind == "theProtocol":
				# Too heavy to tumble: it sinks to its knees and goes dark.
				var t := minf(1.0, float(f.state_frame) / 80.0)
				stretch.y = 1.0 - 0.3 * t
				tilt = 0.12 * t
				opacity = 1.0 - 0.5 * t
			else:
				var t := minf(1.0, float(f.state_frame) / 30.0)
				tilt = 1.4 * t
				opacity = 1.0 - t

	@warning_ignore("integer_division")
	if f.invulnerable > 0 and f.team == "hero" and f.state != Fighter.St.DEAD and (frame / 3) % 2 == 0:
		opacity *= 0.4
	if kind == "scrapDrone" and f.attack_phase() == Fighter.Phase.WINDUP:
		offset.x = -6
		stretch = Vector2(1.1, 0.82)

	figure.rotation = tilt
	figure.scale = stretch
	figure.position = offset
	figure.modulate.a = opacity

	_animate_legs(f, frame)
	_animate_weapon(f)
	_animate_telegraph(f)
	var a2 := f.current_attack()
	if f.is_alive() and (f.state == Fighter.St.DODGE or (a2 != null and a2.holds_still and f.attack_phase() == Fighter.Phase.ACTIVE)):
		_leave_ghost(frame)
	if eye_glow != null:
		eye_glow.visible = f.is_alive() and not (kind == "theProtocol" and not f.awake)
	if core_glow != null:
		var open := f.is_open() and f.is_alive() and f.awake
		core_glow.modulate.a = 0.55 + 0.15 * sin(fr * 0.4) if open else 0.0
	_animate_zone(f)
	_animate_core(f, frame)
	if kind == "theProtocol":
		var lit_up := f.is_alive() and (f.flying or (not f.on_ground and f.phase == 2))
		for n in thrusters.size():
			thrusters[n].visible = lit_up
			thrusters[n].scale.y = 0.8 + 0.3 * absf(sin(float(frame + n * 7) * 0.5))
		if f.phase >= 3 and not execution_look:
			execution_look = true
			for p in body_parts:
				p.stroke_color = Sk.with_alpha(Palette.GOLD, 0.85)
			rim = Palette.GOLD
	if kind == "sentryCore" and f.is_alive():
		figure.position.y += 4.0 * sin(fr * 0.1)
	@warning_ignore("integer_division")
	if f.slow_frames > 0 and f.is_alive() and (frame / 4) % 2 == 0:
		for p in body_parts:
			p.stroke_color = Palette.EMBER
	elif f.team == "hero":
		for p in body_parts:
			p.stroke_color = Sk.with_alpha(rim, 0.45)
	if kind == "theProtocol" and not f.awake:
		# Dormant: slumped and dark until a hero comes near.
		figure.scale.y = 0.88
		figure.modulate.a = 0.55
		if eye != null:
			eye.alpha = 0.15
	elif kind == "theProtocol" and eye != null:
		eye.alpha = 1.0

	if flash_frames > 0:
		flash_frames -= 1
	var fill: Color = Palette.WHITE if flash_frames > 0 else (tint if tint != null else base_fill)
	for p in body_parts:
		p.fill_color = fill
	if shield != null:
		shield.alpha = 1.0 if f.is_guarding() else 0.35


func _animate_legs(f: Fighter, frame: int) -> void:
	var moving := f.state == Fighter.St.RUN or (f.state == Fighter.St.FUSE and absf(f.vel.x) > 1.0)
	var rate := 0.7 if kind == "scrapDrone" else 0.32
	var swing := 0.6 if moving else (0.25 if f.state == Fighter.St.AIR else 0.0)
	for i in legs.size():
		var ph := float(frame) * rate + float(i) * PI
		if moving:
			legs[i].rotation = swing * sin(ph)
		elif f.state == Fighter.St.AIR:
			legs[i].rotation = swing if i % 2 == 0 else -swing
		else:
			legs[i].rotation = 0.0


func _animate_zone(f: Fighter) -> void:
	if kind != "theProtocol" and kind != "sentryCore":
		return
	var a := f.current_attack()
	if f.state != Fighter.St.ATTACK or a == null or f.attack_phase() == Fighter.Phase.RECOVERY or not a.is_strike():
		zone.visible = false
		zone_attack = -1
		return
	if zone_attack != f.attack_index:
		zone_attack = f.attack_index
		var travel := a.lunge * float(a.active) / Tuning.FRAMES_PER_SECOND if a.holds_still else 0.0
		var far := f.spec.width / 2.0 + a.reach + travel
		var from := -far if a.both_sides else 0.0
		zone.path = SkPath.rect(from, a.y_offset, far - from, a.height)
	zone.visible = true
	var striking := f.attack_phase() == Fighter.Phase.ACTIVE
	var t := float(f.state_frame) / float(maxi(a.windup, 1))
	var last := a.windup - f.state_frame <= 8
	zone.fill_color = Sk.with_alpha(Palette.RED, 0.55 if striking else (0.3 if last else 0.05 + 0.13 * t))
	zone.stroke_color = Sk.with_alpha(Palette.RED, 1.0 if striking else 0.25 + 0.5 * t)
	zone.glow_width = 6.0 if striking else 0.0


func _animate_core(f: Fighter, frame: int) -> void:
	if core == null:
		return
	var open := f.is_open() and f.is_alive()
	core.fill_color = Palette.GOLD if open else Palette.BODY
	core.stroke_color = Palette.WHITE if open else Sk.with_alpha(Palette.RED, 0.7 if f.awake else 0.2)
	core.glow_width = 10.0 if open else 0.0
	core.scale = Vector2.ONE * (1.15 + 0.12 * sin(float(frame) * 0.4) if open else 1.0)


func _sweeps() -> Array:
	match kind:
		"caelen":
			return [[0.9, -2.0], [-2.7, 0.2], [1.7, -2.5]]
		"orion":
			return [[-0.4, -2.2], [-2.6, 0.4]]
		"seraphine":
			return [[0.4, -1.9], [-1.57, -1.57]]
		"nimue":
			return [[0.6, -1.8], [0.3, -1.9], [1.2, -2.2]]
	return [[1.1, -2.3]]


func _weapon_length() -> float:
	match kind:
		"caelen": return 62
		"orion": return 46
		"seraphine": return 64
		"nimue": return 30
		"ratborn": return 22
		"smugglerBrute": return 70
		"cinderKing": return 110
		"lineWarden": return 96
		"lamplighter": return 100
		"swornShield": return 60
		"swornSpear": return 140
		"zealot": return 50
		"radiantAcolyte": return 54
		"solarGuard": return 58
		"haloDisciple": return 40
		"lastOracle": return 104
	return 76


func _animate_weapon(f: Fighter) -> void:
	if weapon == null:
		return
	var rest := -2.5 if Fighter.team_of(kind) == "hero" else -2.75
	var phase := f.attack_phase()
	if phase != Fighter.Phase.ACTIVE:
		arc_drawn = false
	var a := f.current_attack()
	if f.state != Fighter.St.ATTACK or a == null:
		weapon_pivot.rotation = rest
		return
	var sweeps := _sweeps()
	var sw: Array = sweeps[f.attack_index % sweeps.size()]
	var from: float = sw[0]
	var to: float = sw[1]
	var fr := float(f.state_frame)
	match phase:
		Fighter.Phase.WINDUP:
			var t := fr / float(maxi(a.windup, 1))
			weapon_pivot.rotation = rest + (from - rest) * minf(1.0, t * 1.6)
		Fighter.Phase.ACTIVE:
			var t := (fr - float(a.windup) + 1.0) / float(a.active)
			weapon_pivot.rotation = from + (to - from) * minf(1.0, t)
			if not arc_drawn:
				arc_drawn = true
				# Seraphine's second strike and all of Nimue's reach out past the weapon: draw how far.
				if (kind == "seraphine" and f.attack_index == 1) or kind == "nimue":
					_draw_streak(a.reach, a.y_offset + a.height / 2.0, 3.0 if kind == "nimue" else 6.0)
				else:
					_draw_arc(from, to, _weapon_length())
		_:
			var t := (fr - float(a.windup + a.active)) / float(maxi(a.recovery, 1))
			weapon_pivot.rotation = to + (rest - to) * t * t


## A bolt of light or a thrown blade's path, straight out from the body.
func _draw_streak(length: float, y: float, width: float) -> void:
	var streak := SkShape.make(SkPath.line(Vector2(12, y), Vector2(12.0 + length, y)), CLEAR, rim, width, width)
	streak.round_cap = true
	Sk.z(streak, 5)
	figure.add_child(streak)
	Sk.fade_out_and_free(streak, 0.18)


func _draw_arc(from: float, to: float, radius: float) -> void:
	var p := SkPath.new().add_arc(Vector2.ZERO, radius, from + PI / 2.0, to + PI / 2.0, to < from)
	var arc := SkShape.make(p, CLEAR, rim, 7, 5)
	arc.round_cap = true
	arc.position = weapon_pivot.position
	Sk.z(arc, 5)
	arc.alpha = 0.85
	figure.add_child(arc)
	Sk.fade_out_and_free(arc, 0.16, 1.12)


## Enemies warn before they strike: the eye swells through the windup and the body flashes just before the hit,
## which is the moment to parry or dodge.
func _animate_telegraph(f: Fighter) -> void:
	if f.team != "enemy" or eye == null:
		return
	var a := f.current_attack()
	if a != null and f.attack_phase() == Fighter.Phase.WINDUP:
		var t := float(f.state_frame) / float(maxi(a.windup, 1))
		eye.scale = Vector2.ONE * (1.0 + 1.2 * t)
		if a.windup - f.state_frame <= 7:
			flash_frames = maxi(flash_frames, 1)
	else:
		eye.scale = Vector2.ONE
