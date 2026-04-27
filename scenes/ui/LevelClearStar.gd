# LevelClearStar.gd
# A 5-pointed star with two visual states: filled (amber, with glow) or empty
# (mute outline). LevelClear instantiates three of these and toggles `filled`
# based on lives lost during the level.
extends Node2D

const STAR_FILL    := Color(1.0, 0.706, 0.329, 0.8)  # rgba(255,180,84,0.8)
const STAR_STROKE  := Color(1.0, 0.706, 0.329, 1.0)  # #FFB454
const STAR_GLOW    := Color(1.0, 0.706, 0.329, 0.45)
const EMPTY_STROKE := Color(0.482, 0.541, 0.686, 1.0)  # #7B8AAF

@export var size: float = 22.0
@export var filled: bool = true:
	set(v):
		filled = v
		queue_redraw()

func _draw() -> void:
	# Star geometry from a 22×22 viewBox, centered on (11,11). Outer points
	# at the tips, inner points at the dips. Pre-computed to avoid trig at
	# runtime.
	var s: float = size / 22.0
	var pts := PackedVector2Array([
		Vector2(11,  2),
		Vector2(13.5, 8),
		Vector2(20,   8.5),
		Vector2(15,  13),
		Vector2(16.5,19.5),
		Vector2(11,  16),
		Vector2( 5.5,19.5),
		Vector2( 7,  13),
		Vector2( 2,   8.5),
		Vector2( 8.5, 8),
	])
	var local := PackedVector2Array()
	for p in pts:
		local.append((p - Vector2(11, 11)) * s)

	var stroke: Color = STAR_STROKE if filled else EMPTY_STROKE
	if filled:
		# Cheap glow: a slightly larger translucent star behind the fill.
		var halo := PackedVector2Array()
		for p in local:
			halo.append(p * 1.18)
		draw_colored_polygon(halo, STAR_GLOW)
		draw_colored_polygon(local, STAR_FILL)

	# Outline as a closed polyline.
	var outline := PackedVector2Array()
	for p in local:
		outline.append(p)
	outline.append(local[0])
	draw_polyline(outline, stroke, 1.0 * s, true)
