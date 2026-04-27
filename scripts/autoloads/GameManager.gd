# GameManager.gd
# Autoload singleton — owns the game session state machine.
# Emits signals for every state transition; UI and Game.gd react to these.
#
# State flow:
#   TITLE → WAITING (start_game called)
#   WAITING → PLAYING (set_playing called by Game.gd on ball launch)
#   PLAYING → DEAD (ball lost, lives > 0)
#   PLAYING → GAME_OVER (ball lost, lives == 0)
#   PLAYING → LEVEL_CLEAR (all bricks destroyed)
#   DEAD → WAITING (reset_after_death called by Game.gd after delay)
#   LEVEL_CLEAR → WAITING (advance_level called by LevelClear screen)
#   GAME_OVER → WAITING (restart called by GameOver screen)
#
# [GDScript] 'extends Node' — autoloads attach to a plain Node in the scene tree.
# [JS equiv]  class GameManager { } — singleton service, no rendering role.
extends Node

# ── State enum ─────────────────────────────────────────────────────────────────
# [GDScript] enum defines named integer constants scoped to this class.
# Accessible externally as: GameManager.State.WAITING
# [JS equiv]  const State = Object.freeze({ TITLE: 0, WAITING: 1, ... })
enum State {
	TITLE,
	WAITING,
	PLAYING,
	DEAD,
	GAME_OVER,
	LEVEL_CLEAR,
}

# ── Session state ──────────────────────────────────────────────────────────────
var state: State = State.TITLE
var lives: int   = 3
var score: int   = 0
var level: int   = 1
var seed:  int   = 0
# Lives the player held when the current level began. Used by LevelClear to
# award stars based on lives lost within the level (lives carry between levels,
# so 'lives at clear' alone wouldn't isolate this level's performance).
var level_lives_start: int = 3

# ── Signals ────────────────────────────────────────────────────────────────────
# [GDScript] Typed signal parameters are enforced at connect() time.
# [JS equiv]  this.addEventListener('stateChanged', callback)
signal state_changed(new_state: State)
signal score_changed(new_score: int)
signal lives_changed(new_lives: int)

# ── Public API ─────────────────────────────────────────────────────────────────

## Start a new game session — resets all state and transitions to WAITING.
## initial_seed: pass -1 to use a random seed, or any int for a reproducible seed.
func start_game(initial_seed: int = -1) -> void:
	lives = 3
	level_lives_start = lives
	score = 0
	level = 1
	# randi() returns a random 32-bit unsigned int.
	# [JS equiv]  Math.floor(Math.random() * 2147483647)
	seed = initial_seed if initial_seed >= 0 else randi() % 2147483647
	# Emit resets so HUD refreshes immediately — without these, the HUD would
	# keep showing the previous game's final lives/score after a restart.
	# [JS equiv]  this.dispatchEvent(new CustomEvent('livesChanged', { detail: 3 }))
	emit_signal("lives_changed", lives)
	emit_signal("score_changed", score)
	_set_state(State.WAITING)

## Called by Game.gd immediately after the ball is launched (player tapped).
func set_playing() -> void:
	if state == State.WAITING:
		_set_state(State.PLAYING)

## Called by Game.gd when Ball emits the 'lost' signal.
## Decrements lives and transitions to DEAD (lives remain) or GAME_OVER (lives = 0).
func lose_life() -> void:
	lives -= 1
	emit_signal("lives_changed", lives)
	if lives <= 0:
		_set_state(State.GAME_OVER)
	else:
		_set_state(State.DEAD)

## Called by Game.gd after the death reset animation completes (~0.6 s delay).
## Transitions DEAD → WAITING so the player can re-launch.
func reset_after_death() -> void:
	if state == State.DEAD:
		_set_state(State.WAITING)

## Called by Game.gd when BrickGrid emits all_cleared.
## Transitions PLAYING → LEVEL_CLEAR.
func level_clear() -> void:
	if state == State.PLAYING:
		_set_state(State.LEVEL_CLEAR)

## Called by LevelClear screen's "Next Level" button.
## Increments level number and transitions back to WAITING.
func advance_level() -> void:
	level += 1
	# Snapshot lives entering the new level so LevelClear can compute lives lost
	# in isolation per level on the next clear.
	level_lives_start = lives
	_set_state(State.WAITING)


## Lives lost since the current level began. Used by the LevelClear screen to
## award stars (3 − lost, min 1). 0 means a clean run of this level.
func get_level_lives_lost() -> int:
	return max(0, level_lives_start - lives)

## Called by GameOver screen's "Restart" button.
## Returns to TITLE state — Main.gd will swap Game.tscn for Title.tscn.
## start_game() is called later by Title.gd when the player taps again.
func restart() -> void:
	_set_state(State.TITLE)

## Add points to the running score. Called by Game.gd on each brick_destroyed event.
## Score formula: 10 × (tier + 1). Tier 0 = 10 pts, tier 3 = 40 pts.
## [JS equiv]  gameManager.addScore(points)
func add_score(points: int) -> void:
	score += points
	# emit_signal() fires synchronously to all connected listeners.
	# [JS equiv]  this.dispatchEvent(new CustomEvent('scoreChanged', { detail: score }))
	emit_signal("score_changed", score)

# ── Internal ───────────────────────────────────────────────────────────────────

func _set_state(new_state: State) -> void:
	state = new_state
	emit_signal("state_changed", new_state)
