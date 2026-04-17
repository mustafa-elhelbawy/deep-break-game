# HUD.gd
# Displays score (top-left) and lives (top-right).
# Connects to GameManager signals in _ready() so it updates automatically.
# Phase 4 replaces the default font with ui_font.ttf and adds icon sprites for lives.
#
# [GDScript] 'extends CanvasLayer' — renders above all Node2D game content.
# [JS equiv]  class HUD { constructor() { this._score = 0; this._lives = 3; } }
extends CanvasLayer

# ── Cached node references ─────────────────────────────────────────────────────
# [GDScript] @onready resolves paths after the scene tree is fully built.
# [JS equiv]  this._scoreLabel = document.getElementById('score')
@onready var _score_label: Label = $ScoreLabel
@onready var _lives_label: Label = $LivesLabel

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Connect to GameManager signals so HUD updates automatically on every change.
	# [GDScript] signal.connect(Callable) — registers a listener.
	# [JS equiv]  gameManager.addEventListener('scoreChanged', this.updateScore.bind(this))
	GameManager.score_changed.connect(update_score)
	GameManager.lives_changed.connect(update_lives)

	# Initialise display to match current GameManager state immediately.
	update_score(GameManager.score)
	update_lives(GameManager.lives)

# ── Public API ─────────────────────────────────────────────────────────────────

## Updates the score label. Called via signal and directly by Game.gd.
## [JS equiv]  updateScore(n) { this._scoreLabel.textContent = String(n) }
func update_score(new_score: int) -> void:
	_score_label.text = str(new_score)

## Updates the lives label. Called via signal and directly by Game.gd.
## [JS equiv]  updateLives(n) { this._livesLabel.textContent = `♥ ${n}` }
func update_lives(new_lives: int) -> void:
	# '%d' is GDScript's printf-style integer format — same as JS template literal.
	# [JS equiv]  `♥ ${newLives}`
	_lives_label.text = "♥ %d" % new_lives
