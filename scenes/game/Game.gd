# Game.gd
# Root controller for a play session.
#
# Phase 1 scope: tap to launch ball, ball bounces, ball lost → reset.
# Phase 2 will add: GameManager state machine, lives, score, bricks, HUD.
# Phase 4 will add: JuiceManager calls, WorldEnvironment.
#
# [GDScript] 'extends Node2D' — this script is attached to the Game Node2D root.
# [JS equiv]  class Game extends HTMLElement { ... }  (Web Component analogy)
extends Node2D

# ── Node references ────────────────────────────────────────────────────────────
# @onready resolves these paths once the scene tree is fully built.
# $ is shorthand for get_node(). $Ball = get_node("Ball").
# [GDScript] The type annotation after ':' enables editor autocomplete.
# [JS equiv]  this._ball = document.getElementById('ball')
@onready var _ball: CharacterBody2D    = $Ball
@onready var _paddle: AnimatableBody2D = $Paddle
@onready var _camera: Camera2D         = $Camera2D

# ── State ──────────────────────────────────────────────────────────────────────
# Phase 1 uses a simple boolean. Phase 2 replaces this with GameManager.State enum.
var _launched: bool = false

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Give JuiceManager a camera reference for screen shake (Phase 4 uses this).
	# In Phase 1 JuiceManager.register_camera() is a no-op stub — safe to call.
	JuiceManager.register_camera(_camera)

	# Snap ball to above the paddle at startup.
	# reset_to_paddle() is defined in Ball.gd.
	_ball.reset_to_paddle(_paddle.global_position)

	# Connect the ball's 'lost' signal to our handler.
	# .connect() takes a Callable — a reference to a method.
	# [GDScript] signal.connect(Callable) registers a listener.
	# [JS equiv]  ball.addEventListener('lost', this._onBallLost.bind(this))
	_ball.lost.connect(_on_ball_lost)

	# Phase 2: connect GameManager.state_changed here.
	# Phase 2: connect _grid.all_cleared here.
	# Phase 2: connect _grid.brick_destroyed to JuiceManager.emit_burst + shake.

# ── Input ──────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	# Only respond to taps before the ball has been launched.
	# Phase 2: gate this on GameManager.state == State.WAITING instead.
	if _launched:
		return

	# [GDScript] 'is' checks the runtime type of 'event'.
	# [JS equiv]  event instanceof TouchEvent && event.type === 'touchstart'
	if event is InputEventScreenTouch and event.pressed:
		_launch_ball()

func _launch_ball() -> void:
	# Launch at a slight left-of-centre angle for a natural first bounce.
	# Vector2(-0.3, -1.0) points upward-left. launch() normalises it.
	# Phase 2: pass GameManager.level to ball.set_speed_for_level() here.
	_ball.launch(Vector2(-0.3, -1.0))
	_launched = true

# ── Signal handlers ────────────────────────────────────────────────────────────

func _on_ball_lost() -> void:
	# Phase 1: just reset immediately — no lives, no game over screen.
	# Phase 2: replace with GameManager.lose_life() which handles lives and
	#          transitions to DEAD / GAME_OVER states.
	_launched = false
	_ball.reset_to_paddle(_paddle.global_position)
