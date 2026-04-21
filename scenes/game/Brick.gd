# Brick.gd
# A single destructible (or indestructible) brick.
# Owned by BrickGrid. Ball.gd calls take_hit() on collision.
#
# [GDScript] 'extends StaticBody2D' — brick is a static physics body.
# [JS equiv]  class Brick extends PhysicsObject { ... }
extends StaticBody2D

# ── Atlas region lookup by tier ────────────────────────────────────────────────
# [GDScript] Array literal. Index = tier number (0–3).
# [JS equiv]  const TIER_REGIONS = [new Rect2(...), ...]
const TIER_REGIONS: Array = [
	Rect2(0, 36, 44, 18),  # tier 0 — teal
	Rect2(0, 54, 44, 18),  # tier 1 — cyan-blue
	Rect2(0, 72, 44, 18),  # tier 2 — amber
	Rect2(0, 90, 44, 18),  # tier 3 — violet (indestructible visual)
]

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

# ── State ──────────────────────────────────────────────────────────────────────
# Power-up type this brick drops on destroy. "" = no drop.
# Set by BrickGrid via set_powerup_type() after instantiation.
# [JS equiv]  #powerupType = ''  (private class field)
var _powerup_type: String = ""

# ── Cached node reference ──────────────────────────────────────────────────────
@onready var _sprite: Sprite2D = $Sprite2D

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Apply the correct atlas region for this brick's tier.
	_apply_tier_visual()

func _apply_tier_visual() -> void:
	# Clamp tier to valid index range.
	# [JS equiv]  Math.max(0, Math.min(3, this.tier))
	var safe_tier: int = clampi(tier, 0, TIER_REGIONS.size() - 1)
	_sprite.region_rect = TIER_REGIONS[safe_tier]

# ── Public API ─────────────────────────────────────────────────────────────────

## Assign a power-up type. Called by BrickGrid after instantiation.
## type: "W", "S", "M", or "" for no drop.
func set_powerup_type(type: String) -> void:
	_powerup_type = type

## Called by Ball.gd on collision (via is_in_group("bricks") check).
func take_hit() -> void:
	# hit_points == 0 is the indestructible sentinel.
	# Indestructible bricks still emit 'hit' (for audio/juice) but never die.
	# [GDScript] Early return with 'return' — same as JS.
	if hit_points == 0:
		emit_signal("hit", global_position)
		return

	hit_points -= 1
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
