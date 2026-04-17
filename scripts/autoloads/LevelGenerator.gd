# LevelGenerator.gd
# Autoload singleton — pure deterministic function: (seed, level) → brick layout.
# Phase 3 fills in the procedural generation algorithm.
# Stub returns an empty array so callers don't crash in Phase 1.
#
# [GDScript] '-> Array' is the return type annotation.
# [JS equiv]  /** @returns {Array} */  function generate(seed, level) { return [] }
extends Node

func generate(_seed: int, _level: int) -> Array:
	# [GDScript] Underscore prefix on parameter names suppresses "unused variable" warning.
	# [JS equiv]  (_seed, _level) => []
	return []
