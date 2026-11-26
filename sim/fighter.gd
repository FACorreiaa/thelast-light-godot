class_name Fighter
extends RefCounted
## One fighter. A Swift struct: World copies it (copy()) exactly where Swift copies it.

enum St { IDLE, RUN, AIR, ATTACK, DODGE, HITSTUN, STAGGERED, FUSE, GUARD_STANCE, PHASE_SHIFT, DEAD }
enum Phase { NONE, WINDUP, ACTIVE, RECOVERY }

const STATE_NAMES := ["idle", "run", "air", "attack", "dodge", "hitstun", "staggered", "fuse",
	"guardStance", "phaseShift", "dead"]

var id: int
## FighterKind case name ("caelen", "scrapDrone").
var kind: String
## "hero" or "enemy".
var team: String
var spec: Specs.FighterSpec
## Centre of the feet.
var pos: Vec2
var vel: Vec2 = Vec2.zero()
var facing: float
var hp: float
var state: St = St.IDLE
## The swing in progress, while state is ATTACK.
var attack_index: int = 0
var state_frame: int = 0
var state_duration: int = 0
var on_ground: bool = true
var dodge_cooldown: int = 0
var invulnerable: int = 0
var ai_cooldown: int = 0
var ai_aux: int = 0
var next_attack: int = 0
var special_cooldown: int = 0
var marked_frames: int = 0
var slow_frames: int = 0
var phase: int = 1
var flying: bool = false
var descending: bool = false
var ai_aux2: int = 0
var ai_aux3: int = 0
var holding: bool = false
var in_light: bool = false
## An attack whose effect the world applies after this frame; -1 for none.
var pending_effect: int = -1
var mark_scale: float = 1.0
var swing_scale: float = 1.0
var special_buffer: int = 0
var wants_command: bool = false
var wants_special: bool = false
var expires: int = 0
var awake: bool = true
## Index of the platform it stands on; -1 for none.
var ground_index: int = -1
var coyote: int = 0
var patrol_frames: int = 0
var stranded_frames: int = 0
## Last safe ground, or null.
var last_safe: Vec2 = null
var attack_buffer: int = 0
var jump_buffer: int = 0
var dodge_buffer: int = 0
## Set of ids already hit by the current swing (keys only).
var hit_ids: Dictionary = {}
var since_hit: int = 0
## Port-only: how far along its ability track this hero is (Progression); 0 for everyone else.
var step: int = 0
## Port-only: the ability swing in progress (Progression), by id, or "" for a swing from the kit's own list.
## `attack_index` then names the kit swing it is drawn like.
var slot: String = ""
var slot_attack: Specs.AttackSpec = null
## Port-only: frames left in which an attack press is a Riposte (Caelen, after a parry).
var riposte_frames: int = 0
## Port-only: while marked, this fighter's shield does not stop the heroes (Caelen's Break Guard).
var mark_breaks_guard: bool = false


static func make(p_id: int, p_kind: String, p_team: String, p_spec: Specs.FighterSpec, p_pos: Vec2,
		p_facing: float) -> Fighter:
	var f := Fighter.new()
	f.id = p_id
	f.kind = p_kind
	f.team = p_team
	f.spec = p_spec
	f.pos = p_pos
	f.facing = p_facing
	f.hp = p_spec.max_hp
	return f


func copy() -> Fighter:
	var f := Fighter.new()
	f.id = id
	f.kind = kind
	f.team = team
	f.spec = spec
	f.pos = pos.copy()
	f.vel = vel.copy()
	f.facing = facing
	f.hp = hp
	f.state = state
	f.attack_index = attack_index
	f.state_frame = state_frame
	f.state_duration = state_duration
	f.on_ground = on_ground
	f.dodge_cooldown = dodge_cooldown
	f.invulnerable = invulnerable
	f.ai_cooldown = ai_cooldown
	f.ai_aux = ai_aux
	f.next_attack = next_attack
	f.special_cooldown = special_cooldown
	f.marked_frames = marked_frames
	f.slow_frames = slow_frames
	f.phase = phase
	f.flying = flying
	f.descending = descending
	f.ai_aux2 = ai_aux2
	f.ai_aux3 = ai_aux3
	f.holding = holding
	f.in_light = in_light
	f.pending_effect = pending_effect
	f.mark_scale = mark_scale
	f.swing_scale = swing_scale
	f.special_buffer = special_buffer
	f.wants_command = wants_command
	f.wants_special = wants_special
	f.expires = expires
	f.awake = awake
	f.ground_index = ground_index
	f.coyote = coyote
	f.patrol_frames = patrol_frames
	f.stranded_frames = stranded_frames
	f.last_safe = last_safe.copy() if last_safe != null else null
	f.attack_buffer = attack_buffer
	f.jump_buffer = jump_buffer
	f.dodge_buffer = dodge_buffer
	f.hit_ids = hit_ids.duplicate()
	f.since_hit = since_hit
	f.step = step
	f.slot = slot
	f.slot_attack = slot_attack
	f.riposte_frames = riposte_frames
	f.mark_breaks_guard = mark_breaks_guard
	return f


