class_name Hud
extends Node2D
## The heads-up display: health bars, boss bar, special, status, banners, hints. Port of HUD.swift.
## Lives on the y-flipped UI layer, in the Swift scene's points with y up, so the layout numbers carry over.

enum Action { NONE, PAUSE }

const CLEAR := Color(0, 0, 0, 0)

var bar_back := SkShape.make(SkPath.rounded_rect(0, 0, 190, 10, 3))
var bar_fill := SkShape.make(SkPath.rect(0, 0, 186, 6), Palette.CYAN, CLEAR)
var hero_name := SkLabel.make("", 12, Sk.with_alpha(Palette.WHITE, 0.85), "demibold")
var partner_back := SkShape.make(SkPath.rounded_rect(0, 0, 110, 7, 2))
var partner_fill := SkShape.make(SkPath.rect(0, 0, 106, 3), Palette.CYAN, CLEAR)
var partner_name := SkLabel.make("", 10, Sk.with_alpha(Palette.WHITE, 0.6), "medium")
var status := SkLabel.make("", 12, Sk.with_alpha(Palette.WHITE, 0.85), "medium")
var banner := SkLabel.make("", 30, Sk.with_alpha(Palette.WHITE, 0.85), "heavy")
var message := SkLabel.make("", 26, Sk.with_alpha(Palette.WHITE, 0.85), "heavy")
var hint := SkLabel.make("", 12, Sk.with_alpha(Palette.WHITE, 0.55), "medium")
var damage := SkShape.new()
var debug := SkLabel.make("", 10, Sk.with_alpha(Palette.WHITE, 0.8), "mono")
var boss_back := SkShape.make(SkPath.rounded_rect(-160, 0, 320, 9, 3))
var boss_fill := SkShape.make(SkPath.rect(0, 0, 316, 5), Palette.RED, CLEAR)
var boss_name := SkLabel.make("", 10, Palette.RED, "demibold")
## A second, thinner bar under the boss bar, for the other one of a sworn pair.
var twin_back := SkShape.make(SkPath.rounded_rect(-160, 0, 320, 6, 2))
var twin_fill := SkShape.make(SkPath.rect(0, 0, 316, 3), Palette.RED, CLEAR)
var special := SkLabel.make("", 10, Palette.GOLD, "demibold")
var pause_button := SkShape.make(SkPath.rect_of(34, 30, 6))
var _banner_tween: Tween
var _hint_tween: Tween
var _damage_tween: Tween


func _init() -> void:
	Sk.z(self, 90)
	bar_back.fill_color = Sk.with_alpha(Palette.BODY, 0.8)
	bar_back.stroke_color = Sk.with_alpha(Palette.CYAN, 0.5)
	bar_fill.position = Vector2(2, 2)
	bar_back.add_child(bar_fill)
	add_child(bar_back)

	partner_back.fill_color = Sk.with_alpha(Palette.BODY, 0.8)
	partner_back.stroke_color = Sk.with_alpha(Palette.CYAN, 0.3)
	partner_fill.position = Vector2(2, 2)
	partner_back.add_child(partner_fill)
	add_child(partner_back)
	boss_back.fill_color = Sk.with_alpha(Palette.BODY, 0.85)
	boss_back.stroke_color = Sk.with_alpha(Palette.RED, 0.6)
	boss_back.visible = false
	boss_fill.position = Vector2(-158, 2)
	boss_back.add_child(boss_fill)
	add_child(boss_back)
	twin_back.fill_color = Sk.with_alpha(Palette.BODY, 0.85)
	twin_back.stroke_color = Sk.with_alpha(Palette.RED, 0.4)
	twin_back.visible = false
	twin_fill.position = Vector2(-158, 1.5)
	twin_back.add_child(twin_fill)
	add_child(twin_back)
	boss_name.v_align = SkLabel.V.TOP
	boss_name.visible = false
	add_child(boss_name)

	special.h_align = SkLabel.H.LEFT
	special.v_align = SkLabel.V.CENTER
	add_child(special)
	partner_name.h_align = SkLabel.H.LEFT
	partner_name.v_align = SkLabel.V.CENTER
	add_child(partner_name)

	for l: SkLabel in [hero_name, status, banner, message, hint]:
		add_child(l)
	hero_name.h_align = SkLabel.H.LEFT
	status.h_align = SkLabel.H.RIGHT
	banner.alpha = 0.0
	message.v_align = SkLabel.V.CENTER
	message.visible = false

	debug.h_align = SkLabel.H.RIGHT
	debug.v_align = SkLabel.V.TOP
	debug.visible = false
	add_child(debug)
	pause_button.fill_color = Sk.with_alpha(Palette.WHITE, 0.06)
	pause_button.stroke_color = Sk.with_alpha(Palette.CYAN, 0.5)
	for x: float in [-4.0, 4.0]:
		pause_button.add_child(SkShape.make(SkPath.rounded_rect(x - 1.5, -7, 3, 14, 1), Sk.with_alpha(Palette.CYAN, 0.85), CLEAR))
	add_child(pause_button)

	damage.fill_color = Palette.RED
	damage.stroke_color = CLEAR
	damage.alpha = 0.0
	Sk.z(damage, -1)
	add_child(damage)


