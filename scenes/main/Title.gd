# Title.gd
# Title screen — shows logo, waits for tap, then transitions to the game.
# Plays entrance animation first; only accepts taps once entrance completes.
#
# [GDScript] extends Node2D — this scene owns no physics bodies.
# [JS equiv]  class TitleScreen extends HTMLElement { ... }
extends Node2D

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _tap_hint: Node2D      = $TapHint

func _ready() -> void:
	# Hide tap hint until entrance completes so it fades in last.
	# [JS equiv]  this._tapHint.style.opacity = '0'
	_tap_hint.modulate.a = 0.0
	_anim.play("entrance")
	# Chain into tap_pulse once entrance finishes.
	# [GDScript] Inline Callable (lambda) — like an arrow fn in JS.
	# [JS equiv]  anim.addEventListener('finish', name => { if(name==='entrance') ... })
	_anim.animation_finished.connect(func(anim_name: String) -> void:
		if anim_name == "entrance":
			_anim.play("tap_pulse")
	)

func _input(event: InputEvent) -> void:
	# Only allow tap once entrance is done (tap_pulse is the active loop).
	# [GDScript] current_animation returns the playing animation name string.
	# [JS equiv]  if (this._anim.currentAnim !== 'tap_pulse') return
	if _anim.current_animation != "tap_pulse":
		return
	if event is InputEventScreenTouch and event.pressed:
		# start_game() → state = WAITING → Main.gd swaps to Game.tscn.
		# [JS equiv]  gameManager.startGame()
		GameManager.start_game()
