class_name SkLabel
extends Node2D
## SKLabelNode: text centred on its x, sitting on its baseline. Flips itself back upright under the y-flipped
## world layer.

static var _fonts: Dictionary = {}

var text := "":
	set(v):
		text = v
		queue_redraw()
var font_size := 16.0:
	set(v):
		font_size = v
		queue_redraw()
var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()
var font: Font


## "demibold" (AvenirNext-DemiBold) or "heavy" (AvenirNext-Heavy).
static func make(p_text: String, size: float, p_color: Color, weight := "heavy") -> SkLabel:
	var l := SkLabel.new()
	l.text = p_text
	l.font_size = size
	l.color = p_color
	l.font = font_for(weight)
	return l


static func font_for(weight: String) -> Font:
	if not _fonts.has(weight):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Avenir Next", "Avenir", "Helvetica Neue", "Segoe UI", "Arial"])
		f.font_weight = 600 if weight == "demibold" else 900
		_fonts[weight] = f
	return _fonts[weight]


func _draw() -> void:
	if text == "" or font == null:
		return
	# Drawn at a fixed pixel size and scaled, so the text keeps its shape at any zoom.
	var px := int(round(font_size))
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, -1) * (font_size / float(px)))
	draw_string(font, Vector2(-w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
