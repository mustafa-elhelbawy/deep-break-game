# Feature Specification: Deep Break — Phase 6 Polish

**Branch**: `phase6-polish`
**Created**: 2026-04-20
**Status**: Draft
**Scope**: Game-feel polish before store submission. No store assets in this phase.

---

## Summary of Changes

| # | Feature | Complexity |
|---|---------|------------|
| 1 | Logo + Title Screen | Medium |
| 2 | Realistic Ball Movement (jitter + paddle spin) | Low |
| 3 | Missing SFX wiring (brick_hit, paddle_hit) | Low |
| 4 | Power-Up System (W / S / M drops) | High |
| 5 | Collapsing / Mobile Bricks | Medium |
| 6 | Flipped Layout Variant | High |

---

## User Stories

### Story 1 — Logo + Title Screen (P1)

A player opens the app and sees a polished title screen with the game's bioluminescent logo before entering the game.

**Acceptance scenarios**:

1. **Given** the app is launched, **When** the first frame renders, **Then** `Title.tscn` is shown — not the game scene directly.
2. **Given** `Title.tscn` is shown, **When** rendered, **Then** the text "DEEP" (teal) and "BREAK" (amber) are displayed with the game's bioluminescent visual style, using Orbitron Bold font.
3. **Given** the title screen is shown, **When** the player taps anywhere, **Then** the game transitions to `Game.tscn` and a new session begins.
4. **Given** the player reaches Game Over or Level Clear (last tap on restart), **When** `GameManager.state == TITLE`, **Then** the scene returns to `Title.tscn`.
5. **Given** the logo, **When** displayed, **Then** it renders with a soft glow outline effect consistent with the bioluminescent palette.

---

### Story 2 — Realistic Ball Movement (P1)

The ball no longer bounces in perfectly predictable mirror-reflection patterns. Brick/wall bounces have slight angle randomness. Paddle movement adds spin to the deflection.

**Acceptance scenarios**:

1. **Given** the ball hits a brick or wall, **When** it reflects, **Then** the outgoing angle varies by ±5° from the ideal mirror angle (random per bounce).
2. **Given** the ball hits the paddle while the paddle is moving left or right, **When** deflection is computed, **Then** the outgoing angle shifts in the direction of paddle movement by up to ±20° (proportional to paddle speed at impact).
3. **Given** the angle jitter + paddle spin modifiers, **When** applied, **Then** `MIN_VERTICAL_SPEED` enforcement still fires — the ball never traps horizontally.

---

### Story 3 — Missing SFX Wiring (P1)

Every game contact event has a sound response.

**Acceptance scenarios**:

1. **Given** the ball hits a brick and does NOT destroy it (HP > 1), **When** impact occurs, **Then** `AudioManager.play("brick_hit")` fires.
2. **Given** the ball hits the paddle, **When** deflection occurs, **Then** `AudioManager.play("paddle_hit")` fires.
3. **Given** both new WAV files are silent placeholders, **When** played, **Then** no error is thrown; they are identical in structure to existing placeholder WAVs.

---

### Story 4 — Power-Up System (P2)

Certain bricks contain a hidden power-up. When destroyed, the power-up token falls from the brick's position. If the paddle catches the falling token, the effect activates for 10 seconds.

**Power-up types**:
- **W — Wide Paddle**: Paddle collision shape + sprite scale to 1.8× for 10 s.
- **S — Slow Motion**: Ball speed multiplied by 0.55 for 10 s (stacks on top of level speed scaling).
- **M — Multi-Ball**: A second `Ball` instance spawns. Lives are only lost when the **last ball** exits the bottom. Catching a second M while multi-ball is active resets nothing (already active).

**Level gating**:
- Level 1–4: No power-ups.
- Level 5–9: W only.
- Level 10–19: W and S.
- Level 20+: W, S, and M.

**Replacement rule**: Catching a new power-up (W or S) while one is active replaces the current effect and resets the 10-second timer. Only one W/S effect is active at a time. M is independent.

**Acceptance scenarios**:

