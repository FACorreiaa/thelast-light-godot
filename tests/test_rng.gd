extends SceneTree
# Replays tests/golden/rng.txt (written by the Swift oracle) against SeededRandom.

func _init() -> void:
	var rng: SeededRandom
	var bad := 0
	var n := 0
	for line in FileAccess.get_file_as_string("res://tests/golden/rng.txt").split("\n", false):
		var f := line.split(" ")
		var got := ""
		var want := ""
		match f[0]:
			"seed":
				rng = SeededRandom.new(int(f[1]))
				continue
			"next":
				got = str(rng.next()); want = f[1]
			"closed":
				got = str(rng.int_closed(int(f[1]), int(f[2]))); want = f[3]
			"half":
				got = str(rng.int_half_open(int(f[1]), int(f[2]))); want = f[3]
			"unit":
				got = _bits(rng.double_half_open(0.0, 1.0)); want = f[1]
			"double":
				got = _bits(rng.double_half_open(_f(f[1]), _f(f[2]))); want = f[3]
			"dclosed":
				got = _bits(rng.double_closed(_f(f[1]), _f(f[2]))); want = f[3]
			"bool":
				got = "1" if rng.coin() else "0"; want = f[1]
		n += 1
		var state_ok := str(rng.state) == f[f.size() - 1]
		if got != want or not state_ok:
			bad += 1
			if bad <= 8:
				print("MISMATCH line %d %s: got %s want %s, state %s want %s" % [n, f[0], got, want, rng.state, f[f.size() - 1]])
	print("rng: %d calls, %d mismatched" % [n, bad])
	quit(1 if bad > 0 else 0)

func _bits(x: float) -> String:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	return str(b.decode_s64(0))


func _f(bits_text: String) -> float:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_s64(0, int(bits_text))
	return b.decode_double(0)
