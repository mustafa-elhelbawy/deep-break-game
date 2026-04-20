# Phase 6 — System Architecture Map

> Read this before touching any Phase 6 task. It tells you where each new feature fits, what breaks if you do it wrong, and which task files need amending.

---

## Existing System (Phase 1–5 baseline)

```
Autoloads (singletons, always live)
┌─────────────────┐   ┌──────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│  GameManager    │   │  LevelGenerator  │   │  AudioManager   │   │  JuiceManager   │
│  state machine  │   │  generate(s,l)   │   │  play(id)       │   │  shake/flash    │
│  lives/score    │   │  → Array         │◄──│  _streams{}     │   │  emit_burst     │
│  signals        │   │                  │   │                 │   │  _camera ref    │
└────────┬────────┘   └──────────────────┘   └─────────────────┘   └────────┬────────┘
         │state_changed                                                       │
         ▼                                                                    │
Scene: Main.tscn (entry point — currently empty, no script)                  │
         │                                                                    │
         └──► Game.tscn (currently the effective entry point)                │
              │                                                               │
              ├── Game.gd (orchestrator)  ◄────────────────────────────────-─┘
              │     • reacts to GameManager.state_changed                register_camera
              │     • calls LevelGenerator.generate()
              │     • calls _grid.spawn(descriptors)
              │     • connects ball.lost → GameManager.lose_life()  ← LAMBDA (no ref)
              │     • calls JuiceManager / AudioManager on events
              │
              ├── Ball.tscn / Ball.gd
              │     • CharacterBody2D, move_and_collide
              │     • signal lost
              │     • set_speed_for_level(level)
              │     • paddle deflection: angle from contact_x
              │
              ├── Paddle.tscn / Paddle.gd
              │     • AnimatableBody2D
              │     • _handle_touch / _handle_drag
              │     • lower 40% zone filter
              │     • no velocity tracking yet
              │
              ├── Walls.tscn (static, no script)
              │     • WallTop, WallLeft, WallRight
              │     • NO WallBottom yet
              │
              ├── BrickGrid.tscn / BrickGrid.gd
              │     • owns all Brick instances
              │     • signal all_cleared, brick_destroyed(pos, tier), brick_hit(pos)
              │     • spawn(descriptors: Array)  ← only Array, no flipped param yet
              │     • get_brick_count() counts hit_points > 0
              │
              │    Each brick:
              │     └── Brick.tscn / Brick.gd
              │           • StaticBody2D
              │           • @export hit_points, tier
              │           • signal destroyed(pos, tier), hit(pos)
              │           • take_hit() called by Ball.gd via is_in_group("bricks")
              │
              ├── HUD.tscn / HUD.gd  (CanvasLayer)
              │     • listens to GameManager.score_changed, lives_changed
              │
              ├── GameOver.tscn / GameOver.gd  (CanvasLayer)
              │     • show_with_score(n)
              │     • RestartButton → GameManager.restart() → start_game() → WAITING
              │
              └── LevelClear.tscn / LevelClear.gd  (CanvasLayer)
```

---

## Phase 6 Target System

