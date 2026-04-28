# BallVisual.gd
# Drawn ball — radial-gradient white→teal→dark-teal core with a soft glow halo.
# Sits as a child of Ball and follows it via the parent transform.
extends Node2D

const CORE_COLOR  := Color(1.0, 1.0, 1.0, 1.0)
const MID_COLOR   := Color(0.0, 0.898, 0.784, 1.0)   # #00E5C8
const OUTER_COLOR := Color(0.0, 0.545, 0.471, 1.0)   # #008b78
const GLOW_COLOR  := Color(0.0, 0.898, 0.784, 0.5)

# Visual radius. Collision radius is 10 px; visual is sized to match.
@export var radius: float = 10.0

func _draw() -> void:
	# Soft outer glow — two faint rings expanding past the body.
	draw_circle(Vector2.ZERO, radius + 4.0, GLOW_COLOR * Color(1, 1, 1, 0.18))
	draw_circle(Vector2.ZERO, radius + 2.0, GLOW_COLOR * Color(1, 1, 1, 0.35))

	# Three-stop radial gradient faked with concentric circles.
	draw_circle(Vector2.ZERO, radius, OUTER_COLOR)
	draw_circle(Vector2.ZERO, radius * 0.78, MID_COLOR)
	# Off-center bright highlight (top-left, mimicking the design's 35% 35%).
	draw_circle(Vector2(-radius * 0.22, -radius * 0.22), radius * 0.34, CORE_COLOR)
