# Implementation Plan: Deep Break — Core Game

**Branch**: `001-deep-break-core` | **Date**: 2026-04-13 | **Spec**: `specs/001-deep-break-core.md`

---

## Summary

Build a hyper-casual breakout game in Godot 4 (GDScript) for Android. A `CharacterBody2D` ball bounces off walls, an `AnimatableBody2D` paddle (touch-controlled), and `StaticBody2D` bricks. Levels are generated procedurally from a seed + level number. The game runs at 60 fps on mid-range Android within a ≤ 30 draw-call budget. Delivered in five phases sized for 1–2 hour sessions.

---

## Technical Context

| Key | Value |
|-----|-------|
| **Language / Version** | GDScript · Godot 4.3 stable |
| **Scripting only** | No C#, no GDNative, no third-party plugins |
| **Target Platform** | Android API 26+ (portrait, 360 × 780 logical px) |
| **Performance Goals** | ≥ 60 fps sustained · ≤ 30 draw calls · no heap alloc in `_physics_process` |
| **Storage** | In-memory only (no persistence in this spec) |
| **Testing** | Manual playtest on device + Godot profiler; no automated test runner |
| **Build Machine** | Windows or Mac or Linux (Godot CLI + Android SDK) |
| **Edit Machine** | Mac, VS Code with `godot-tools` extension |
| **Export Format** | Signed `.apk` via `godot --headless --export-release` |

---

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. GDScript + JS comments | REQUIRED — every non-trivial block | Plan includes comment patterns per file |
| II. Touch-only | REQUIRED — paddle uses `InputEventScreenTouch/Drag` | No keyboard fallback in game logic |
| III. Tight scope | PASS — five phases, one feature per session | Multi-ball, power-ups, IAP are explicitly excluded |
| IV. No plugins | PASS — all Godot 4 built-ins only | `GPUParticles2D`, `AudioStreamPlayer`, `WorldEnvironment` all built-in |
| V. Performance | REQUIRED — draw call budget enforced via atlas | Profiler check gates Phase 4 sign-off |
| VI. Cross-machine | REQUIRED — `res://` paths only, `export_presets.cfg` committed | `docs/build.md` covers both platforms |

---

## Project File Structure

```text
deep-break-game/           ← Godot project root (project.godot lives here)
│
├── project.godot           ← display/stretch, autoloads, input map
├── export_presets.cfg      ← committed; keystore path uses env var
│
├── docs/
│   └── build.md            ← headless export steps (Mac + Windows)
│
├── scenes/
│   ├── main/
│   │   └── Main.tscn       ← entry scene; loads title or game
│   ├── game/
│   │   ├── Game.tscn       ← root of a play session
│   │   ├── Ball.tscn       ← CharacterBody2D + script
│   │   ├── Paddle.tscn     ← AnimatableBody2D + script
│   │   ├── Brick.tscn      ← StaticBody2D + script (packed scene, instanced many times)
│   │   ├── BrickGrid.tscn  ← Node2D; spawns / owns Brick instances
│   │   └── Walls.tscn      ← StaticBody2D × 3 (top, left, right)
│   └── ui/
│       ├── HUD.tscn        ← CanvasLayer: score, lives
│       ├── GameOver.tscn   ← CanvasLayer: final score, restart button
│       └── LevelClear.tscn ← CanvasLayer: level number, next button
│
├── scripts/
│   └── autoloads/
│       ├── GameManager.gd  ← state machine, lives, score, level, seed
│       ├── LevelGenerator.gd ← pure function: (seed, level) → Array[Dictionary]
│       ├── AudioManager.gd ← 8-slot AudioStreamPlayer pool
│       └── JuiceManager.gd ← shake(trauma), flash(colour), emit_burst(pos, tier)
│
├── assets/
│   ├── textures/
│   │   └── atlas.png       ← single sprite atlas (ball, paddle, brick tiers, particles)
│   ├── audio/
│   │   └── sfx/            ← brick_hit.ogg, brick_destroy.ogg, paddle_hit.ogg,
│   │                          ball_lost.ogg, level_clear.ogg
│   └── fonts/
│       └── ui_font.ttf
│
└── specs/                  ← Speckit docs (not included in APK export)
    ├── 001-deep-break-core.md
    └── 001-deep-break-core-plan.md   ← this file
```

**Structure decision**: Single Godot project, no sub-projects or workspaces. All GDScript is co-located with its scene (inline `[script]` references in `.tscn` files) except autoloads which live in `scripts/autoloads/`. `specs/` is in the repo root for Speckit but is excluded from the Godot export via the `.gdignore` pattern.

---

## Phase 1 — Godot Project Scaffold + First Scene

**Goal**: A bouncing ball reflecting off three walls and a touch-draggable paddle. No bricks. No game logic. Runs on Android without crashing.

**Estimated sessions**: 2–3 × 90 min

---

### 1.1 — project.godot Settings

Configure before writing any GDScript.

```ini
[display]
window/size/viewport_width = 360
window/size/viewport_height = 780
window/stretch/mode = "canvas_items"   ; scales content, preserves aspect ratio
window/stretch/aspect = "keep"         ; letterbox on wide screens

[input_devices]
pointing/emulate_touch_from_mouse = true   ; lets you test touch in editor on Mac

[rendering]
renderer/rendering_method = "mobile"   ; USE THIS — not "forward_plus" (too heavy for Android)
```

> **Mac vs Windows note**: `emulate_touch_from_mouse = true` is for Mac editor only. It has no effect on device. Leave it in — it does not affect the Android build.

---

### 1.2 — Autoload Registration

Register all four autoloads in `project.godot` before any scene references them. Order matters: `GameManager` must load before `JuiceManager`.

