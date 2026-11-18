class_name InputFrame
extends RefCounted
## One frame of intent. `move_x` and `jump_held` are held state; the rest mean "pressed this frame".

var move_x: float = 0.0
var jump: bool = false
var jump_held: bool = false
var attack: bool = false
var dodge: bool = false
var special: bool = false
var switch_hero: bool = false


static func make(mx: float = 0.0, j: bool = false, jh: bool = false, a: bool = false, d: bool = false,
		s: bool = false, sw: bool = false) -> InputFrame:
	var i := InputFrame.new()
	i.move_x = mx
	i.jump = j
	i.jump_held = jh
	i.attack = a
	i.dodge = d
	i.special = s
	i.switch_hero = sw
	return i


static func neutral() -> InputFrame:
	return InputFrame.new()


func copy() -> InputFrame:
	return make(move_x, jump, jump_held, attack, dodge, special, switch_hero)


func equals(o: InputFrame) -> bool:
	return move_x == o.move_x and jump == o.jump and jump_held == o.jump_held and attack == o.attack \
		and dodge == o.dodge and special == o.special and switch_hero == o.switch_hero
