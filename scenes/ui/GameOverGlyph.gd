# GameOverGlyph.gd
# Hero glyph for the GameOver modal: a dashed magenta circle wrapping a thick
# magenta "X". Drawn entirely with primitives — no textures.
extends Node2D

const RING_COLOR := Color(1.0, 0.310, 0.659, 0.6)   # #FF4FA8 @ 60%
const X_COLOR    := Color(1.0, 0.310, 0.659, 1.0)   # #FF4FA8

@export var size: float = 56.0

func _draw() -> void:
	# Source viewBox 56×56, recentered to (0,0). Scale to `size`.
	var s: float = size / 56.0
	var radius: float = 22.0 * s

	# Dashed circle — 24 segments, every other one drawn for the dash effect.
	var segs := 24
	for i in segs:
		if i % 2 == 1:
			continue
		var a0: float = float(i)     / float(segs) * TAU - PI * 0.5
		var a1: float = float(i + 1) / float(segs) * TAU - PI * 0.5
		draw_arc(Vector2.ZERO, radius, a0, a1, 6, RING_COLOR, 1.2 * s, true)

	# "X" — two diagonal strokes from (19,19)→(37,37) and (37,19)→(19,37) in
	# source coords, recentered around (28,28).
	var a1_from := (Vector2(19, 19) - Vector2(28, 28)) * s
	var a1_to   := (Vector2(37, 37) - Vector2(28, 28)) * s
	var a2_from := (Vector2(37, 19) - Vector2(28, 28)) * s
	var a2_to   := (Vector2(19, 37) - Vector2(28, 28)) * s
	draw_line(a1_from, a1_to, X_COLOR, 3.0 * s, true)
	draw_line(a2_from, a2_to, X_COLOR, 3.0 * s, true)
