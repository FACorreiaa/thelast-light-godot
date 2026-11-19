class_name SkShape
extends Node2D
## SKShapeNode: fills and strokes a path. Defaults are SpriteKit's: no fill, a white 1-point stroke, no glow.
## Lives under a y-flipped layer, so paths are in the Swift scene's y-up units.
##
## Glow (SpriteKit's glowWidth) is drawn here as widening translucent strokes under the line, so it looks the
## same on every renderer. It is one place to change if a shader or HDR glow replaces it.

const _GLOW_PASSES: Array[Vector2] = [Vector2(1.0, 0.16), Vector2(0.66, 0.22), Vector2(0.33, 0.3)]

var path: SkPath:
	set(v):
		path = v
		_fills = []
		if v != null:
			for i in v.subpaths.size():
				var pts := v.subpaths[i]
				if v.closed[i] and pts.size() >= 3 and not Geometry2D.triangulate_polygon(pts).is_empty():
					_fills.append(pts)
		queue_redraw()
var fill_color := Color(0, 0, 0, 0):
	set(v):
		if v != fill_color:
			fill_color = v
			queue_redraw()
var stroke_color := Color.WHITE:
	set(v):
		if v != stroke_color:
			stroke_color = v
			queue_redraw()
var line_width := 1.0:
	set(v):
		if v != line_width:
			line_width = v
			queue_redraw()
var glow_width := 0.0:
	set(v):
		if v != glow_width:
			glow_width = v
			queue_redraw()
var round_cap := false
## SKNode.alpha: multiplies this node and its children.
var alpha: float:
	get:
		return modulate.a
	set(v):
		modulate.a = v

var _fills: Array[PackedVector2Array] = []


static func make(p: SkPath, fill := Color(0, 0, 0, 0), stroke := Color.WHITE, width := 1.0, glow := 0.0) -> SkShape:
	var s := SkShape.new()
	s.path = p
	s.fill_color = fill
	s.stroke_color = stroke
	s.line_width = width
	s.glow_width = glow
	return s


func _draw() -> void:
	if path == null:
		return
	if glow_width > 0.0 and stroke_color.a > 0.0:
		for g in _GLOW_PASSES:
			var c := stroke_color
			c.a *= g.y
			_stroke(c, line_width + glow_width * 2.0 * g.x)
	for pts in _fills:
		if fill_color.a > 0.0:
			draw_colored_polygon(pts, fill_color)
	if stroke_color.a > 0.0 and line_width > 0.0:
		_stroke(stroke_color, line_width)


func _stroke(c: Color, w: float) -> void:
	for i in path.subpaths.size():
		var pts := path.subpaths[i]
		if pts.size() < 2:
			continue
		if path.closed[i]:
			pts = pts.duplicate()
			pts.append(pts[0])
		draw_polyline(pts, c, w, true)
		if round_cap and not path.closed[i]:
			draw_circle(pts[0], w / 2.0, c, true, -1.0, true)
			draw_circle(pts[-1], w / 2.0, c, true, -1.0, true)


## A copy of this shape with the same look, for ghosts (Node.duplicate() skips script fields).
func clone() -> SkShape:
	var s := SkShape.make(path, fill_color, stroke_color, line_width, glow_width)
	s.round_cap = round_cap
	s.transform = transform
	s.z_index = z_index
	s.modulate = modulate
	s.visible = visible
	return s


## Copies a figure tree: SkShapes by their look, sprites and plain nodes by Godot's duplicate.
static func clone_tree(node: Node) -> Node:
	var out: Node
	if node is SkShape:
		out = (node as SkShape).clone()
	elif node is Node2D and node.get_script() == null and not (node is Sprite2D):
		var n2 := Node2D.new()
		n2.transform = (node as Node2D).transform
		n2.z_index = (node as Node2D).z_index
		n2.modulate = (node as Node2D).modulate
		n2.visible = (node as Node2D).visible
		out = n2
	else:
		out = node.duplicate(0)
		for c in out.get_children():
			c.free()
	for c in node.get_children():
		out.add_child(clone_tree(c))
	return out
