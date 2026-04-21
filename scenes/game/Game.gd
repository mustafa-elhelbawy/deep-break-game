# Game.gd
# Root controller for a play session — Phase 2 full implementation.
#
# Responsibilities:
#   - Reacts to GameManager state transitions
#   - Spawns bricks via BrickGrid
#   - Wires Ball lost signal → GameManager.lose_life()
#   - Wires BrickGrid signals → score + juice
#   - Shows/hides GameOver and LevelClear overlays
#
# Phase 1 was: "tap to launch, ball bounces". This replaces that stub entirely.
# Phase 3 will add: LevelGenerator data passed to BrickGrid.spawn()
# Phase 4 will add: JuiceManager calls for all game events
#
# [GDScript] 'extends Node2D' — root of the play scene.
# [JS equiv]  class Game extends HTMLElement { ... }
extends Node2D

# ── Scene resources ────────────────────────────────────────────────────────────
# Power-up token scene — spawned here, not in Brick.gd, to keep visuals out of data nodes (ADR-002).
# [JS equiv]  import PowerUpScene from './PowerUp.js'
const PowerUpScene: PackedScene = preload("res://scenes/game/PowerUp.tscn")
# Extra ball scene — reused for multi-ball M power-up (T055).
# [JS equiv]  import BallScene from './Ball.js'
const BallScene: PackedScene = preload("res://scenes/game/Ball.tscn")

# ── Node references ────────────────────────────────────────────────────────────
# [GDScript] @onready resolves paths once the scene tree is built.
# $ is shorthand for get_node("NodeName").
# [JS equiv]  this._ball = document.getElementById('ball')
@onready var _ball: CharacterBody2D    = $Ball
@onready var _paddle: AnimatableBody2D = $Paddle
@onready var _camera: Camera2D         = $Camera2D
@onready var _grid: Node2D             = $BrickGrid
@onready var _hud: CanvasLayer         = $HUD
@onready var _game_over: CanvasLayer   = $GameOver
@onready var _level_clear: CanvasLayer = $LevelClear

# ── State ──────────────────────────────────────────────────────────────────────
# Tracks the state we came FROM so WAITING knows whether to re-spawn bricks.
# After DEAD (life lost), bricks must NOT reset — the player continues the same layout.
# After LEVEL_CLEAR or GAME_OVER, bricks DO reset for a fresh grid.
# [JS equiv]  this._prevState = State.TITLE
var _prev_state: GameManager.State = GameManager.State.TITLE

# Active ball counter for multi-ball (T055). Starts at 1 (primary ball only).
# Lives only decrement when _ball_count drops to zero (ADR-006).
# [JS equiv]  #ballCount = 1
var _ball_count: int = 1

# Extra ball instances spawned by M power-up. Primary ball is always _ball.
# [JS equiv]  #extraBalls = []  (private class field)
var _extra_balls: Array[CharacterBody2D] = []

# Slow-motion timer — tracked to cancel on re-catch (replacement behaviour).
# [JS equiv]  #slowTimer = null
var _slow_timer: SceneTreeTimer = null
const SLOW_DURATION: float = 10.0

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Give JuiceManager the camera reference (Phase 4 uses it for screen shake).
	# No-op in Phase 2 — stub already accepts the call safely.
	JuiceManager.register_camera(_camera)

	# Connect GameManager state machine to this scene.
	# [JS equiv]  gameManager.addEventListener('stateChanged', this._onStateChanged.bind(this))
	GameManager.state_changed.connect(_on_state_changed)

	# NOTE: score_changed / lives_changed are connected inside HUD._ready() — no
	# need to connect them here as well. Double-connecting the same Callable prints
	# a Godot warning and the second connect is silently ignored anyway.

	# Connect BrickGrid aggregate signals.
	_grid.all_cleared.connect(_on_all_cleared)
	_grid.brick_destroyed.connect(_on_brick_destroyed)
	# Wire brick_hit through BrickGrid relay — sound plays here, not in Brick.gd (T049/BUG-3).
	# [JS equiv]  this._grid.addEventListener('brickHit', this._onBrickHit.bind(this))
	_grid.brick_hit.connect(_on_brick_hit)
	# Wire power-up relay — Game.gd spawns the token (ADR-002).
	# [JS equiv]  this._grid.addEventListener('powerupDropped', this._onPowerupDropped.bind(this))
	_grid.powerup_dropped.connect(_on_powerup_dropped)

	# Connect Ball lost signal → life counter (T049 / ADR-006).
	# Named method — cannot double-fire like an anonymous lambda when multi-ball is added.
	# [JS equiv]  ball.addEventListener('lost', this._onPrimaryBallLost.bind(this))
	_ball.lost.connect(_on_primary_ball_lost)

	# React to the current state rather than calling start_game() directly.
	# Main.gd loaded us because GameManager.state is already WAITING (set by Title.gd).
	# Calling start_game() here would reset score/lives to zero on every scene swap.
	# [JS equiv]  this._onStateChanged(gameManager.state)
	_on_state_changed(GameManager.state)