```
[autoload]
GameManager="*res://scripts/autoloads/GameManager.gd"
LevelGenerator="*res://scripts/autoloads/LevelGenerator.gd"
AudioManager="*res://scripts/autoloads/AudioManager.gd"
JuiceManager="*res://scripts/autoloads/JuiceManager.gd"
```

Create stub files for each now (empty `extends Node` + `func _ready(): pass`) so the project loads without errors. Fill in Phase 2 and 3.

---

### 1.3 — Walls Scene (`Walls.tscn`)

Three `StaticBody2D` nodes as children of a root `Node2D`. Use `CollisionShape2D` with `WorldBoundaryShape2D` for each.

```
Walls (Node2D)
├── WallTop    (StaticBody2D + CollisionShape2D[WorldBoundaryShape2D, normal=(0,1)])
├── WallLeft   (StaticBody2D + CollisionShape2D[WorldBoundaryShape2D, normal=(1,0)])
└── WallRight  (StaticBody2D + CollisionShape2D[WorldBoundaryShape2D, normal=(-1,0)])
```

`WorldBoundaryShape2D` is an infinite plane — no sizing needed, no drift when the screen size changes.

> **Why not a single `StaticBody2D` with three shapes?** Godot 4's `move_and_collide()` returns one collision at a time. Separate bodies ensures each collision has a clean, single normal.

---

### 1.4 — Ball Scene (`Ball.tscn`)

```
Ball (CharacterBody2D)
├── CollisionShape2D   [CircleShape2D, radius=10]
└── Sprite2D           [texture=atlas.png, region=(ball tile)]
```

**`Ball.gd`** — attach inline:

```gdscript
# Ball.gd
extends CharacterBody2D

# [GDScript] Constants use the 'const' keyword and are typed automatically.
# [JS equiv]  const SPEED = 400  (same concept, no type annotation needed in JS)
const BASE_SPEED: float = 400.0

# [GDScript] 'var' inside a class body is a member variable (like 'this.velocity' in JS).
# [JS equiv]  this.velocity = new Vector2(...)
var _velocity: Vector2 = Vector2.ZERO
var _active: bool = false  # false = waiting on paddle before launch

func launch(direction: Vector2) -> void:
    # [GDScript] .normalized() returns a unit vector (length=1), then we scale it.
    # [JS equiv]  this._velocity = direction.normalize().multiplyScalar(BASE_SPEED)
    _velocity = direction.normalized() * BASE_SPEED
    _active = true

func _physics_process(delta: float) -> void:
    # [GDScript] 'if not' is idiomatic; same as '!active' in JS.
    if not _active:
        return

    # move_and_collide moves by the given vector and returns a KinematicCollision2D
    # (or null if no collision). [JS equiv] No direct equivalent — this is Godot's
    # built-in swept-shape collision.
    var collision := move_and_collide(_velocity * delta)

    if collision:
        var collider = collision.get_collider()

        # [GDScript] is_in_group() checks the node's group membership — like checking
        # a CSS class. [JS equiv]  collider.classList.contains('brick')
        if collider.is_in_group("bricks"):
            collider.take_hit()

        # bounce() reflects _velocity across the collision normal (mirror reflection).
        # [JS equiv]  No direct equivalent; formula: v - 2*(v·n)*n
        _velocity = _velocity.bounce(collision.get_normal())

        # Maintain constant speed after bounce (floating-point drift fix)
        _velocity = _velocity.normalized() * BASE_SPEED
```

> **No heap allocation in `_physics_process`**: `Vector2.ZERO` and `collision.get_normal()` return structs by value in GDScript 4 — no GC pressure. `move_and_collide` does allocate a `KinematicCollision2D` if there's a hit, but that is unavoidable and acceptable.

---

### 1.5 — Paddle Scene (`Paddle.tscn`)

```
Paddle (AnimatableBody2D)          ← NOT CharacterBody2D; NOT StaticBody2D
├── CollisionShape2D  [RectangleShape2D, size=(120, 16)]
└── Sprite2D          [texture=atlas.png, region=(paddle tile)]
```

`AnimatableBody2D` is Godot 4's kinematic body designed for objects you move by script. Moving its `position` directly each frame is fully supported and triggers correct collision responses for objects moving into it.

**`Paddle.gd`**:

```gdscript
# Paddle.gd
extends AnimatableBody2D

# Half the viewport width minus half the paddle width = maximum X position
# These are set in _ready() after the node is in the scene tree.
# [GDScript] @onready is a property annotation that runs the assignment when
#            _ready() fires — equivalent to document.querySelector() in DOMContentLoaded.
# [JS equiv]  this._halfPaddleWidth = null; // assigned in connectedCallback()
@onready var _half_width: float = $CollisionShape2D.shape.size.x / 2.0

var _screen_half_width: float = 0.0
var _active_touch_index: int = -1  # -1 means no active touch
# [GDScript] -1 as a sentinel value for "none" is idiomatic GDScript (like null for objects).
# [JS equiv]  this._activeTouchId = null

func _ready() -> void:
    # get_viewport().get_visible_rect() returns the current viewport rectangle.
    # .size.x gives the width. Divide by 2 for the centre offset.
    # [JS equiv]  window.innerWidth / 2
    _screen_half_width = get_viewport().get_visible_rect().size.x / 2.0

func _input(event: InputEvent) -> void:
    # [GDScript] 'is' checks the runtime type — like 'instanceof' in JS.
    # [JS equiv]  event instanceof TouchEvent && event.type === 'touchstart'
    if event is InputEventScreenTouch:
        _handle_touch(event)
    elif event is InputEventScreenDrag:
        _handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
    # Only respond to touches that START in the lower 40% of the screen.
    var screen_height: float = get_viewport().get_visible_rect().size.y
    var lower_zone_y: float = screen_height * 0.60  # top of lower-40% zone

    if event.pressed and _active_touch_index == -1:
        if event.position.y >= lower_zone_y:
            _active_touch_index = event.index  # claim this touch

    elif not event.pressed and event.index == _active_touch_index:
        _active_touch_index = -1  # release claim

func _handle_drag(event: InputEventScreenDrag) -> void:
    if event.index != _active_touch_index:
        return  # ignore drags from non-claimed touches

    # Clamp paddle centre to screen bounds with padding equal to its half-width.
    # clamp(value, min, max) — same name and behaviour as Math.max(min, Math.min(max, v)) in JS.
    var new_x: float = clamp(event.position.x, _half_width, _screen_half_width * 2 - _half_width)
    position.x = new_x
```

