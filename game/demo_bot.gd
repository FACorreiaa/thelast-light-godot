class_name DemoBot
extends RefCounted
## Plays the feel slice badly but busily, so the scene can be watched and screenshotted without hands.


static func input_for(world: World) -> InputFrame:
	var hero := world.controlled()
	if hero == null:
		return InputFrame.neutral()
	var enemies: Array[Fighter] = []
	var live: Array[Fighter] = []
	for f in world.fighters:
		if f.team == "enemy" and f.is_alive():
			enemies.append(f)
			if not f.spec.immortal:
				live.append(f)
	var pool := enemies if live.is_empty() else live
	var target: Fighter = null
	for f in pool:
		if target == null or absf(f.pos.x - hero.pos.x) < absf(target.pos.x - hero.pos.x):
			target = f
	if target == null:
		return InputFrame.neutral()
	var dx := target.pos.x - hero.pos.x
	var dir := 1.0 if dx >= 0.0 else -1.0
	var inp := InputFrame.neutral()
	inp.switch_hero = world.frame % 600 == 599
	if target.state == Fighter.St.FUSE and absf(dx) < 150.0:
		inp.move_x = -dir
		return inp
	var a := target.current_attack()
	if a != null and target.attack_phase() == Fighter.Phase.WINDUP and a.windup - target.state_frame <= 5 and absf(dx) < 150.0:
		inp.move_x = dir
		# Alternates between parrying and dodging through.
		@warning_ignore("integer_division")
		if (world.frame / 240) % 2 == 0:
			inp.attack = true
		else:
			inp.dodge = true
		return inp
	if absf(dx) > 88.0:
		inp.move_x = dir
		inp.jump = world.frame % 170 == 0
		inp.jump_held = true
	else:
		inp.move_x = dir * 0.02
		inp.attack = world.frame % 9 == 0
	return inp