1. **Given** a "reward brick" (has a `powerup_type` set), **When** destroyed, **Then** a `PowerUp` token falls from the brick's position downward at constant speed.
2. **Given** a falling `PowerUp` token, **When** the paddle overlaps it (Area2D detection), **Then** the token disappears and the corresponding effect activates.
3. **Given** W is active, **When** rendered, **Then** the paddle's `CollisionShape2D` size and `Sprite2D` scale are 1.8× the normal values.
4. **Given** S is active, **When** the ball moves, **Then** `_current_speed` equals `level_speed × 0.55`.
5. **Given** M activates, **When** in play, **Then** two balls are visible and the player does not lose a life when the first ball is lost — only when the last ball is lost.
6. **Given** a power-up is active, **When** a new W or S token is caught, **Then** the old effect ends immediately, the new effect starts, and the 10-second timer resets.
7. **Given** the HUD, **When** a power-up is active, **Then** a small indicator shows the active power-up name and a shrinking bar representing remaining time.
8. **Given** 10 seconds pass since activation, **When** the timer expires, **Then** W/S effects revert to normal; M has no revert (balls remain until naturally lost).

---

### Story 5 — Collapsing / Mobile Bricks (P2)

From level 10 onward, a subset of bricks are "mobile" — they drift downward at constant speed. A mobile brick that collides with the paddle causes a life loss. The ball bounces off mobile bricks normally.

**Acceptance scenarios**:

1. **Given** a mobile brick spawned by `LevelGenerator`, **When** in play, **Then** it drifts downward at its assigned `collapse_speed` (px/s), visually distinguishable (tinted with slight red shift on the existing tier colour).
2. **Given** a mobile brick in motion, **When** the ball collides with it, **Then** the ball reflects and the brick takes damage normally (same as a static brick hit).
3. **Given** a mobile brick drifting downward, **When** it reaches the paddle's Y position, **Then** `GameManager.lose_life()` is called and the brick is removed.
4. **Given** a mobile brick drifting downward, **When** it exits the screen bottom WITHOUT hitting the paddle, **Then** it is silently removed (no life loss).
5. **Given** level 10–19, **When** the grid is generated, **Then** ~15% of bricks are mobile (speed 30–50 px/s).
6. **Given** level 20+, **When** the grid is generated, **Then** ~20% of bricks are mobile (speed 50–90 px/s).

---

### Story 6 — Flipped Layout Variant (P2)

Some levels are "flipped": the paddle moves to the top of the screen, bricks appear in the lower portion, the ball launches downward, and the death wall is the TOP edge (ball exiting the top = life lost). The bottom wall bounces the ball.

**Flip conditions**: ~20% random chance per level, starting from level 3.

**Acceptance scenarios**:

1. **Given** a flipped level, **When** loaded, **Then** a "FLIP LEVEL!" banner displays for 2 seconds before ball launch is enabled.
2. **Given** a flipped level, **When** `Game.gd` sets up the scene, **Then**: paddle Y position is near the top (≈70 px), bricks spawn in the lower half, WallTop is disabled, a WallBottom is enabled.
3. **Given** a flipped level, **When** the player taps to launch, **Then** the ball launches downward (Vector2(-0.3, +1.0)) from below the paddle.
4. **Given** a flipped level, **When** the ball exits the TOP of the screen (y < -20), **Then** it is treated as "lost" — `GameManager.lose_life()` fires.
5. **Given** a flipped level, **When** the player drags their finger, **Then** only touches in the **upper 40%** of the screen move the paddle.
6. **Given** a flipped level, **When** the level ends (all bricks cleared), **Then** the NEXT level may be normal or flipped (independent 20% roll).

---

## Requirements

### Functional Requirements