---

### 1.6 — Game Scene (`Game.tscn`) — Phase 1 version

```
Game (Node2D)
├── Walls        (instance of Walls.tscn)
├── Paddle       (instance of Paddle.tscn, position y=700)
├── Ball         (instance of Ball.tscn, position y=670)
└── Camera2D     (position=(180, 390), zoom=(1,1))
     └── [Camera2D is a child so JuiceManager can offset it for screen shake]
```

**`Game.gd`** (Phase 1 stub — just launches ball on first tap):

```gdscript
# Game.gd
extends Node2D

@onready var _ball: Ball = $Ball
@onready var _paddle: Paddle = $Paddle

var _launched: bool = false

func _input(event: InputEvent) -> void:
    if _launched:
        return
    if event is InputEventScreenTouch and event.pressed:
        # Launch at a fixed upward-right angle for Phase 1 testing.
        # Vector2(-0.3, -1).normalized() ≈ 288° — slightly left of straight up.
        _ball.launch(Vector2(-0.3, -1.0))
        _launched = true
```

**Phase 1 done when**: Ball bounces off all three walls and the paddle indefinitely. Touch drag moves the paddle. No crashes on Android emulator or device.

---

## Phase 2 — Core Mechanics: Bricks, Collision, Game Loop

**Goal**: Bricks on screen, ball breaks them, lives and score tracked, Game Over and Level Clear screens shown.

**Estimated sessions**: 3–4 × 90 min

---

### 2.1 — Brick Scene (`Brick.tscn`)

```
Brick (StaticBody2D)  [group: "bricks"]
├── CollisionShape2D  [RectangleShape2D, size=(44, 18)]
└── Sprite2D          [texture=atlas.png, region determined by tier]
```

**`Brick.gd`**:

```gdscript
# Brick.gd
extends StaticBody2D

# Exported variables appear in the Godot Inspector panel.
# [GDScript] @export annotation makes a variable editable in the editor.
# [JS equiv]  No direct equivalent; closest is a prop in React/Vue with a default.
@export var hit_points: int = 1
@export var tier: int = 0  # 0=teal, 1=cyan, 2=amber, 3=violet, -1=indestructible

# [GDScript] signal declares an event that other nodes can connect to.
# [JS equiv]  this.addEventListener('destroyed', callback) — but signals are
#             first-class and type-checked.
signal destroyed(position: Vector2, tier: int)
signal hit(position: Vector2)

func take_hit() -> void:
    if hit_points <= 0:  # indestructible sentinel
        emit_signal("hit", global_position)
        return

    hit_points -= 1
    emit_signal("hit", global_position)

    if hit_points == 0:
        emit_signal("destroyed", global_position, tier)
        queue_free()  # [JS equiv] element.remove() — removes node next frame
```

---

### 2.2 — BrickGrid Scene (`BrickGrid.tscn`)

```
BrickGrid (Node2D)
└── [Brick instances added at runtime by spawn()]
```

**`BrickGrid.gd`**:

```gdscript
# BrickGrid.gd
extends Node2D

# preload() loads a resource at parse time (not runtime).
# [GDScript] Store it as a const so it is only loaded once.
# [JS equiv]  import BrickScene from './Brick.js'  (static import)
const BrickScene: PackedScene = preload("res://scenes/game/Brick.tscn")

# Grid layout constants
const BRICK_W: float = 44.0
const BRICK_H: float = 18.0
const PADDING_X: float = 4.0
const PADDING_Y: float = 4.0
const GRID_ORIGIN: Vector2 = Vector2(8.0, 60.0)  # top-left of grid, below HUD

# descriptors is Array[Dictionary] from LevelGenerator.generate()
# Each dict: { "grid_pos": Vector2i, "hit_points": int, "tier": int }
func spawn(descriptors: Array) -> void:
    # Clear previous level bricks if any
    for child in get_children():
        child.queue_free()

    for desc in descriptors:
        var brick: Brick = BrickScene.instantiate()
        # [GDScript] add_child() attaches the node to the scene tree.
        # [JS equiv]  this.element.appendChild(brick.element)
        add_child(brick)

        var col: int = desc["grid_pos"].x
        var row: int = desc["grid_pos"].y
        brick.global_position = GRID_ORIGIN + Vector2(
            col * (BRICK_W + PADDING_X),
            row * (BRICK_H + PADDING_Y)
        )
        brick.hit_points = desc["hit_points"]
        brick.tier = desc["tier"]

        # Connect brick signals to this grid's handlers.
        # [GDScript] signal.connect(callable) — like addEventListener in JS.
        # [JS equiv]  brick.addEventListener('destroyed', _on_brick_destroyed)
        brick.destroyed.connect(_on_brick_destroyed)
        brick.hit.connect(_on_brick_hit)

var _brick_count: int = 0

func get_brick_count() -> int:
    # [GDScript] get_children() returns all direct child nodes as an Array.
    # Filter to only Brick instances. [JS equiv] [...this.children].filter(n => n instanceof Brick)
    return get_children().filter(func(n): return n is StaticBody2D).size()

signal all_cleared
signal brick_hit(position: Vector2)
signal brick_destroyed(position: Vector2, tier: int)

func _on_brick_destroyed(pos: Vector2, tier: int) -> void:
    emit_signal("brick_destroyed", pos, tier)
    # Check win condition next frame (queue_free hasn't run yet for the brick)
    # [GDScript] call_deferred() runs the method after the current physics step.
    # [JS equiv]  setTimeout(() => this._checkWin(), 0)
    call_deferred("_check_cleared")

func _on_brick_hit(pos: Vector2) -> void:
    emit_signal("brick_hit", pos)

func _check_cleared() -> void:
    # Count only StaticBody2D children still in the tree
    var remaining := get_children().filter(func(n): return n is StaticBody2D)
    if remaining.is_empty():
        emit_signal("all_cleared")
```

