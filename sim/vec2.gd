class_name Vec2
extends RefCounted
## A point in world units, float64. Swift's `Vec2` is a value type: copy() wherever Swift copies.
## Never use Godot's `Vector2` in the simulation; it is float32 and breaks parity.

var x: float
var y: float


func _init(px: float = 0.0, py: float = 0.0) -> void:
	x = px
	y = py


func copy() -> Vec2:
	return Vec2.new(x, y)


func equals(o: Vec2) -> bool:
	return x == o.x and y == o.y


func to_canon() -> Dictionary:
	return {"x": x, "y": y}


static func zero() -> Vec2:
	return Vec2.new(0.0, 0.0)


static func from_data(d: Dictionary) -> Vec2:
	return Vec2.new(float(d.x), float(d.y))
