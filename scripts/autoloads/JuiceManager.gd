# JuiceManager.gd
# Autoload singleton — screen shake, colour flash, particle burst effects.
# Phase 4 fills in the trauma-based shake system and GPUParticles2D bursts.
# All methods are no-ops in Phase 1 so game scenes can call them safely.
#
# [GDScript] 'Color' is a built-in struct — r, g, b, a floats in 0..1 range.
# [JS equiv]  class JuiceManager { shake(i,d){} flash(c,d){} emitBurst(p,t){} }
extends Node

func shake(_intensity: float, _duration: float) -> void:
	pass

func flash(_colour: Color, _duration: float) -> void:
	pass

func emit_burst(_world_pos: Vector2, _tier: int) -> void:
	pass