---

### 2.3 — GameManager Autoload (`GameManager.gd`)

The state machine for the entire game session.

```gdscript
# GameManager.gd
extends Node

# [GDScript] enum defines named integer constants, scoped to this class.
# [JS equiv]  const State = Object.freeze({ TITLE: 0, WAITING: 1, ... })
enum State { TITLE, WAITING, PLAYING, DEAD, GAME_OVER, LEVEL_CLEAR }

var state: State = State.TITLE
var lives: int = 3
var score: int = 0
var level: int = 1
var seed: int = 0

# Signals for UI and scene reactions
signal state_changed(new_state: State)
signal score_changed(new_score: int)
signal lives_changed(new_lives: int)

func start_game(initial_seed: int = -1) -> void:
    lives = 3
    score = 0
    level = 1
    # [GDScript] randi() returns a random 32-bit unsigned int.
    # [JS equiv]  Math.floor(Math.random() * 2147483647)
    seed = initial_seed if initial_seed >= 0 else randi() % 2147483647
    _set_state(State.WAITING)

func add_score(points: int) -> void:
    score += points
    emit_signal("score_changed", score)

func lose_life() -> void:
    lives -= 1
    emit_signal("lives_changed", lives)
    if lives <= 0:
        _set_state(State.GAME_OVER)
    else:
        _set_state(State.WAITING)  # reset ball to paddle

func level_clear() -> void:
    level += 1
    _set_state(State.LEVEL_CLEAR)

func advance_level() -> void:
    _set_state(State.WAITING)

func _set_state(new_state: State) -> void:
    state = new_state
    emit_signal("state_changed", new_state)
```

---

### 2.4 — Game Scene (`Game.tscn`) — Phase 2 full version

Wire BrickGrid, HUD, and state machine together.

```
Game (Node2D)                  ← Game.gd
├── Walls                      (instance)
├── BrickGrid                  (instance)
├── Paddle                     (instance)
├── Ball                       (instance)
├── Camera2D
├── HUD                        (instance of HUD.tscn)
├── GameOver                   (instance of GameOver.tscn, visible=false)
└── LevelClear                 (instance of LevelClear.tscn, visible=false)
```

**`Game.gd`** — connects everything:

```gdscript
# Game.gd
extends Node2D

@onready var _ball: Ball = $Ball
@onready var _paddle: Paddle = $Paddle
@onready var _grid: BrickGrid = $BrickGrid
@onready var _hud = $HUD
@onready var _game_over_screen = $GameOver
@onready var _level_clear_screen = $LevelClear

func _ready() -> void:
    # Connect GameManager signals to local handlers
    GameManager.state_changed.connect(_on_state_changed)
    GameManager.score_changed.connect(_hud.update_score)
    GameManager.lives_changed.connect(_hud.update_lives)

    # Connect BrickGrid signals
    _grid.all_cleared.connect(_on_all_cleared)
    _grid.brick_destroyed.connect(_on_brick_destroyed)

    GameManager.start_game()

func _on_state_changed(new_state: GameManager.State) -> void:
    match new_state:
        # [GDScript] match is like switch/case in JS but uses structural pattern matching.
        # [JS equiv]  switch(newState) { case State.WAITING: ...; break; }
        GameManager.State.WAITING:
            _spawn_level()
            _reset_ball()
            _game_over_screen.hide()
            _level_clear_screen.hide()
        GameManager.State.GAME_OVER:
            _ball.deactivate()
            _game_over_screen.show()
        GameManager.State.LEVEL_CLEAR:
            _ball.deactivate()
            _level_clear_screen.show()

func _spawn_level() -> void:
    var descriptors := LevelGenerator.generate(GameManager.seed, GameManager.level)
    _grid.spawn(descriptors)

func _reset_ball() -> void:
    # Snap ball to just above paddle centre
    _ball.reset_to_paddle(_paddle.global_position)

func _on_all_cleared() -> void:
    GameManager.level_clear()

func _on_brick_destroyed(pos: Vector2, tier: int) -> void:
    GameManager.add_score(10 * (tier + 1))
    JuiceManager.emit_burst(pos, tier)
    JuiceManager.shake(0.3, 0.1)

func _input(event: InputEvent) -> void:
    if GameManager.state != GameManager.State.WAITING:
        return
    if event is InputEventScreenTouch and event.pressed:
        _ball.launch(Vector2(-0.3, -1.0))
        GameManager.state = GameManager.State.PLAYING
```

**Ball lost detection** — add to `Ball.gd`:

```gdscript
signal lost  # emitted when ball exits the bottom of the screen

func _physics_process(delta: float) -> void:
    if not _active:
        return
    var screen_height: float = get_viewport().get_visible_rect().size.y
    # If ball centre passes 20px below the screen bottom, it's lost.
    if global_position.y > screen_height + 20.0:
        _active = false
        emit_signal("lost")
        return
    # ... collision code from Phase 1
```

Connect in `Game.gd` `_ready()`:
```gdscript
_ball.lost.connect(func(): GameManager.lose_life())
```

