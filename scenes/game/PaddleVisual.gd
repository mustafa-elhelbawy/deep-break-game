# PaddleVisual.gd
# Drawn paddle body — rounded teal bar with top/bottom shading and a soft outer
# glow halo. Owned by Paddle. Horizontal scale.x is used by the Wide power-up
# to match the visual to the expanded collision shape.
extends Node2D

const TOP_COLOR    := Color(0.310, 0.914, 0.835, 1.0) # #4FE9D5
const MID_COLOR    := Color(0.0,   0.898, 0.784, 1.0) # #00E5C8
const BOTTOM_COLOR := Color(0.0,   0.659, 0.561, 1.0) # #00A88F
const HIGHLIGHT    := Color(1.0,   1.0,   1.0,   0.4)
const GLOW_COLOR   := Color(0.0,   0.898, 0.784, 1.0)

@export var width: float  = 120.0
@export var height: float = 16.0
@export var corner_radius: float = 4.0

func _draw() -> void:
	var half_w: float = width  * 0.5
	var half_h: float = height * 0.5

	# Outer glow halos behind the body — wider/taller, low alpha.
	_draw_rounded_rect(
		Rect2(Vector2(-half_w - 8.0, -half_h - 6.0),
		      Vector2(width + 16.0, height + 12.0)),
		corner_radius + 6.0,
		GLOW_COLOR * Color(1, 1, 1, 0.18)
	)
	_draw_rounded_rect(
		Rect2(Vector2(-half_w - 4.0, -half_h - 3.0),
		      Vector2(width + 8.0, height + 6.0)),
		corner_radius + 3.0,
		GLOW_COLOR * Color(1, 1, 1, 0.32)
	)

	# Bottom shadow stripe (drawn first so the mid body covers most of it).
	_draw_rounded_rect(
		Rect2(Vector2(-half_w, -half_h), Vector2(width, height)),
		corner_radius,
		BOTTOM_COLOR
	)

	# Mid body, slightly inset from the bottom — leaves a 2 px darker rim.
	_draw_rounded_rect(
		Rect2(Vector2(-half_w, -half_h), Vector2(width, height - 2.0)),
		corner_radius,
		MID_COLOR
	)

	# Top accent stripe — first ~40% of the bar height in lighter teal.
	_draw_rounded_rect(
		Rect2(Vector2(-half_w + 1.0, -half_h + 1.0),
		      Vector2(width - 2.0, height * 0.45)),
		corner_radius - 1.0,
		TOP_COLOR
	)

	# Single-pixel bright highlight along the top edge.
	draw_rect(
		Rect2(Vector2(-half_w + corner_radius, -half_h + 1.0),
		      Vector2(width - corner_radius * 2.0, 1.0)),
		HIGHLIGHT,
		true
	)


# Draws a filled rounded rectangle by stacking strips and corner circles. Cheap
# and accurate enough for the paddle and glow halos at this scale.
func _draw_rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	radius = min(radius, min(rect.size.x, rect.size.y) * 0.5)
	var inner := rect.grow(-radius)
	# Center fill (between corners).
	draw_rect(inner, color, true)
	# Top/bottom strips between corner circles.
	draw_rect(Rect2(Vector2(inner.position.x, rect.position.y),
	                Vector2(inner.size.x, radius)), color, true)
	draw_rect(Rect2(Vector2(inner.position.x, inner.end.y),
	                Vector2(inner.size.x, radius)), color, true)
	# Left/right strips between corner circles.
	draw_rect(Rect2(Vector2(rect.position.x, inner.position.y),
	                Vector2(radius, inner.size.y)), color, true)
	draw_rect(Rect2(Vector2(inner.end.x, inner.position.y),
	                Vector2(radius, inner.size.y)), color, true)
	# Corner discs.
	draw_circle(inner.position,                         radius, color)
	draw_circle(Vector2(inner.end.x, inner.position.y), radius, color)
	draw_circle(Vector2(inner.position.x, inner.end.y), radius, color)
	draw_circle(inner.end,                              radius, color)
