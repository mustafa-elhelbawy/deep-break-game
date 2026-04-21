# HUD.gd
# Displays score (top-left), lives (top-right), and active power-up (bottom-left).
# Connects to GameManager signals in _ready() so it updates automatically.
#
# [GDScript] 'extends CanvasLayer' — renders above all Node2D game content.
# [JS equiv]  class HUD { constructor() { this._score = 0; this._lives = 3; } }
extends CanvasLayer

# ── Cached node references ─────────────────────────────────────────────────────
# [GDScript] @onready resolves paths after the scene tree is fully built.
# [JS equiv]  this._scoreLabel = document.getElementById('score')
@onready var _score_label: Label       = $ScoreLabel
@onready var _lives_label: Label       = $LivesLabel
@onready var _powerup_container: VBoxContainer = $PowerUpContainer
@onready var _powerup_label: Label     = $PowerUpContainer/PowerUpLabel
@onready var _powerup_bar: ColorRect   = $PowerUpContainer/PowerUpBar

# ── Power-up display state ─────────────────────────────────────────────────────
# Tween for animating the bar width down to zero during power-up countdown.
# [JS equiv]  #barTween = null
var _bar_tween: Tween = null

# Full bar width in pixels — matches PowerUpBar custom_minimum_size.x.
const BAR_FULL_W: float = 100.0

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

## Shows the power-up indicator with a shrinking bar countdown.
## type: "W" | "S" | "M"   duration: seconds until the effect expires.
## Safe to call while already showing — replaces label and restarts the bar.
## [JS equiv]  showPowerup(type, duration) { ... }
func show_powerup(type: String, duration: float) -> void:
	# Set human-readable label text.
	# [JS equiv]  const LABELS = { W: 'WIDE', S: 'SLOW', M: 'MULTI' }
	var labels: Dictionary = {"W": "WIDE", "S": "SLOW", "M": "MULTI"}
	_powerup_label.text = labels.get(type, type)

	# Reset bar to full width before (re)starting the tween.
	# size.x directly sets the rendered width of a ColorRect.
	# [JS equiv]  this._powerUpBar.style.width = BAR_FULL_W + 'px'
	_powerup_bar.size.x = BAR_FULL_W

	# Kill any in-progress tween so we can start a fresh one.
	# [JS equiv]  if (this._barTween) cancelAnimationFrame(this._barTween)
	if _bar_tween != null and _bar_tween.is_valid():
		_bar_tween.kill()

	# Animate bar width from BAR_FULL_W to 0 over `duration` seconds (linear).
	# Tween.tween_property() smoothly interpolates a property over time.
	# [JS equiv]  CSS transition: width 10s linear
	_bar_tween = create_tween()
	_bar_tween.tween_property(_powerup_bar, "size:x", 0.0, duration).set_trans(Tween.TRANS_LINEAR)

	_powerup_container.show()

## Hides the power-up indicator and stops any running countdown tween.
## Called when the effect expires or when all balls are cleared between levels.
## [JS equiv]  hidePowerup() { this._powerUpContainer.style.display = 'none' }
func hide_powerup() -> void:
	if _bar_tween != null and _bar_tween.is_valid():
		_bar_tween.kill()
	_bar_tween = null
	_powerup_container.hide()