**Phase 2 done when**: Ball breaks bricks, score increments, lives decrement on ball lost, Game Over screen appears, Level Clear screen appears when all bricks gone, restart works.

---

## Phase 3 — Procedural Level Generator + Seed System

**Goal**: Fully deterministic, seed-reproducible level layouts that scale in difficulty with level number.

**Estimated sessions**: 2–3 × 90 min

---

### 3.1 — LevelGenerator Autoload (`LevelGenerator.gd`)

No scene dependencies. Pure function returning data. Testable in isolation.

```gdscript
# LevelGenerator.gd
extends Node

# Grid dimensions
const COLS: int = 7
const MIN_ROWS: int = 4
const MAX_ROWS: int = 12

# Difficulty breakpoints — level N uses the entry where level >= threshold.
# [GDScript] Array of Dictionaries — like an array of objects in JS.
# [JS equiv]  const TIERS = [{ threshold: 1, maxHp: 1 }, ...]
const DIFFICULTY_TABLE: Array = [
    { "threshold": 1,  "max_rows": 5,  "max_hp": 1, "indestructible_chance": 0.0 },
    { "threshold": 5,  "max_rows": 7,  "max_hp": 2, "indestructible_chance": 0.0 },
    { "threshold": 10, "max_rows": 9,  "max_hp": 3, "indestructible_chance": 0.05 },
    { "threshold": 20, "max_rows": 12, "max_hp": 3, "indestructible_chance": 0.10 },
]

# generate() is a pure function: same inputs always produce the same output.
# [GDScript] -> Array means the return type is Array (of Dictionaries here).
# [JS equiv]  function generate(seed, level) { return [...] }
func generate(seed: int, level: int) -> Array:
    # Wrap seed to 32-bit signed range to avoid RandomNumberGenerator issues.
    var safe_seed: int = abs(seed % 2147483647)

    # Combine seed and level into a unique seed for this specific level.
    # Using a prime multiplier keeps seeds well-distributed.
    # [GDScript] ^ is bitwise XOR, same as in JS.
    var level_seed: int = safe_seed ^ (level * 2654435761)

    # [GDScript] RandomNumberGenerator is a seeded PRNG — like seedrandom in JS.
    # It is NOT the global randi(); it is a local, seeded instance.
    var rng := RandomNumberGenerator.new()
    rng.seed = level_seed

    # Look up difficulty for this level
    var diff: Dictionary = DIFFICULTY_TABLE[0]
    for entry in DIFFICULTY_TABLE:
        if level >= entry["threshold"]:
            diff = entry  # last matching entry wins

    # Decide row count for this level (scales with level number, capped by difficulty)
    var rows: int = clampi(
        MIN_ROWS + int(level * 0.4),
        MIN_ROWS,
        diff["max_rows"]
    )

    # Build the brick descriptor array
    var result: Array = []

    for row in range(rows):
        for col in range(COLS):
            # Randomly skip ~15% of cells for visual interest
            if rng.randf() < 0.15:
                continue

            # Determine hit points: higher rows more likely to have higher HP
            var row_fraction: float = float(row) / float(rows)  # 0.0 (top) → 1.0 (bottom)
            var max_hp: int = diff["max_hp"]
            var hp: int = 1 + int(rng.randf() * row_fraction * max_hp)
            hp = clampi(hp, 1, max_hp)

            # Indestructible brick (sentinel: hit_points = 0 means indestructible)
            if rng.randf() < diff["indestructible_chance"]:
                hp = 0

            # tier maps to a colour: 0=teal, 1=cyan, 2=amber, 3=violet
            var tier: int = clampi(hp - 1, 0, 3)

            result.append({
                "grid_pos": Vector2i(col, row),
                "hit_points": hp,
                "tier": tier
            })

    return result
```

> **Testability without a test runner**: In the Godot editor, attach a temporary script to a Node in a test scene that calls `LevelGenerator.generate(42, 1)` in `_ready()` and prints the result. Compare level 1 vs level 10 output manually. Delete the test node before committing.

---

### 3.2 — Dynamic Ball Speed Scaling

Ball speed increases as level number grows. Add to `Ball.gd`:

```gdscript
# Called by Game.gd before each launch, passing the current level number.
func set_speed_for_level(level: int) -> void:
    # Speed increases 8% per level, capped at 2× base speed.
    # [GDScript] minf() is the float version of min(). Equivalent to Math.min() in JS.
    var scale: float = minf(1.0 + level * 0.08, 2.0)
    BASE_SPEED = 400.0 * scale  # BASE_SPEED is now a var, not const, from Phase 3 onward
```

---

### 3.3 — Stuck Ball Watchdog

Add to `Ball.gd` to prevent horizontal-oscillation stalls:

```gdscript
var _stuck_timer: float = 0.0
const STUCK_TIMEOUT: float = 5.0
const STUCK_NUDGE: float = 60.0  # px/s lateral nudge

func _physics_process(delta: float) -> void:
    if not _active:
        return

    # Accumulate time. Reset whenever vertical speed is significant.
    # abs() returns the absolute value — same as Math.abs() in JS.
    if abs(_velocity.y) > 30.0:
        _stuck_timer = 0.0
    else:
        _stuck_timer += delta

    if _stuck_timer >= STUCK_TIMEOUT:
        # Apply a random horizontal nudge to un-trap the ball.
        # randf_range(-1, 1) returns a float in [-1, 1].
        _velocity.x += randf_range(-STUCK_NUDGE, STUCK_NUDGE)
        _velocity = _velocity.normalized() * _current_speed
        _stuck_timer = 0.0

    # ... rest of physics from Phase 1
```

**Phase 3 done when**: Level 1 and level 10 produce visually different layouts from the same seed. Generating the same seed+level twice gives identical results. Ball speed is noticeably faster at level 10.

