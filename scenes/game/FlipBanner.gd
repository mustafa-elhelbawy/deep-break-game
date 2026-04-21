# FlipBanner.gd
# Brief full-screen announcement shown at the start of a flipped level (T064).
# Auto-hides after the animation completes — caller has no teardown responsibility.
#
# [GDScript] 'extends CanvasLayer' — renders above all game content.
# [JS equiv]  class FlipBanner extends HTMLElement { showBanner() { ... } }
extends CanvasLayer

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Hidden until show_banner() is explicitly called.
	hide()

# ── Public API ─────────────────────────────────────────────────────────────────

## Plays a 2.2 s fade-in → hold → fade-out animation then self-hides.
## Safe to call while already visible — kills the previous tween and restarts.
## Called by Game.gd._apply_flip() when layout_flipped = true.
## [JS equiv]  showBanner() { this.style.display = 'flex'; setTimeout(hide, 2200) }
func show_banner() -> void:
	modulate.a = 0.0
	show()

	# Chain: fade in (0.25 s) → hold (1.5 s) → fade out (0.45 s) → hide.
	# Tween.TRANS_SINE gives a smooth ease rather than linear opacity.
	# [JS equiv]  element.animate([{opacity:0},{opacity:1},{opacity:1},{opacity:0}], { duration: 2200 })
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(1.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(hide)