- **FR-P01**: Title screen must display before any game logic runs on cold launch.
- **FR-P02**: `GameManager.State.TITLE` must be the initial state; `Main.tscn` must handle scene switching.
- **FR-P03**: Ball angle jitter (±5°) MUST NOT produce a result where `abs(_velocity.y) < MIN_VERTICAL_SPEED` after application — re-enforce the clamp after jitter.
- **FR-P04**: Paddle spin contribution MUST be clamped so the resulting angle never exceeds ±70° from vertical (prevents near-horizontal shots).
- **FR-P05**: Power-up tokens MUST be removed from the scene tree when caught OR when they exit the screen bottom (to prevent memory leaks).
- **FR-P06**: Wide Paddle (W) MUST revert `CollisionShape2D` size AND `Sprite2D` scale simultaneously to avoid collision/visual mismatch.
- **FR-P07**: Slow Motion (S) MUST apply as a multiplier on `_current_speed`, NOT on `BASE_SPEED` — it must stack correctly with level speed scaling.
- **FR-P08**: Multi-Ball (M) MUST use the same `Ball.tscn` packed scene — no separate scene.
- **FR-P09**: When multi-ball is active, EACH ball independently emits `lost` — `Game.gd` must count active balls and only call `GameManager.lose_life()` when the count reaches 0.
- **FR-P10**: Mobile bricks MUST convert their underlying `StaticBody2D` to use an `AnimatableBody2D` motion path — or use `CharacterBody2D` for simplest implementation.
- **FR-P11**: Flipped layout MUST toggle `WallTop.set_deferred("disabled", true)` and enable a WallBottom node in `Walls.tscn` (the node must exist but be disabled by default).
- **FR-P12**: `Ball.gd` `_check_lost()` MUST read a `_flipped: bool` flag to determine which edge is lethal.
- **FR-P13**: `Paddle.gd` `_handle_touch()` MUST read a `_flipped: bool` flag to switch the active touch zone.
- **FR-P14**: No background music. All audio is reactive SFX only.
- **FR-P15**: Draw call budget (≤ 30) must still be met — power-up tokens use the existing `atlas.png`; mobile bricks reuse the existing `Brick.tscn` material.

### New Key Entities

- **PowerUp** (`scenes/game/PowerUp.tscn` + `PowerUp.gd`): Falling token. `Area2D` child for catch detection. Falls at 200 px/s. Carries `powerup_type: String`. Auto-removes on catch or screen exit.
- **WallBottom** (`Walls.tscn` addition): A 4th `StaticBody2D` with `WorldBoundaryShape2D` pointing upward. Disabled by default. Enabled only in flipped levels.
- **PowerUpManager** (not a new autoload — logic lives in `Game.gd`): Tracks `_active_powerup: String`, `_powerup_timer: float`, `_ball_count: int`. No separate autoload needed to keep scope tight.

---

## Success Criteria

- **SC-P01**: On cold launch, title screen displays before any game scene is visible.
- **SC-P02**: Across 20 brick bounces in editor play, no two consecutive bounces produce the same outgoing angle to the naked eye.
- **SC-P03**: All 6 SFX events (brick_hit, brick_destroy, paddle_hit, ball_lost, game_over, level_clear) fire without error on device.
- **SC-P04**: W, S, M effects all activate and revert correctly across 3 consecutive power-up catches in a single session.
- **SC-P05**: A mobile brick drifting to paddle Y triggers a life loss — confirmed on device.
- **SC-P06**: A flipped level loads, the paddle is at the top, ball launches down, a top-exit costs a life — confirmed on device.
- **SC-P07**: Frame rate remains ≥ 55 fps with 2 active balls + particle bursts + mobile bricks all active simultaneously.

---

## Assumptions

- Font: Orbitron Bold `.ttf` downloaded from fonts.google.com (free OFL licence) and saved to `assets/fonts/Orbitron-Bold.ttf` before T044 begins.
- Silent WAV placeholders for `brick_hit.wav` and `paddle_hit.wav` are created by copying the structure of existing silent WAVs (T049).
- Power-up visual: a small square icon in the existing `atlas.png` at a new region. Atlas region T049 or later task adds the icon via code (ColorRect fallback if atlas not updated).
- Flipped levels do not have a separate `LevelGenerator` path — the same `generate()` function returns both the brick array and a `layout_flipped` bool in a new wrapper dictionary.
- The `Brick.tscn` node type change (StaticBody2D → CharacterBody2D for mobile bricks) is handled at runtime via `set_mobile()` — the scene root type stays `StaticBody2D`; motion is applied via `move_and_collide` in `_physics_process` when `_speed > 0`.