---

## Phase 4 — Visual Polish + Mobile UX

**Goal**: Bioluminescent theme, particle effects, screen shake, bloom, and a polished UI. All effects run within the ≤ 30 draw-call budget.

**Estimated sessions**: 3–4 × 90 min

---

### 4.1 — Colour Palette Constants

Create `scripts/Palette.gd` (not an autoload — just a static helper):

```gdscript
# Palette.gd — static class (no instantiation, pure data)
# [GDScript] 'class_name' registers the type globally so any script can use Palette.TEAL.
# [JS equiv]  export const Palette = { TEAL: '#00c8b8', ... }  (named export)
class_name Palette

const BACKGROUND: Color  = Color(0.039, 0.055, 0.102)  # #0a0e1a  dark navy
const TEAL:       Color  = Color(0.000, 0.784, 0.722)  # #00c8b8
const CYAN:       Color  = Color(0.000, 0.878, 1.000)  # #00e0ff
const AMBER:      Color  = Color(1.000, 0.757, 0.027)  # #ffc107
const VIOLET:     Color  = Color(0.694, 0.404, 1.000)  # #b167ff
const WHITE_SOFT: Color  = Color(0.878, 0.925, 1.000)  # #e0ecff  (never pure white)

# Indexed by tier for quick lookup in BrickGrid/JuiceManager
const TIER_COLOURS: Array[Color] = [TEAL, CYAN, AMBER, VIOLET]
```

---

### 4.2 — WorldEnvironment + Bloom

Add a `WorldEnvironment` node to `Game.tscn` (sibling of Camera2D):

```gdscript
# Set via Inspector or in Game.gd _ready():
func _configure_environment() -> void:
    var env: Environment = $WorldEnvironment.environment

    # Bloom (glow) — keep intensity low per constitution (≤ 0.4)
    env.glow_enabled = true
    env.glow_normalized = true
    env.glow_intensity = 0.30
    env.glow_bloom = 0.15
    env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

    # Background colour — dark navy, NOT pure black
    env.background_mode = Environment.BG_COLOR
    env.background_color = Palette.BACKGROUND
```

> **Android performance note**: Glow in Godot 4 `mobile` renderer uses a downsampled blur pass. At `glow_intensity = 0.30` with the mobile renderer this costs ~1 ms on mid-range Android — acceptable. Do not use `glow_levels` > 4 on mobile.

---

### 4.3 — JuiceManager Autoload (`JuiceManager.gd`)

```gdscript
# JuiceManager.gd
extends Node

# Cache the camera reference once the scene tree is ready.
# We use a 'trauma' value (0.0–1.0) that decays each frame.
# Offset = trauma² × max_shake — trauma² makes small shakes subtle.
# This pattern avoids moving Camera2D.global_position directly, which
# causes drift artifacts when the camera is also following a target.
# [JS equiv]  No direct equiv; similar to camera-shake in three.js using a
#             trauma/decay model.

var _camera: Camera2D = null
var _trauma: float = 0.0
const MAX_SHAKE_OFFSET: float = 12.0
const TRAUMA_DECAY: float = 2.5  # trauma units lost per second

# Particle scene — one shared PackedScene, instanced per burst
const BurstScene: PackedScene = preload("res://scenes/game/effects/BrickBurst.tscn")

# Flash overlay — a ColorRect covering the full viewport, normally hidden
var _flash_rect: ColorRect = null

func _ready() -> void:
    # Flash overlay: full-screen ColorRect, drawn above game, below HUD
    _flash_rect = ColorRect.new()
    _flash_rect.color = Color.TRANSPARENT
    _flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    _flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # Add to a CanvasLayer so it always renders above game nodes
    var layer := CanvasLayer.new()
    layer.layer = 10
    add_child(layer)
    layer.add_child(_flash_rect)

func register_camera(cam: Camera2D) -> void:
    # Called by Game.gd in _ready() to give JuiceManager a camera reference.
    _camera = cam

func shake(intensity: float, duration: float) -> void:
    # intensity: 0.0 (nothing) → 1.0 (max). duration is informational;
    # we set trauma and let it decay naturally.
    _trauma = minf(_trauma + intensity, 1.0)

func flash(colour: Color, duration: float) -> void:
    _flash_rect.color = colour
    # Tween the alpha from 0.7 back to 0 over 'duration' seconds.
    # [GDScript] create_tween() creates a fire-and-forget animation.
    # [JS equiv]  element.animate([{opacity: 0.7}, {opacity: 0}], { duration: duration * 1000 })
    var tween := create_tween()
    tween.tween_property(_flash_rect, "color:a", 0.0, duration)

func emit_burst(world_pos: Vector2, tier: int) -> void:
    # Instance a GPUParticles2D burst at world_pos.
    var burst: GPUParticles2D = BurstScene.instantiate()
    # Add to the current scene tree root so it isn't destroyed with a specific scene node.
    get_tree().current_scene.add_child(burst)
    burst.global_position = world_pos
    # Set burst colour from tier palette
    # [GDScript] modulate tints the entire node; for particles, set process_material instead.
    (burst.process_material as ParticleProcessMaterial).color = Palette.TIER_COLOURS[clampi(tier, 0, 3)]
    burst.emitting = true
    # Auto-remove after the burst lifetime is done (one-shot)
    # [GDScript] await pauses this function until the signal fires (like 'await' in JS async).
    # [JS equiv]  await new Promise(resolve => setTimeout(resolve, burst.lifetime * 1000))
    await get_tree().create_timer(burst.lifetime + 0.1).timeout
    burst.queue_free()

func _process(delta: float) -> void:
    if _camera == null or _trauma <= 0.0:
        return

    # Decay trauma over time
    _trauma = maxf(_trauma - TRAUMA_DECAY * delta, 0.0)

    # Apply squared trauma as offset (trauma² keeps small shakes subtle)
    var t2: float = _trauma * _trauma
    # randf_range(-1, 1) — same as Math.random() * 2 - 1 in JS
    var offset := Vector2(
        randf_range(-1.0, 1.0) * MAX_SHAKE_OFFSET * t2,
        randf_range(-1.0, 1.0) * MAX_SHAKE_OFFSET * t2
    )
    _camera.offset = offset
```

