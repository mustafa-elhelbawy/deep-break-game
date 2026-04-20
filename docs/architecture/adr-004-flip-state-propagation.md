# ADR-004: Flip State Propagated by Game.gd via Method Calls (Not a Shared Flag)

**Status**: Accepted
**Affects**: T060, T061, T062, T063

---

## Context

Five systems need to know when a level is "flipped": `Ball.gd`, `Paddle.gd`, `BrickGrid.gd`, `Brick.gd` (mobile direction), and `Walls.tscn` nodes. Options for how to propagate this:

## Options

| Option | How | Pros | Cons |
|--------|-----|------|------|
| A: Central `_flipped` flag in GameManager | Autoload holds state; any node reads `GameManager.flipped` | Available everywhere | GameManager grows; flip is session-level not game-level state |
| B: Game.gd calls methods on each child (`set_flipped`, `set_mobile_direction`, etc.) | Explicit push from orchestrator | Clear data flow; each system is isolated | Game.gd knows about more children |
| C: `flipped` signal from GameManager | Subscribe-based; loose coupling | Systems self-configure | Can't guarantee order of reconfiguration before ball is placed |

## Decision

**Option B**: `Game.gd._apply_flip(flipped: bool)` explicitly calls each child in a defined order:
1. `_wall_top` / `_wall_bottom` — toggle via `set_deferred`
2. `_paddle.set_flipped(flipped)` — repositioned + touch zone switched
3. `_ball.set_flipped(flipped)` — death edge switched
4. `_grid.spawn(descriptors, flipped)` — brick placement (called separately in `_spawn_level`)

## Rationale

- `_apply_flip()` runs BEFORE the ball is placed on the paddle and BEFORE the level spawns — guaranteed order.
- `GameManager` already owns enough state (lives, score, level, seed). Flip is not game-progression state — it resets every level. Keeping it out of GameManager keeps the singleton focused.
- The subscribe pattern (Option C) risks a ball being placed at the wrong position if a listener fires late.

## Wall Toggle: set_deferred Timing

`_wall_top.get_node("CollisionShape2D").set_deferred("disabled", true)` schedules for the next idle frame. The ball is NOT placed until `_ball.reset_to_paddle()` is called, which happens in the `WAITING` state handler — the same or next frame. No race condition.

## Flipped Ball Position

In normal mode: ball spawns at `paddle.global_position + Vector2(0, -30)` (above paddle).
In flipped mode: ball spawns at `paddle.global_position + Vector2(0, +30)` (below paddle, since paddle is at top).

`Ball.reset_to_paddle()` currently hardcodes `-30` offset. Two options:
- A: Add `reset_to_paddle(pos, flipped: bool)` overload
- B: Game.gd sets `_ball.global_position` directly in flipped mode after calling `reset_to_paddle()`

**Decision**: Option B — Game.gd overrides position after reset for flipped mode. Avoids changing Ball.gd's clean public API.

```gdscript
func _place_ball_on_paddle() -> void:
    if _flipped:
        _ball._active = false
        _ball._velocity = Vector2.ZERO
        _ball.global_position = _paddle.global_position + Vector2(0.0, 30.0)
    else:
        _ball.reset_to_paddle(_paddle.global_position)
```

Note: Accessing `_ball._active` and `_ball._velocity` from Game.gd crosses the public API boundary. The cleaner fix is to add `func park()` to Ball.gd that stops movement and accepts an explicit world position:

```gdscript
# Ball.gd — add:
func park(world_pos: Vector2) -> void:
    _active = false
    _velocity = Vector2.ZERO
    global_position = world_pos
```

Then Game.gd:
```gdscript
var offset_y: float = -30.0 if not _flipped else 30.0
_ball.park(_paddle.global_position + Vector2(0.0, offset_y))
```

**This is cleaner and should be used instead of direct private field access.**

## Trade-offs Accepted

- `Game.gd` is the orchestrator and knows about all children. This is intentional — it IS the scene controller.
- Flip state is not persisted in `GameManager` — it's re-derived from `LevelGenerator.generate()` on each level load. This is fine because the seed + level always produces the same flip result.

## Revisit Trigger

If a second scene (e.g., a "spectator view") needs to know the flip state, move `_flipped` into GameManager.
