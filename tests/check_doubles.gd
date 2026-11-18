extends SceneTree
# Proves Godot's JSON reader turns every decimal the Swift exporter wrote back into the same bits.

func _bits_hex(f: float) -> String:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, f)
	b.reverse()
	var h := b.hex_encode().lstrip("0")
	return h if h != "" else "0"

func _init() -> void:
	var pairs: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/doubles.json"))
	var bad := 0
	for p: Array in pairs:
		var text: String = p[0]
		var parsed: float = (JSON.parse_string("[" + text + "]") as Array)[0]
		if _bits_hex(parsed) != String(p[1]):
			bad += 1
			if bad <= 10:
				print("MISMATCH %s → %s want %s" % [text, _bits_hex(parsed), p[1]])
	print("doubles: %d checked, %d mismatched" % [pairs.size(), bad])
	quit(1 if bad > 0 else 0)
