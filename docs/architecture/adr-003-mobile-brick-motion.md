# ADR-003: Mobile Brick Uses StaticBody2D + Direct position.y Mutation

**Status**: Accepted with speed cap
**Affects**: T057, T058

---

## Context

Collapsing bricks need to move downward (or upward in flipped mode). `Brick.tscn` currently uses `StaticBody2D`. The question is whether to keep this type or switch to something that natively supports motion.

## Options

| Option | Body Type | How It Moves | Physics Visibility | Scene Change? |
|--------|-----------|--------------|-------------------|---------------|
| A: Direct position mutation | StaticBody2D (current) | `position.y += speed * delta` | Engine does NOT know it moved — zero-velocity collision normals | No |
| B: AnimatableBody2D + sync_to_physics | AnimatableBody2D | Same direct mutation but engine sees it as moving | Engine computes velocity from position delta | Yes — Brick.tscn root type changes |
| C: CharacterBody2D + move_and_collide | CharacterBody2D | `move_and_collide(Vector2(0, speed * delta))` | Full swept collision, no tunnelling | Yes |

## Analysis

**Option A**: At 30–90 px/s and 60 fps, the brick moves 0.5–1.5 px/frame. The ball's radius is 10px. Godot's physics safe margin is ~0.08 units by default. Ball tunnelling through a 1.5px-moving brick is practically impossible at these speeds. The zero-velocity normal means the brick doesn't push the ball — only the ball bounces off the brick. This is acceptable game feel (the brick is "heavy", not elastic).

**Option B**: Changing `Brick.tscn` root type from `StaticBody2D` to `AnimatableBody2D` changes behaviour for ALL bricks, not just mobile ones. All brick collision handling, group membership, and `take_hit()` calls from Ball.gd remain valid. The scene file change is small but requires Godot editor work.

**Option C**: Cleanest physics but requires the most change. `CharacterBody2D.move_and_collide()` properly sweeps the shape. For 30–90 px/s there is no practical benefit over Option A.

## Decision

**Option A with speed cap of 90 px/s**. 

If a future level requires collapse_speed > 150 px/s, switch mobile bricks to Option B (`AnimatableBody2D`). Add a `const MAX_COLLAPSE_SPEED: float = 90.0` enforced in `set_mobile()`.

## Rationale

- No scene file changes — `Brick.tscn` stays as-is.
- The speed range (30–90 px/s) is far below the tunnelling threshold for a 10px ball.
- The game feel of a brick that "drifts" (rather than physically pushes) is appropriate for this game style.
- If it turns out the normals feel wrong on-device, the fix is a one-line type change in `Brick.tscn` + removing the `AnimatableBody2D`-specific sync flag.

## Bug: drifted_off must trigger cleared check

When a mobile brick exits the screen via `queue_free()` without emitting `destroyed`, `BrickGrid._check_cleared()` is never called. Fix: add `signal drifted_off` to `Brick.gd`, emit it before the silent `queue_free()`, wire it in `BrickGrid` to `call_deferred("_check_cleared")`.

```gdscript
# Brick.gd _physics_process — when exiting bottom screen:
emit_signal("drifted_off")
queue_free()
```

```gdscript
# BrickGrid.gd spawn loop, after connecting other signals:
brick.drifted_off.connect(_on_brick_drifted_off)

func _on_brick_drifted_off() -> void:
    call_deferred("_check_cleared")
```

## Trade-offs Accepted

- Zero-velocity collision normals on moving bricks. Ball bounces off them "as if they were static". At these speeds, imperceptible.
- Speed cap of 90 px/s. Level designs above this speed are not supported without a scene type change.

## Revisit Trigger

Any level that requires collapse_speed > 90 px/s. Switch to `AnimatableBody2D` (Option B) at that point.
