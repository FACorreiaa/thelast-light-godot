class_name Box
extends RefCounted
## An axis-aligned box, float64. A value type in Swift: copy() wherever Swift copies.

var min_x: float
var min_y: float
var max_x: float
var max_y: float


func _init(x0: float = 0.0, y0: float = 0.0, x1: float = 0.0, y1: float = 0.0) -> void:
	min_x = x0
	min_y = y0
	max_x = x1
	max_y = y1


func copy() -> Box:
	return Box.new(min_x, min_y, max_x, max_y)


func width() -> float:
	return max_x - min_x


func center() -> Vec2:
	return Vec2.new((min_x + max_x) / 2.0, (min_y + max_y) / 2.0)


func offset(dx: float, dy: float) -> Box:
	return Box.new(min_x + dx, min_y + dy, max_x + dx, max_y + dy)


func intersects(o: Box) -> bool:
	return min_x < o.max_x and o.min_x < max_x and min_y < o.max_y and o.min_y < max_y


func equals(o: Box) -> bool:
	return min_x == o.min_x and min_y == o.min_y and max_x == o.max_x and max_y == o.max_y


func to_canon() -> Dictionary:
	return {"minX": min_x, "minY": min_y, "maxX": max_x, "maxY": max_y}


static func from_data(d: Dictionary) -> Box:
	return Box.new(float(d.minX), float(d.minY), float(d.maxX), float(d.maxY))
