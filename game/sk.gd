class_name Sk
extends RefCounted
## Small helpers for writing SpriteKit code in Godot.
##
## zPosition: SpriteKit's is fractional and relative to the parent, Godot's z_index is an int and also
## relative by default. Every z is doubled, so the .5 steps the Swift code uses stay distinct.


static func z(node: CanvasItem, value: float) -> void:
	node.z_index = int(round(value * 2.0))


static func with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


## SKAction.fadeOut then removeFromParent.
static func fade_out_and_free(node: CanvasItem, duration: float, grow_to := 1.0) -> void:
	var t := node.create_tween()
	t.set_parallel(true)
	t.tween_property(node, "modulate:a", 0.0, duration)
	if grow_to != 1.0:
		t.tween_property(node, "scale", Vector2(grow_to, grow_to) * node.scale.sign(), duration)
	t.chain().tween_callback(node.queue_free)
