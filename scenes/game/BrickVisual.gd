# BrickVisual.gd
# Drawn brick body — filled tinted rectangle with a 1 px neon edge, soft outer
# glow halo, and a subtle inner glow. Owned by Brick.tscn.
#
# `color_index` selects the palette slot, matching the design's BRICK_COLORS:
#   0 teal · 1 cyan · 2 amber · 3 violet · 4 red (used for mobile bricks)
extends Node2D

const _EDGES: Array = [
	Color(0.0,   0.898, 0.784, 1.0),  # 0 teal    #00E5C8
	Color(0.310, 0.765, 1.0,   1.0),  # 1 cyan    #4FC3FF
	Color(1.0,   0.706, 0.329, 1.0),  # 2 amber   #FFB454
	Color(0.545, 0.361, 0.965, 1.0),  # 3 violet  #8B5CF6
	Color(1.0,   0.353, 0.431, 1.0),  # 4 red     #FF5A6E
]
const _FILL_ALPHA: float       = 0.18
const _RED_FILL_ALPHA: float   = 0.22
const _INNER_GLOW_ALPHA: float = 0.20
const _OUTER_GLOW_ALPHA: float = 0.33

@export var width: float  = 44.0
@export var height: float = 18.0
@export var corner_radius: float = 4.0

@export var color_index: int = 0:
	set(v):
		color_index = clampi(v, 0, _EDGES.size() - 1)
		queue_redraw()

# Hit points remaining — drives the small white HP dots drawn on top of the
# body. Brick.gd updates this on every take_hit().
@export var hp: int = 1:
	set(v):
		hp = max(0, v)
		queue_redraw()

func _draw() -> void:
	var edge: Color = _EDGES[color_index]
	var fill_alpha: float = _RED_FILL_ALPHA if color_index == 4 else _FILL_ALPHA
	var fill: Color = Color(edge.r, edge.g, edge.b, fill_alpha)

	var half_w: float = width  * 0.5
	var half_h: float = height * 0.5
	var body_rect := Rect2(Vector2(-half_w, -half_h), Vector2(width, height))

	# Outer glow halo — a wider, softer rounded rect underneath.
	_draw_rounded_rect(
		Rect2(Vector2(-half_w - 4.0, -half_h - 3.0),
		      Vector2(width + 8.0, height + 6.0)),
		corner_radius + 3.0,
		Color(edge.r, edge.g, edge.b, _OUTER_GLOW_ALPHA * 0.5)
	)

	# Body fill.
	_draw_rounded_rect(body_rect, corner_radius, fill)

	# Inner glow — a slightly inset rounded rect at low alpha sits inside the
	# body to mimic the design's "inset 0 0 6px ${edge}33" shadow.
	_draw_rounded_rect(
		Rect2(Vector2(-half_w + 1.5, -half_h + 1.5),
		      Vector2(width - 3.0, height - 3.0)),
		max(corner_radius - 1.0, 1.0),
		Color(edge.r, edge.g, edge.b, _INNER_GLOW_ALPHA * 0.4)
	)

	# 1 px neon border — drawn as four thin rects + four corner arcs.
	_draw_rounded_border(body_rect, corner_radius, edge, 1.0)

	# Mobile-brick warning dot (top-right) when red.
	if color_index == 4:
		var dot_pos := Vector2(half_w - 5.0, -half_h + 5.0)
		draw_circle(dot_pos, 3.0, Color(edge.r, edge.g, edge.b, 0.55))
		draw_circle(dot_pos, 2.0, edge)

	# HP dots — white centres with an edge-coloured halo, mirroring the design
	# (boxShadow: 0 0 4px ${edge}). Drawn for HP >= 2, capped at 3 dots.
	if hp >= 2:
		var dot_count: int = min(hp - 1, 3)
		var spacing: float = 6.0  # 3 px dot + 3 px gap between centres
		var total: float = (dot_count - 1) * spacing
		for i in dot_count:
			var x: float = -total * 0.5 + i * spacing
			var pos := Vector2(x, 0.0)
			# Halo (edge colour, soft).
			draw_circle(pos, 3.0, Color(edge.r, edge.g, edge.b, 0.5))
			# White core.
			draw_circle(pos, 1.5, Color(1.0, 1.0, 1.0, 0.95))


func _draw_rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	radius = min(radius, min(rect.size.x, rect.size.y) * 0.5)
	var inner := rect.grow(-radius)
	draw_rect(inner, color, true)
	draw_rect(Rect2(Vector2(inner.position.x, rect.position.y),
	                Vector2(inner.size.x, radius)), color, true)
	draw_rect(Rect2(Vector2(inner.position.x, inner.end.y),
	                Vector2(inner.size.x, radius)), color, true)
	draw_rect(Rect2(Vector2(rect.position.x, inner.position.y),
	                Vector2(radius, inner.size.y)), color, true)
	draw_rect(Rect2(Vector2(inner.end.x, inner.position.y),
	                Vector2(radius, inner.size.y)), color, true)
	draw_circle(inner.position,                         radius, color)
	draw_circle(Vector2(inner.end.x, inner.position.y), radius, color)
	draw_circle(Vector2(inner.position.x, inner.end.y), radius, color)
	draw_circle(inner.end,                              radius, color)


func _draw_rounded_border(rect: Rect2, radius: float, color: Color, thickness: float) -> void:
	radius = min(radius, min(rect.size.x, rect.size.y) * 0.5)
	var inner := rect.grow(-radius)
	# Top, bottom, left, right edges.
	draw_line(Vector2(inner.position.x, rect.position.y),
	          Vector2(inner.end.x,      rect.position.y), color, thickness, true)
	draw_line(Vector2(inner.position.x, rect.end.y),
	          Vector2(inner.end.x,      rect.end.y),      color, thickness, true)
	draw_line(Vector2(rect.position.x, inner.position.y),
	          Vector2(rect.position.x, inner.end.y),      color, thickness, true)
	draw_line(Vector2(rect.end.x,      inner.position.y),
	          Vector2(rect.end.x,      inner.end.y),      color, thickness, true)
	# Corner arcs.
	draw_arc(inner.position,                         radius, PI,         PI * 1.5, 8, color, thickness, true)
	draw_arc(Vector2(inner.end.x, inner.position.y), radius, -PI * 0.5,  0.0,      8, color, thickness, true)
	draw_arc(Vector2(inner.position.x, inner.end.y), radius, PI * 0.5,   PI,       8, color, thickness, true)
	draw_arc(inner.end,                              radius, 0.0,        PI * 0.5, 8, color, thickness, true)
