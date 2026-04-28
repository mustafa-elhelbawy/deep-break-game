# LifeDot.gd
# A single life indicator dot drawn as a teal radial-gradient circle when filled,
# or a thin teal-bordered ring when empty. Used by the HUD lives row.
extends Node2D

const FILL_CORE   := Color(1.0, 1.0, 1.0, 1.0)            # white core
const FILL_MID    := Color(0.0, 0.898, 0.784, 1.0)        # #00E5C8
const FILL_OUTER  := Color(0.0, 0.545, 0.471, 1.0)        # #008b78
const GLOW_COLOR  := Color(0.0, 0.898, 0.784, 0.6)
const RING_COLOR  := Color(0.0, 0.898, 0.784, 0.4)

@export var size: float = 11.0
@export var filled: bool = true:
	set(v):
		filled = v
		queue_redraw()

func _draw() -> void:
	var r: float = size * 0.5
	if filled:
		# Soft outer glow halo.
		draw_circle(Vector2.ZERO, r + 2.0, GLOW_COLOR * Color(1, 1, 1, 0.35))
		# Outer rim (darker teal).
		draw_circle(Vector2.ZERO, r, FILL_OUTER)
		# Mid teal body.
		draw_circle(Vector2.ZERO, r * 0.78, FILL_MID)
		# Bright off-center highlight.
		draw_circle(Vector2(-r * 0.18, -r * 0.18), r * 0.32, FILL_CORE)
	else:
		# Hollow ring — 1px teal stroke.
		draw_arc(Vector2.ZERO, r - 0.5, 0.0, TAU, 24, RING_COLOR, 1.0, true)
