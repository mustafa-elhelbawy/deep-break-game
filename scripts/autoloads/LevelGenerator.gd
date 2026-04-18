# LevelGenerator.gd
# Autoload singleton — pure function: (seed, level) → Array[Dictionary].
# No scene dependencies. Same inputs always produce identical output (deterministic).
#
# Each returned dictionary has:
#   "grid_pos"   : Vector2i  — column (x) and row (y) in the grid
#   "hit_points" : int       — 1–3 for destructible; 0 for indestructible
#   "tier"       : int       — 0–3, maps to atlas colour region
#
# Difficulty by level:
#   Levels  1–4:  5 rows,  max 1 HP, no indestructible
#   Levels  5–9:  7 rows,  max 2 HP, no indestructible
#   Levels 10–19: 9 rows,  max 3 HP, 5% indestructible
#   Levels 20+:  12 rows,  max 3 HP, 10% indestructible
#
# [GDScript] 'extends Node' — autoload attaches to a plain Node in the scene tree.
# [JS equiv]  class LevelGenerator { generate(seed, level) { return [...] } }
extends Node

# ── Grid constants ─────────────────────────────────────────────────────────────
# [GDScript] 'const' = compile-time constant; cannot be reassigned.
# [JS equiv]  const COLS = 7
const COLS: int     = 7
const MIN_ROWS: int = 4
const MAX_ROWS: int = 12

# ── Difficulty table ───────────────────────────────────────────────────────────
# Each entry activates when GameManager.level >= threshold.
# The last matching entry (highest threshold ≤ level) wins.
# [GDScript] Array of Dictionaries — like an array of plain objects in JS.
# [JS equiv]  const DIFFICULTY_TABLE = [{ threshold: 1, max_rows: 5, ... }, ...]
const DIFFICULTY_TABLE: Array = [
	{ "threshold": 1,  "max_rows": 5,  "max_hp": 1, "indestructible_chance": 0.00 },
	{ "threshold": 5,  "max_rows": 7,  "max_hp": 2, "indestructible_chance": 0.00 },
	{ "threshold": 10, "max_rows": 9,  "max_hp": 3, "indestructible_chance": 0.05 },
	{ "threshold": 20, "max_rows": 12, "max_hp": 3, "indestructible_chance": 0.10 },
]

# ── Public API ─────────────────────────────────────────────────────────────────

## Pure function — returns an Array of brick descriptor Dictionaries.
## Same seed + level always produces the same layout (deterministic).
## Called by Game.gd in _spawn_level() on every new level start.
## [JS equiv]  generate(seed, level) { return descriptors }
func generate(seed: int, level: int) -> Array:
	# Clamp seed to positive 32-bit range to avoid RandomNumberGenerator issues.
	# abs() = Math.abs() in JS.
	var safe_seed: int = abs(seed % 2147483647)

	# XOR seed with a level-based offset using a large prime multiplier.
	# This ensures levels 1 and 2 produce very different layouts from the same base seed.
	# [GDScript] ^ is bitwise XOR — same operator as in JS.
	# [JS equiv]  const levelSeed = safeSeed ^ (level * 2654435761)
	var level_seed: int = safe_seed ^ (level * 2654435761)

	# Use a LOCAL RandomNumberGenerator — never share state with the engine's global rng.
	# Global randi() is consumed by the engine itself, making generation non-reproducible.
	# [JS equiv]  const rng = new SeededRandom(levelSeed)  (seedrandom lib equivalent)
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed

	# ── Determine difficulty for this level ────────────────────────────────────
	# Walk the table; the last entry whose threshold ≤ level wins.
	# [JS equiv]  const diff = DIFFICULTY_TABLE.filter(e => level >= e.threshold).at(-1)
	var diff: Dictionary = DIFFICULTY_TABLE[0]
	for entry in DIFFICULTY_TABLE:
		if level >= entry["threshold"]:
			diff = entry

	# ── Decide row count ───────────────────────────────────────────────────────
	# Rows grow linearly with level (0.4 rows per level) capped by difficulty table.
	# clampi() = integer clamp — like Math.max(MIN, Math.min(MAX, v)) in JS.
	var rows: int = clampi(
		MIN_ROWS + int(level * 0.4),
		MIN_ROWS,
		diff["max_rows"]
	)

	# ── Build descriptor array ─────────────────────────────────────────────────
	var result: Array = []

	for row in range(rows):
		for col in range(COLS):
			# Skip ~15% of cells for visual variety (gaps in the grid).
			# Every rng call must stay in the same order — inserting or removing
			# calls would break seed reproducibility for existing runs.
			# [JS equiv]  if (rng.random() < 0.15) continue
			if rng.randf() < 0.15:
				continue

			# HP scales with row depth: top rows (row 0) are easier (lower HP),
			# bottom rows (closer to paddle) are harder (higher HP within diff cap).
			# row_fraction: 0.0 at row 0 (top) → 1.0 at last row (bottom).
			# [JS equiv]  const rowFraction = row / Math.max(rows - 1, 1)
			var row_fraction: float = float(row) / float(max(rows - 1, 1))
			var max_hp: int = diff["max_hp"]
			var hp: int = 1 + int(rng.randf() * row_fraction * max_hp)
			hp = clampi(hp, 1, max_hp)

			# Indestructible brick (hit_points = 0 sentinel).
			# Ball still bounces; brick never disappears; level still clearable
			# because BrickGrid.get_brick_count() only counts hp > 0 bricks.
			# [JS equiv]  if (rng.random() < diff.indestructibleChance) hp = 0
			if rng.randf() < diff["indestructible_chance"]:
				hp = 0

			# tier maps hp to atlas colour region:
			#   hp=1 → tier 0 (teal)
			#   hp=2 → tier 1 (cyan)
			#   hp=3 → tier 2 (amber)
			#   hp=0 (indestructible) → tier 3 (violet) as visual cue
			# [JS equiv]  const tier = hp === 0 ? 3 : Math.max(0, hp - 1)
			var tier: int = 3 if hp == 0 else clampi(hp - 1, 0, 2)

			result.append({
				"grid_pos":   Vector2i(col, row),
				"hit_points": hp,
				"tier":       tier,
			})

	return result