func is_alive() -> bool:
	return state != St.DEAD


func is_attacking() -> bool:
	return state == St.ATTACK


func hurtbox() -> Box:
	return Box.new(pos.x - spec.width / 2.0, pos.y, pos.x + spec.width / 2.0, pos.y + spec.height)


## The swing in progress, or null.
func current_attack() -> Specs.AttackSpec:
	if state != St.ATTACK:
		return null
	return slot_attack if slot_attack != null else spec.attacks[attack_index]


func attack_phase() -> Phase:
	var a := current_attack()
	if a == null:
		return Phase.NONE
	if state_frame < a.windup:
		return Phase.WINDUP
	if state_frame < a.windup + a.active:
		return Phase.ACTIVE
	return Phase.RECOVERY


## The area a swing hits, while it is in its active frames; null otherwise.
func hitbox() -> Box:
	var a := current_attack()
	if a == null or attack_phase() != Phase.ACTIVE or not a.is_strike():
		return null
	if a.both_sides:
		return Box.new(pos.x - spec.width / 2.0 - a.reach, pos.y + a.y_offset,
			pos.x + spec.width / 2.0 + a.reach, pos.y + a.y_offset + a.height)
	var front := pos.x + facing * (spec.width / 2.0 + a.reach)
	return Box.new(Sw.min_d(pos.x, front), pos.y + a.y_offset, Sw.max_d(pos.x, front), pos.y + a.y_offset + a.height)


func is_dodge_invulnerable() -> bool:
	return state == St.DODGE and spec.dodge != null and spec.dodge.invulnerable.contains(state_frame)


func is_parrying() -> bool:
	return state == St.ATTACK and state_frame < spec.parry_window


## True while a frontal hit would be stopped by its shield.
func is_guarding() -> bool:
	if not spec.frontal_block:
		return false
	if mark_breaks_guard and marked_frames > 0:
		return false
	if state == St.IDLE or state == St.RUN:
		return true
	if spec.guards_while_swinging and state == St.ATTACK:
		return attack_phase() != Phase.RECOVERY
	return false


## True while an armoured fighter can be hurt.
func is_open() -> bool:
	return not spec.armored or attack_phase() == Phase.RECOVERY or state == St.STAGGERED


func is_actionable() -> bool:
	return state == St.IDLE or state == St.RUN or state == St.AIR


func enter(new_state: St, duration: int = 0) -> void:
	state = new_state
	state_frame = 0
	state_duration = duration
	slot = ""
	slot_attack = null


func enter_attack(index: int) -> void:
	attack_index = index
	enter(St.ATTACK)


func state_canon() -> Variant:
	if state == St.ATTACK:
		if slot != "":
			return {"case": "attack", "_0": attack_index, "slot": slot}
		return {"case": "attack", "_0": attack_index}
	return STATE_NAMES[state]


func to_canon() -> Dictionary:
	return {
		"id": id, "kind": kind, "team": team, "pos": pos, "vel": vel, "facing": facing, "hp": hp,
		"state": state_canon(), "stateFrame": state_frame, "stateDuration": state_duration,
		"onGround": on_ground, "dodgeCooldown": dodge_cooldown, "invulnerable": invulnerable,
		"aiCooldown": ai_cooldown, "aiAux": ai_aux, "nextAttack": next_attack,
		"specialCooldown": special_cooldown, "markedFrames": marked_frames, "slowFrames": slow_frames,
		"phase": phase, "flying": flying, "descending": descending, "aiAux2": ai_aux2, "aiAux3": ai_aux3,
		"holding": holding, "inLight": in_light,
		"pendingEffect": pending_effect if pending_effect >= 0 else null,
		"markScale": mark_scale, "swingScale": swing_scale, "specialBuffer": special_buffer,
		"wantsCommand": wants_command, "wantsSpecial": wants_special, "expires": expires,
		"awake": awake, "groundIndex": ground_index if ground_index >= 0 else null, "coyote": coyote,
		"patrolFrames": patrol_frames, "strandedFrames": stranded_frames, "lastSafe": last_safe,
		"attackBuffer": attack_buffer, "jumpBuffer": jump_buffer, "dodgeBuffer": dodge_buffer,
		"hitIDs": Canon.int_set(hit_ids), "sinceHit": since_hit,
	}.merged(_port_canon())


## Port-only state, written only when it differs from its default, so a step-0 run hashes as it always has.
func _port_canon() -> Dictionary:
	var out := {}
	if step != 0:
		out["step"] = step
	if riposte_frames != 0:
		out["riposteFrames"] = riposte_frames
	if mark_breaks_guard:
		out["markBreaksGuard"] = true
	return out


static func team_of(k: String) -> String:
	return "hero" if k in ["caelen", "orion", "seraphine", "nimue", "decoy"] else "enemy"
