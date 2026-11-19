class_name Sound
extends Node
## Placeholder sound. Port of Sound.swift: every effect is computed at launch from tones and noise, so there are
## no audio files yet. Recorded or designed sound replaces `_render` later without touching the callers.

const RATE := 44100
const EFFECTS := ["swing", "heavySwing", "hit", "heavyHit", "hurt", "blocked", "parry", "jump", "land", "dodge",
	"pickup", "secret", "checkpoint", "join", "fuse", "explosion", "fall", "warning", "bossWake", "bossDown",
	"clear", "down"]

## 0 to 1, as the Swift mixer's outputVolume.
var volume := 0.7
var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next := 0
## The frame an effect last started on, so the same sound is not stacked many times in one instant.
var _last_played: Dictionary = {}
var _tick := 0
var _task := -1

# Noise state, reset per effect as Swift's `var noise = Noise()` is.
var _noise_state := 0x12345678
var _noise_smooth := 0.0


func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	# About a third of a second of synthesis on a Mac: done off the main thread so launch does not wait.
	# Sounds asked for before it finishes are skipped.
	_task = WorkerThreadPool.add_task(_render_all)


func _render_all() -> void:
	var out := {}
	for e: String in EFFECTS:
		out[e] = _render(e)
	_rendered.call_deferred(out)


func _rendered(out: Dictionary) -> void:
	_streams = out
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## Call once per drawn frame; it only counts time for the stacking guard.
func advance() -> void:
	_tick += 1


func play(effect: String, p_volume := 1.0) -> void:
	if volume <= 0.001 or not _streams.has(effect):
		return
	if _last_played.has(effect) and _tick - int(_last_played[effect]) < 2:
		return
	_last_played[effect] = _tick
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[effect]
	player.volume_db = linear_to_db(maxf(0.0001, p_volume * volume))
	player.play()


# MARK: Synthesis


## White noise through a one-pole low-pass; `cutoff` near 1 is bright, near 0 is a rumble.
func _noise(cutoff: float) -> float:
	_noise_state = (_noise_state * 1664525 + 1013904223) & 0xFFFFFFFF
	var white := float(_noise_state >> 8) / float(1 << 23) - 1.0
	_noise_smooth += (white - _noise_smooth) * cutoff
	return _noise_smooth


## A sine whose pitch glides from `from` to `to` over the sound (`length` seconds).
static func _glide(t: float, length: float, from: float, to: float) -> float:
	# Phase of a linear sweep: the integral of the frequency.
	return sin(TAU * (from * t + (to - from) * t * t / (2.0 * maxf(length, 0.0001))))


static func _decay(p: float, sharpness: float) -> float:
	return exp(-sharpness * p)


static func _sq(x: float, amp: float) -> float:
	return amp if x > 0.0 else -amp


func _render(effect: String) -> AudioStreamWAV:
	_noise_state = 0x12345678
	_noise_smooth = 0.0
	var seconds: float = {"swing": 0.12, "heavySwing": 0.2, "hit": 0.11, "heavyHit": 0.22, "hurt": 0.26, "blocked": 0.18,
		"parry": 0.45, "jump": 0.1, "land": 0.08, "dodge": 0.16, "pickup": 0.2, "secret": 0.5, "checkpoint": 0.4,
		"join": 0.5, "fuse": 0.3, "explosion": 0.6, "fall": 0.4, "warning": 0.5, "bossWake": 1.4, "bossDown": 1.6,
		"clear": 0.9, "down": 0.9}[effect]
	var count := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var p := float(i) / float(count)
		var t := float(i) / float(RATE)
		var s := 0.0
		match effect:
			"swing":
				s = _noise(0.25 + 0.5 * p) * sin(PI * p) * 0.5
			"heavySwing":
				s = _noise(0.12 + 0.4 * p) * sin(PI * p) * 0.7
			"hit":
				s = (_glide(t, seconds, 210, 90) * 0.6 + _noise(0.6) * 0.5) * _decay(p, 6)
			"heavyHit":
				s = (_glide(t, seconds, 150, 45) * 0.9 + _noise(0.5) * 0.6) * _decay(p, 5)
			"hurt":
				s = (_glide(t, seconds, 320, 110) * 0.6 + _noise(0.3) * 0.5) * _decay(p, 4)
			"blocked":
				s = (sin(TAU * 1240 * t) * 0.35 + sin(TAU * 1830 * t) * 0.25 + _noise(0.9) * 0.2) * _decay(p, 7)
			"parry":
				s = (sin(TAU * 1760 * t) * 0.4 + sin(TAU * 2640 * t) * 0.3 + sin(TAU * 3520 * t) * 0.15) * _decay(p, 5)
			"jump":
				s = _glide(t, seconds, 300, 560) * 0.25 * _decay(p, 3)
			"land":
				s = (_glide(t, seconds, 120, 60) * 0.4 + _noise(0.2) * 0.3) * _decay(p, 6)
			"dodge":
				s = _noise(0.7 - 0.5 * p) * sin(PI * p) * 0.45
			"pickup":
				s = sin(TAU * (1320.0 if p < 0.4 else 1760.0) * t) * 0.3 * _decay(p, 3)
			"secret":
				var note := 1047.0 if p < 0.25 else (1319.0 if p < 0.5 else (1568.0 if p < 0.75 else 2093.0))
				s = sin(TAU * note * t) * 0.3 * _decay(p, 2)
			"checkpoint":
				s = (sin(TAU * 660 * t) + sin(TAU * 990 * t)) * 0.2 * _decay(p, 3)
			"join":
				s = (sin(TAU * (523.0 if p < 0.5 else 784.0) * t) + sin(TAU * (659.0 if p < 0.5 else 1047.0) * t)) * 0.2 * _decay(p, 2)
			"fuse":
				s = _sq(sin(TAU * 1500 * t), 0.2) * (1.0 if int(p * 6.0) % 2 == 0 else 0.0)
			"explosion":
				s = (_noise(0.25 - 0.2 * p) * 1.2 + _glide(t, seconds, 90, 30) * 0.7) * _decay(p, 4)
			"fall":
				s = _glide(t, seconds, 500, 80) * 0.4 * _decay(p, 2)
			"warning":
				s = _sq(sin(TAU * 110 * t), 0.25) * sin(PI * p) + _glide(t, seconds, 220, 440) * 0.15 * p
			"bossWake":
				s = (_noise(0.04) * 2.5 + sin(TAU * 55 * t) * 0.6 + _glide(t, seconds, 80, 160) * 0.3) * sin(PI * p)
			"bossDown":
				s = (_noise(0.2 - 0.18 * p) * 1.3 + _glide(t, seconds, 200, 28) * 0.8) * _decay(p, 2.5)
			"clear":
				var note := 523.0 if p < 0.2 else (659.0 if p < 0.4 else (784.0 if p < 0.6 else 1047.0))
				s = (sin(TAU * note * t) + sin(TAU * note * 1.5 * t) * 0.4) * 0.25 * _decay(p, 1.5)
			"down":
				var note := 330.0 if p < 0.33 else (262.0 if p < 0.66 else 196.0)
				s = sin(TAU * note * t) * 0.35 * _decay(p, 1.5)
		# A few milliseconds of fade at both ends, so nothing clicks.
		var edge := minf(1.0, minf(float(i) / 90.0, float(count - i) / 200.0))
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * edge * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
