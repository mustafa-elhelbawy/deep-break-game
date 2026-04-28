# Brick.gd
# A single destructible (or indestructible) brick.
# Owned by BrickGrid. Ball.gd calls take_hit() on collision.
#
# Mobile bricks (T057): set_mobile(speed) makes the brick drift downward.
# If it reaches paddle_y it fires reached_paddle (player loses a life — T059).
# If it drifts off screen it fires drifted_off (counts as cleared for win check).
#
# [GDScript] 'extends StaticBody2D' — brick is a static physics body.
# [JS equiv]  class Brick extends PhysicsObject { ... }
extends StaticBody2D

# ── Exported properties (set by BrickGrid after instantiate()) ─────────────────
# [GDScript] @export makes these editable in the Inspector AND settable by code.
# [JS equiv]  class Brick { constructor({ hitPoints, tier }) { ... } }
@export var hit_points: int = 1
@export var tier: int = 0  # 0=teal, 1=cyan, 2=amber, 3=violet

# ── Signals ────────────────────────────────────────────────────────────────────
# [GDScript] Signals carry typed parameters — checked at connect() time.
# [JS equiv]  this.dispatchEvent(new CustomEvent('destroyed', { detail: { position, tier } }))
signal destroyed(position: Vector2, tier: int)
signal hit(position: Vector2)
## Emitted on destroy when this brick carries a power-up (ADR-002).
## BrickGrid relays this to Game.gd, which spawns the visual token.
## Brick does NOT preload or instantiate PowerUp.tscn — it just announces the drop.
## [JS equiv]  this.emit('powerupDropped', type, position)
signal powerup_dropped(type: String, pos: Vector2)
## Emitted when a mobile brick drifts down to paddle_y — player loses a life (T059).
## [JS equiv]  this.emit('reachedPaddle')
signal reached_paddle
## Emitted when a mobile brick exits the bottom of the screen — counts as cleared (BUG-2 fix).
## [JS equiv]  this.emit('driftedOff')
signal drifted_off

# ── State ──────────────────────────────────────────────────────────────────────
# Power-up type this brick drops on destroy. "" = no drop.
# Set by BrickGrid via set_powerup_type() after instantiation.
# [JS equiv]  #powerupType = ''  (private class field)
var _powerup_type: String = ""

# Mobile-brick state (T057). _is_mobile = false for all normal bricks.
# _collapse_speed: drift speed in px/s (set by set_mobile()).
# _paddle_y: the Y threshold at which reached_paddle fires (set by set_paddle_y()).
# [JS equiv]  #isMobile = false; #collapseSpeed = 0; #paddleY = 700
var _is_mobile: bool           = false
var _collapse_speed: float     = 0.0
var _paddle_y: float           = 700.0

# ── Cached node references ─────────────────────────────────────────────────────
@onready var _visual: Node2D = $Visual

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Apply tier colour and HP-dot count to the drawn visual.
	_apply_tier_visual()
	_update_hp_dots()

func _apply_tier_visual() -> void:
	# Tier indices map directly onto BrickVisual's first four palette slots
	# (0 teal · 1 cyan · 2 amber · 3 violet). Slot 4 is reserved for the red
	# mobile tint applied by set_mobile().
	_visual.color_index = clampi(tier, 0, 3)

func _update_hp_dots() -> void:
	# BrickVisual draws 0/1/2/3 dots based on hp (none for hp<=1, capped at 3).
	_visual.hp = hit_points

# ── Physics loop (mobile bricks only) ─────────────────────────────────────────

## Runs every physics tick only when this brick is mobile.
## Moves the brick downward at _collapse_speed px/s and checks exit conditions.
## [JS equiv]  // called inside requestAnimationFrame at 60 Hz
func _physics_process(delta: float) -> void:
	if not _is_mobile:
		return

	# Drift downward at _collapse_speed px/s.
	# ADR-003: direct position.y mutation is correct for StaticBody2D ≤ 90 px/s.
	# [JS equiv]  this.y += this._collapseSpeed * delta
	position.y += _collapse_speed * delta

	# Reached paddle zone — fires when the brick crosses _paddle_y drifting down.
	# [JS equiv]  const hitPaddle = y >= paddleY
	if position.y >= _paddle_y:
		emit_signal("reached_paddle")
		queue_free()
		return

	# Drifted off-screen — exits bottom (y > screen_h + 20).
	# Treat as destroyed for win-condition (BUG-2 fix).
	# [JS equiv]  const offScreen = y > screenH + 20
	var screen_h: float = get_viewport().get_visible_rect().size.y
	if position.y > screen_h + 20.0:
		emit_signal("drifted_off")
		queue_free()

# ── Public API ─────────────────────────────────────────────────────────────────

## Assign a power-up type. Called by BrickGrid after instantiation.
## type: "W", "S", "M", or "" for no drop.
func set_powerup_type(type: String) -> void:
	_powerup_type = type

## Activate mobile-brick mode. The brick will drift downward at speed px/s.
## Applies a red tint to give players a visual warning.
## Called by BrickGrid in spawn() when collapse_speed > 0.
## [JS equiv]  setMobile(speed) { this._isMobile = true; this.element.classList.add('mobile') }
func set_mobile(speed: float) -> void:
	_is_mobile = true
	_collapse_speed = speed
	# Switch the visual to its red palette slot — also enables the small red
	# warning dot drawn in the top-right of the brick.
	_visual.color_index = 4

## Sets the Y threshold at which reached_paddle fires.
## Injected by Game.gd in _wire_mobile_bricks() with the real paddle Y position.
## Default is 700 px (placeholder until paddle position is known).
## [JS equiv]  setPaddleY(y) { this._paddleY = y }
func set_paddle_y(y: float) -> void:
	_paddle_y = y

## Called by Ball.gd on collision (via is_in_group("bricks") check).
func take_hit() -> void:
	# hit_points == 0 is the indestructible sentinel.
	# Indestructible bricks still emit 'hit' (for audio/juice) but never die.
	# [GDScript] Early return with 'return' — same as JS.
	if hit_points == 0:
		emit_signal("hit", global_position)
		return

	hit_points -= 1
	_update_hp_dots()
	emit_signal("hit", global_position)

	if hit_points == 0:
		# Signal a power-up drop before freeing — BrickGrid relays to Game.gd (ADR-002).
		# [JS equiv]  if (this._powerupType) this.emit('powerupDropped', this._powerupType, pos)
		if _powerup_type != "":
			emit_signal("powerup_dropped", _powerup_type, global_position)
		# queue_free() removes the node from the scene tree next frame.
		# [JS equiv]  this.element.remove()  (deferred one frame by the engine)
		emit_signal("destroyed", global_position, tier)
		queue_free()
