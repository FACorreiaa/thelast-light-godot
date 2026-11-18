class_name Canon
extends RefCounted
## The canonical state tree both engines hash (see tools/oracle/README.md).
## Values: null, bool, int, float, String, Array, Dictionary with String keys, or an object with
## to_canon(). Objects and dictionaries are written with keys in byte order. An event dictionary
## holding only "case" is a payload-less enum and becomes its case name.


static func of(v: Variant) -> Variant:
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return v
		TYPE_STRING_NAME:
			return String(v)
		TYPE_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var out: Array = []
			for x: Variant in v:
				out.append(of(x))
			return out
		TYPE_DICTIONARY:
			var d: Dictionary = v
			if d.size() == 1 and d.has("case"):
				return String(d["case"])
			var o := {}
			for k: Variant in d:
				o[str(k)] = of(d[k])
			return o
		TYPE_OBJECT:
			return of((v as Object).call("to_canon"))
	push_error("Canon: unsupported type %s" % type_string(typeof(v)))
	return null


## A sorted array of ints: Swift's Set<Int> in canonical form.
static func int_set(s: Dictionary) -> Array:
	var keys: Array = s.keys()
	keys.sort()
	return keys


static func string_set(s: Dictionary) -> Array:
	var keys: Array = s.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return _bytes_less(a, b))
	return keys


static func hash_hex(v: Variant) -> String:
	var buf := PackedByteArray()
	_encode(of(v), buf)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(buf)
	return ctx.finish().slice(0, 8).hex_encode()


static func _encode(v: Variant, buf: PackedByteArray) -> void:
	match typeof(v):
		TYPE_NIL:
			buf.append(0x6E)  # n
		TYPE_BOOL:
			buf.append(0x62)  # b
			buf.append(1 if v else 0)
		TYPE_INT:
			buf.append(0x69)  # i
			var o := buf.size()
			buf.resize(o + 8)
			buf.encode_s64(o, v)
		TYPE_FLOAT:
			buf.append(0x66)  # f
			var o := buf.size()
			buf.resize(o + 8)
			buf.encode_double(o, v)
		TYPE_STRING:
			buf.append(0x73)  # s
			_str(v, buf)
		TYPE_ARRAY:
			var a: Array = v
			buf.append(0x61)  # a
			_u32(a.size(), buf)
			for x: Variant in a:
				_encode(x, buf)
		TYPE_DICTIONARY:
			var d: Dictionary = v
			buf.append(0x6F)  # o
			_u32(d.size(), buf)
			var keys: Array = d.keys()
			keys.sort_custom(func(a: String, b: String) -> bool: return _bytes_less(a, b))
			for k: String in keys:
				_str(k, buf)
				_encode(d[k], buf)


static func _u32(n: int, buf: PackedByteArray) -> void:
	var o := buf.size()
	buf.resize(o + 4)
	buf.encode_u32(o, n)


static func _str(s: String, buf: PackedByteArray) -> void:
	var b := s.to_utf8_buffer()
	_u32(b.size(), buf)
	buf.append_array(b)


static func _bytes_less(a: String, b: String) -> bool:
	var x := a.to_utf8_buffer()
	var y := b.to_utf8_buffer()
	for i in mini(x.size(), y.size()):
		if x[i] != y[i]:
			return x[i] < y[i]
	return x.size() < y.size()


## Reads a canonical float written by the oracle as "f:<decimal>:<hex bits>".
static func float_from_tag(s: String) -> float:
	var hex := s.get_slice(":", 2)
	var b := PackedByteArray()
	b.resize(8)
	var hi := ("0".repeat(16 - hex.length()) + hex)
	for i in 8:
		b[7 - i] = hi.substr(i * 2, 2).hex_to_int()
	return b.decode_double(0)


## Turns parsed oracle JSON (floats tagged, ints parsed as float) back into a canonical tree.
static func from_oracle_json(v: Variant) -> Variant:
	match typeof(v):
		TYPE_STRING:
			var s: String = v
			return float_from_tag(s) if s.begins_with("f:") else s
		TYPE_FLOAT:
			return int(v)
		TYPE_ARRAY:
			var out: Array = []
			for x: Variant in v:
				out.append(from_oracle_json(x))
			return out
		TYPE_DICTIONARY:
			var o := {}
			for k: Variant in v:
				o[k] = from_oracle_json(v[k])
			return o
	return v
