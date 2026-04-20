# ADR-001: LevelGenerator Returns Dictionary Wrapper, Not Raw Array

**Status**: Accepted
**Affects**: T051, T060 — and the single caller `Game.gd._spawn_level()`

---

## Context

`LevelGenerator.generate()` currently returns `Array` of brick descriptors. Phase 6 needs two more fields at the level (not brick) level: `layout_flipped: bool` and potentially future fields (e.g. `ball_speed_override`, `background_variant`). These cannot be appended to the brick array without breaking the descriptor contract.

## Options

| Option | Pros | Cons |
|--------|------|------|
| A: Return `Array`, add sentinel first element | No type change | Fragile — positional convention, breaks all array iteration |
| B: Return `Dictionary { bricks, layout_flipped }` | Clean, extensible, self-documenting | One caller must update |
| C: Add separate `get_level_meta(seed, level)` method | Pure function contract preserved | Two calls per level spawn; seed/rng must be re-seeded identically — error-prone |

## Decision

**Option B**: return `Dictionary { "bricks": Array, "layout_flipped": bool }`.

## Rationale

- There is exactly ONE caller: `Game.gd._spawn_level()`. The update cost is one line.
- The flip decision uses the same seeded `rng` instance as brick generation — it MUST be the last call in `generate()` to preserve seed reproducibility. Option C would require careful rng synchronisation across two function calls.
- Future level metadata (e.g. speed modifier, visual theme) can be added as new keys without touching callers that don't need them.

## RNG Call Order Contract

All calls to `rng` inside `generate()` must stay in this order or seed reproducibility breaks:

```
1. grid layout: rng.randf() for gap (existing)
2. hp:          rng.randf() (existing)
3. indestructible: rng.randf() (existing)
4. powerup_type: rng.randf() + rng.randi_range() (T051 — NEW)
5. collapse_speed: rng.randf() + rng.randf_range() (T058 — NEW)
6. layout_flipped: rng.randf() (T060 — NEW, LAST)
```

Inserting any call between existing calls breaks all downstream seeds. Adding at the end is safe.

## Trade-offs Accepted

- Callers must destructure: `var data = LevelGenerator.generate(...)` then `data["bricks"]`. Slightly more verbose.
- If a second caller is added in the future, it must also be updated. Acceptable given the game's scope.

## Revisit Trigger

If LevelGenerator needs more than 3 metadata fields, consider an inner class `LevelData` instead of a Dictionary.
