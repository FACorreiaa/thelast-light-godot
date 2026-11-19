class_name SkPath
extends RefCounted
## A CGPath in miniature: subpaths of points in the scene's y-up units, each open or closed.
## Curves are flattened when added, so drawing is only polygons and polylines.

var subpaths: Array[PackedVector2Array] = []
var closed: Array[bool] = []


func move_to(p: Vector2) -> SkPath:
	subpaths.append(PackedVector2Array([p]))
	closed.append(false)
	return self


func line_to(p: Vector2) -> SkPath:
	if subpaths.is_empty():
		return move_to(p)
	subpaths[-1].append(p)
	return self


## CGMutablePath.addLines(between:): starts a new subpath.
func add_lines(points: Array) -> SkPath:
	move_to(points[0])
	for i in range(1, points.size()):
		line_to(points[i])
	return self


func close() -> SkPath:
	if not closed.is_empty():
		closed[-1] = true
	return self


## CGPath.addArc(center:radius:startAngle:endAngle:clockwise:) in y-up coordinates. Joins the current
## subpath with a line, as CoreGraphics does, or starts one.
func add_arc(c: Vector2, r: float, start: float, end: float, clockwise: bool) -> SkPath:
	var sweep := end - start
	if clockwise:
		while sweep > 0.0:
			sweep -= TAU
	else:
		while sweep < 0.0:
			sweep += TAU
	var n := maxi(2, int(ceil(absf(sweep) * r / 3.0)) + 1)
	n = mini(n, 96)
	for i in n + 1:
		var a := start + sweep * float(i) / float(n)
		var p := c + Vector2(cos(a), sin(a)) * r
		if i == 0 and (subpaths.is_empty() or closed[-1]):
			move_to(p)
		else:
			line_to(p)
	return self


## CGMutablePath.addQuadCurve(to:control:), flattened.
func add_quad(to: Vector2, control: Vector2) -> SkPath:
	var from := subpaths[-1][-1]
	for i in range(1, 13):
		var t := float(i) / 12.0
		var u := 1.0 - t
		line_to(from * u * u + control * 2.0 * u * t + to * t * t)
	return self


static func rect(x: float, y: float, w: float, h: float) -> SkPath:
	return SkPath.new().add_lines([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)]).close()


## CGPath(roundedRect:cornerWidth:cornerHeight:) with equal corners, clamped to half the short side.
static func rounded_rect(x: float, y: float, w: float, h: float, r: float) -> SkPath:
	r = minf(r, minf(w, h) / 2.0)
	if r <= 0.0:
		return rect(x, y, w, h)
	var p := SkPath.new()
	p.add_arc(Vector2(x + w - r, y + r), r, -PI / 2.0, 0.0, false)
	p.add_arc(Vector2(x + w - r, y + h - r), r, 0.0, PI / 2.0, false)
	p.add_arc(Vector2(x + r, y + h - r), r, PI / 2.0, PI, false)
	p.add_arc(Vector2(x + r, y + r), r, PI, PI * 1.5, false)
	return p.close()


## CGPath(ellipseIn:).
static func ellipse(x: float, y: float, w: float, h: float) -> SkPath:
	var c := Vector2(x + w / 2.0, y + h / 2.0)
	var n := clampi(int((w + h) * 0.8), 12, 64)
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * w / 2.0, sin(a) * h / 2.0))
	var p := SkPath.new()
	p.subpaths.append(pts)
	p.closed.append(true)
	return p


## SKShapeNode(circleOfRadius:): centred on the origin.
static func circle(r: float) -> SkPath:
	return ellipse(-r, -r, r * 2.0, r * 2.0)


## SKShapeNode(rectOf:cornerRadius:): centred on the origin.
static func rect_of(w: float, h: float, r: float = 0.0) -> SkPath:
	return rounded_rect(-w / 2.0, -h / 2.0, w, h, r)


static func polygon(points: Array) -> SkPath:
	return SkPath.new().add_lines(points).close()


static func line(a: Vector2, b: Vector2) -> SkPath:
	return SkPath.new().move_to(a).line_to(b)
