# LogoGlyph.gd
# Custom-drawn title-screen emblem: a slowly rotating dashed hexagon ring
# (drawn by the Ring child) wrapping a stack of multi-colour brick outlines
# and a glowing ball with a short trail (drawn here). No images required.
extends Node2D

@export var size: float = 108.0

const BRICK_TEAL    := Color(0.0, 0.898, 0.784)    # #00E5C8
const BRICK_MAGENTA := Color(1.0, 0.310, 0.659)    # #FF4FA8
const BRICK_AMBER   := Color(1.0, 0.706, 0.329)    # #FFB454
const BRICK_VIOLET  := Color(0.545, 0.361, 0.965)  # #8B5CF6
const BALL_CORE     := Color(1.0, 1.0, 1.0)
const BALL_GLOW     := Color(0.0, 0.898, 0.784, 0.55)
const TRAIL_COLOR   := Color(0.0, 0.898, 0.784)

func _draw() -> void:
	# Source viewBox is 100×100 centered on (50,50); recenter to (0,0) and
	# scale so the glyph spans `size` × `size`.
	var s: float = size / 100.0

	var bricks := [
		[Vector2(28, 38), Vector2(20, 8), BRICK_TEAL],
		[Vector2(50, 38), Vector2(20, 8), BRICK_MAGENTA],
		[Vector2(34, 48), Vector2(20, 8), BRICK_AMBER],
		[Vector2(56, 48), Vector2(14, 8), BRICK_VIOLET],
	]
	for b in bricks:
		var pos:    Vector2 = (b[0] - Vector2(50, 50)) * s
		var dim:    Vector2 = b[1] * s
		var stroke: Color   = b[2]
		var fill:   Color   = Color(stroke.r, stroke.g, stroke.b, 0.18)
		var rect := Rect2(pos, dim)
		draw_rect(rect, fill, true)
		draw_rect(rect, stroke, false, 1.2 * s)

	var ball_center: Vector2 = (Vector2(38, 68) - Vector2(50, 50)) * s
	draw_circle(ball_center, 7.5 * s, BALL_GLOW)
	draw_circle(ball_center, 4.5 * s, BALL_CORE)

	var trail_a: Vector2 = (Vector2(26, 80) - Vector2(50, 50)) * s
	var trail_b: Vector2 = (Vector2(30, 76) - Vector2(50, 50)) * s
	draw_line(ball_center, trail_a, Color(TRAIL_COLOR, 0.5), 1.0 * s, true)
	draw_line(ball_center, trail_b, Color(TRAIL_COLOR, 0.8), 1.0 * s, true)
