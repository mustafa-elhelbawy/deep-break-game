# LevelClear.gd
# Overlay shown when all destructible bricks are destroyed.
# Player taps "Next Level" to advance to the next procedural level.
#
# [GDScript] 'extends CanvasLayer' — renders above all 2D game content.
# [JS equiv]  class LevelClearScreen { show(level) {} hide() {} }
extends CanvasLayer

# ── Cached node references ─────────────────────────────────────────────────────
@onready var _level_label: Label = $VBox/LevelLabel
@onready var _next_btn: Button   = $VBox/NextButton

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Connect the Next Level button's pressed signal.
	# [GDScript] signal.connect(Callable) — like addEventListener in JS.
	# [JS equiv]  this._nextBtn.addEventListener('click', this._onNext.bind(this))
	_next_btn.pressed.connect(_on_next_pressed)

# ── Public API ─────────────────────────────────────────────────────────────────

## Called by Game.gd to show this screen with the completed level number.
## [JS equiv]  showForLevel(completedLevel) { this._levelLabel.textContent = `Level ${completedLevel} complete` }
func show_for_level(completed_level: int) -> void:
	_level_label.text = "Level %d complete" % completed_level
	_next_btn.disabled = false
	show()

# ── Handlers ───────────────────────────────────────────────────────────────────

func _on_next_pressed() -> void:
	# Debounce: disable immediately to prevent double-tap.
	_next_btn.disabled = true

	# GameManager.advance_level() increments level and emits state_changed(WAITING).
	# Game.gd reacts by hiding this screen and spawning a new brick layout.
	# [JS equiv]  gameManager.advanceLevel()
	GameManager.advance_level()
