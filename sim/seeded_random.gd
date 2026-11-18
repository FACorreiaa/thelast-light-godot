class_name SeededRandom
extends RefCounted
## SplitMix64, bit-for-bit the Swift `SeededRandom`, plus the Swift standard library's ways of
## turning its output into ranges (`Int.random(in:)`, `Double.random(in:)`, `Bool.random()`).
##
## The 64-bit state is unsigned in Swift. GDScript ints are signed 64-bit, and signed overflow is
## not something to rely on across compilers, so additions and multiplications go through 16-bit
## limbs, where nothing can overflow. XOR and shifts work on the int64 bit pattern directly.

const _MIN := -9223372036854775807 - 1
## 0x9E3779B97F4A7C15, 0xBF58476D1CE4E5B9 and 0x94D049BB133111EB as 16-bit limbs, low first.
const _GOLDEN: Array[int] = [0x7C15, 0x7F4A, 0x79B9, 0x9E37]
const _MUL1: Array[int] = [0xE5B9, 0x1CE4, 0x476D, 0xBF58]
const _MUL2: Array[int] = [0x11EB, 0x1331, 0x49BB, 0x94D0]

## The state as an int64 bit pattern.
var state: int


func _init(seed: int) -> void:
	state = seed


## The next raw 64-bit value, as an int64 bit pattern.
func next() -> int:
	state = _to_i64(_add(_limbs(state), _GOLDEN))
	var z := state
	z = _to_i64(_mul_low(_limbs(z ^ _shr(z, 30)), _MUL1))
	z = _to_i64(_mul_low(_limbs(z ^ _shr(z, 27)), _MUL2))
	return z ^ _shr(z, 31)


## Swift `Int.random(in: lo...hi, using:)`.
func int_closed(lo: int, hi: int) -> int:
	return lo + _next_below(hi - lo + 1)


## Swift `Int.random(in: lo..<hi, using:)`.
func int_half_open(lo: int, hi: int) -> int:
	assert(hi > lo, "empty range")
	return lo + _next_below(hi - lo)


## Swift `Double.random(in: lo..<hi, using:)`.
func double_half_open(lo: float, hi: float) -> float:
	var delta := hi - lo
	# 53 random bits, as the standard library takes them for a Double.
	var bits := next() & 0x1FFFFFFFFFFFFF
	var unit := float(bits) / 9007199254740992.0  # times Double.ulpOfOne / 2 (2^-53), exact
	var r := delta * unit + lo
	if r == hi:
		return double_half_open(lo, hi)  # Swift draws again
	return r


## Swift `Double.random(in: lo...hi, using:)`.
func double_closed(lo: float, hi: float) -> float:
	var delta := hi - lo
	var bits := _next_below(0x20000000000001)  # 2^53 + 1
	if bits == 0x20000000000000:
		return hi
	var unit := float(bits) / 9007199254740992.0
	return delta * unit + lo


## Swift `Bool.random(using:)`.
func coin() -> bool:
	return (_shr(next(), 17) & 1) == 0


func to_canon() -> Dictionary:
	return {"state": state}


# Lemire's multiply-shift with rejection: Swift's `RandomNumberGenerator.next(upperBound:)`.
# `bound` is positive and below 2^62 here.
func _next_below(bound: int) -> int:
	var b := _limbs(bound)
	var m := _mul_full(_limbs(next()), b)
	var low := _to_i64(m.slice(0, 4))
	if _ult(low, bound):
		var t := _two64_mod(bound)
		while _ult(low, t):
			m = _mul_full(_limbs(next()), b)
			low = _to_i64(m.slice(0, 4))
	return _to_i64(m.slice(4, 8))


## 2^64 mod b, which equals Swift's `(0 &- b) % b`, for 0 < b < 2^62.
static func _two64_mod(b: int) -> int:
	var r := (1 << 62) % b
	r = (r * 2) % b
	return (r * 2) % b


## Unsigned a < b on int64 bit patterns.
static func _ult(a: int, b: int) -> bool:
	return (a ^ _MIN) < (b ^ _MIN)


## Logical shift right, 1 <= n <= 63.
static func _shr(x: int, n: int) -> int:
	return (x >> n) & ((1 << (64 - n)) - 1) if n > 1 else (x >> 1) & 0x7FFFFFFFFFFFFFFF


static func _limbs(x: int) -> Array[int]:
	return [x & 0xFFFF, (x >> 16) & 0xFFFF, (x >> 32) & 0xFFFF, (x >> 48) & 0xFFFF]


static func _to_i64(l: Array) -> int:
	var top: int = l[3]
	if top >= 0x8000:
		top -= 0x10000
	return top * 0x1000000000000 + int(l[2]) * 0x100000000 + int(l[1]) * 0x10000 + int(l[0])


static func _add(a: Array[int], b: Array[int]) -> Array[int]:
	var r: Array[int] = [0, 0, 0, 0]
	var carry := 0
	for i in 4:
		var s := a[i] + b[i] + carry
		r[i] = s & 0xFFFF
		carry = s >> 16
	return r


## The full 128-bit product as eight 16-bit limbs, low first.
static func _mul_full(a: Array[int], b: Array[int]) -> Array[int]:
	var acc: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
	for i in 4:
		for j in 4:
			acc[i + j] += a[i] * b[j]
	var carry := 0
	for k in 8:
		var v := acc[k] + carry
		acc[k] = v & 0xFFFF
		carry = v >> 16
	return acc


static func _mul_low(a: Array[int], b: Array[int]) -> Array[int]:
	return _mul_full(a, b).slice(0, 4)

