class_name SkLabel
extends Node2D
## SKLabelNode: text placed by horizontalAlignmentMode and verticalAlignmentMode (default centre, baseline),
## with newlines making more lines. Flips itself back upright under the y-flipped layers.

enum H { CENTER, LEFT, RIGHT }
enum V { BASELINE, CENTER, TOP, BOTTOM }

static var _fonts: Dictionary = {}

var text := "":
	set(v):
		if v != text:
			text = v
			queue_redraw()
var font_size := 16.0:
	set(v):
		font_size = v
		queue_redraw()
var color := Color.WHITE:
	set(v):
		if v != color:
			color = v
			queue_redraw()
var h_align := H.CENTER:
	set(v):
		h_align = v
		queue_redraw()
var v_align := V.BASELINE:
	set(v):
		v_align = v
		queue_redraw()
var font: Font
var alpha: float:
	get:
		return modulate.a
	set(v):
		modulate.a = v


## weight: "medium", "demibold", "bold", "heavy" (Avenir Next's weights 500/600/700/900) or "mono" (Menlo).
static func make(p_text: String, size: float, p_color: Color, weight := "heavy") -> SkLabel:
	var l := SkLabel.new()
	l.text = p_text
	l.font_size = size
	l.color = p_color
	l.font = font_for(weight)
	return l


## The HUD family, bundled so every platform draws the same weights (Godot only reaches Avenir Next's Bold
## face, and Windows has no Avenir). Both are SIL OFL; `--hud-font NunitoSans` picks the other one.
const HUD_FAMILIES := {"Figtree": "res://fonts/Figtree.ttf", "NunitoSans": "res://fonts/NunitoSans.ttf"}
static var hud_family := _family_from_args()
const WEIGHTS := {"medium": 500, "demibold": 600, "bold": 700, "heavy": 900}


static func _family_from_args() -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--hud-font")
	return args[i + 1] if i >= 0 and i + 1 < args.size() and HUD_FAMILIES.has(args[i + 1]) else "Figtree"


static func font_for(weight: String) -> Font:
	if not _fonts.has(weight):
		if weight == "mono":
			var m := SystemFont.new()
			m.font_names = PackedStringArray(["Menlo", "SF Mono", "Consolas", "monospace"])
			_fonts[weight] = m
		else:
			var f := FontVariation.new()
			f.base_font = load(HUD_FAMILIES[hud_family])
			f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): WEIGHTS.get(weight, 900)}
			f.fallbacks = [symbols()]
			_fonts[weight] = f
	return _fonts[weight]


## Neither family has the HUD's marks (⇄ ✦ ◆ ⚔ ▲ ▸); the system symbol fonts do, on Apple and Windows.
static func symbols() -> Font:
	if not _fonts.has("_symbols"):
		var s := SystemFont.new()
		s.font_names = PackedStringArray(["Apple Symbols", "Hiragino Sans", "Segoe UI Symbol", "Segoe UI", "DejaVu Sans"])
		_fonts["_symbols"] = s
	return _fonts["_symbols"]


func _draw() -> void:
	if text == "" or font == null:
		return
	# Drawn at a whole pixel size and scaled, so the text keeps its shape at any zoom.
	var px := maxi(1, int(round(font_size)))
	var k := font_size / float(px)
	var lines := text.split("\n")
	var ascent := font.get_ascent(px)
	var descent := font.get_descent(px)
	var line_h := font.get_height(px)
	var block := line_h * float(lines.size() - 1) + ascent + descent
	# Baseline of the first line, in the upright (y-down) frame, before scaling.
	var y0 := 0.0
	match v_align:
		V.TOP:
			y0 = ascent
		V.CENTER:
			y0 = ascent - block / 2.0
		V.BOTTOM:
			y0 = ascent - block
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, -k))
	for i in lines.size():
		var w := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var x := 0.0 if h_align == H.LEFT else (-w if h_align == H.RIGHT else -w / 2.0)
		draw_string(font, Vector2(x, y0 + line_h * float(i)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