# ── State machine reactor ──────────────────────────────────────────────────────

func _on_state_changed(new_state: GameManager.State) -> void:
	# Capture and update _prev_state BEFORE the match so it is always recorded
	# even when a branch contains 'await' (which suspends this coroutine before
	# reaching the bottom of the function).
	#
	# Why this matters for DEAD:
	#   _on_state_changed(DEAD) hits 'await 0.6s' and suspends.
	#   Inside that same coroutine, GameManager.reset_after_death() fires
	#   _on_state_changed(WAITING) as a *nested* synchronous call.
	#   If _prev_state were updated at the bottom, it would still be PLAYING
	#   at that point — making the WAITING branch think it came from PLAYING
	#   and incorrectly re-spawn bricks.
	#   By updating _prev_state first, it is already DEAD when WAITING runs. ✓
	#
	# [JS equiv]  const cameFrom = this._prevState; this._prevState = newState
	var came_from: GameManager.State = _prev_state
	_prev_state = new_state

	# [GDScript] 'match' is like switch/case — uses structural pattern matching.
	# [JS equiv]  switch(newState) { case State.WAITING: ...; break; }
	match new_state:
		GameManager.State.WAITING:
			# Only (re)spawn bricks when starting fresh — NOT when recovering from a
			# lost ball. After DEAD the same brick layout must persist so the player
			# continues from where the ball fell, and accumulated score is preserved.
			# [JS equiv]  if (cameFrom !== State.DEAD) this._spawnLevel()
			if came_from != GameManager.State.DEAD:
				# Fresh level start — clean up any extra balls from previous level.
				_clear_extra_balls()
				_spawn_level()
			_ball.reset_to_paddle(_paddle.global_position)
			_game_over.hide()
			_level_clear.hide()

		GameManager.State.DEAD:
			# Ball was lost, lives remain. Reset ball and re-enter WAITING.
			_ball.reset_to_paddle(_paddle.global_position)
			AudioManager.play("ball_lost")
			# Short delay then transition back to WAITING so player sees the reset.
			# [GDScript] await pauses this function until the timer finishes.
			# [JS equiv]  await new Promise(resolve => setTimeout(resolve, 600))
			await get_tree().create_timer(0.6).timeout
			GameManager.reset_after_death()

		GameManager.State.GAME_OVER:
			# Clean up extra balls before stopping — avoids orphaned ball nodes.
			_clear_extra_balls()
			_ball.deactivate()
			AudioManager.play("game_over")
			_game_over.show_with_score(GameManager.score)

		GameManager.State.LEVEL_CLEAR:
			# Clean up extra balls — next level starts fresh with one ball.
			_clear_extra_balls()
			_ball.deactivate()
			AudioManager.play("level_clear")
			_level_clear.show_for_level(GameManager.level)

# ── Input ──────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	# Only launch ball when in WAITING state (ball sitting on paddle).
	# [GDScript] '!=' comparison — same as JS.
	if GameManager.state != GameManager.State.WAITING:
		return
	if event is InputEventScreenTouch and event.pressed:
		_launch_ball()

# ── Private helpers ────────────────────────────────────────────────────────────

func _launch_ball() -> void:
	# Scale ball speed for the current level before each serve.
	# Level 1 = 432 px/s · level 10 = 720 px/s · capped at 800 px/s from level 13+.
	# [JS equiv]  this._ball.setSpeedForLevel(GameManager.level)
	_ball.set_speed_for_level(GameManager.level)
	_ball.launch(Vector2(-0.3, -1.0))
	GameManager.set_playing()

func _spawn_level() -> void:
	# generate() now returns a Dictionary: { "bricks": Array, "layout_flipped": bool }
	# layout_flipped is always false until T060 adds real flip logic.
	# [JS equiv]  const { bricks, layoutFlipped } = LevelGenerator.generate(seed, level)
	var level_data: Dictionary = LevelGenerator.generate(GameManager.seed, GameManager.level)
	var descriptors: Array = level_data["bricks"]
	_grid.spawn(descriptors)

# ── BrickGrid signal handlers ──────────────────────────────────────────────────

func _on_all_cleared() -> void:
	GameManager.level_clear()

## Called when a brick survives a hit (HP > 0 after decrement).
## Pos is the world position — available for future particle effects.
func _on_brick_hit(_pos: Vector2) -> void:
	AudioManager.play("brick_hit")

func _on_brick_destroyed(pos: Vector2, tier: int) -> void:
	# Score: 10 × (tier + 1). Tier 0 = 10 pts, tier 3 = 40 pts.
	# [JS equiv]  gameManager.addScore(10 * (tier + 1))
	GameManager.add_score(10 * (tier + 1))

	JuiceManager.emit_burst(pos, tier)
	JuiceManager.shake(0.3, 0.1)
	AudioManager.play("brick_destroy")

