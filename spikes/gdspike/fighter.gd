## Language spike for The Last Light Godot port (statically typed GDScript).
## Same checks as the Go/C# spikes. Headless parity run:
##   godot --headless --path . -- --sim-ticks=600
extends Node2D

var world: SimWorld
var sim_ticks: int = 0
var last_touch: bool = false


func _ready() -> void:
	var raw := FileAccess.get_file_as_string("res://data/level.json")
	var lvl: Variant = JSON.parse_string(raw)
	if lvl is Dictionary:
		print("SPIKE json: OK ", lvl.name)
	else:
		print("SPIKE json: FAIL")
		lvl = {"name": "fallback", "width": 1280, "floor": 560, "gravity": 2400, "speed": 320, "jump": 900}
	world = SimWorld.new(lvl)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--sim-ticks="):
			sim_ticks = int(a.trim_prefix("--sim-ticks="))
	if Engine.has_singleton("Steam"):
		var steam: Object = Engine.get_singleton("Steam")
		print("SPIKE steam: steamInitEx -> ", steam.call("steamInitEx", 480, true))
	else:
		print("SPIKE steam: no GodotSteam singleton")


func _physics_process(_delta: float) -> void:
	var move := 0.0
	var jump := false
	var attack := false
	if sim_ticks > 0:
		var s: Array = SimWorld.script(world.tick + 1)
		move = s[0]; jump = s[1]; attack = s[2]
	else:
		move = Input.get_axis("ui_left", "ui_right")
		jump = Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_accept")
		attack = Input.is_action_just_pressed("ui_select")
		var touching := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if touching:
			var vp := get_viewport_rect().size
			var p := get_global_mouse_position()
			if p.x < vp.x / 3.0: move = -1.0
			elif p.x > vp.x * 2.0 / 3.0: move = 1.0
			elif not last_touch and p.y < vp.y / 2.0: jump = true
			elif not last_touch: attack = true
		last_touch = touching
	world.step(move, jump, attack)
	queue_redraw()
	if sim_ticks > 0 and world.tick >= sim_ticks:
		print("SPIKE sim: ticks=%d hash=%s" % [world.tick, world.state_hash()])
		get_tree().quit()


func _glow_line(a: Vector2, b: Vector2, col: Color) -> void:
	draw_line(a, b, Color(col, 0.18), 10.0, true)
	draw_line(a, b, col, 2.5, true)


func _draw() -> void:
	if world == null:
		return
	var w := world
	var cyan := Color(0.3, 0.95, 1.0)
	var gold := Color(1.0, 0.8, 0.3)
	var fl := float(w.level.floor)
	_glow_line(Vector2(0, fl + 2), Vector2(float(w.level.width), fl + 2), Color(0.5, 0.4, 1.0))
	var feet := Vector2(w.x, w.y)
	var hip := feet + Vector2(0, -40)
	var neck := hip + Vector2(0, -40)
	_glow_line(hip, feet + Vector2(-12, 0), cyan)
	_glow_line(hip, feet + Vector2(12, 0), cyan)
	_glow_line(hip, neck, cyan)
	draw_circle(neck + Vector2(0, -14), 12, Color(cyan, 0.25))
	draw_circle(neck + Vector2(0, -14), 12, cyan, false, 2.5, true)
	var hand := neck + Vector2(18 * w.facing, 14)
	_glow_line(neck, hand, cyan)
	var tip := hand + (Vector2(52 * w.facing, 4) if w.attack_t > 0 else Vector2(10 * w.facing, -46))
	_glow_line(hand, tip, gold)