---

### 4.4 — BrickBurst Particle Scene (`BrickBurst.tscn`)

```
BrickBurst (GPUParticles2D)
    amount = 12
    lifetime = 0.35
    one_shot = true
    explosiveness = 0.9     ← emit all particles at once, not spread over lifetime
    process_material = ParticleProcessMaterial:
        direction = Vector3(0, -1, 0)
        spread = 180.0       ← full sphere burst
        initial_velocity_min = 80.0
        initial_velocity_max = 200.0
        gravity = Vector3(0, 200, 0)
        scale_min = 3.0
        scale_max = 6.0
        color = [set at runtime by JuiceManager]
```

> **Draw call budget**: `GPUParticles2D` is a single draw call regardless of `amount`. Twelve particles = 1 draw call. Keep `amount ≤ 15` per burst to stay within budget across simultaneous events.

---

### 4.5 — AudioManager Autoload (`AudioManager.gd`)

Eight `AudioStreamPlayer` nodes in a pool prevent audio stutter when multiple bricks are hit in a single frame.

```gdscript
# AudioManager.gd
extends Node

const POOL_SIZE: int = 8

# [GDScript] Array is typed with [AudioStreamPlayer] for clarity.
# [JS equiv]  this._pool = Array.from({length: 8}, () => new Audio())
var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0  # round-robin index

# Pre-load audio streams at startup to avoid hitches during play.
# [GDScript] preload() resolves at compile time — resource is bundled immediately.
var _sounds: Dictionary = {
    "brick_hit":     preload("res://assets/audio/sfx/brick_hit.ogg"),
    "brick_destroy": preload("res://assets/audio/sfx/brick_destroy.ogg"),
    "paddle_hit":    preload("res://assets/audio/sfx/paddle_hit.ogg"),
    "ball_lost":     preload("res://assets/audio/sfx/ball_lost.ogg"),
    "level_clear":   preload("res://assets/audio/sfx/level_clear.ogg"),
}

func _ready() -> void:
    # Build the pool
    for i in range(POOL_SIZE):
        var player := AudioStreamPlayer.new()
        player.bus = "SFX"  # Route through an "SFX" audio bus (set up in AudioBusLayout)
        add_child(player)
        _pool.append(player)

func play(sound_name: String) -> void:
    if not _sounds.has(sound_name):
        push_warning("AudioManager: unknown sound '%s'" % sound_name)
        return

    # Grab next slot in round-robin fashion and play
    var player: AudioStreamPlayer = _pool[_pool_index]
    _pool_index = (_pool_index + 1) % POOL_SIZE  # % is modulo — same as JS
    player.stream = _sounds[sound_name]
    player.play()
```

> **`.ogg` not `.mp3`**: Godot 4's Android export supports `.ogg` natively with no extra decoder overhead. Use `.ogg` for all SFX. `.mp3` introduces latency on first play due to decoder initialisation.

---

### 4.6 — Paddle Bounce Angle Calculation

Replace the flat `velocity.bounce(normal)` for paddle hits with angle-based deflection:

```gdscript
# In Ball.gd _physics_process(), after detecting a paddle collider:
if collider.is_in_group("paddle"):
    var paddle_half_width: float = collider.get_node("CollisionShape2D").shape.size.x / 2.0
    # offset: -1.0 (far left) → +1.0 (far right) of paddle
    var offset: float = (global_position.x - collider.global_position.x) / paddle_half_width
    offset = clampf(offset, -1.0, 1.0)

    # Map offset to angle: centre (0) = 80° from horizontal (steep), edge (±1) = 30°
    # [GDScript] lerp() linearly interpolates between two values. Same as JS lerp.
    # [JS equiv]  const angle = THREE.MathUtils.lerp(80, 30, Math.abs(offset))
    var angle_deg: float = lerpf(80.0, 30.0, abs(offset))
    var angle_rad: float = deg_to_rad(angle_deg)

    # Build a new velocity vector: always travels upward (-Y) after paddle hit
    var direction_x: float = sign(offset) * cos(angle_rad)
    var direction_y: float = -sin(angle_rad)  # negative Y = upward in Godot 2D
    _velocity = Vector2(direction_x, direction_y) * _current_speed
    AudioManager.play("paddle_hit")
```

**Phase 4 done when**: Bloom visible, bricks glow in tier colours, particle bursts on destroy, screen shake on destroy, paddle bounce feels satisfying, all juice sounds play without clipping. Profiler shows ≤ 30 draw calls, ≥ 60 fps sustained.

---

## Phase 5 — Signed APK Pipeline for Google Play

**Goal**: A documented, reproducible headless export that produces a signed APK on any machine (Windows, Mac, Linux) without opening the Godot editor.

**Estimated sessions**: 1–2 × 90 min

---

### 5.1 — Android Export Prerequisites

These steps are one-time setup on the build machine. Document each in `docs/build.md`.

| Step | Mac | Windows |
|------|-----|---------|
| Install Godot CLI | `brew install godot` or download binary | Download from godotengine.org, add to PATH |
| Install JDK 17 | `brew install openjdk@17` | Download Adoptium Temurin 17 |
| Install Android SDK | Android Studio or `sdkmanager` | Android Studio or `sdkmanager` |
| Accept SDK licences | `sdkmanager --licenses` | `sdkmanager --licenses` |
| Install platform tools | `sdkmanager "platform-tools" "platforms;android-33" "build-tools;33.0.2"` | Same |
| Generate keystore | `keytool -genkey -v -keystore deep-break.keystore ...` | Same (keytool ships with JDK) |

