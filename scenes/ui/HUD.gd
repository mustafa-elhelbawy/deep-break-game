# HUD.gd
# Top HUD overlay shown during gameplay.
# Displays score (top-left), level number (top-center), lives row (top-right),
# and an active power-up indicator (bottom-left).
#
# Connects to GameManager signals so updates are automatic. Level is refreshed
# on every state transition since GameManager doesn't emit a level_changed
# signal — `level` only mutates inside advance_level()/start_game(), each of
# which is followed by a state change.
extends CanvasLayer

const BAR_FULL_W: float = 128.0  # PowerUpBar inner width (130 panel - 2*1px border)

@onready var _score_label: Label = $ScoreGroup/ScoreLabel
@onready var _level_label: Label = $LevelGroup/LevelLabel
@onready var _life_dots: Array[Node2D] = [
	$LivesGroup/LivesRow/LifeDot1Slot/LifeDot1,
	$LivesGroup/LivesRow/LifeDot2Slot/LifeDot2,
	$LivesGroup/LivesRow/LifeDot3Slot/LifeDot3,
]
@onready var _powerup_container: VBoxContainer = $PowerUpContainer
@onready var _powerup_label: Label             = $PowerUpContainer/PowerUpLabel
@onready var _powerup_bar: ColorRect           = $PowerUpContainer/PowerUpBarBg/PowerUpBar
@onready var _powerup_time: Label              = $PowerUpContainer/PowerUpTimeLabel

var _bar_tween: Tween = null

# Power-up text shown next to the lightning glyph in the label.
const _POWERUP_NAMES: Dictionary = {"W": "WIDE", "S": "SLOW", "M": "MULTI"}
# Static description shown beneath the bar.
const _POWERUP_DESCS: Dictionary = {"W": "PADDLE +80%", "S": "BALL ×0.55", "M": "EXTRA BALL"}

func _ready() -> void:
	GameManager.score_changed.connect(update_score)
	GameManager.lives_changed.connect(update_lives)
	GameManager.state_changed.connect(_on_state_changed)

	update_score(GameManager.score)
	update_lives(GameManager.lives)
	_update_level(GameManager.level)

# ── Public API ────────────────────────────────────────────────────────────────

func update_score(new_score: int) -> void:
	_score_label.text = _format_score(new_score)

func update_lives(new_lives: int) -> void:
	for i in _life_dots.size():
		_life_dots[i].filled = i < new_lives

## Shows the power-up indicator with a shrinking bar countdown.
## type: "W" | "S" | "M"   duration: seconds until the effect expires.
## Pass duration <= 0 for indicators with no timer (e.g. "M" multi-ball).
func show_powerup(type: String, duration: float) -> void:
	var name_text: String = _POWERUP_NAMES.get(type, type)
	# Lightning bolt prefix mirrors the "⚡" glyph in the design.
	_powerup_label.text = "⚡  %s" % name_text
	_powerup_time.text = _POWERUP_DESCS.get(type, "")

	_kill_tween(_bar_tween)

	_powerup_bar.size.x = BAR_FULL_W
	if duration > 0.0:
		_bar_tween = create_tween()
		_bar_tween.tween_property(_powerup_bar, "size:x", 0.0, duration).set_trans(Tween.TRANS_LINEAR)

	_powerup_container.show()

func hide_powerup() -> void:
	_kill_tween(_bar_tween)
	_bar_tween = null
	_powerup_container.hide()

# ── Internal ──────────────────────────────────────────────────────────────────

func _on_state_changed(_new_state: GameManager.State) -> void:
	# Refresh level whenever the state changes — covers start_game (TITLE→WAITING)
	# and advance_level (LEVEL_CLEAR→WAITING) without needing a dedicated signal.
	_update_level(GameManager.level)

func _update_level(level: int) -> void:
	_level_label.text = "%02d" % level

func _kill_tween(t: Tween) -> void:
	if t != null and t.is_valid():
		t.kill()

# Insert thousands separators ("12480" → "12,480").
func _format_score(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if n < 0 else out
