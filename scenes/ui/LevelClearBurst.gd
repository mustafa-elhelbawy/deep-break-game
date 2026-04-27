# LevelClearBurst.gd
# Hero glyph for the LevelClear modal: a dashed teal circle wrapping a filled
# 5-pointed star. Fully self-contained — no external textures.
extends Node2D

const TEAL_RING := Color(0.0, 0.898, 0.784, 0.7)   # #00E5C8 @ 70%
const TEAL_FILL := Color(0.0, 0.898, 0.784, 0.25)
const TEAL_EDGE := Color(0.0, 0.898, 0.784, 1.0)

@export var size: float = 56.0

func _draw() -> void:
	# Source viewBox 56×56, recentered to (0,0). Scale to `size`.
	var s: float = size / 56.0
	var radius: float = 22.0 * s

	# Dashed circle — emulated by drawing many short arc segments around a
	# circle. 24 segments × 50% on/off → ~12 visible dashes.
	var segs := 24
	var dash_color := TEAL_RING
	for i in segs:
		if i % 2 == 1:
			continue
		var a0: float = float(i)     / float(segs) * TAU - PI * 0.5
		var a1: float = float(i + 1) / float(segs) * TAU - PI * 0.5
		draw_arc(Vector2.ZERO, radius, a0, a1, 6, dash_color, 1.2 * s, true)

	# 5-pointed star, larger than the small stars below — uses the same
	# 10-point outline.
	var pts := PackedVector2Array([
		Vector2(28, 12),
		Vector2(32, 24),
		Vector2(44, 24),
		Vector2(34, 32),
		Vector2(38, 44),
		Vector2(28, 36),
		Vector2(18, 44),
		Vector2(22, 32),
		Vector2(12, 24),
		Vector2(24, 24),
	])
	var local := PackedVector2Array()
	for p in pts:
		local.append((p - Vector2(28, 28)) * s)

	draw_colored_polygon(local, TEAL_FILL)
	var outline := PackedVector2Array()
	for p in local:
		outline.append(p)
	outline.append(local[0])
	draw_polyline(outline, TEAL_EDGE, 1.5 * s, true)
