# GameOver.gd
# Full-screen overlay shown when lives reach 0.
# Displays final score and a debounced Restart button.
#
# [GDScript] 'extends CanvasLayer' — renders above all 2D game content.
# [JS equiv]  class GameOverScreen { show() {} hide() {} }
extends CanvasLayer

# ── Cached node references ─────────────────────────────────────────────────────
@onready var _score_label: Label  = $VBox/ScoreLabel
@onready var _restart_btn: Button = $VBox/RestartButton

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Connect the restart button's pressed signal.
	# [GDScript] signal.connect(Callable) — like addEventListener in JS.
	# [JS equiv]  this._restartBtn.addEventListener('click', this._onRestart.bind(this))
	_restart_btn.pressed.connect(_on_restart_pressed)

# ── Public API ─────────────────────────────────────────────────────────────────

## Called by Game.gd to show this screen with the final score.
## [JS equiv]  showWithScore(finalScore) { this._scoreLabel.textContent = `Score: ${finalScore}` }
func show_with_score(final_score: int) -> void:
	_score_label.text = "Score: %d" % final_score
	_restart_btn.disabled = false
	show()

# ── Handlers ───────────────────────────────────────────────────────────────────

func _on_restart_pressed() -> void:
	# Debounce: disable button immediately to prevent double-tap.
	# Re-enabled automatically when show_with_score() is called next time.
	_restart_btn.disabled = true

	# GameManager.restart() resets state and emits state_changed(WAITING).
	# Game.gd reacts to that signal and hides this screen.
	# [JS equiv]  gameManager.restart()
	GameManager.restart()
