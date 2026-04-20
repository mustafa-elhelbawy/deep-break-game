# Implementation Plan: Deep Break — Phase 6 Polish

**Branch**: `phase6-polish` | **Date**: 2026-04-20 | **Spec**: `specs/phase6-polish.md`

---

## Summary

Polish the game before store submission. Six feature groups: logo + title screen, realistic ball movement, missing SFX, power-up system (W/S/M), collapsing mobile bricks, and flipped layout variant. No background music. No store assets (those are Phase 7). Delivered in 7 sessions.

---

## Technical Context

| Key | Value |
|-----|-------|
| **Language** | GDScript · Godot 4.3 stable |
| **All changes** | Mac edit machine unless noted `[BUILD]` |
| **Performance constraint** | ≤ 30 draw calls · ≥ 55 fps with 2 balls + particles + mobile bricks |
| **Audio** | Reactive SFX only — no background music |
| **Power-up tracking** | `Game.gd` (not a new autoload) |
| **Flipped layout** | Runtime flag — no separate scene variant |

---

## New / Modified Files

| File | Change Type |
|------|-------------|
| `assets/fonts/Orbitron-Bold.ttf` | NEW — must be downloaded by user |
| `scenes/main/Title.tscn` | NEW |
| `scenes/main/Main.tscn` | MODIFIED — add scene switcher logic |
| `scenes/game/Walls.tscn` | MODIFIED — add WallBottom node (disabled by default) |
| `scenes/game/Ball.gd` | MODIFIED — jitter, spin, flip flag, speed modifier, multi-ball |
| `scenes/game/Brick.gd` | MODIFIED — `set_mobile()`, `set_powerup_type()` |
| `scenes/game/Paddle.gd` | MODIFIED — velocity tracking, wide effect, flip zone |
| `scenes/game/BrickGrid.gd` | MODIFIED — accept `flipped` flag, lower-half spawn |
| `scenes/game/Game.gd` | MODIFIED — power-up manager, flip orchestration, multi-ball |
| `scenes/game/PowerUp.tscn` | NEW |
| `scenes/game/PowerUp.gd` | NEW |
| `scenes/ui/HUD.tscn` | MODIFIED — power-up indicator |
| `scenes/ui/HUD.gd` | MODIFIED — show active power-up |
| `scripts/autoloads/LevelGenerator.gd` | MODIFIED — powerup_type, collapse_speed, layout_flipped |
| `scripts/autoloads/AudioManager.gd` | MODIFIED — register new SFX keys |
| `assets/audio/sfx/brick_hit.wav` | NEW (silent placeholder) |
| `assets/audio/sfx/paddle_hit.wav` | NEW (silent placeholder) |

---

## Session Overview

```
Session 1 → T044–T046   Logo + Title Screen
Session 2 → T047–T049   Realistic Ball Movement + Missing SFX
Session 3 → T050–T052   Power-Up Foundation (token + LevelGenerator + Brick drop)
Session 4 → T053–T056   Power-Up Effects (W, S, M, HUD)
Session 5 → T057–T059   Collapsing / Mobile Bricks
Session 6 → T060–T064   Flipped Layout Variant
Session 7 → T065–T066   Phase 6 Smoke Test + Tag
```

---

## Session 1 — Logo + Title Screen

**Goal**: Player sees the Deep Break bioluminescent logo on a title screen before the game starts. Tapping anywhere transitions to gameplay.

**Tasks**: T044, T045, T046

**Architecture**:
- `Main.tscn` becomes the root scene (replaces `Game.tscn` in Project Settings → Run → Main Scene).
- `Main.gd` listens for `GameManager.state_changed`; loads `Title.tscn` when state = TITLE, loads `Game.tscn` when state transitions to WAITING from TITLE.
- `Title.tscn` calls `GameManager.start_game()` on tap, which fires `state_changed(WAITING)`, which `Main.gd` catches to swap scenes.
- Logo: two `Label` nodes (Orbitron Bold 64px). "DEEP" teal `#00c8b8`, "BREAK" amber `#ffc107`. Both with 4px dark outline. Floats on a sine curve via `AnimationPlayer`.

---

## Session 2 — Realistic Ball Movement + Missing SFX

**Goal**: Ball bounces feel less deterministic. Paddle movement adds spin. Two new SFX events are wired.

**Tasks**: T047, T048, T049

**Architecture — angle jitter (T047)**:
- After `_velocity.bounce(normal)` in `_move_and_reflect()`, rotate `_velocity` by `randf_range(-0.087, 0.087)` radians (±5°).
- After rotation, re-enforce `MIN_VERTICAL_SPEED` (same clamp already present at bottom of `_move_and_reflect`).
- Jitter does NOT apply to paddle deflection (paddle already uses full angle calculation).

