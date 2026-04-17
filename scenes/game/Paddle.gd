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
# @onready runs the right-hand assignment during _ready(), after the scene tree
# is fully built. Like DOMContentLoaded in JS — safe to query child nodes here.
# [GDScript] @onready var x = expr  ≡  var x; func _ready() { x = expr }
# [JS equiv]  connectedCallback() { this._halfWidth = this.offsetWidth / 2 }
@onready var _half_width: float = (
	($CollisionShape2D.shape as RectangleShape2D).size.x / 2.0
)

var _screen_width: float  = 360.0  # updated in _ready from actual viewport
var _screen_height: float = 780.0  # updated in _ready from actual viewport

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
	# Lower zone: bottom 40% of the screen.
	# _screen_height * 0.60 is the Y coordinate where the zone begins.
	# [JS equiv]  const lowerZoneTop = window.innerHeight * 0.60
	var lower_zone_top: float = _screen_height * 0.60

	if event.pressed:
		# Claim this touch only if:
		#   (a) no touch is currently active  AND
		#   (b) the touch starts inside the lower zone
		# [JS equiv]  if (this._activeTouchId === null && event.clientY >= lowerZoneTop)
		if _active_touch_index == -1 and event.position.y >= lower_zone_top:
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

func _move_to_x(target_x: float) -> void:
	# Clamp the paddle centre so it never goes outside the viewport.
	# clamp(value, min, max) = Math.max(min, Math.min(max, value)) in JS.
	# _half_width padding ensures the paddle edge never leaves the screen.
	# [JS equiv]  this.element.style.left = Math.max(hw, Math.min(sw - hw, targetX)) + 'px'
	position.x = clamp(target_x, _half_width, _screen_width - _half_width)
	# Note: position.y is fixed — the paddle only moves horizontally.
	# position.y is set by Game.tscn when the Paddle is instanced (y = 710).
