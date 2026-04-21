# PowerUp.gd
# A falling token spawned when a brick with a power-up is destroyed.
# Area2D detects overlap with the paddle (AnimatableBody2D on layer 1).
# Emits 'caught(type)' when the paddle overlaps it; auto-removes on catch or screen exit.
#
# Ownership: spawned by Game.gd (not Brick.gd) via the powerup_dropped relay (ADR-002).
# Game.gd preloads this scene, instantiates it, calls setup(type), then add_child().
#
# [GDScript] extends Area2D — no physics body, purely an overlap sensor.
# [JS equiv]  class PowerUpToken extends GameObject { ... }
extends Area2D

# ── Signals ────────────────────────────────────────────────────────────────────
# [GDScript] typed signal — Game.gd connects to this after spawning.
# [JS equiv]  this.addEventListener('caught', callback)
signal caught(type: String)

# ── Constants ──────────────────────────────────────────────────────────────────
# Fall speed in pixels per second. Slow enough to give the player time to react.
# [JS equiv]  const FALL_SPEED = 200
const FALL_SPEED: float = 200.0

# Type-to-colour lookup — visual identity for each power-up.
# [GDScript] Dictionary literal — like a plain JS object { W: Color(...), ... }
const TYPE_COLOURS: Dictionary = {
	"W": Color(0.0,    0.784, 0.722, 1.0),   # teal  — Wide Paddle  #00c8b8
	"S": Color(0.0,    0.878, 1.0,   1.0),   # cyan  — Slow Motion  #00e0ff
	"M": Color(1.0,    0.757, 0.027, 1.0),   # amber — Multi-Ball   #ffc107
}

# ── State ──────────────────────────────────────────────────────────────────────
# Set by setup() before the node is added to the tree.
# [JS equiv]  #type = ''  (private class field)
var _type: String         = ""
var _screen_height: float = 780.0

# ── Setup ──────────────────────────────────────────────────────────────────────

## Called by Game.gd immediately after instantiation, before add_child().
## type: "W" (Wide), "S" (Slow), "M" (Multi-Ball)
func setup(type: String) -> void:
	_type = type
	# Set icon colour based on type. Falls back to white for unknown types.
	# [GDScript] Dictionary.get(key, default) — like JS: dict?.[key] ?? fallback
	var colour: Color = TYPE_COLOURS.get(type, Color.WHITE)
	$Icon.color = colour

func _ready() -> void:
	_screen_height = get_viewport().get_visible_rect().size.y
	# body_entered fires when a physics body (paddle) overlaps this Area2D.
	# [JS equiv]  this.addEventListener('collisionEnter', handler)
	body_entered.connect(_on_body_entered)

# ── Physics ────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	# Move downward each frame. +Y is downward in Godot 2D.
	# [JS equiv]  this.y += FALL_SPEED * delta
	position.y += FALL_SPEED * delta

	# Auto-remove when off the bottom of the screen.
	# [JS equiv]  if (this.globalY > screenHeight + 40) this.remove()
	if position.y > _screen_height + 40.0:
		queue_free()

# ── Catch detection ────────────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	# Only the paddle triggers a catch — it is the only AnimatableBody2D in the scene.
	# [GDScript] 'is' = instanceof check.
	# [JS equiv]  if (body instanceof Paddle)
	if body is AnimatableBody2D:
		# Emit with the stored type string so Game.gd can apply the correct effect.
		# [JS equiv]  this.dispatchEvent(new CustomEvent('caught', { detail: this._type }))
		emit_signal("caught", _type)
		queue_free()
