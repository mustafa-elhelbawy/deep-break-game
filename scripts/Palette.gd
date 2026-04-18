# Palette.gd
# Global static colour constants for the bioluminescent deep-sea theme.
# Registered as a class_name so any script can use Palette.TEAL without importing.
#
# [GDScript] 'class_name' makes this type globally accessible across the project.
# [JS equiv]  export const Palette = { TEAL: '#00c8b8', ... }  (named ES module export)
class_name Palette
extends Node

# ── Brand colours ──────────────────────────────────────────────────────────────
# All values are linear (non-sRGB) as Godot 4 uses linear colour space internally.
# [GDScript] Color(r, g, b) — components are 0.0–1.0 floats.
# [JS equiv]  const BACKGROUND = { r: 0.039, g: 0.055, b: 0.102 }  (or CSS '#0a0e1a')
const BACKGROUND: Color  = Color(0.039, 0.055, 0.102)  # #0a0e1a  dark navy
const TEAL:       Color  = Color(0.000, 0.784, 0.722)  # #00c8b8  tier 0 bricks + paddle
const CYAN:       Color  = Color(0.000, 0.878, 1.000)  # #00e0ff  tier 1 bricks
const AMBER:      Color  = Color(1.000, 0.757, 0.027)  # #ffc107  tier 2 bricks
const VIOLET:     Color  = Color(0.694, 0.404, 1.000)  # #b167ff  tier 3 / indestructible
const WHITE_SOFT: Color  = Color(0.878, 0.925, 1.000)  # #e0ecff  ball (never pure white)

# ── Tier colour lookup ─────────────────────────────────────────────────────────
# Indexed by tier (0–3) for use in JuiceManager.emit_burst() and BrickBurst.
# [GDScript] Array[Color] — typed array of Color values.
# [JS equiv]  const TIER_COLOURS = [Palette.TEAL, Palette.CYAN, Palette.AMBER, Palette.VIOLET]
const TIER_COLOURS: Array[Color] = [TEAL, CYAN, AMBER, VIOLET]
