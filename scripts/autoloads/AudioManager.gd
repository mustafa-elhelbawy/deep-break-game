# AudioManager.gd
# Autoload singleton — manages an 8-slot AudioStreamPlayer pool.
# Phase 4 fills in the pool and pre-loaded sound streams.
# Stub silently ignores all play() calls so game scenes don't crash.
#
# [GDScript] String is a built-in type — no import needed.
# [JS equiv]  class AudioManager { play(soundName) {} }
extends Node

func play(_sound_name: String) -> void:
	# Intentional no-op in Phase 1. Phase 4 replaces this with pool playback.
	pass