## `size` in points; insets are the screen edges to keep clear (left, top, right, bottom), also in points.
func layout(size: Vector2, insets: Rect2) -> void:
	var left := maxf(insets.position.x, 16) + 8.0
	var right := size.x - maxf(insets.size.x, 16) - 8.0
	var top := size.y - maxf(insets.position.y, 10) - 14.0
	hero_name.position = Vector2(left, top - 6)
	bar_back.position = Vector2(left, top - 24)
	partner_back.position = Vector2(left, top - 40)
	partner_name.position = Vector2(left + 118, top - 36)
	status.position = Vector2(right, top - 6)
	banner.position = Vector2(size.x / 2.0, size.y * 0.68)
	message.position = Vector2(size.x / 2.0, size.y * 0.56)
	hint.position = Vector2(size.x / 2.0, top - 6)
	damage.path = SkPath.rect(0, 0, size.x, size.y)
	special.position = Vector2(left, top - 54)
	boss_back.position = Vector2(size.x / 2.0, top - 30)
	twin_back.position = Vector2(size.x / 2.0, top - 39)
	boss_name.position = Vector2(size.x / 2.0, top - 34)
	pause_button.position = Vector2(right - 17, top - 30)
	debug.position = Vector2(right, top - 52)


## The pause button under the status line, with a generous target. `point` in points, y up.
func action_at(point: Vector2) -> Action:
	var p := pause_button.position
	return Action.PAUSE if absf(point.x - p.x) < 30.0 and absf(point.y - p.y) < 26.0 else Action.NONE


func set_debug(text: String) -> void:
	debug.visible = text != ""
	debug.text = text


## The controlled hero gets the large bar; the partner, if there is one, the small one under it.
## lead and partner are [name, health]; an empty partner hides the small bar.
func set_heroes(lead: Array, partner: Array) -> void:
	hero_name.text = lead[0]
	var health: float = lead[1]
	bar_fill.scale.x = clampf(health, 0.0, 1.0)
	bar_fill.fill_color = Palette.RED if health < 0.3 else Palette.CYAN
	partner_back.visible = not partner.is_empty()
	partner_name.visible = not partner.is_empty()
	if partner.is_empty():
		return
	var ph: float = partner[1]
	partner_name.text = "%s  DOWN" % partner[0] if ph <= 0.0 else String(partner[0])
	partner_fill.scale.x = clampf(ph, 0.0, 1.0)
	partner_fill.fill_color = Palette.RED if ph < 0.3 else Palette.CYAN


## The boss bar, top centre. boss is [name, health, open] or empty to hide; twin is [health, open] or empty.
func set_boss(boss: Array, twin: Array = []) -> void:
	boss_back.visible = not boss.is_empty()
	boss_name.visible = not boss.is_empty()
	twin_back.visible = not boss.is_empty() and not twin.is_empty()
	# The name sits under whichever bar is lowest.
	boss_name.position.y = boss_back.position.y - (4.0 if twin.is_empty() else 13.0)
	if not twin.is_empty():
		twin_fill.scale.x = clampf(twin[0], 0.0, 1.0)
		twin_fill.fill_color = Palette.GOLD if twin[1] else Palette.RED
	if boss.is_empty():
		return
	var open: bool = boss[2]
	boss_name.text = "%s   OPEN" % boss[0] if open else String(boss[0])
	boss_name.color = Palette.GOLD if open else Palette.RED
	boss_fill.scale.x = clampf(boss[1], 0.0, 1.0)
	boss_fill.fill_color = Palette.GOLD if open else Palette.RED


## The controlled hero's special: [name, cooldown frames], or empty to hide.
func set_special(info: Array) -> void:
	special.visible = not info.is_empty()
	if info.is_empty():
		return
	var cooldown: int = info[1]
	@warning_ignore("integer_division")
	special.text = "✦ %s" % info[0] if cooldown == 0 else "✦ %s  %ds" % [info[0], cooldown / 60 + 1]
	special.color = Palette.GOLD if cooldown == 0 else Sk.with_alpha(Palette.WHITE, 0.4)


func set_status(text: String) -> void:
	status.text = text


func announce(text: String) -> void:
	banner.text = text
	if _banner_tween != null:
		_banner_tween.kill()
	banner.alpha = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.12)
	_banner_tween.tween_interval(0.8)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.4)


func show_message(text: String) -> void:
	message.text = text
	message.visible = true


func hide_message() -> void:
	message.visible = false


func show_hint(text: String) -> void:
	hint.text = text
	if _hint_tween != null:
		_hint_tween.kill()
	hint.alpha = 1.0
	_hint_tween = create_tween()
	_hint_tween.tween_interval(9.0)
	_hint_tween.tween_property(hint, "modulate:a", 0.0, 1.0)


func flash_damage() -> void:
	if _damage_tween != null:
		_damage_tween.kill()
	damage.alpha = 0.22
	_damage_tween = create_tween()
	_damage_tween.tween_property(damage, "modulate:a", 0.0, 0.3)
