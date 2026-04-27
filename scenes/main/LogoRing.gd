# LogoRing.gd
# Draws a dashed hexagonal outline that the AnimationPlayer rotates.
# Placed on its own node so rotation does not affect the inner artwork
# (bricks/ball) drawn by LogoGlyph.gd on the parent.
extends Node2D

@export var size: float = 108.0

const RING_COLOR := Color(0.0, 0.898, 0.784, 0.95)  # #00E5C8

func _draw() -> void:
	var s: float = size / 100.0
	var verts := [
		Vector2(50,  4), Vector2(88, 26), Vector2(88, 74),
		Vector2(50, 96), Vector2(12, 74), Vector2(12, 26),
	]
	var local: Array[Vector2] = []
	for v in verts:
		local.append((v - Vector2(50, 50)) * s)
	var n := local.size()
	for i in n:
		var a: Vector2 = local[i]
		var b: Vector2 = local[(i + 1) % n]
		draw_dashed_line(a, b, RING_COLOR, 1.5 * s, 6.0 * s, true, true)
