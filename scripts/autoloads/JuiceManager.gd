# JuiceManager.gd
# Autoload singleton — screen shake, colour flash, particle bursts.
# All effects are additive and non-blocking: they do not pause game logic.
#
# Shake model: trauma (0–1) is added on each event and decays over time.
# Camera offset = trauma² × MAX_SHAKE_OFFSET — squaring keeps small shakes subtle.
#
# [GDScript] 'extends Node' — autoload attaches to a plain Node.
# [JS equiv]  class JuiceManager { shake(i,d){} flash(c,d){} emitBurst(p,t){} }
extends Node

# ── Preloaded scenes ───────────────────────────────────────────────────────────
# preload() resolves at parse time — resource is guaranteed available at runtime.
# [GDScript] const PackedScene — loaded once, instantiated many times.
# [JS equiv]  import BurstScene from './BrickBurst.js'  (static import)
const BurstScene: PackedScene = preload("res://scenes/game/effects/BrickBurst.tscn")

# ── Shake constants ────────────────────────────────────────────────────────────
const MAX_SHAKE_OFFSET: float = 12.0   # px — maximum camera displacement at trauma=1
const TRAUMA_DECAY: float     = 2.5    # trauma units lost per second

# ── State ──────────────────────────────────────────────────────────────────────
var _camera: Camera2D    = null   # set by register_camera() from Game.gd
var _trauma: float       = 0.0   # current shake intensity (0 = no shake, 1 = max)
var _flash_rect: ColorRect = null  # full-screen flash overlay, created in _ready()

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Build a full-screen flash overlay: CanvasLayer(layer=10) → ColorRect.
	# layer=10 renders above game nodes (layer=1 for HUD) but below debug overlays.
	# [JS equiv]  const overlay = document.createElement('div'); overlay.style.position='fixed'
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_flash_rect = ColorRect.new()
	_flash_rect.color = Color.TRANSPARENT
	# PRESET_FULL_RECT anchors all four sides to the parent container edges.
	# [JS equiv]  overlay.style = 'top:0;left:0;width:100%;height:100%'
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash_rect)

# ── Public API ─────────────────────────────────────────────────────────────────

## Called by Game.gd in _ready() — gives JuiceManager a camera reference for shake.
## [JS equiv]  registerCamera(cam) { this._camera = cam }
func register_camera(cam: Camera2D) -> void:
	_camera = cam

## Add trauma to trigger camera shake. Multiple calls stack (capped at 1.0).
## intensity: 0.0 = no effect, 1.0 = maximum shake. Decays automatically.
## [JS equiv]  shake(intensity) { this._trauma = Math.min(this._trauma + intensity, 1) }
func shake(intensity: float, _duration: float = 0.0) -> void:
	# _duration parameter kept for API compatibility with spec — trauma decay
	# is time-based automatically so explicit duration is not needed.
	# minf() = Math.min() in JS.
	_trauma = minf(_trauma + intensity, 1.0)

## Flash the screen with a colour for a short duration.
## colour: the flash tint. duration: seconds to fade back to transparent.
## [JS equiv]  flash(colour, duration) { overlay.style.opacity = 0.7; fadeOut(duration) }
func flash(colour: Color, duration: float) -> void:
	_flash_rect.color = Color(colour.r, colour.g, colour.b, 0.65)
	# Tween alpha from 0.65 back to 0 over 'duration' seconds.
	# create_tween() returns a fire-and-forget animation — no manual cleanup needed.
	# [JS equiv]  element.animate([{opacity: 0.65}, {opacity: 0}], { duration: duration*1000 })
	var tween := create_tween()
	tween.tween_property(_flash_rect, "color:a", 0.0, duration)

## Spawn a one-shot particle burst at world_pos, tinted by tier colour.
## Async: auto-removes the burst node after its lifetime expires.
## [JS equiv]  async emitBurst(worldPos, tier) { ... await delay(lifetime); node.remove() }
func emit_burst(world_pos: Vector2, tier: int) -> void:
	var burst: GPUParticles2D = BurstScene.instantiate()
	# Add to the current scene root so it survives node tree changes in Game.tscn.
	# [JS equiv]  document.body.appendChild(burstEl)
	get_tree().current_scene.add_child(burst)
	burst.global_position = world_pos

	# Tint particles with the tier's brand colour from Palette.
	# We set the color on the ProcessMaterial rather than modulate — modulate
	# tints the whole node uniformly; ProcessMaterial.color mixes with particle colour.
	# [JS equiv]  burst.material.color = Palette.TIER_COLOURS[tier]
	var mat := burst.process_material as ParticleProcessMaterial
	if mat != null:
		mat.color = Palette.TIER_COLOURS[clampi(tier, 0, 3)]

	burst.emitting = true

	# Auto-remove the node after its lifetime + a small buffer frame.
	# 'await' suspends this function only — it does NOT block the game loop.
	# [JS equiv]  await new Promise(resolve => setTimeout(resolve, (burst.lifetime + 0.1) * 1000))
	await get_tree().create_timer(burst.lifetime + 0.1).timeout
	if is_instance_valid(burst):
		burst.queue_free()

# ── Per-frame shake update ─────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _camera == null or _trauma <= 0.0:
		return

	# Decay trauma toward zero each frame.
	# maxf() = Math.max() in JS.
	_trauma = maxf(_trauma - TRAUMA_DECAY * delta, 0.0)

	# Offset = trauma² × max_offset — squaring keeps gentle events subtle.
	# randf_range(-1, 1) produces a random direction each frame for jitter effect.
	# [JS equiv]  const t2 = trauma**2; camera.offset = { x: rand()*MAX*t2, y: rand()*MAX*t2 }
	var t2: float = _trauma * _trauma
	_camera.offset = Vector2(
		randf_range(-1.0, 1.0) * MAX_SHAKE_OFFSET * t2,
		randf_range(-1.0, 1.0) * MAX_SHAKE_OFFSET * t2
	)

	# When trauma fully decays, snap camera offset back to zero.
	if _trauma <= 0.0:
		_camera.offset = Vector2.ZERO
