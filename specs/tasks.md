# Tasks: Deep Break — Phase 1 (Environment + First Scene)

**Plan**: `specs/001-deep-break-core-plan.md`  
**Spec**: `specs/001-deep-break-core.md`  
**Scope**: Phase 1 only — Godot project scaffold, bouncing ball, touch paddle. No bricks, no game logic.  
**Updated**: 2026-04-13

---

## Machine Legend

| Badge | Meaning |
|-------|---------|
| `[MAC]` | Mac editing machine only (Godot editor + VS Code) |
| `[BUILD]` | Requires the build machine (Windows, Mac, or Linux with Android SDK) |
| `[EITHER]` | Can be done on whichever machine you are at |

> **Rule**: All `[MAC]` tasks produce committed, pushable changes. All `[BUILD]` tasks pull those changes and verify the result on an Android device or emulator. You never need both machines open at the same time.

---

## Phase 1 Overview

```
Session 1 → T001–T003  Environment setup + project creation
Session 2 → T004–T006  Folder structure + autoload stubs + Walls scene
Session 3 → T007–T009  Ball scene + Ball.gd
Session 4 → T010–T011  Paddle scene + Paddle.gd
Session 5 → T012–T014  Game scene + wiring + editor smoke-test
Session 6 → T015–T017  Android build prerequisites + device verification
```

---

## Session 1 — Environment Setup + Godot Project Creation

**Goal**: A working Godot project that opens in the editor and renders a blank navy screen. Nothing moves yet.

**Estimated time**: 60–90 min  
**Machine**: `[MAC]`

---

