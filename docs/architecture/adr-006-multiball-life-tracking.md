# ADR-006: Multi-Ball Life Tracking Lives in Game.gd (Not GameManager)

**Status**: Accepted
**Affects**: T055

---

## Context

When M (Multi-Ball) is active, a second `Ball` instance exists. Lives should only decrement when ALL active balls are lost. A counter is needed. Where does it live?

## Options

| Option | Location | Lives decrement | Complexity |
|--------|----------|----------------|------------|
| A: `_ball_count` in `Game.gd` | Session-scoped, scene-local | Game.gd counts; calls `GameManager.lose_life()` only at 0 | Low |
| B: `active_balls: int` in `GameManager` | Autoload-global | GameManager.lose_life() only fires if active_balls == 0 | Medium — GameManager must know about a visual concern |
| C: Ball signals carry a `is_last: bool` payload | Signal-level contract | Ball knows whether it's the last — requires Ball knowing about other balls | High coupling |

## Decision

**Option A**: `Game.gd` owns `_ball_count: int` and `_extra_balls: Array[CharacterBody2D]`.

## Rationale

- Ball count is a visual/session concern, not a game-progression concern. `GameManager` tracks lives/score/level/seed — adding ball count there violates its focus.
- `Game.gd` is the natural owner: it spawns balls, tracks them, and calls `GameManager` when appropriate. This is the orchestrator pattern already in use.
- The fix is straightforward: replace the anonymous lambda `func(): GameManager.lose_life()` with a named `_on_primary_ball_lost()` that delegates to the shared `_on_ball_lost()` counter logic.

## Critical Connection Order (BUG-1 mitigation)

The anonymous lambda on `_ball.lost` CANNOT be disconnected. It MUST be replaced before T055 is implemented. The replacement in T049 or earlier:

```gdscript
# In _ready() — replace lambda with named method:
_ball.lost.connect(_on_primary_ball_lost)

func _on_primary_ball_lost() -> void:
    _on_ball_lost()

func _on_ball_lost() -> void:
    _ball_count -= 1
    if _ball_count <= 0:
        _ball_count = 1
        GameManager.lose_life()
```

Extra ball connections (T055):
```gdscript
func _spawn_extra_ball() -> void:
    var extra = BallScene.instantiate()
    # ...
    _extra_balls.append(extra)
    _ball_count += 1
    extra.lost.connect(func(): _on_extra_ball_lost(extra))

func _on_extra_ball_lost(ball: CharacterBody2D) -> void:
    _extra_balls.erase(ball)
    _on_ball_lost()
```

## Cleanup Contract

On any state transition that resets the level (GAME_OVER, LEVEL_CLEAR, or WAITING from non-DEAD):
```gdscript
func _clear_extra_balls() -> void:
    for b in _extra_balls:
        if is_instance_valid(b):
            b.queue_free()
    _extra_balls.clear()
    _ball_count = 1
```

This must be called BEFORE `_ball.reset_to_paddle()` so the ball count is clean for the new serve.

## Slow Motion and Extra Balls

When `_activate_slow()` is called while multi-ball is active, it must apply to ALL active balls:
```gdscript
func _activate_slow() -> void:
    _ball.activate_slow()
    for b in _extra_balls:
        if is_instance_valid(b):
            b.activate_slow()
    # ... timer setup ...
```

The same applies to `_revert_slow()`.

## Trade-offs Accepted

- `Game.gd` tracks one additional concept (ball count). Acceptable — it already tracks `_flipped`, `_prev_state`, and power-up timers.
- Multi-ball state does not survive a scene transition (Title → Game). On a fresh game, `_ball_count = 1` always. This is correct.

## Revisit Trigger

If a power-up adds a third ball or if ball count needs to appear in the HUD, consider promoting it to GameManager.
