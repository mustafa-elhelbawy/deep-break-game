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
# Top-left corner of the grid — below HUD area in normal mode.
# In flipped mode the origin is mirrored: rows count upward from (35, screen_h - 60).
# [JS equiv]  const GRID_ORIGIN = { x: 35, y: 60 }
const GRID_ORIGIN: Vector2 = Vector2(35.0, 60.0)

# ── Signals ────────────────────────────────────────────────────────────────────
# [GDScript] Signals bubble: Brick → BrickGrid → Game.gd
# [JS equiv]  this.dispatchEvent(new CustomEvent('allCleared'))
signal all_cleared
signal brick_destroyed(position: Vector2, tier: int)
signal brick_hit(position: Vector2)
## Relayed from Brick.powerup_dropped — received by Game.gd to spawn the token.
## BrickGrid does not own token spawning; it only passes the signal through.
signal powerup_dropped(type: String, pos: Vector2)

# ── Public API ─────────────────────────────────────────────────────────────────

## Clears current bricks and spawns a new layout from descriptors.
## descriptors: Array of Dictionaries with keys:
##   "grid_pos"       : Vector2i  — column and row in the grid
##   "hit_points"     : int       — 1–3 for standard; 0 for indestructible
##   "tier"           : int       — 0–3, maps to atlas colour region
##   "collapse_speed" : float     — 0 = static; > 0 = mobile
##
## flipped: when true, bricks are placed from the bottom of the screen upward (T061).
##          Row 0 = bottom-most row, row N = closer to the top.
##
## Called by Game.gd on every new level start.
## [JS equiv]  brickGrid.spawn(descriptors, flipped)
func spawn(descriptors: Array, flipped: bool = false) -> void:
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

	# In flipped mode bricks count upward from the bottom margin.
	# screen_h mirrors the normal GRID_ORIGIN.y gap from the opposite edge.
	# [JS equiv]  const screenH = window.innerHeight
	var screen_h: float = get_viewport().get_visible_rect().size.y

	for desc in layout:
		var brick: StaticBody2D = BrickScene.instantiate()
		add_child(brick)

		var col: int = desc["grid_pos"].x
		var row: int = desc["grid_pos"].y

		# Normal:  y increases downward from the top margin.
		# Flipped: y decreases upward from the bottom margin (mirrored origin).
		# [JS equiv]  const y = flipped ? screenH - ORIGIN.y - row*step : ORIGIN.y + row*step
		var brick_x: float = GRID_ORIGIN.x + col * (BRICK_W + PADDING_X)
		var brick_y: float
		if flipped:
			brick_y = (screen_h - GRID_ORIGIN.y) - row * (BRICK_H + PADDING_Y)
		else:
			brick_y = GRID_ORIGIN.y + row * (BRICK_H + PADDING_Y)

		brick.global_position = Vector2(brick_x, brick_y)
		brick.hit_points = desc["hit_points"]
		brick.tier       = desc["tier"]

		# Apply power-up type from descriptor (T051 — "" means no drop).
		# [JS equiv]  if (desc.powerupType) brick.setPowerupType(desc.powerupType)
		if desc.get("powerup_type", "") != "":
			brick.set_powerup_type(desc["powerup_type"])

		# Apply mobile drift if descriptor carries a collapse_speed > 0 (T058).
		# set_paddle_y() uses a placeholder; Game.gd _wire_mobile_bricks()
		# injects the real paddle position and direction after spawn (T059/T063).
		# [JS equiv]  if (desc.collapseSpeed > 0) { brick.setMobile(desc.collapseSpeed) }
		var collapse_speed: float = desc.get("collapse_speed", 0.0)
		if collapse_speed > 0.0:
			brick.set_mobile(collapse_speed)

		# Connect brick signals to this grid's relay handlers.
		# [GDScript] .connect(Callable) — registers a listener.
		# [JS equiv]  brick.addEventListener('destroyed', _on_brick_destroyed)
		brick.destroyed.connect(_on_brick_destroyed)
		brick.hit.connect(_on_brick_hit)
		# Relay power-up drop signal to Game.gd (ADR-002).
		# [JS equiv]  brick.on('powerupDropped', (...a) => this.emit('powerupDropped', ...a))
		brick.powerup_dropped.connect(_on_powerup_dropped)
		# Mobile bricks fire drifted_off when they exit the screen (BUG-2 fix).
		# Still counts toward the cleared check so the level can end normally.
		# [JS equiv]  brick.on('driftedOff', () => this._onBrickDriftedOff())
		brick.drifted_off.connect(_on_brick_drifted_off)

## Returns all mobile bricks currently in the grid.
## Used by Game.gd _wire_mobile_bricks() to inject the real paddle Y position
## and connect the reached_paddle signal (T059).
## [JS equiv]  getMobileBricks() { return [...this.children].filter(b => b._isMobile) }
func get_mobile_bricks() -> Array:
	var result: Array = []
	for child in get_children():
		if child is StaticBody2D and child._is_mobile:
			result.append(child)
	return result

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

func _on_powerup_dropped(type: String, pos: Vector2) -> void:
	# Pass through — BrickGrid does not own token spawning.
	emit_signal("powerup_dropped", type, pos)

func _on_brick_drifted_off() -> void:
	# Mobile brick left the screen — treat it as destroyed for win-condition purposes.
	# queue_free() already called inside Brick.gd, so the node count is decreasing.
	# Defer the cleared check just like _on_brick_destroyed does.
	# [JS equiv]  setTimeout(() => this._checkCleared(), 0)
	call_deferred("_check_cleared")

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