**Architecture — paddle spin (T048)**:
- `Paddle.gd`: add `var paddle_velocity_x: float = 0.0` tracked each `_physics_process` frame as `(position.x - _prev_x) / delta`.
- `Ball.gd`: in the `AnimatableBody2D` branch, after computing `angle` from `contact_x`, add `spin = clampf(collider.paddle_velocity_x / 600.0, -1.0, 1.0) * (PI / 9.0)` (max ±20°). Final angle = `clampf(angle + spin, -PI/2.6, PI/2.6)` (keeps within ±70° from vertical).

**Architecture — missing SFX (T049)**:
- Copy a silent WAV to `brick_hit.wav` and `paddle_hit.wav`.
- Register both in `AudioManager.gd`'s `_sounds` dictionary.
- `Brick.gd`: call `AudioManager.play("brick_hit")` in `take_hit()` when HP > 0 after decrement.
- `Ball.gd`: call `AudioManager.play("paddle_hit")` in the `AnimatableBody2D` branch of `_move_and_reflect()`.

---

## Session 3 — Power-Up Foundation

**Goal**: Power-up tokens exist as falling objects. `LevelGenerator` assigns types to bricks. `Brick.gd` drops a token on destroy.

**Tasks**: T050, T051, T052

**Architecture**:
- `PowerUp.tscn`: `Area2D` root → `CollisionShape2D` (RectangleShape2D 20×20) + `ColorRect` (20×20, colour set at runtime per type). Moves downward at 200 px/s in `_physics_process`. Auto-removes when `position.y > screen_height + 40`.
- `LevelGenerator` returns a top-level `Dictionary`:
  ```
  { "bricks": [...], "layout_flipped": bool }
  ```
  Each brick descriptor gains `"powerup_type": String` (`""`, `"W"`, `"S"`, `"M"`).
- Level gating in `LevelGenerator`: W from level 5, S from level 10, M from level 20. 12% of eligible bricks get a power-up.
- `Brick.gd` gains `_powerup_type: String`. On destroy (HP reaches 0): if `_powerup_type != ""`, instantiate `PowerUp.tscn`, set its type and position, add to scene root.
- `Game.gd`: connect `Area2D.body_entered` on each spawned PowerUp to `_on_powerup_caught(type)`.

---

## Session 4 — Power-Up Effects

**Goal**: W, S, M effects all work. HUD shows the active effect with a countdown bar.

**Tasks**: T053, T054, T055, T056

**Architecture — W (T053)**:
- `Paddle.gd`: `func activate_wide()` — set `CollisionShape2D.shape.size.x = _normal_width * 1.8`, set `Sprite2D.scale.x = 1.8`. Timer reverts after 10 s using `get_tree().create_timer(10.0).timeout`.
- On new W catch while active: cancel old timer, restart it, re-apply scale (idempotent).

**Architecture — S (T054)**:
- `Ball.gd`: add `_speed_modifier: float = 1.0`. Modify `_physics_process` to use `_current_speed * _speed_modifier`. `func activate_slow()` sets `_speed_modifier = 0.55`, schedules revert via timer. Revert: `_speed_modifier = 1.0`.
- Applies to ALL active balls when multi-ball is running.

**Architecture — M (T055)**:
- `Game.gd`: `_ball_count: int = 1`. `func _spawn_extra_ball()` — instantiate `Ball.tscn`, position it alongside the primary ball, call `launch(Vector2(0.3, -1.0))` (slight opposite angle). Connect its `lost` signal to `_on_extra_ball_lost()`.
- `_on_extra_ball_lost()`: `_ball_count -= 1`. If `_ball_count == 0`: existing `GameManager.lose_life()` flow. If `_ball_count > 0`: no action (remaining balls continue).
- On level clear / game over / life lost: free all extra balls, reset `_ball_count = 1`.

**Architecture — HUD indicator (T056)**:
- `HUD.tscn`: add `PowerUpLabel` (Label) + `PowerUpBar` (ColorRect, shrinks from full width to 0 via Tween).
- `HUD.gd`: `func show_powerup(type: String, duration: float)` called by `Game.gd` on activation. `func hide_powerup()` on expiry.

---

## Session 5 — Collapsing / Mobile Bricks

**Goal**: Subset of bricks drift downward from spawn. Ball bounces off them. Brick reaching paddle Y = life lost.

**Tasks**: T057, T058, T059