```
Autoloads (unchanged structure, LevelGenerator return type changes)
┌─────────────────┐   ┌──────────────────────────────┐   ┌──────────────────┐
│  GameManager    │   │  LevelGenerator               │   │  AudioManager    │
│  + TITLE state  │   │  generate(s,l)                │   │  + brick_hit     │
│  restart()→TITLE│   │  → Dictionary {               │   │  + paddle_hit    │
│                 │   │      bricks: Array,            │   │                  │
└────────┬────────┘   │      layout_flipped: bool      │   └──────────────────┘
         │            │    }                           │
         ▼            │  each brick descriptor adds:   │
Main.tscn / Main.gd   │    powerup_type: String        │
  • swap Title ↔ Game │    collapse_speed: float        │
  • on WAITING from   └──────────────────────────────-─┘
    TITLE → load Game
  • on TITLE → load Title

Title.tscn / Title.gd
  • Logo.tscn (animated, Orbitron font)
  • GPUParticles2D (floating sparkles)
  • tap → GameManager.start_game() → WAITING

Game.tscn / Game.gd  (heavily extended)
  │
  ├── NEW: _flipped: bool
  ├── NEW: _ball_count: int  (multi-ball counter)
  ├── NEW: _extra_balls: Array  (extra Ball instances)
  ├── NEW: _slow_timer / _active_powerup tracking
  ├── NEW: _apply_flip(flipped)
  ├── NEW: _on_powerup_caught(type)
  ├── NEW: _activate_wide/slow/multiball
  ├── NEW: _wire_mobile_bricks()
  ├── NEW: _on_mobile_brick_hit()
  ├── NEW: _on_ball_lost()  ← replaces anonymous lambda
  ├── NEW: FlipBanner (CanvasLayer child node)
  │
  ├── Ball.gd  (extended)
  │     + _flipped: bool     (which edge is lethal)
  │     + _speed_modifier: float  (slow-mo multiplier)
  │     + set_flipped(v)
  │     + activate_slow() / revert_slow()
  │     + BOUNCE_JITTER_RAD constant
  │     + ±5° jitter in else branch
  │     + paddle spin from collider.paddle_velocity_x
  │     + MAX_SPIN_RAD, MAX_ANGLE_FROM_VERTICAL constants
  │
  ├── Paddle.gd  (extended)
  │     + paddle_velocity_x: float  (public, tracked in _physics_process)
  │     + _prev_x: float
  │     + _flipped: bool
  │     + _normal_width: float
  │     + _wide_timer reference
  │     + set_flipped(v)
  │     + activate_wide() / _revert_wide()
  │     + _physics_process (NEW — velocity tracking only)
  │
  ├── Walls.tscn  (extended)
  │     + WallBottom (StaticBody2D, disabled by default)
  │         normal: (0, -1, 0), position: (180, 780)
  │
  ├── BrickGrid.gd  (extended)
  │     + spawn(descriptors, flipped: bool = false)
  │     + flipped Y calculation
  │     + get_mobile_bricks() → Array
  │     + connect brick.drifted_off → _check_cleared  ← NEW signal needed
  │
  ├── Brick.gd  (extended)
  │     + _powerup_type: String
  │     + _collapse_speed: float
  │     + _is_mobile: bool
  │     + _paddle_y: float
  │     + _mobile_direction: float  (1.0 or -1.0)
  │     + signal reached_paddle
  │     + signal drifted_off  ← NEW (needed for cleared check)
  │     + set_mobile(speed)
  │     + set_paddle_y(y)
  │     + set_mobile_direction(dir)
  │     + _physics_process (NEW)
  │     + _drop_powerup()  ← does NOT spawn PowerUp directly
  │     + NEW signal: powerup_dropped(type, position)  ← cleaner than direct spawn
  │
  ├── PowerUp.tscn / PowerUp.gd  (NEW)
  │     • Area2D root
  │     • falls at 200 px/s
  │     • signal caught(type)
  │     • auto-removes on catch or screen exit
  │     • spawned by Game.gd (not Brick.gd)
  │
  ├── HUD.gd  (extended)
  │     + PowerUpContainer, PowerUpLabel, PowerUpBar
  │     + show_powerup(type, duration)
  │     + hide_powerup()
  │
  └── Logo.tscn  (NEW, used by Title.tscn)
```

---

## Signal Flow Map (Phase 6 additions highlighted)

```
Ball.lost
  └── Game._on_ball_lost()             ← replaces lambda; counts balls
        ├── if _ball_count == 0 → GameManager.lose_life()
        └── if _ball_count > 0  → silent (extra ball lost)

Brick.destroyed(pos, tier)
  └── BrickGrid._on_brick_destroyed()
        ├── emit brick_destroyed(pos, tier)  → Game._on_brick_destroyed()
        │     ├── GameManager.add_score()
        │     ├── JuiceManager.emit_burst()
        │     ├── JuiceManager.shake()
        │     └── AudioManager.play("brick_destroy")
        └── call_deferred(_check_cleared)

Brick.powerup_dropped(type, pos)      ← NEW signal
  └── BrickGrid._on_powerup_dropped()  ← NEW relay
        └── emit powerup_dropped(type, pos) → Game._on_powerup_dropped()
              └── instantiate PowerUp.tscn, setup(type), place at pos
                    └── PowerUp.caught(type) → Game._on_powerup_caught(type)

Brick.hit(pos)
  └── BrickGrid._on_brick_hit()
        └── emit brick_hit(pos) → Game._on_brick_hit()  ← NEW handler needed
              └── AudioManager.play("brick_hit")

Brick.reached_paddle                   ← NEW signal
  └── Game._on_mobile_brick_hit()
        ├── JuiceManager.flash(dark_red, 0.3)
        ├── JuiceManager.shake(0.5, 0.15)
        └── GameManager.lose_life()

Brick.drifted_off                      ← NEW signal
  └── BrickGrid._on_brick_drifted_off()
        └── call_deferred(_check_cleared)   ← ensures level clears if last brick drifts off

GameManager.state_changed(TITLE)
  └── Main._on_state_changed()
        └── _load_title()

GameManager.state_changed(WAITING) [from TITLE]
  └── Main._on_state_changed()
        └── _load_game()
```

---

## Data Flow: LevelGenerator → BrickGrid → Brick

