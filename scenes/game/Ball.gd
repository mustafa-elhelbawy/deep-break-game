# Ball.gd
# Controls ball movement, collision reflection, and lost detection.
#
# Architecture: CharacterBody2D + move_and_collide() — NOT RigidBody2D.
# Reason: move_and_collide() gives full deterministic control over reflection
# angles, which is required for seed-reproducible level generation (Phase 3).
# RigidBody2D introduces physics-engine non-determinism that breaks that guarantee.
#
# JS/TS developer note: GDScript uses tabs for indentation (not spaces).
# The Godot LSP will warn if you mix them.
extends CharacterBody2D

# ── Signals ────────────────────────────────────────────────────────────────────
# [GDScript] 'signal' is a first-class keyword — declares a typed event bus entry.
# Listeners connect with: ball.lost.connect(my_callback)
# [JS equiv]  this.addEventListener('lost', callback)  — but checked at design time.
signal lost

# ── Constants ──────────────────────────────────────────────────────────────────
# [GDScript] 'const' = compile-time constant; cannot be reassigned at runtime.
# [JS equiv]  const BASE_SPEED = 400
# Phase 3: change this to 'var _current_speed: float = 400.0' so speed can
# scale with level number via set_speed_for_level(level).
# BASE_SPEED is the reference value at level 1 — never mutated.
# _current_speed is the actual speed used this session, set by set_speed_for_level().
# [GDScript] 'const' = immutable compile-time constant; 'var' = mutable member.
# [JS equiv]  const BASE_SPEED = 400;  let _currentSpeed = 400;
const BASE_SPEED: float = 400.0

# Minimum absolute vertical speed enforced after every bounce.
# Prevents the ball from travelling nearly horizontally, which causes it to
# bounce left–right many times without reaching the bricks or paddle.
# 120 px/s ≈ 30% of BASE_SPEED — allows ~72° max angle from vertical.
# [JS equiv]  const MIN_VERTICAL_SPEED = 120
const MIN_VERTICAL_SPEED: float = 120.0

# Stuck-ball watchdog: backup safety net in case the ball somehow enters a
# near-horizontal trajectory that the per-bounce clamp missed (edge case).
# Reduced from 5 s to 2 s because MIN_VERTICAL_SPEED handles the common case.
const STUCK_TIMEOUT: float = 2.0

# ── State ──────────────────────────────────────────────────────────────────────
# [GDScript] Member variables at class scope — equivalent to 'this._velocity' in JS.
# '_' prefix is the GDScript convention for private members.
# [JS equiv]  #_velocity = new Vector2(0, 0)  (private class field syntax)
var _velocity: Vector2    = Vector2.ZERO
var _active: bool         = false
var _stuck_timer: float   = 0.0
# Actual speed for this level — set by set_speed_for_level() before each launch.
# Starts equal to BASE_SPEED and scales 8% per level (capped at 2×).
# [JS equiv]  let _currentSpeed = BASE_SPEED
var _current_speed: float = BASE_SPEED

# ── Public API ─────────────────────────────────────────────────────────────────

## Launch the ball in the given direction at BASE_SPEED.
## Call this from Game.gd when the player taps to serve.
## direction does not need to be pre-normalised — this method normalises it.
func launch(direction: Vector2) -> void:
	# Use _current_speed (set by set_speed_for_level before this call), not BASE_SPEED.
	# [JS equiv]  this._velocity = direction.normalize().multiplyScalar(this._currentSpeed)
	_velocity = direction.normalized() * _current_speed
	_active = true
	_stuck_timer = 0.0

## Snap the ball to 30px above the paddle centre and stop all movement.
## Called by Game.gd on startup, after a life is lost, and on level change.
func reset_to_paddle(paddle_global_pos: Vector2) -> void:
	_active = false
	_velocity = Vector2.ZERO
	# Vector2 addition shifts the position up by 30px.
	# In Godot 2D, +Y is downward, so -Y moves upward.
	# [JS equiv]  this.position = { x: paddle_global_pos.x, y: paddle_global_pos.y - 30 }
	global_position = paddle_global_pos + Vector2(0.0, -30.0)

## Sets ball speed for the given level. Call BEFORE launch() on every serve.
## Speed grows 8% per level, capped at 2× BASE_SPEED (800 px/s from level 13+).
## [JS equiv]  setSpeedForLevel(level) { this._currentSpeed = Math.min(1 + level*0.08, 2) * BASE_SPEED }
func set_speed_for_level(level: int) -> void:
	# minf() is the float version of min() — same as Math.min() in JS.
	var scale: float = minf(1.0 + level * 0.08, 2.0)
	_current_speed = BASE_SPEED * scale