# ── Ball lost handlers ─────────────────────────────────────────────────────────

## Primary ball lost — delegates to shared counter logic (ADR-006).
## Separate named method so it can be disconnected and won't double-fire
## when extra-ball lambdas are also connected (T055).
func _on_primary_ball_lost() -> void:
	_on_ball_lost()

## Shared ball-lost counter. Decrements _ball_count; only loses a life when all
## active balls are gone. Extra balls (T055) call this too via their own lambdas.
func _on_ball_lost() -> void:
	_ball_count -= 1
	# [JS equiv]  if (this._ballCount <= 0) { this._ballCount = 1; gameManager.loseLife() }
	if _ball_count <= 0:
		_ball_count = 1
		GameManager.lose_life()

# ── Power-up handling ──────────────────────────────────────────────────────────

## Called by BrickGrid relay when a brick with a power-up is destroyed.
## Spawns the falling token at the brick's world position.
## [JS equiv]  _onPowerupDropped(type, pos) { const token = new PowerUpToken(); ... }
func _on_powerup_dropped(type: String, pos: Vector2) -> void:
	var token: Area2D = PowerUpScene.instantiate()
	add_child(token)
	# Place at brick's world position — token then falls under its own _physics_process.
	token.global_position = pos
	token.setup(type)
	# Connect catch signal → effect handler (T053–T055 implement effects).
	# [JS equiv]  token.addEventListener('caught', type => this._onPowerupCaught(type))
	token.caught.connect(_on_powerup_caught)

## Called when the paddle catches a falling power-up token.
## type: "W" (Wide), "S" (Slow), "M" (Multi-Ball)
func _on_powerup_caught(type: String) -> void:
	match type:
		"W":
			# Expand paddle to 1.8× width for 10 s. Catching again resets timer.
			# [JS equiv]  this._paddle.activateWide()
			_paddle.activate_wide()
		"S":
			# Slow all active balls to 55% speed for 10 s. Catching again resets timer.
			_activate_slow()
		"M":
			# Spawn a second ball. No-op if one is already active.
			_activate_multiball()

# ── Slow-motion effect (T054) ──────────────────────────────────────────────────

func _activate_slow() -> void:
	# Cancel existing timer on re-catch (replacement behaviour).
	if _slow_timer != null and is_instance_valid(_slow_timer):
		if _slow_timer.timeout.is_connected(_revert_slow):
			_slow_timer.timeout.disconnect(_revert_slow)

	# Apply to primary ball.
	# [JS equiv]  this._ball.activateSlow()
	_ball.activate_slow()
	# Apply to any extra balls active during multi-ball.
	for b in _extra_balls:
		if is_instance_valid(b):
			b.activate_slow()

	_slow_timer = get_tree().create_timer(SLOW_DURATION)
	_slow_timer.timeout.connect(_revert_slow)

func _revert_slow() -> void:
	_ball.revert_slow()
	for b in _extra_balls:
		if is_instance_valid(b):
			b.revert_slow()
	_slow_timer = null

# ── Multi-ball effect (T055) ───────────────────────────────────────────────────

func _activate_multiball() -> void:
	# Only one extra ball at a time — catching M while active does nothing.
	# [JS equiv]  if (this._extraBalls.length > 0) return
	if _extra_balls.size() > 0:
		return

	var extra: CharacterBody2D = BallScene.instantiate()
	add_child(extra)
	# Offset slightly so the two balls don't start at the identical position.
	extra.global_position = _ball.global_position + Vector2(20.0, 0.0)
	extra.set_speed_for_level(GameManager.level)

	# Inherit slow-mo if already active.
	if _slow_timer != null and is_instance_valid(_slow_timer):
		extra.activate_slow()

	# Launch in mirror direction for variety.
	# [JS equiv]  extraBall.launch({ x: 0.3, y: -1.0 })
	extra.launch(Vector2(0.3, -1.0))

	_extra_balls.append(extra)
	_ball_count += 1
	# Anonymous lambda here is intentional — extra balls are cleaned up by _clear_extra_balls()
	# when the level ends, so disconnection on scene teardown is not a concern.
	# [JS equiv]  extra.addEventListener('lost', () => this._onExtraBallLost(extra))
	extra.lost.connect(func(): _on_extra_ball_lost(extra))

func _on_extra_ball_lost(ball: CharacterBody2D) -> void:
	_extra_balls.erase(ball)
	_on_ball_lost()

## Returns active extra balls — used by _activate_slow / _revert_slow.
func _get_extra_balls() -> Array:
	return _extra_balls

## Frees all extra balls and resets _ball_count to 1.
## Called on WAITING (non-DEAD), GAME_OVER, and LEVEL_CLEAR transitions.
func _clear_extra_balls() -> void:
	for b in _extra_balls:
		if is_instance_valid(b):
			b.queue_free()
	_extra_balls.clear()
	# [JS equiv]  this._ballCount = 1
	_ball_count = 1
