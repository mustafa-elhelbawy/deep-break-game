# GameOver.gd
# Full-screen overlay shown when lives reach 0.
# Renders a centered modal: hero "X" glyph, "GAME OVER" title, divider,
# "FINAL SCORE" caption with the score, and a debounced Restart button.
#
# [GDScript] 'extends CanvasLayer' — renders above all 2D game content.
# [JS equiv]  class GameOverScreen { show() {} hide() {} }
extends CanvasLayer

@onready var _score_label: Label  = $Modal/VBox/ScoreLabel
@onready var _restart_btn: Button = $Modal/VBox/RestartButton

func _ready() -> void:
	_restart_btn.pressed.connect(_on_restart_pressed)

## Called by Game.gd to show this screen with the final score.
func show_with_score(final_score: int) -> void:
	_score_label.text = _format_score(final_score)
	_restart_btn.disabled = false
	show()

func _on_restart_pressed() -> void:
	# Debounce: disable button immediately to prevent double-tap.
	# Re-enabled when show_with_score() is called next time.
	_restart_btn.disabled = true
	GameManager.restart()

# Insert thousands separators ("12480" → "12,480") so large scores read
# cleanly at the modal's display size.
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