## Stop the ball immediately. Called by Game.gd on game-over or level-clear.
func deactivate() -> void:
	_active = false
	_velocity = Vector2.ZERO

# ── Physics loop ───────────────────────────────────────────────────────────────

# _physics_process runs every physics tick (default 60Hz on Android).
# Use this — not _process — for any code that moves physics bodies.
# [JS equiv]  requestAnimationFrame callback, but called at a fixed 60Hz rate.
func _physics_process(delta: float) -> void:
	# [GDScript] 'if not' is idiomatic; same as '!_active' in JS.
	if not _active:
		return

	_check_stuck(delta)
	_move_and_reflect(delta)
	_check_lost()

func _move_and_reflect(delta: float) -> void:
	# move_and_collide() moves the body by (_velocity * delta) units this frame.
	# It sweeps the collision shape along the motion vector and returns the first hit.
	# Returns a KinematicCollision2D object if something was hit, null otherwise.
	# [JS equiv]  No direct equivalent — Godot handles swept-shape collision internally.
	var collision := move_and_collide(_velocity * delta)

	if collision == null:
		return  # no hit this frame — continue on current trajectory

	var collider: Object = collision.get_collider()

	# ── Brick hit (Phase 2 adds bricks; in Phase 1 this branch never fires) ──
	# [GDScript] is_in_group() checks group membership set in the Godot editor.
	# [JS equiv]  collider.classList.contains('bricks')
	if collider.is_in_group("bricks"):
		# take_hit() is defined in Brick.gd (Phase 2). Safe to call here because
		# is_in_group("bricks") will never be true until Phase 2 adds bricks.
		collider.take_hit()

	# ── Reflect velocity across the collision normal ──────────────────────────
	# bounce(normal) computes:  v' = v - 2 * dot(v, n) * n  (mirror reflection)
	# get_normal() returns the surface normal at the hit point.
	# [JS equiv]  No built-in; the formula above is the standard reflection.
	_velocity = _velocity.bounce(collision.get_normal())

	# Re-normalise then rescale: floating-point arithmetic causes tiny speed drift
	# across hundreds of bounces. This keeps speed exactly at _current_speed always.
	# [JS equiv]  this._velocity = this._velocity.normalize().multiplyScalar(this._currentSpeed)
	_velocity = _velocity.normalized() * _current_speed

	# ── Enforce minimum vertical speed ────────────────────────────────────────
	# After a grazing bounce (e.g. hitting a brick corner or a wall at a shallow
	# angle) the vertical component can drop near zero, trapping the ball in a
	# left-right horizontal oscillation for many seconds.
	# Fix: if |vy| is below the threshold, snap it to ±MIN_VERTICAL_SPEED,
	# preserving the original vertical direction (up or down). If vy is exactly
	# zero, default to upward (-y in Godot 2D) so the ball heads toward the bricks.
	# [JS equiv]  if (Math.abs(vy) < MIN_VY) vy = vy <= 0 ? -MIN_VY : MIN_VY
	if abs(_velocity.y) < MIN_VERTICAL_SPEED:
		_velocity.y = -MIN_VERTICAL_SPEED if _velocity.y <= 0.0 else MIN_VERTICAL_SPEED
		_velocity = _velocity.normalized() * _current_speed

func _check_stuck(delta: float) -> void:
	# Backup watchdog — fires only if the per-bounce clamp somehow missed.
	# Uses the same MIN_VERTICAL_SPEED threshold for consistency.
	# abs() = Math.abs() in JS.
	if abs(_velocity.y) < MIN_VERTICAL_SPEED:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0

	if _stuck_timer >= STUCK_TIMEOUT:
		# Nudge with a random horizontal kick to break the oscillation.
		# randf_range(a, b) → random float in [a, b].
		# [JS equiv]  Math.random() * (b - a) + a
		_velocity.x += randf_range(-80.0, 80.0)
		_velocity = _velocity.normalized() * _current_speed
		_stuck_timer = 0.0

func _check_lost() -> void:
	# The bottom of the viewport is at y = viewport_height.
	# Allow 20px grace past the bottom before declaring the ball lost.
	# get_viewport().get_visible_rect() returns the current viewport Rect2.
	# [JS equiv]  window.innerHeight
	var screen_h: float = get_viewport().get_visible_rect().size.y
	if global_position.y > screen_h + 20.0:
		_active = false
		# emit_signal() fires 'lost' to all connected listeners synchronously.
		# [JS equiv]  this.dispatchEvent(new Event('lost'))
		emit_signal("lost")
