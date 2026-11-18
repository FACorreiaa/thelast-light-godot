## Pure GDScript stand-in for ActionCore: RefCounted, no nodes, fixed 60 Hz
## step, 64-bit float state (GDScript float == Swift Double). Must produce
## the same hash as the Go and C# spikes after 600 scripted ticks.
class_name SimWorld
extends RefCounted

const DT: float = 1.0 / 60.0

var level: Dictionary
var tick: int = 0
var x: float
var y: float
var vx: float = 0.0
var vy: float = 0.0
var facing: float = 1.0
var on_ground: bool = true
var attack_t: int = 0


func _init(lvl: Dictionary) -> void:
	level = lvl
	x = float(lvl.width) / 2.0
	y = float(lvl.floor)


func step(move: float, jump: bool, attack: bool) -> void:
	tick += 1
	vx = move * float(level.speed)
	if move != 0.0:
		facing = signf(move)
	if jump and on_ground:
		vy = -float(level.jump)
		on_ground = false
	if attack and attack_t == 0:
		attack_t = 18
	if attack_t > 0:
		attack_t -= 1
	vy += float(level.gravity) * DT
	x += vx * DT
	y += vy * DT
	if y >= float(level.floor):
		y = float(level.floor)
		vy = 0.0
		on_ground = true
	x = minf(maxf(x, 20.0), float(level.width) - 20.0)


## First 8 bytes (hex) of SHA-256 over x, y, vx, vy, facing as LE float64,
## then attack_t as LE int32. Same layout in every spike.
func state_hash() -> String:
	var buf := PackedByteArray()
	buf.resize(44)
	var o := 0
	for f: float in [x, y, vx, vy, facing]:
		buf.encode_double(o, f)
		o += 8
	buf.encode_s32(o, attack_t)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(buf)
	return ctx.finish().slice(0, 8).hex_encode()


## Deterministic autopilot: [move, jump, attack] for a given tick.
static func script(t: int) -> Array:
	var move := -1.0 if (t / 120) % 2 == 1 else 1.0
	return [move, t % 90 == 0, t % 45 == 0]