- [ ] **T001** `[MAC]` — Install Godot 4.3 editor on Mac and configure VS Code

  **Steps**:
  1. Download Godot 4.3 stable (standard version, not .NET/C#) from godotengine.org
  2. Move `Godot_v4.3-stable_macos.universal` to `/Applications/Godot.app`
  3. In VS Code, install the **godot-tools** extension (publisher: `geequlim`)
  4. Open VS Code settings → search `godot` → set `godot_tools.editor_path` to `/Applications/Godot.app`
  5. In Godot Editor → Editor Settings → Text Editor → External → check **Use External Editor**, set executable to the VS Code `code` CLI (`/usr/local/bin/code` or `$(which code)`)

  **Verify**: Clicking a `.gd` file in the Godot FileSystem panel opens it in VS Code with syntax highlighting.

  **GDScript gotcha**: The `godot-tools` extension provides autocomplete by connecting to a running Godot Language Server. Keep the Godot editor open while editing in VS Code — the LSP only runs when Godot is open.

---

- [ ] **T002** `[MAC]` — Create the Godot project with correct display and renderer settings

  **Steps**:
  1. Open Godot → New Project → name `deep-break-game`, point to the repo root (the folder already exists from git clone)
  2. Renderer: select **Mobile** (not Forward+ — too heavy for mid-range Android)
  3. After the project opens, go to **Project → Project Settings**:

  ```
  Display → Window:
    Viewport Width  = 360
    Viewport Height = 780
    Stretch Mode    = canvas_items
    Stretch Aspect  = keep

  Input Devices → Pointing:
    Emulate Touch From Mouse = ON   ← editor-only convenience; no effect on device

  Rendering → Renderer:
    Rendering Method = mobile      ← confirm this was set at project creation
  ```

  4. Save the project. A `project.godot` file now exists at the repo root.

  **Verify**: Project opens without errors. The editor viewport background is grey (no scene loaded yet). `project.godot` appears in git status as a new file.

  > **Mac vs Build Machine**: `Emulate Touch From Mouse` only works in the Godot editor on Mac. It has no effect on the Android APK. Leave it enabled — it does not affect any exported build.

---

- [ ] **T003** `[MAC]` — Create the project folder structure and add placeholder files

  Create these folders and placeholder files so the Godot FileSystem panel shows the intended layout. Godot will not show empty folders — each needs at least a `.gdignore` or placeholder.

  **Folders to create** (relative to project root):

  ```
  scenes/main/
  scenes/game/
  scenes/game/effects/
  scenes/ui/
  scripts/autoloads/
  assets/textures/
  assets/audio/sfx/
  assets/fonts/
  docs/
  build/android/        ← output dir for APK; add to .gitignore
  ```

  **Files to create**:

  | File | Content |
  |------|---------|
  | `docs/build.md` | `# Build Guide\n\n_To be filled in Phase 5._` |
  | `build/.gitignore` | `*` (ignore all build output) |
  | `specs/.gdignore` | empty (prevents Godot exporting spec files into APK) |
  | `docs/.gdignore` | empty |

  **Verify**: All folders appear in Godot's FileSystem panel. `git status` shows new directories tracked. `build/android/` does not appear (it is gitignored).

---

## Session 2 — Autoload Stubs + Walls Scene

**Goal**: Four autoload scripts registered and loadable. Three-wall boundary in its own scene.

**Estimated time**: 75–90 min  
**Machine**: `[MAC]`

---

- [ ] **T004** `[MAC]` — Create the four autoload stub scripts

  Create these four files. Each is just a stub — real logic comes in Phases 2–4. The stubs must exist now so that later scenes can reference them without errors.

  **`scripts/autoloads/GameManager.gd`**:
  ```gdscript
  # GameManager.gd
  # Autoload singleton — tracks game state, lives, score, level number, seed.
  # Filled in during Phase 2. Stub only for Phase 1.
  # [GDScript] 'extends Node' means this script attaches to a plain Node.
  # [JS equiv]  class GameManager { } — a plain class with no DOM/rendering role.
  extends Node

  func _ready() -> void:
      pass  # [GDScript] 'pass' is a no-op placeholder, like an empty {} block in JS.
  ```

  **`scripts/autoloads/LevelGenerator.gd`**:
  ```gdscript
  # LevelGenerator.gd
  # Autoload singleton — pure function: (seed, level) → Array[Dictionary].
  # Filled in during Phase 3. Stub only for Phase 1.
  extends Node

  func generate(_seed: int, _level: int) -> Array:
      # [GDScript] The underscore prefix on a parameter name suppresses
      # the "unused variable" warning. [JS equiv] (_seed, _level) => []
      return []
  ```

  **`scripts/autoloads/AudioManager.gd`**:
  ```gdscript
  # AudioManager.gd
  # Autoload singleton — 8-slot AudioStreamPlayer pool.
  # Filled in during Phase 4. Stub only for Phase 1.
  extends Node

  func play(_sound_name: String) -> void:
      pass
  ```

  **`scripts/autoloads/JuiceManager.gd`**:
  ```gdscript
  # JuiceManager.gd
  # Autoload singleton — screen shake, flash, particle bursts.
  # Filled in during Phase 4. Stub only for Phase 1.
  extends Node

  func shake(_intensity: float, _duration: float) -> void:
      pass

  func flash(_colour: Color, _duration: float) -> void:
      pass

  func emit_burst(_world_pos: Vector2, _tier: int) -> void:
      pass
  ```

  **Register autoloads in `project.godot`**:

  Open **Project → Project Settings → Autoload** tab. Add each in this order (order matters — GameManager must load first):

  | Name | Path |
  |------|------|
  | `GameManager` | `res://scripts/autoloads/GameManager.gd` |
  | `LevelGenerator` | `res://scripts/autoloads/LevelGenerator.gd` |
  | `AudioManager` | `res://scripts/autoloads/AudioManager.gd` |
  | `JuiceManager` | `res://scripts/autoloads/JuiceManager.gd` |

  **Verify**: Project loads with no "autoload not found" errors in the Godot Output panel. Each `.gd` file opens correctly in VS Code.

---

- [ ] **T005** `[MAC]` — Create the placeholder sprite atlas

  For Phase 1, real art is not needed. Create a single 128×128 PNG with four coloured regions that stand in for the final atlas:

  | Region (x, y, w, h) | Colour | Used for |
  |---------------------|--------|---------|
  | 0, 0, 20, 20 | White circle on transparent | Ball |
  | 0, 20, 120, 16 | Cyan rect | Paddle |
  | 0, 36, 44, 18 | Teal rect | Brick (tier 0) |
  | 0, 54, 44, 18 | Amber rect | Brick (tier 2) |

  **How to create without Photoshop** (options):
  - Open Godot's built-in image editor: right-click `assets/textures/` → New Resource → ImageTexture, or
  - Use any free tool (GIMP, Pixelmator, even macOS Preview with the markup toolbar) to make a 128×128 PNG with four coloured rectangles
  - Save as `assets/textures/atlas.png`

  Import settings in Godot:
  - Click `atlas.png` in FileSystem → Import tab → **Filter**: Nearest (pixel-art crisp edges) → Re-Import

  **Verify**: `atlas.png` appears in Godot FileSystem without import errors. The import tab shows it as a `CompressedTexture2D`.

  > **Phase 1 note**: The placeholder atlas is intentionally rough. Phase 4 replaces it with a properly lit bioluminescent spritesheet. Using `Sprite2D.region_rect` from day one means swapping the art in Phase 4 requires only changing the PNG — no scene changes needed.

---

- [ ] **T006** `[MAC]` — Create `Walls.tscn`

  **Scene tree**:
  ```
  Walls (Node2D)  ← root
  ├── WallTop   (StaticBody2D)
  │   └── CollisionShape2D  [WorldBoundaryShape2D]
  ├── WallLeft  (StaticBody2D)
  │   └── CollisionShape2D  [WorldBoundaryShape2D]
  └── WallRight (StaticBody2D)
      └── CollisionShape2D  [WorldBoundaryShape2D]
  ```

  **Per-wall configuration in the Inspector**:

  | Wall | CollisionShape2D → Shape | Normal |
  |------|--------------------------|--------|
  | WallTop | WorldBoundaryShape2D | `(0, 1, 0)` — points downward into play area |
  | WallLeft | WorldBoundaryShape2D | `(1, 0, 0)` — points right into play area |
  | WallRight | WorldBoundaryShape2D | `(-1, 0, 0)` — points left into play area |

  **WallTop position**: `(180, 0)` — centred at the top edge of the 360×780 viewport.  
  **WallLeft position**: `(0, 390)` — centred on the left edge.  
  **WallRight position**: `(360, 390)` — centred on the right edge.

  No script needed on this scene. Save as `scenes/game/Walls.tscn`.

  **Verify**: Open the scene. In the 2D editor, use **Debug → Visible Collision Shapes** to confirm three boundary planes appear at the correct edges. No errors in Output panel.

  > **Why `WorldBoundaryShape2D` and not a `RectangleShape2D` border?** A `WorldBoundaryShape2D` is an infinite plane — it never needs resizing when the viewport changes on different screen sizes. A rectangle border would require manual updates when testing on different Android aspect ratios.

---

## Session 3 — Ball Scene + Ball.gd

**Goal**: A ball that launches upward, bounces off all three walls, and emits a `lost` signal when it exits the bottom of the screen.

**Estimated time**: 75–90 min  
**Machine**: `[MAC]`

---

- [ ] **T007** `[MAC]` — Create `Ball.tscn`

  **Scene tree**:
  ```
  Ball (CharacterBody2D)  ← root; will have Ball.gd attached
  ├── CollisionShape2D  [CircleShape2D, radius = 10]
  └── Sprite2D          [texture = atlas.png, region_rect = Rect2(0, 0, 20, 20)]
  ```

  **CharacterBody2D Inspector settings**:
  - Motion Mode: **Floating** (not Grounded — "Grounded" adds gravity logic we don't want)
  - Collision Layer: `1` (default)
  - Collision Mask: `1` (collides with walls, paddle, bricks — all on layer 1)

  Save as `scenes/game/Ball.tscn`.

  **Verify**: Scene opens without errors. The white circle sprite is visible in the 2D editor centred on the origin.

---

- [ ] **T008** `[MAC]` — Write `Ball.gd` — movement, wall bounce, lost detection

  Attach a new script to the `Ball` root node. Save it inline with the scene (Godot default).

  ```gdscript
  # Ball.gd
  # Handles ball movement, reflection off walls/paddle/bricks, and lost detection.
  #
  # Architecture note: The ball uses CharacterBody2D + move_and_collide() rather than
  # RigidBody2D. This gives us deterministic control over reflection angles — critical
  # for seed-reproducible levels (Phase 3). RigidBody2D introduces physics-engine
  # non-determinism that would break that guarantee.
  extends CharacterBody2D

  # ── Signals ──────────────────────────────────────────────────────────────────
  # [GDScript] 'signal' declares a typed event. Other nodes subscribe with .connect().
  # [JS equiv]  this.dispatchEvent(new Event('lost')) — but signals are first-class
  #             and the editor shows connection errors at design time.
  signal lost

  # ── Constants ─────────────────────────────────────────────────────────────────
  # [GDScript] 'const' is a compile-time constant — cannot be reassigned.
  # In Phase 3 this becomes a 'var' so speed can scale with level number.
  # [JS equiv]  const BASE_SPEED = 400
  const BASE_SPEED: float = 400.0

  # ── State ─────────────────────────────────────────────────────────────────────
  # [GDScript] Member variables declared at class level. '_' prefix = private convention.
  # [JS equiv]  #_velocity = Vector2.ZERO  (private class field)
  var _velocity: Vector2 = Vector2.ZERO
  var _active: bool = false

  # Stuck-ball watchdog — prevents ball getting trapped in horizontal oscillation.
  var _stuck_timer: float = 0.0
  const STUCK_TIMEOUT: float = 5.0

  # ── Public API ────────────────────────────────────────────────────────────────

  ## Called by Game.gd when the player taps to launch.
  ## direction: a Vector2 pointing the intended travel direction (will be normalised).
  func launch(direction: Vector2) -> void:
      # .normalized() scales the vector to length 1, then we set the speed.
      # [JS equiv]  this._velocity = direction.clone().normalize().multiplyScalar(BASE_SPEED)
      _velocity = direction.normalized() * BASE_SPEED
      _active = true
      _stuck_timer = 0.0

  ## Snap ball to just above the paddle. Called on state reset (life lost, new level).
  func reset_to_paddle(paddle_pos: Vector2) -> void:
      _active = false
      _velocity = Vector2.ZERO
      # Position the ball 30px above the paddle's centre.
      global_position = paddle_pos + Vector2(0.0, -30.0)

  ## Called by Game.gd (Phase 2) when game ends so the ball stops moving.
  func deactivate() -> void:
      _active = false
      _velocity = Vector2.ZERO

  # ── Physics ───────────────────────────────────────────────────────────────────

  func _physics_process(delta: float) -> void:
      # [GDScript] 'if not' is idiomatic — equivalent to '!_active' in JS.
      if not _active:
          return

      _check_stuck(delta)
      _move_and_reflect(delta)
      _check_lost()

  func _move_and_reflect(delta: float) -> void:
      # move_and_collide() moves the body by the given vector this frame.
      # It returns a KinematicCollision2D if something was hit, or null.
      # [JS equiv]  No direct equivalent; Godot handles swept-shape collision internally.
      var collision := move_and_collide(_velocity * delta)

      if collision == null:
          return

      var collider: Object = collision.get_collider()

      # Notify brick that it was hit (Phase 2 wires this up; stub nodes ignore it).
      # [GDScript] is_in_group() checks a node's group membership, like CSS class check.
      # [JS equiv]  collider.classList.contains('bricks')
      if collider.is_in_group("bricks"):
          collider.take_hit()

      # Reflect velocity across the collision normal (mirror reflection).
      # bounce(normal) = velocity - 2 * dot(velocity, normal) * normal
      # [JS equiv]  No built-in; this is the standard reflection formula.
      _velocity = _velocity.bounce(collision.get_normal())

      # Re-normalise then rescale to prevent floating-point speed drift over many bounces.
      _velocity = _velocity.normalized() * BASE_SPEED

  func _check_stuck(delta: float) -> void:
      # If the ball's vertical speed is very low it may be bouncing horizontally forever.
      # abs() = Math.abs() in JS.
      if abs(_velocity.y) < 30.0:
          _stuck_timer += delta
      else:
          _stuck_timer = 0.0

      if _stuck_timer >= STUCK_TIMEOUT:
          # Add a random lateral nudge to break the oscillation.
          # randf_range(a, b) returns a random float in [a, b].
          # [JS equiv]  Math.random() * (b - a) + a
          _velocity.x += randf_range(-80.0, 80.0)
          _velocity = _velocity.normalized() * BASE_SPEED
          _stuck_timer = 0.0

  func _check_lost() -> void:
      # The bottom of the viewport is at y = viewport_height.
      # If the ball drops 20px below that, it is lost.
      var screen_h: float = get_viewport().get_visible_rect().size.y
      if global_position.y > screen_h + 20.0:
          _active = false
          # [GDScript] emit_signal() fires the signal to all connected listeners.
          # [JS equiv]  this.dispatchEvent(new Event('lost'))
          emit_signal("lost")
  ```

  **Verify**: Script attaches with no parse errors. In the Godot editor, play the scene in isolation (F6). Nothing moves yet — the ball needs `launch()` called. Add a temporary `_ready()` line `launch(Vector2(-0.3, -1.0))` to test, then remove it.

---

- [ ] **T009** `[MAC]` — Smoke-test Ball in isolation (editor only)

  Before building the full scene, verify the ball behaves correctly with a quick in-editor test.

  **Steps**:
  1. Temporarily add to `Ball.gd` `_ready()`:
     ```gdscript
     func _ready() -> void:
         launch(Vector2(-0.3, -1.0))
     ```
  2. Instance `Walls.tscn` as a child of a temporary test `Node2D` scene
  3. Add `Ball.tscn` as a sibling, positioned at `(180, 600)`
  4. Run with F6 — ball should bounce off top and side walls, eventually fall off the bottom

  **What to check**:
  - Ball bounces at visible angles, not randomly
  - Ball does not tunnel through walls (if it does: check that `Motion Mode = Floating` on CharacterBody2D)
  - After ball exits bottom, no further movement (lost signal fired, `_active = false`)
  - No errors in Output panel

  5. Delete the temporary `_ready()` test code before committing
  6. Delete the temporary test scene — do not commit it

---

## Session 4 — Paddle Scene + Paddle.gd

**Goal**: A paddle that tracks a dragged finger to its horizontal position. Works in the editor with mouse-emulated touch.

**Estimated time**: 75 min  
**Machine**: `[MAC]`

---

- [ ] **T010** `[MAC]` — Create `Paddle.tscn`

  **Scene tree**:
  ```
  Paddle (AnimatableBody2D)  ← root; will have Paddle.gd attached
  ├── CollisionShape2D  [RectangleShape2D, size = Vector2(120, 16)]
  └── Sprite2D          [texture = atlas.png, region_rect = Rect2(0, 20, 120, 16)]
  ```

  **AnimatableBody2D Inspector settings**:
  - Sync to Physics: **ON** — this ensures position updates are visible to the physics engine on the same frame, so the ball can bounce off a fast-moving paddle correctly
  - Collision Layer: `1`
  - Collision Mask: `1`

  **Node group**: Select the `Paddle` root node → Node tab → Groups → add `"paddle"`. The ball script checks `is_in_group("paddle")` in Phase 4 for angle-based deflection.

  Save as `scenes/game/Paddle.tscn`.

  **Verify**: Scene opens without errors. The cyan rectangle is visible centred on the origin in the 2D editor.

---

- [ ] **T011** `[MAC]` — Write `Paddle.gd` — touch tracking with lower-zone filtering

  ```gdscript
  # Paddle.gd
  # Moves the paddle horizontally to follow a touch in the lower 40% of the screen.
  # Uses AnimatableBody2D so the physics engine sees it as a properly-moving body
  # (a StaticBody2D moved by setting .position directly would cause incorrect
  # collision normals at high paddle speeds).
  extends AnimatableBody2D

  # ── Cached references (set in _ready) ─────────────────────────────────────────
  # @onready runs this assignment after the scene tree is fully built.
  # [GDScript] Think of it as: the right-hand side runs inside _ready() automatically.
  # [JS equiv]  connectedCallback() { this._halfWidth = this.querySelector('...').width / 2 }
  @onready var _half_width: float = ($CollisionShape2D.shape as RectangleShape2D).size.x / 2.0

  # ── State ─────────────────────────────────────────────────────────────────────
  # -1 is the "no active touch" sentinel. Touch indices are 0-based integers.
  # [JS equiv]  this._activeTouchId = null
  var _active_touch_index: int = -1
  var _screen_width: float  = 360.0  # updated in _ready from actual viewport
  var _screen_height: float = 780.0

  # ── Lifecycle ─────────────────────────────────────────────────────────────────

  func _ready() -> void:
      var viewport_rect: Rect2 = get_viewport().get_visible_rect()
      _screen_width  = viewport_rect.size.x
      _screen_height = viewport_rect.size.y

  # ── Input ─────────────────────────────────────────────────────────────────────

  # _input() receives ALL input events, even those consumed by UI nodes.
  # For game input that should always fire, _input() is correct.
  # [JS equiv]  document.addEventListener('touchstart', handler, { passive: true })
  func _input(event: InputEvent) -> void:
      # [GDScript] 'is' is a runtime type check — like 'instanceof' in JS.
      if event is InputEventScreenTouch:
          _handle_touch(event as InputEventScreenTouch)
      elif event is InputEventScreenDrag:
          _handle_drag(event as InputEventScreenDrag)

  func _handle_touch(event: InputEventScreenTouch) -> void:
      # Only claim touches that START in the lower 40% of the screen.
      var lower_zone_top: float = _screen_height * 0.60

      if event.pressed:
          # Claim only if no touch is currently active AND the touch starts in the zone.
          if _active_touch_index == -1 and event.position.y >= lower_zone_top:
              _active_touch_index = event.index
              # Immediately snap paddle to touch position on first contact.
              _move_to_x(event.position.x)
      else:
          # Release claim when the specific finger lifts.
          if event.index == _active_touch_index:
              _active_touch_index = -1
              # Paddle does NOT snap to centre — stays at last position.

  func _handle_drag(event: InputEventScreenDrag) -> void:
      # Ignore drags from fingers we haven't claimed.
      if event.index != _active_touch_index:
          return
      _move_to_x(event.position.x)

  func _move_to_x(target_x: float) -> void:
      # Clamp so the paddle never goes out of bounds.
      # clamp(value, min, max) — same name and semantics as JS Math.clamp (non-standard)
      # or the equivalent: Math.max(min, Math.min(max, value))
      position.x = clamp(target_x, _half_width, _screen_width - _half_width)
  ```

  **Verify**: Script attaches with no errors. Play the Paddle scene in isolation (F6 on a scene that contains just Paddle + a background ColorRect). Click and drag with the mouse — `Emulate Touch From Mouse` converts it to a touch event. The paddle should slide left/right and stop at the screen edges.

  > **Common mistake**: Dragging above the 60% line (upper 60% of the screen) will NOT move the paddle. This is intentional — the lower-zone filter prevents accidental movement when the player is touching the score display or UI. Verify this works by starting a drag from the upper half of the screen.

---

## Session 5 — Game Scene Assembly + Editor Smoke-Test

**Goal**: All three scenes (Ball, Paddle, Walls) composed into a playable Game scene. Tap to launch, drag to deflect, ball bounces indefinitely in the editor.

**Estimated time**: 90 min  
**Machine**: `[MAC]`

---

- [ ] **T012** `[MAC]` — Create `Game.tscn` with all Phase 1 nodes

  **Scene tree**:
  ```
  Game (Node2D)    ← root; will have Game.gd attached
  ├── Walls        (instance of scenes/game/Walls.tscn)
  ├── BallSpawnPoint  (Marker2D, position = (180, 660))   ← reference point only, no physics
  ├── Paddle       (instance of scenes/game/Paddle.tscn, position = (180, 710))
  ├── Ball         (instance of scenes/game/Ball.tscn,   position = (180, 680))
  └── Camera2D     (position = (180, 390))
  ```

  **Camera2D settings**:
  - Anchor Mode: **Fixed Top Left** — do not use "Drag Center"; we want a fixed viewport for mobile
  - Position Smoothing: OFF — mobile game; we want crisp, not floaty camera

  **Background**: With the `mobile` renderer and `WorldEnvironment`, the background defaults to grey. For now, add a `ColorRect` as the first child of `Game`:
  ```
  ColorRect  (position = (0,0), size = (360, 780), color = #0a0e1a)
  ```
  This will be replaced by the `WorldEnvironment` bloom setup in Phase 4.

  Save as `scenes/game/Game.tscn`.

---

- [ ] **T013** `[MAC]` — Write `Game.gd` — Phase 1 launch-on-tap stub

  ```gdscript
  # Game.gd
  # Phase 1 stub: tap anywhere to launch the ball. No game logic yet.
  # Phase 2 will replace _input() with a proper state-machine-driven launch.
  extends Node2D

  # @onready caches node references after the scene tree is ready.
  # These must match the exact node paths in Game.tscn.
  # [GDScript] $NodeName is shorthand for get_node("NodeName").
  # [JS equiv]  this._ball = document.getElementById('ball')
  @onready var _ball: CharacterBody2D = $Ball
  @onready var _paddle: AnimatableBody2D = $Paddle

  var _launched: bool = false

  func _ready() -> void:
      # Snap the ball to its position above the paddle at startup.
      # reset_to_paddle() is defined in Ball.gd.
      _ball.reset_to_paddle(_paddle.global_position)

      # Wire up the ball's lost signal so we can reset the scene when it falls.
      # .connect() takes a Callable — a reference to a function.
      # [JS equiv]  ball.addEventListener('lost', () => this._on_ball_lost())
      _ball.lost.connect(_on_ball_lost)

  func _input(event: InputEvent) -> void:
      if _launched:
          return
      # Launch on the first tap anywhere on the screen.
      if event is InputEventScreenTouch and event.pressed:
          # Slight left-of-centre angle to make the starting bounce less predictable.
          _ball.launch(Vector2(-0.3, -1.0))
          _launched = true

  func _on_ball_lost() -> void:
      # Phase 1 behaviour: just reset and allow re-launch.
      # Phase 2 replaces this with GameManager.lose_life().
      _launched = false
      _ball.reset_to_paddle(_paddle.global_position)
  ```

  **Verify**: Script attaches with no parse errors.

---

- [ ] **T014** `[MAC]` — Create `Main.tscn` and set it as the main scene, then run the full editor smoke-test

  **`Main.tscn`** (minimal — just loads Game):
  ```
  Main (Node)           ← root
  └── (no children)     ← In Phase 2 this will handle title screen / scene transitions.
                           For Phase 1, set the main scene directly to Game.tscn.
  ```

  Actually for Phase 1, skip Main and set Game.tscn as the main scene directly:

  **Project → Project Settings → Application → Run → Main Scene** → pick `scenes/game/Game.tscn`

  **Editor smoke-test checklist** (run with F5 or the play button):

  - [ ] Navy background visible (`#0a0e1a`)
  - [ ] Ball appears above paddle at startup, not moving
  - [ ] Tapping (mouse click with touch emulation) launches the ball upward at an angle
  - [ ] Ball bounces off top wall — angle changes correctly (not straight back)
  - [ ] Ball bounces off left wall — continues bouncing
  - [ ] Ball bounces off right wall — continues bouncing
  - [ ] Ball bounces off paddle when paddle is in the ball's path
  - [ ] Ball exits the bottom → ball snaps back to above paddle → tap again to re-launch
  - [ ] Dragging the mouse left/right in the lower half of the viewport moves the paddle
  - [ ] Paddle stops at screen edges (does not go off-screen)
  - [ ] No errors or warnings in the Godot Output panel

  **Commit everything now** with message: `feat: Phase 1 — bouncing ball + touch paddle (editor verified)`

---

## Session 6 — Android Build Prerequisites + Device Verification

**Goal**: The Phase 1 build runs on a real Android device (or emulator). No crashes, stable 60 fps with just the ball and paddle.

**Estimated time**: 60–120 min (varies by machine setup)  
**Machine**: `[BUILD]` — Windows, Mac, or Linux build machine

> **Note**: This session can be done on the same Mac used for editing if you have Android SDK installed there, or on a separate Windows build machine. The steps are identical — only the shell syntax differs (Bash vs PowerShell).

---

- [ ] **T015** `[BUILD]` — Install Android build prerequisites (one-time setup)

  This task only needs to be done once per build machine. If the machine already has these, skip to T016.

  **1. Install JDK 17**

  | Machine | Command |
  |---------|---------|
  | Mac | `brew install openjdk@17` then add to PATH per brew output |
  | Windows | Download Adoptium Temurin 17 installer from adoptium.net |
  | Linux | `sudo apt install openjdk-17-jdk` |

  Verify: `java -version` shows `17.x.x`

  **2. Install Android SDK command-line tools**

  Download from developer.android.com/studio#command-tools (the "Command line tools only" option — no Android Studio needed).

  Unzip to a folder, e.g. `~/Android/Sdk/cmdline-tools/latest/` (Mac/Linux) or `C:\Android\Sdk\cmdline-tools\latest\` (Windows).

  Add `sdkmanager` to PATH. Then:

  ```bash
  # Accept licences first (required)
  sdkmanager --licenses

  # Install required components
  sdkmanager "platform-tools" "platforms;android-33" "build-tools;33.0.2"
  ```

  **3. Configure Godot's Android SDK path**

  Godot Editor → Editor Settings → Export → Android:
  - Android SDK Path: set to the root of your SDK folder (e.g. `~/Android/Sdk`)

  **4. Install the Android export template for Godot 4.3**

  In Godot Editor → Editor → Manage Export Templates → Download. This downloads ~300 MB. Must be done once per Godot version.

  Alternatively (headless):
  ```bash
  # Download the export templates .tpz file from godotengine.org releases page
  # for Godot 4.3 stable, then install:
  godot --headless --install-android-build-template
  ```

  **Verify**: No errors in the Godot Export dialog when Android is selected.

---

- [ ] **T016** `[BUILD]` — Export a debug APK and install it on a device

  **Steps**:

  1. In Godot Editor → Project → Export → Add → Android
  2. Set Package Unique Name: `com.deepbreak.game`
  3. Screen Orientations: Portrait
  4. For Phase 1 testing, use a **debug export** (no signing required):
     - Export → Export Project → uncheck "Export With Debug" if you want a release build, or leave checked for a debug build
     - Save to `build/android/DeepBreak-debug.apk`

  **Or via command line** (works on any machine with Godot in PATH):

  ```bash
  # Mac / Linux
  godot --headless --export-debug "Android" build/android/DeepBreak-debug.apk

  # Windows PowerShell
  godot.exe --headless --export-debug "Android" build\android\DeepBreak-debug.apk
  ```

  **Install on device**:
  ```bash
  # Enable USB debugging on Android device first (Settings → Developer Options)
  adb install build/android/DeepBreak-debug.apk
  ```

  **Or** copy the APK to the device via USB and install it manually.

  > **Mac vs Windows note**: `adb` is in `platform-tools/`. On Mac it's usually in PATH after SDK setup. On Windows, add `C:\Android\Sdk\platform-tools\` to the system PATH, or call it with the full path.

---

- [ ] **T017** `[BUILD]` — Device verification checklist

  Run the APK on a physical Android device (preferred) or Android emulator.

  **Hardware target**: Any Android phone from 2019 or later. If testing on a mid-range device (e.g. Pixel 3a, Samsung A51), that is the official spec target.

  **Checklist**:

  - [ ] App opens without crash on first launch
  - [ ] Navy background renders (not black, not grey)
  - [ ] Ball appears above the paddle at app start
  - [ ] Tapping the screen launches the ball
  - [ ] Ball bounces off top and side walls — physics look correct
  - [ ] Dragging thumb in the **lower half** of the screen moves the paddle left/right
  - [ ] Dragging thumb in the **upper half** of the screen does NOT move the paddle
  - [ ] Paddle stops at screen edges
  - [ ] Ball bouncing off paddle deflects upward
  - [ ] Ball falling past paddle → resets to above paddle → tap to re-launch
  - [ ] No visible lag or jitter on paddle drag (should feel immediate)
  - [ ] Godot profiler (or Android GPU Inspector) shows ≥ 55 fps during active play

  **If the game runs below 55 fps on device** (unlikely at Phase 1 complexity):
  - Check that `Rendering Method = mobile` is set in project.godot (not `forward_plus`)
  - Ensure the `ColorRect` background is not using an expensive shader
  - Check that `Sync to Physics = ON` on the Paddle's `AnimatableBody2D` is not causing double physics steps

  **Commit the export_presets.cfg** once the export configuration is stable:
  ```bash
  git add export_presets.cfg
  git commit -m "feat: add Android export preset for Phase 1 debug build"
  ```

  **Phase 1 is complete** when this checklist passes on a real device.

---

## Dependencies & Execution Order

```
T001 (install tools)
  └── T002 (create project)
        └── T003 (folder structure)
              ├── T004 (autoload stubs)    ← can be done alongside T005
              ├── T005 (placeholder atlas) ← can be done alongside T004
              └── T006 (Walls scene)
                    └── T007 (Ball scene)
                          └── T008 (Ball.gd)
                                └── T009 (ball smoke-test — then delete test code)
                                      └── T010 (Paddle scene)
                                            └── T011 (Paddle.gd)
                                                  └── T012 (Game scene)
                                                        └── T013 (Game.gd)
                                                              └── T014 (editor test + commit)
                                                                    └── T015 (build machine setup — one-time)
                                                                          └── T016 (export APK)
                                                                                └── T017 (device verify)
```

**Parallel opportunities** (tasks with no shared files):

| Can run in parallel | Why |
|---------------------|-----|
| T004 + T005 | Different files (`scripts/` vs `assets/`) |
| T010 + (any docs work) | `Paddle.tscn` is independent of all other scenes until T012 |
| T015 (build machine setup) + T013/T014 (Mac work) | Different machines entirely |

---

## Phase 1 Exit Gate

Before starting Phase 2 (bricks + game loop), all of the following must be true:

- [ ] All 17 tasks checked off
- [ ] Device verification checklist (T017) passes on a physical Android device
- [ ] `export_presets.cfg` committed to repo
- [ ] No errors or warnings in Godot Output panel during editor play
- [ ] `git log` shows a clean commit history (no WIP or debug code committed)
- [ ] Temporary test code from T009 has been removed

**Then**: proceed to Phase 2 tasks (bricks, collision, game loop, GameManager, HUD).
