# BrickGrid.gd
# Owns all Brick instances for the current level.
# Spawns bricks from a descriptor array, relays brick signals upward,
# and emits all_cleared when the last destructible brick is removed.
#
# [GDScript] 'extends Node2D' — container node, no physics.
# [JS equiv]  class BrickGrid extends HTMLElement { ... }
extends Node2D

# ── Constants ──────────────────────────────────────────────────────────────────
# Preload the Brick packed scene at parse time — avoids runtime I/O stalls.
# [GDScript] preload() runs at script parse time, not at runtime.
# [JS equiv]  import BrickScene from './Brick.js'  (static import)
const BrickScene: PackedScene = preload("res://scenes/game/Brick.tscn")

const BRICK_W: float   = 44.0
const BRICK_H: float   = 18.0
const PADDING_X: float = 4.0
const PADDING_Y: float = 4.0
# Top-left corner of the grid — below HUD area.
# [JS equiv]  const GRID_ORIGIN = { x: 8, y: 60 }
const GRID_ORIGIN: Vector2 = Vector2(8.0, 60.0)

# ── Signals ────────────────────────────────────────────────────────────────────
# [GDScript] Signals bubble: Brick → BrickGrid → Game.gd
# [JS equiv]  this.dispatchEvent(new CustomEvent('allCleared'))
signal all_cleared
signal brick_destroyed(position: Vector2, tier: int)
signal brick_hit(position: Vector2)

# ── Public API ─────────────────────────────────────────────────────────────────

## Clears current bricks and spawns a new layout from descriptors.
## descriptors: Array of Dictionaries with keys:
##   "grid_pos"   : Vector2i  — column and row in the grid
##   "hit_points" : int       — 1–3 for standard; 0 for indestructible
##   "tier"       : int       — 0–3, maps to atlas colour region
##
## Called by Game.gd on every new level start.
## [JS equiv]  brickGrid.spawn(descriptors)
func spawn(descriptors: Array) -> void:
	# Remove all existing brick nodes.
	# [GDScript] get_children() returns all direct children as an Array.
	# [JS equiv]  [...this.children].forEach(c => c.remove())
	for child in get_children():
		child.queue_free()

	# Phase 2 fallback: if LevelGenerator returns empty, use a simple test layout.
	# Phase 3 replaces this when LevelGenerator.generate() is fully implemented.
	var layout: Array = descriptors
	if layout.is_empty():
		layout = _fallback_layout()

	for desc in layout:
		var brick: StaticBody2D = BrickScene.instantiate()
		add_child(brick)

		var col: int = desc["grid_pos"].x
		var row: int = desc["grid_pos"].y
		brick.global_position = GRID_ORIGIN + Vector2(
			col * (BRICK_W + PADDING_X),
			row * (BRICK_H + PADDING_Y)
		)
		brick.hit_points = desc["hit_points"]
		brick.tier       = desc["tier"]

		# Connect brick signals to this grid's relay handlers.
		# [GDScript] .connect(Callable) — registers a listener.
		# [JS equiv]  brick.addEventListener('destroyed', _on_brick_destroyed)
		brick.destroyed.connect(_on_brick_destroyed)
		brick.hit.connect(_on_brick_hit)

## Returns the number of destructible bricks still alive.
## Used by _check_cleared() to determine the win condition.
## [JS equiv]  [...this.children].filter(n => n.hitPoints > 0).length
func get_brick_count() -> int:
	var count: int = 0
	for child in get_children():
		if child is StaticBody2D and child.hit_points > 0:
			count += 1
	return count

# ── Signal relay handlers ──────────────────────────────────────────────────────

func _on_brick_destroyed(pos: Vector2, tier: int) -> void:
	emit_signal("brick_destroyed", pos, tier)
	# Defer the cleared check — queue_free() hasn't run yet this frame.
	# [GDScript] call_deferred() runs after the current physics/render step.
	# [JS equiv]  setTimeout(() => this._checkCleared(), 0)
	call_deferred("_check_cleared")

func _on_brick_hit(pos: Vector2) -> void:
	emit_signal("brick_hit", pos)

func _check_cleared() -> void:
	if get_brick_count() == 0:
		emit_signal("all_cleared")

# ── Phase 2 fallback layout ────────────────────────────────────────────────────

func _fallback_layout() -> Array:
	# Simple 5-row × 7-col grid, all tier 0, 1 HP each.
	# Replaced by LevelGenerator.generate() data in Phase 3.
	var result: Array = []
	for row in range(5):
		for col in range(7):
			result.append({
				"grid_pos":   Vector2i(col, row),
				"hit_points": 1,
				"tier":       0
			})
	return result
