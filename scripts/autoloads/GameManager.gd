# GameManager.gd
# Autoload singleton — owns game state: lives, score, current level, seed.
# Phases 2–3 fill in the real state machine and signals.
# Stub only for Phase 1: does nothing, but must exist so other scenes can
# reference GameManager without "Autoload not found" errors.
#
# [GDScript] 'extends Node' attaches this script to a plain scene-tree Node.
# [JS equiv]  class GameManager { } — a stateful service class, no rendering.
extends Node

func _ready() -> void:
	# [GDScript] 'pass' is a no-op placeholder — like an empty {} block in JS.
	# [JS equiv]  constructor() {}
	pass
