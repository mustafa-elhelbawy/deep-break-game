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

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Give JuiceManager the camera reference (Phase 4 uses it for screen shake).
	# No-op in Phase 2 — stub already accepts the call safely.
	JuiceManager.register_camera(_camera)

	# Connect GameManager state machine to this scene.
	# [JS equiv]  gameManager.addEventListener('stateChanged', this._onStateChanged.bind(this))
	GameManager.state_changed.connect(_on_state_changed)

	# Connect GameManager score/lives directly to HUD.
	# HUD.gd also connects these in its own _ready() — both connections are safe
	# (Godot allows multiple listeners on the same signal).
	GameManager.score_changed.connect(_hud.update_score)
	GameManager.lives_changed.connect(_hud.update_lives)

	# Connect BrickGrid aggregate signals.
	_grid.all_cleared.connect(_on_all_cleared)
	_grid.brick_destroyed.connect(_on_brick_destroyed)

	# Connect Ball lost signal → GameManager life tracking.
	# [GDScript] Inline Callable (lambda) — like an arrow function in JS.
	# [JS equiv]  ball.addEventListener('lost', () => gameManager.loseLife())
	_ball.lost.connect(func(): GameManager.lose_life())

	# Kick off the first game session.
	GameManager.start_game()

# ── State machine reactor ──────────────────────────────────────────────────────

func _on_state_changed(new_state: GameManager.State) -> void:
	# [GDScript] 'match' is like switch/case — uses structural pattern matching.
	# [JS equiv]  switch(newState) { case State.WAITING: ...; break; }
	match new_state:
		GameManager.State.WAITING:
			_spawn_level()
			_ball.reset_to_paddle(_paddle.global_position)
			_game_over.hide()
			_level_clear.hide()

		GameManager.State.DEAD:
			# Ball was lost, lives remain. Reset ball and re-enter WAITING.
			_ball.reset_to_paddle(_paddle.global_position)
			# Phase 4: AudioManager.play("ball_lost") here.
			# Short delay then transition back to WAITING so player sees the reset.
			# [GDScript] await pauses this function until the timer finishes.
			# [JS equiv]  await new Promise(resolve => setTimeout(resolve, 600))
			await get_tree().create_timer(0.6).timeout
			GameManager.reset_after_death()

		GameManager.State.GAME_OVER:
			_ball.deactivate()
			# Phase 4: AudioManager.play("game_over") here.
			_game_over.show_with_score(GameManager.score)

		GameManager.State.LEVEL_CLEAR:
			_ball.deactivate()
			# Phase 4: AudioManager.play("level_clear") here.
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
	# Phase 3: call _ball.set_speed_for_level(GameManager.level) here.
	_ball.launch(Vector2(-0.3, -1.0))
	GameManager.set_playing()

func _spawn_level() -> void:
	# Phase 3: pass LevelGenerator.generate(GameManager.seed, GameManager.level)
	# instead of an empty array — the fallback layout fires until then.
	_grid.spawn([])

# ── BrickGrid signal handlers ──────────────────────────────────────────────────

func _on_all_cleared() -> void:
	GameManager.level_clear()

func _on_brick_destroyed(pos: Vector2, tier: int) -> void:
	# Score: 10 × (tier + 1). Tier 0 = 10 pts, tier 3 = 40 pts.
	# [JS equiv]  gameManager.addScore(10 * (tier + 1))
	GameManager.add_score(10 * (tier + 1))

	# Phase 4: JuiceManager.emit_burst(pos, tier) here.
	# Phase 4: JuiceManager.shake(0.3, 0.1) here.
	# Phase 4: AudioManager.play("brick_destroy") here.
