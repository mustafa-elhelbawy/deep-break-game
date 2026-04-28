# BallTrail.gd
# Decorative trail behind the ball — four fading teal circles sampled from the
# ball's recent positions. Drawn in world space (top_level=true) so the trail
# stays put while the ball moves forward, matching the design.
#
# Owned by Ball.tscn. Reads its parent's global_position each physics frame.
extends Node2D

const TRAIL_COLOR := Color(0.0, 0.898, 0.784, 1.0) # #00E5C8
const SEGMENTS: int = 4
const SAMPLE_GAP: int = 2  # store every Nth physics frame to space the trail out

# Per-segment radius and base alpha — index 0 is the closest segment.
const SEG_RADIUS := [4.25, 3.5, 2.75, 2.0]
const SEG_ALPHA  := [0.32, 0.24, 0.16, 0.08]

var _samples: Array[Vector2] = []
var _frame: int = 0
var _ball: Node2D = null

func _ready() -> void:
	# Render in world coordinates so the trail does not move with the parent.
	top_level = true
	_ball = get_parent() as Node2D

func _physics_process(_delta: float) -> void:
	if _ball == null:
		return
	_frame += 1
	if _frame % SAMPLE_GAP == 0:
		_samples.push_front(_ball.global_position)
		if _samples.size() > SEGMENTS:
			_samples.resize(SEGMENTS)
		queue_redraw()

func _draw() -> void:
	for i in _samples.size():
		var col := TRAIL_COLOR
		col.a = SEG_ALPHA[i]
		# Halo + core for a soft blurred look without a shader.
		draw_circle(_samples[i], SEG_RADIUS[i] + 1.5, Color(col.r, col.g, col.b, col.a * 0.5))
		draw_circle(_samples[i], SEG_RADIUS[i], col)

# Called by Ball when it is parked or deactivated so the trail does not linger.
func clear_trail() -> void:
	_samples.clear()
	queue_redraw()