**Architecture**:
- `Brick.gd` stays `extends StaticBody2D`. Add `_collapse_speed: float = 0.0` and `_is_mobile: bool = false`.
- `func set_mobile(speed: float)`: sets flag + speed. In `_physics_process(delta)`: if `_is_mobile`, `position.y += _collapse_speed * delta`.
- Visual cue: modulate `Sprite2D.modulate` by `Color(1.2, 0.8, 0.8)` (slight red tint) when mobile.
- `LevelGenerator` descriptor gains `"collapse_speed": float` (0.0 = static). For levels 10–19: 15% of bricks get 30–50 px/s. For levels 20+: 20% get 50–90 px/s.
- `BrickGrid.gd`: after calling `brick.spawn(descriptor)`, check `descriptor["collapse_speed"] > 0` and call `brick.set_mobile(...)`.
- `Game.gd`: connect a signal or poll in `_process()` — simpler: `Brick.gd` emits `signal reached_paddle` when `global_position.y >= _paddle_y`. `Game.gd` connects this per-brick and calls `GameManager.lose_life()` + `queue_free()` on the brick.
- `_paddle_y` is set on mobile bricks by `Game.gd` after spawning: `brick.set_paddle_y(_paddle.global_position.y)`.

---

## Session 6 — Flipped Layout Variant

**Goal**: ~20% of levels (from level 3) are "flipped" — paddle at top, bricks at bottom, ball launches down, top edge is lethal.

**Tasks**: T060, T061, T062, T063, T064

**Architecture**:
- `LevelGenerator.generate()` now returns `{ "bricks": [...], "layout_flipped": bool }`.
- `BrickGrid.gd`: `func spawn(descriptors: Array, flipped: bool)` — when `flipped`, brick `grid_pos` Y is measured from the bottom of the play area instead of the top.
- `Game.gd`: after calling `LevelGenerator.generate()`, read `layout_flipped`. Call `_apply_flip(flipped)`.
- `_apply_flip(flipped)`: move paddle to top (y=70) or bottom (y=710). Toggle `$Walls/WallTop` and `$Walls/WallBottom` (new node). Call `_ball.set_flipped(flipped)`. Call `_paddle.set_flipped(flipped)`.
- `Ball.gd`: `_check_lost()` checks `y < -20.0` when `_flipped == true`.
- `Paddle.gd`: `set_flipped(v)` stores flag. `_handle_touch()` switches threshold: upper 40% when flipped.
- `Walls.tscn`: add `WallBottom` (`StaticBody2D` + `WorldBoundaryShape2D` normal `(0, -1, 0)`) at position `(180, 780)`. Default: `disabled = true`.
- "FLIP LEVEL!" banner: a `CanvasLayer` Label in `Game.tscn`, shown for 2 s at start of each flipped level before `_input()` accepts launch taps.

---

## Session 7 — Smoke Test + Tag

**Tasks**: T065 `[BUILD]`, T066 `[EITHER]`

Full on-device checklist covering all 6 new feature groups. Tag `v0.6.0-phase6` from Mac after all items pass.

---

## Dependency Graph

```
T044 (font + logo)
  └── T045 (Title.tscn)
        └── T046 (Main.tscn wiring)

T047 (ball jitter)
  └── T048 (paddle spin)        ← can overlap with T046
        └── T049 (SFX wiring)

T050 (PowerUp scene)
  └── T051 (LevelGenerator powerup)
        └── T052 (Brick drop)
              ├── T053 (W effect)
              ├── T054 (S effect)
              └── T055 (M effect)
                    └── T056 (HUD indicator)

T057 (Brick mobile)
  └── T058 (LevelGenerator collapse_speed)
        └── T059 (Game.gd life-lost detection)

T060 (LevelGenerator flipped flag)
  └── T061 (BrickGrid flipped spawn)
        └── T062 (Game.gd flip orchestration)
              ├── T063 (Paddle flip zone)
              └── T064 (FLIP LEVEL! banner)

All above complete
  └── T065 (smoke test)
        └── T066 (tag)
```

**Parallel opportunities**:
- Sessions 1, 2, and 3 can be done across separate working sessions in any order.
- T053 (W) and T054 (S) have no dependency on each other — can be done in either order.
- T057–T059 (collapsing bricks) is fully independent of T053–T056 (power-up effects).

---

## Phase 6 Exit Gate

Before Phase 7 (store assets), all of the following must be true:

- [ ] All 23 tasks (T044–T066) checked off
- [ ] Title screen loads before game on cold launch
- [ ] All 6 SFX events fire without error on device
- [ ] W, S, M power-ups activate and revert correctly
- [ ] Mobile brick reaching paddle Y causes a life loss (on device)
- [ ] A flipped level loads, paddle is at top, ball launches down, top-exit = life lost
- [ ] 55 fps sustained with 2 balls + mobile bricks + particles active (Godot profiler)
- [ ] `v0.6.0-phase6` tag pushed to remote
