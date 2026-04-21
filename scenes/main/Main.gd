# Main.gd
# Scene root — routes between Title.tscn and Game.tscn based on GameManager state.
# Listens to state_changed and swaps the active child scene manually (ADR-005).
#
# Why manual swap instead of change_scene_to_file():
#   Manual add_child/queue_free gives deterministic ordering — old scene freed
#   first, new scene initialised after. GameManager autoload is never reset.
#
# [GDScript] extends Node — no 2D or 3D rendering at this level.
# [JS equiv]  class AppRouter { } — top-level controller, no visual output.
extends Node

# ── Scene resources ────────────────────────────────────────────────────────────
# Preload both scenes so swaps are instantaneous (no disk reads during play).
# [JS equiv]  import TitleScene from './scenes/main/Title.js'  (static import)
const TitleScene: PackedScene = preload("res://scenes/main/Title.tscn")
const GameScene:  PackedScene = preload("res://scenes/game/Game.tscn")

# ── State ──────────────────────────────────────────────────────────────────────
# Reference to the currently active child scene node.
# [JS equiv]  #currentScene = null  (private class field)
var _current_scene: Node = null

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Subscribe to every state transition in the game.
	# [JS equiv]  gameManager.addEventListener('stateChanged', this._onStateChanged.bind(this))
	GameManager.state_changed.connect(_on_state_changed)
	# Cold launch: always start at the title screen.
	_load_title()

# ── Scene loading ──────────────────────────────────────────────────────────────

func _load_title() -> void:
	_swap_to(TitleScene)

func _load_game() -> void:
	_swap_to(GameScene)

func _swap_to(packed: PackedScene) -> void:
	# Free existing scene before loading new one.
	# queue_free() defers destruction to end-of-frame — safe even mid-signal.
	# [JS equiv]  if (this._currentScene) this._currentScene.remove()
	if _current_scene != null and is_instance_valid(_current_scene):
		_current_scene.queue_free()
	# Instantiate and attach as direct child of Main.
	# [GDScript] PackedScene.instantiate() = new SceneClass() in JS.
	_current_scene = packed.instantiate()
	add_child(_current_scene)

# ── State reactor ──────────────────────────────────────────────────────────────

func _on_state_changed(new_state: GameManager.State) -> void:
	match new_state:
		GameManager.State.WAITING:
			# WAITING from TITLE = player tapped "play" — swap to game.
			# WAITING from DEAD / LEVEL_CLEAR happens inside Game.tscn — no swap needed.
			# [JS equiv]  if (this._currentScene?.scenePath === TitleScene.path) ...
			if _current_scene != null and _current_scene.scene_file_path == TitleScene.resource_path:
				_load_game()

		GameManager.State.TITLE:
			# Return to title (e.g., after Game Over restart).
			_load_title()
