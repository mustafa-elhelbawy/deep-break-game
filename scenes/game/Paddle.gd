# Paddle.gd
# Moves the paddle horizontally to track a touch in the lower 40% of the screen.
#
# Node type: AnimatableBody2D
# Why AnimatableBody2D and not CharacterBody2D or StaticBody2D:
#   AnimatableBody2D is Godot 4's type specifically designed for objects that are
#   moved by script. Moving its position directly each frame correctly notifies
#   the physics engine of the paddle's velocity, so the ball bounces off a moving
#   paddle with proper collision normals. StaticBody2D moved the same way would
#   not report velocity to the engine, causing incorrect deflection angles.
extends AnimatableBody2D

# ── Cached dimensions ──────────────────────────────────────────────────────────
# Computed in _ready() (not @onready) so _normal_width and _half_width derive
# from the same shape read, and activate_wide() can mutate them consistently.
# [JS equiv]  connectedCallback() { this._halfWidth = this.offsetWidth / 2 }
var _half_width: float    = 0.0   # set in _ready from actual shape
var _normal_width: float  = 120.0 # set in _ready; used to revert wide effect

var _screen_width: float  = 360.0  # updated in _ready from actual viewport
var _screen_height: float = 780.0  # updated in _ready from actual viewport

# ── Wide Paddle constants ──────────────────────────────────────────────────────
# [JS equiv]  const WIDE_SCALE = 1.8; const WIDE_DURATION = 10
const WIDE_SCALE: float    = 1.8
const WIDE_DURATION: float = 10.0

# ── Wide Paddle state ─────────────────────────────────────────────────────────
# Timer reference — null when effect is not active.
# Tracked so re-catching W disconnects the old timeout and resets the 10 s.
# [JS equiv]  #wideTimer = null  (private class field)
var _wide_timer: SceneTreeTimer = null

# ── Velocity tracking ─────────────────────────────────────────────────────────
# Public — read by Ball.gd during paddle contact to compute spin effect (T048).
# Updated each physics frame as the change in position divided by delta time.
# [JS equiv]  get paddleVelocityX() { return this._paddleVelocityX }
var paddle_velocity_x: float = 0.0

# Previous frame's X position — used to compute per-frame velocity.
# [JS equiv]  #prevX = 0.0  (private class field)
var _prev_x: float = 0.0

# ── Touch tracking ─────────────────────────────────────────────────────────────
# Touch index of the finger currently controlling the paddle.
# -1 = no active touch (sentinel value — Godot touch indices start at 0).
# [JS equiv]  this._activeTouchId = null
var _active_touch_index: int = -1

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Read actual viewport size at runtime — do not hard-code 360/780, because
	# the Android device may have a different resolution and Godot will scale.
	# get_visible_rect() returns the Rect2 of the current viewport in pixels.
	# [JS equiv]  window.innerWidth / window.innerHeight
	var vp: Rect2 = get_viewport().get_visible_rect()
	_screen_width  = vp.size.x
	_screen_height = vp.size.y
	_prev_x = position.x
	# Derive _normal_width and _half_width from the actual shape at runtime.
	# Done here (not @onready) so activate_wide() can read _normal_width reliably.
	_normal_width = ($CollisionShape2D.shape as RectangleShape2D).size.x
	_half_width   = _normal_width / 2.0

# ── Physics loop ───────────────────────────────────────────────────────────────

# Track horizontal velocity each physics tick (60 Hz).
# Ball.gd reads paddle_velocity_x during paddle contact to add spin.
# AnimatableBody2D has no built-in velocity property — manual tracking required.
# [JS equiv]  // called inside requestAnimationFrame at fixed 60 Hz
func _physics_process(delta: float) -> void:
	# Velocity = displacement / time. Guard against a zero/negative delta on startup.
	# [JS equiv]  this._paddleVelocityX = (this.x - this._prevX) / delta
	if delta > 0.0:
		paddle_velocity_x = (position.x - _prev_x) / delta
	_prev_x = position.x

# ── Input ──────────────────────────────────────────────────────────────────────

# _input() receives all input events before UI nodes can consume them.
# Correct for persistent game input like paddle dragging.
# [JS equiv]  document.addEventListener('touchstart', handler, { capture: true })
func _input(event: InputEvent) -> void:
	# [GDScript] 'is' = runtime type check. Same as 'instanceof' in JS.
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)

func _handle_touch(event: InputEventScreenTouch) -> void:
	# Lower 40% zone — touch Y must be >= screen_height * 0.60.
	if event.pressed:
		# Claim this touch only if no touch is currently active AND it's in the zone.
		# [JS equiv]  if (this._activeTouchId === null && inZone(event))
		var in_zone: bool = event.position.y >= _screen_height * 0.60
		if _active_touch_index == -1 and in_zone:
			_active_touch_index = event.index
			# Snap paddle to the finger's X immediately on first contact.
			_move_to_x(event.position.x)
	else:
		# Finger lifted — release the claim if it was our finger.
		# [JS equiv]  if (event.identifier === this._activeTouchId) this._activeTouchId = null
		if event.index == _active_touch_index:
			_active_touch_index = -1
			# Paddle stays at its last position — does NOT snap to centre.

func _handle_drag(event: InputEventScreenDrag) -> void:
	# Ignore drag events from fingers we have not claimed.
	# [JS equiv]  if (event.identifier !== this._activeTouchId) return
	if event.index != _active_touch_index:
		return
	_move_to_x(event.position.x)

# ── Movement ───────────────────────────────────────────────────────────────────

## Activates the Wide Paddle effect. Safe to call while already active — resets timer.
## Expands collision shape width and sprite scale to WIDE_SCALE× for WIDE_DURATION seconds.
func activate_wide() -> void:
	var new_width: float = _normal_width * WIDE_SCALE
	# Expand collision shape.
	# [JS equiv]  this.collisionShape.size.x = newWidth
	($CollisionShape2D.shape as RectangleShape2D).size.x = new_width
	$Sprite2D.scale.x = WIDE_SCALE
	_half_width = new_width / 2.0

	# Cancel any existing timer — catching W again resets the 10 s (replacement behaviour).
	if _wide_timer != null and is_instance_valid(_wide_timer):
		if _wide_timer.timeout.is_connected(_revert_wide):
			_wide_timer.timeout.disconnect(_revert_wide)

	# Start a fresh 10 s countdown.
	# [JS equiv]  clearTimeout(this._wideTimer); this._wideTimer = setTimeout(_revertWide, 10000)
	_wide_timer = get_tree().create_timer(WIDE_DURATION)
	_wide_timer.timeout.connect(_revert_wide)

func _revert_wide() -> void:
	# Restore normal collision width and sprite scale.
	($CollisionShape2D.shape as RectangleShape2D).size.x = _normal_width
	$Sprite2D.scale.x = 1.0
	_half_width = _normal_width / 2.0
	_wide_timer = null

func _move_to_x(target_x: float) -> void:
	# Clamp the paddle centre so it never goes outside the viewport.
	# clamp(value, min, max) = Math.max(min, Math.min(max, value)) in JS.
	# _half_width padding ensures the paddle edge never leaves the screen.
	# [JS equiv]  this.element.style.left = Math.max(hw, Math.min(sw - hw, targetX)) + 'px'
	position.x = clamp(target_x, _half_width, _screen_width - _half_width)
	# Note: position.y is fixed — the paddle only moves horizontally.
	# position.y is set by Game.tscn when the Paddle is instanced (y = 710).