```
LevelGenerator.generate(seed, level)
  returns Dictionary:
  {
    "bricks": [
      {
        "grid_pos":       Vector2i(col, row),
        "hit_points":     int,           # 1-3 or 0
        "tier":           int,           # 0-3
        "powerup_type":   String,        # "" | "W" | "S" | "M"
        "collapse_speed": float,         # 0.0 = static
      },
      ...
    ],
    "layout_flipped": bool
  }

BrickGrid.spawn(descriptors, flipped):
  for each descriptor:
    brick = BrickScene.instantiate()
    brick.hit_points  = desc["hit_points"]
    brick.tier        = desc["tier"]
    brick.position    = _calc_position(desc["grid_pos"], flipped)
    if desc["powerup_type"] != "":
        brick.set_powerup_type(desc["powerup_type"])   ← new setter
    if desc["collapse_speed"] > 0.0:
        brick.set_mobile(desc["collapse_speed"])
    brick.destroyed.connect(...)
    brick.hit.connect(...)
    brick.powerup_dropped.connect(...)  ← new connection
    brick.drifted_off.connect(...)      ← new connection
    if brick._is_mobile:
        brick.reached_paddle.connect(...) ← injected later by Game.gd
```

---

## Bugs Found During Architecture Review

### BUG-1: Anonymous lambda on ball.lost cannot be disconnected (CRITICAL for T055)

**Location**: `Game.gd._ready()` line 60
```gdscript
_ball.lost.connect(func(): GameManager.lose_life())  # ← anonymous, no disconnect possible
```
**Impact**: When T055 adds multi-ball, if this lambda is still connected AND `_on_ball_lost()` is also connected, every primary ball loss decrements lives TWICE.

**Fix required in T049 (or earlier)**: Replace the lambda with a named method BEFORE multi-ball is implemented:
```gdscript
_ball.lost.connect(_on_primary_ball_lost)
func _on_primary_ball_lost() -> void:
    _on_ball_lost()  # shared counter logic
```

---

### BUG-2: Mobile brick drifting off-screen never triggers level-clear check (CRITICAL for T057–T059)

**Location**: `Brick.gd._physics_process()` — when `position.y > screen_h + 20`, calls `queue_free()` silently.
**Impact**: If the last remaining brick is a mobile one that drifts past the bottom without being hit, `BrickGrid.get_brick_count()` will return 0 (the node is freed) but `_check_cleared()` is never called → level never clears.

**Fix required in T057**: Add `signal drifted_off` to `Brick.gd`. Emit it before `queue_free()`. `BrickGrid` connects it to `call_deferred("_check_cleared")`.

---

### BUG-3: Game.gd brick_hit signal not connected (MISSING HANDLER for T049)

**Location**: `BrickGrid.gd` already emits `brick_hit(pos)` from `_on_brick_hit()`. But `Game.gd` has no `_on_brick_hit()` handler connected anywhere.
**Impact**: `AudioManager.play("brick_hit")` in T049 is proposed to go in `Brick.gd` directly. This works but bypasses the BrickGrid relay pattern. Inconsistency.

**Decision**: Wire `brick_hit` through BrickGrid → Game.gd the same way `brick_destroyed` is. In `Game.gd._ready()`, add:
```gdscript
_grid.brick_hit.connect(_on_brick_hit)
func _on_brick_hit(_pos: Vector2) -> void:
    AudioManager.play("brick_hit")
```
Remove the `AudioManager.play("brick_hit")` call proposed for `Brick.gd` in T049.

---

### BUG-4: GameManager.restart() → start_game() bypasses TITLE state (Title screen flow)

**Location**: `GameOver.gd._on_restart_pressed()` calls `GameManager.restart()`.
**Current**: `restart()` calls `start_game()` → state goes to WAITING → `Game.gd` reacts and resets.
**Phase 6 intent**: `restart()` should go to TITLE so `Main.gd` shows the title screen.
**Impact**: If `restart()` changes to emit TITLE, `Game.gd`'s `_on_state_changed(WAITING)` will NOT fire after restart. The game scene will still be showing when TITLE loads — `Main.gd` must `queue_free()` the game scene first.

**Fix**: The task files correctly propose this. Just noting the coupling: `Main.gd` must handle the TITLE transition robustly by checking whether the current scene is Game or Title before deciding to load.

---

## Constraints and Non-Negotiables

| Constraint | Source | Impact on Phase 6 |
|------------|--------|-------------------|
| ≤ 30 draw calls | constitution.md | PowerUp tokens use atlas.png, not new textures |
| No allocs in `_physics_process` | constitution.md | Brick._physics_process only mutates floats — no Array/Dictionary creation |
| Tabs only, `# [JS equiv]` on non-trivial lines | constitution.md | Every new GDScript file |
| No third-party plugins | constitution.md | AnimationPlayer for logo, not a tween library |
| Touch-only input | constitution.md | Flip banner tap-block uses the same `_input()` gate |
| RNG call order immutable | LevelGenerator seed contract | New rng calls (powerup, collapse, flip) go AFTER existing calls, in that order |
