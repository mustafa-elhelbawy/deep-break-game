# LevelClear.gd
# Overlay shown when all destructible bricks are destroyed.
# Renders a centered modal: hero burst glyph, "LEVEL CLEAR" title, the
# completed level number, a 3-star rating reflecting lives lost in this level,
# and a "Next Level" button.
#
# Star rule: filled = max(1, 3 − lives_lost). One star is always awarded since
# reaching this screen means the level was cleared.
extends CanvasLayer

const _MAX_STARS: int = 3

@onready var _level_label: Label = $Modal/VBox/LevelLabel
@onready var _next_btn: Button   = $Modal/VBox/NextButton
@onready var _stars: Array[Node2D] = [
	$Modal/VBox/StarsRow/Star1Slot/Star1,
	$Modal/VBox/StarsRow/Star2Slot/Star2,
	$Modal/VBox/StarsRow/Star3Slot/Star3,
]

func _ready() -> void:
	_next_btn.pressed.connect(_on_next_pressed)

## Called by Game.gd to show this screen with the completed level number.
func show_for_level(completed_level: int) -> void:
	_level_label.text = "LEVEL %02d COMPLETE" % completed_level
	_apply_stars(GameManager.get_level_lives_lost())
	_next_btn.disabled = false
	show()

func _apply_stars(lives_lost: int) -> void:
	# 0 lost → 3 stars · 1 lost → 2 stars · 2+ lost → 1 star.
	# Clearing the level guarantees at least one star.
	var filled_count: int = clampi(_MAX_STARS - lives_lost, 1, _MAX_STARS)
	for i in _stars.size():
		_stars[i].filled = i < filled_count

func _on_next_pressed() -> void:
	# Debounce: disable immediately to prevent double-tap.
	_next_btn.disabled = true
	GameManager.advance_level()