> **Mac vs Windows path note**: On Mac, `GODOT_CLI` is typically `godot` (in PATH after brew). On Windows, it is `godot.exe` or the full path. The export command in `docs/build.md` must document both variants.

---

### 5.2 — `export_presets.cfg`

Commit this file to the repo. Use environment variables for secrets (never hardcode keystore paths or passwords).

```ini
[preset.0]
name="Android Release"
platform="Android"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter="specs/*,docs/*"

[preset.0.options]
custom_template/release=""
gradle_build/use_gradle_build=true
gradle_build/compress_native_libraries=true
package/unique_name="com.deepbreak.game"
package/name="Deep Break"
package/signed=true
keystore/release="%DEEP_BREAK_KEYSTORE_PATH%"
keystore/release_user="%DEEP_BREAK_KEY_ALIAS%"
keystore/release_password="%DEEP_BREAK_KEY_PASSWORD%"
screen/orientations=1   ; 1 = portrait
```

> **Environment variables**: `DEEP_BREAK_KEYSTORE_PATH`, `DEEP_BREAK_KEY_ALIAS`, `DEEP_BREAK_KEY_PASSWORD`. Set these in the shell before running the export command. Never commit them. Document them in `docs/build.md` as "set these before running."

---

### 5.3 — Headless Export Command

**Mac / Linux**:
```bash
export DEEP_BREAK_KEYSTORE_PATH=/path/to/deep-break.keystore
export DEEP_BREAK_KEY_ALIAS=deep-break-key
export DEEP_BREAK_KEY_PASSWORD=yourpassword

godot --headless --export-release "Android Release" build/android/DeepBreak.apk
```

**Windows (PowerShell)**:
```powershell
$env:DEEP_BREAK_KEYSTORE_PATH = "C:\keys\deep-break.keystore"
$env:DEEP_BREAK_KEY_ALIAS = "deep-break-key"
$env:DEEP_BREAK_KEY_PASSWORD = "yourpassword"

godot.exe --headless --export-release "Android Release" build\android\DeepBreak.apk
```

> The `--headless` flag prevents Godot from opening a display. Required for CI/CD and for running on Windows machines that may not have a display attached during automated builds.

---

### 5.4 — `.gdignore` for Specs

Create `specs/.gdignore` (empty file) and `docs/.gdignore` (empty file). Godot's exporter skips any directory containing a `.gdignore` file — spec and documentation files will not be bundled into the APK.

---

### 5.5 — `docs/build.md` Checklist

```markdown
# Deep Break — Android Build Guide

## One-time setup
1. Install Godot 4.3 CLI and add to PATH
2. Install JDK 17 and add keytool to PATH
3. Install Android SDK: platform-tools, platforms;android-33, build-tools;33.0.2
4. Run: sdkmanager --licenses
5. Generate keystore: keytool -genkey -v -keystore deep-break.keystore \
     -alias deep-break-key -keyalg RSA -keysize 2048 -validity 10000
6. Store keystore in a safe location OUTSIDE the repo

## Per-build steps
1. Set env vars: DEEP_BREAK_KEYSTORE_PATH, DEEP_BREAK_KEY_ALIAS, DEEP_BREAK_KEY_PASSWORD
2. Run: godot --headless --export-release "Android Release" build/android/DeepBreak.apk
3. Verify: adb install build/android/DeepBreak.apk

## Troubleshooting
- "Godot export template not found": Download Android export templates from
  Godot 4.3 release page and install via Editor > Manage Export Templates
  (one-time, can be done headlessly with --install-android-build-template)
- "keytool not found on Windows": Ensure JDK 17 bin directory is in PATH
```

**Phase 5 done when**: A fresh `git clone` + documented commands produces a working `.apk` on a machine that has never run Godot editor for this project.

---

## Complexity Tracking

No constitution violations. All choices use Godot 4 built-ins.

| Architectural Choice | Justification |
|----------------------|---------------|
| `AnimatableBody2D` for paddle (not `CharacterBody2D`) | Paddle is moved by setting `position` directly each frame; `AnimatableBody2D` is Godot 4's designed type for this pattern and correctly reports to the physics engine as a moving body |
| `CharacterBody2D` + `move_and_collide()` for ball (not `RigidBody2D`) | Full deterministic control over reflection angles; `RigidBody2D` introduces physics-engine non-determinism that breaks reproducible levels |
| Four autoloads (`GameManager`, `LevelGenerator`, `AudioManager`, `JuiceManager`) | Each singleton has a distinct, non-overlapping responsibility. Collapsing them would create a 500-line god object |
| `RandomNumberGenerator` instance in `LevelGenerator` (not global `randi()`) | Global `randi()` shares state with the engine — using it would make level generation non-reproducible. A local seeded instance is isolated |

---

## Session Roadmap

| Phase | Sessions (est.) | Gate to next phase |
|-------|-----------------|-------------------|
| 1 — Scaffold + ball + paddle | 2–3 | Ball bounces, paddle tracks finger, runs on Android |
| 2 — Bricks + game loop | 3–4 | Full loop: launch → break → game over/clear → restart |
| 3 — Procedural generator | 2–3 | Reproducible layouts, difficulty visible at level 10 |
| 4 — Visual polish + juice | 3–4 | All juice events fire within ≤ 30 draw calls at 60 fps |
| 5 — APK pipeline | 1–2 | Clean-clone export produces working APK |
| **Total** | **11–16 sessions** | ≈ 3–4 months at 1 session/week |
