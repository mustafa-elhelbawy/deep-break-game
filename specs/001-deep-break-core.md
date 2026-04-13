# Feature Specification: Deep Break — Core Game

**Feature Branch**: `001-deep-break-core`  
**Created**: 2026-04-13  
**Status**: Draft  
**Input**: User description: "Build Deep Break — a hyper-casual breakout-style mobile game in Godot 4."

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Complete Game Loop (Priority: P1)

A player opens the app, launches the ball, breaks bricks with the bouncing ball while dragging their thumb to control the paddle, loses when the ball falls past the paddle, and can immediately restart.

**Why this priority**: Without a playable end-to-end loop there is nothing to test, tune, or ship. Every other story depends on this skeleton being solid.

**Independent Test**: Launch the APK on an Android device. Drag the paddle, let the ball bounce, allow it to fall past the paddle. Confirm the "Game Over" screen appears and the restart button returns the player to a fresh level — all without crashing or freezing.

**Acceptance Scenarios**:

1. **Given** the app is open on the title screen, **When** the player taps "Play", **Then** the ball sits on the paddle and waits for a launch tap.
2. **Given** the ball is waiting to launch, **When** the player taps the screen, **Then** the ball leaves the paddle at a fixed upward angle and begins bouncing.
3. **Given** the ball is in play, **When** it contacts a brick, **Then** the brick's hit-point counter decrements; if it reaches zero the brick is destroyed and a score point is awarded.
4. **Given** the ball is in play, **When** it contacts the paddle, **Then** it reflects off at an angle influenced by where it hit on the paddle's surface (centre = steep, edge = shallow).
5. **Given** the ball is in play, **When** it exits the bottom of the screen past the paddle, **Then** the player loses one life; if lives reach zero, the Game Over screen is shown.
6. **Given** the Game Over screen is shown, **When** the player taps "Restart", **Then** a new level is generated using a new seed and the loop begins again from the launch state.
7. **Given** all bricks on the current level are destroyed, **When** the last brick is removed, **Then** a "Level Clear" screen is shown and the next (harder) procedural level is loaded after a short delay.

---

### User Story 2 — Touch Paddle Control (Priority: P1)

A player controls the paddle exclusively by dragging a thumb anywhere on the lower half of the screen. The paddle tracks the horizontal finger position with no perceptible lag.

**Why this priority**: This is the only control input in the game. If it feels sluggish or imprecise the entire game experience collapses. Must be dialled in before any other feature is polished.

**Independent Test**: Build the APK. With only the paddle and a bouncing ball (no bricks required), play for 60 seconds. Confirm the paddle tracks the finger without drift, stutter, or finger-offset error on a mid-range Android device.

**Acceptance Scenarios**:

1. **Given** the ball is in play, **When** the player places and drags a finger anywhere in the lower 40 % of the screen, **Then** the paddle's centre follows the finger's X position, clamped to the screen edges.
2. **Given** the player lifts their finger, **When** there is no active touch, **Then** the paddle remains at its last position (does not drift or snap to centre).
3. **Given** a second simultaneous touch occurs (accidental palm), **When** there are two active touches, **Then** only the most-recently-started touch drives the paddle; the other is ignored.
4. **Given** the player's finger is at the screen edge, **When** the paddle would be driven beyond the play area, **Then** the paddle stops at the boundary without clamping artefacts.

---

### User Story 3 — Procedural Level Generation (Priority: P2)

Each level layout is generated from a numeric seed. Levels grow harder as the player's level number increases. Passing the same seed to the generator always produces the same layout.

**Why this priority**: Infinite progression and replayability are the core differentiators of Deep Break from a fixed-level breakout clone. Needed before public testing but can use placeholder difficulty tuning initially.

**Independent Test**: In the Godot editor, call the level generator with seed `42` at level 1, level 5, and level 10. Confirm: (a) layouts differ between levels, (b) calling with the same seed + level number twice produces identical layouts, (c) brick count and hit-points increase with level number.

**Acceptance Scenarios**:

1. **Given** level number N and seed S, **When** `LevelGenerator.generate(seed: S, level: N)` is called, **Then** it returns a deterministic array of brick descriptors (position, colour tier, hit-points).
2. **Given** level 1, **When** the layout is generated, **Then** the grid contains 30–50 bricks, all with 1 hit-point, arranged in simple rows.
3. **Given** level 10, **When** the layout is generated, **Then** the grid contains 60–90 bricks, with a mix of 1-, 2-, and 3-hit bricks, and at least one indestructible obstacle brick.
4. **Given** the same seed and level number are used twice, **When** both layouts are compared, **Then** every brick position and hit-point value is identical.
5. **Given** level N+1 vs level N with the same seed, **When** layouts are compared, **Then** level N+1 has strictly more bricks, higher average hit-points, or a tighter layout.

---

### User Story 4 — Juice Layer: Screen Shake, Particles, Sound (Priority: P2)

Every significant game event (brick hit, brick destroy, ball launch, paddle hit, game over) triggers a small visual and audio response that makes actions feel satisfying without being distracting.

**Why this priority**: "Juice" is what separates a hyper-casual hit from a tech demo. Should be layered in early so it can be tuned, not bolted on last.

**Independent Test**: Play a session on device with sound on. For each event type, confirm a response fires and does not degrade frame-rate below 55 fps on a mid-range device. Confirm no audio clipping or overlapping loops.

**Acceptance Scenarios**:

1. **Given** the ball hits a standard brick, **When** the brick absorbs the hit, **Then** a small burst of 4–6 glowing particles emits from the impact point and fades within 0.3 s.
2. **Given** a brick's hit-points reach zero, **When** the brick is destroyed, **Then** a larger particle burst (10–15 particles) plays, the brick flashes white for one frame, a short "crack" sound plays, and the camera shakes for 0.1 s at low intensity.
3. **Given** the ball hits the paddle, **When** deflection occurs, **Then** a soft "thud" sound plays; no screen shake.
4. **Given** the ball is lost (falls off-screen), **When** the life count decrements, **Then** a low-pitched "whoosh" plays and the screen flashes dark red for 0.2 s.
5. **Given** the last brick is destroyed, **When** the level clears, **Then** a multi-burst particle cascade plays, a bright chime sound plays, and the screen fades to white before transitioning.
6. **Given** a juice effect fires, **When** the effect plays, **Then** the frame time does not exceed 20 ms (≥50 fps) measured via Godot's performance monitor.

---

### User Story 5 — Bioluminescent Visual Theme (Priority: P3)

The game presents a deep-sea bioluminescent visual style: dark navy backgrounds, softly glowing bricks, warm particle colours, and a subtle bloom post-process effect. The palette is eye-friendly for extended sessions.

**Why this priority**: Theme polish comes after mechanics are solid. A wrong palette can be swapped in minutes; broken paddle physics cannot.

**Independent Test**: Run the game in the Godot editor. Screenshot the play scene. Confirm: background is dark navy (not pure black), bricks glow visibly against the background, particles use warm teal/cyan/amber hues, and the overall scene is readable without eye strain.

**Acceptance Scenarios**:

1. **Given** the play scene is loaded, **When** rendered, **Then** the background colour is in the range `#0a0e1a` – `#0d1530` (dark navy, not `#000000`).
2. **Given** a standard brick is rendered, **When** viewed, **Then** it uses a `CanvasItemMaterial` with `light_mode = LIGHT_ONLY` or a shader that produces a soft inner glow; colour is from the approved palette (teal, cyan, amber, violet — no pure white or neon green).
3. **Given** the `WorldEnvironment` node is active, **When** rendered, **Then** `Environment.glow_enabled = true`, `glow_intensity ≤ 0.4`, `glow_bloom ≤ 0.2` (muted, not blown-out).
4. **Given** the game is played for 10 minutes, **When** assessed subjectively, **Then** no tester reports eye fatigue caused by the palette (no high-contrast flickering, no pure white sustained on screen).

---

### User Story 6 — Android APK Headless Export (Priority: P3)

The project can be exported to a signed Android APK via the Godot CLI without opening the Godot editor GUI, runnable on a Windows, Mac, or Linux build machine.

**Why this priority**: Required before any public distribution, but not needed during early iteration. The game must work first.

**Independent Test**: On a clean Windows machine with Godot CLI and Android SDK installed, run the documented export command from `docs/build.md`. Confirm a `.apk` is produced and installs on a physical Android device without errors.

**Acceptance Scenarios**:

1. **Given** Godot CLI, Android SDK, and the project repo are present, **When** the command in `docs/build.md` is run, **Then** a signed `.apk` is produced in `build/android/` within 5 minutes.
2. **Given** the produced APK, **When** installed on a device running Android 8.0 (API 26) or higher, **Then** the app launches without crashes.
3. **Given** the export preset `export_presets.cfg` is committed to the repo, **When** a fresh clone is used, **Then** no manual export configuration is required in the editor.

---

### Edge Cases

- What happens when the ball gets trapped in a corner oscillating horizontally without hitting bricks? → A "stuck ball" timer (5 s) triggers a slight random velocity nudge to un-trap it.
- What happens when all bricks are destroyed but the ball is still mid-air? → The level-clear sequence waits for the ball to reach its next paddle contact or bottom-of-screen event, then transitions.
- What happens when the player's finger starts outside the lower 40 % zone and drags into it? → The paddle only responds to touches that *begin* in the lower 40 %; touches entering from above are ignored.
- What happens when the seed value overflows a 32-bit integer? → The generator wraps the seed using `seed % 2147483647` before use.
- What happens when the device has very low RAM and particles are dropped by the OS? → Particle nodes use `GPUParticles2D` with `one_shot = true` and `amount ≤ 15`; the game remains playable even if particles are culled.
- What happens if the user rapidly taps "Restart" multiple times? → The restart action is disabled for 0.5 s after the first tap (debounce) to prevent double-loading.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The game MUST support a complete loop: title → launch → play → game-over or level-clear → restart/next-level.
- **FR-002**: All player input MUST be handled via `InputEventScreenTouch` and `InputEventScreenDrag`; no keyboard or mouse input in game logic.
- **FR-003**: The paddle MUST track the active touch's X position each physics frame, clamped to the play area bounds.
- **FR-004**: The ball MUST reflect off the paddle with an angle calculated from the normalised offset of the hit point from the paddle centre (range: 30°–80° from vertical).
- **FR-005**: The ball MUST reflect off the top wall and both side walls; the bottom edge is the lose condition, not a wall.
- **FR-006**: Each brick MUST have an integer hit-point value (1–3 for standard bricks; `INF` / indestructible for obstacle bricks from level 10+).
- **FR-007**: The level generator MUST accept `(seed: int, level: int)` and return a deterministic, reproducible array of brick descriptors.
- **FR-008**: Difficulty scaling MUST increase brick count, hit-points, and/or ball speed incrementally per level without jumps that make the game unplayable.
- **FR-009**: The juice system MUST emit particles and play a sound for: brick hit, brick destroy, paddle hit, ball lost, level clear.
- **FR-010**: Screen shake MUST be implemented without moving the `Camera2D` node's global position (use a `trauma`-based offset pattern to avoid jitter artifacts on Android).
- **FR-011**: The `WorldEnvironment` bloom MUST be enabled with `glow_intensity ≤ 0.4` to achieve the bioluminescent theme without performance degradation.
- **FR-012**: The project MUST include an `export_presets.cfg` committed to the repo and a `docs/build.md` describing the headless CLI export command.
- **FR-013**: The game MUST target a minimum of 60 fps on a mid-range Android device (≈2019–2021, Adreno 618 / Mali-G76).
- **FR-014**: Draw calls per frame MUST not exceed 30; all brick and particle sprites MUST use a single texture atlas per scene.

### Key Entities

- **Ball**: Single physics body (`CharacterBody2D` or `RigidBody2D`). Has velocity, speed scalar, and a stuck-ball watchdog timer.
- **Paddle**: `CharacterBody2D`. Tracks touch X position. Has a width property that may increase via power-ups in future (out of scope now).
- **Brick**: `StaticBody2D` with a hit-point counter, colour tier (maps to palette), and a destroy signal. Instantiated from a packed scene.
- **LevelGenerator**: Autoload singleton (`Node`). Pure function: given `(seed, level)` returns `Array[BrickDescriptor]`. No scene dependencies.
- **BrickDescriptor**: A plain data object (GDScript `Dictionary` or inner class) with `grid_pos: Vector2i`, `hit_points: int`, `tier: int`.
- **GameManager**: Autoload singleton. Tracks lives, score, current level number, current seed. Emits signals for state transitions (game over, level clear).
- **JuiceManager**: Autoload singleton or scene-level node. Exposes methods: `shake(intensity, duration)`, `flash(colour, duration)`, `emit_burst(position, tier)`.
- **AudioManager**: Autoload singleton. Wraps `AudioStreamPlayer` pool (8 slots) to prevent audio starvation on rapid events.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A first-time player on a fresh APK install can reach a playable game state (ball bouncing, bricks breaking) within 5 seconds of opening the app — no tutorial or instructions required.
- **SC-002**: The game sustains ≥ 60 fps for at least 5 consecutive minutes on a mid-range Android device (confirmed via Godot's built-in profiler or Android GPU Inspector).
- **SC-003**: Draw calls per frame remain ≤ 30 during active gameplay (bricks on screen, particles firing), confirmed via Godot's profiler.
- **SC-004**: The level generator produces visually distinct layouts for level 1 vs level 10 using any given seed (subjective reviewer check — layouts must not look identical).
- **SC-005**: A headless CLI export command documented in `docs/build.md` produces a working APK on a clean Windows machine within 5 minutes, without opening the Godot editor GUI.
- **SC-006**: The game loop completes end-to-end (launch → break all bricks → level clear → new level → ball lost → game over → restart) without a crash or freeze across 10 consecutive playthroughs.
- **SC-007**: All juice events (brick hit, destroy, paddle hit, ball lost, level clear) fire correctly and do not cause frame time to exceed 20 ms.

---

## Assumptions

- The game targets Android API level 26 (Android 8.0) as the minimum, consistent with Godot 4's default Android export target.
- Portrait orientation is the only supported orientation; landscape will not be handled.
- The play area is 9:19.5 aspect ratio (360×780 logical pixels) as a baseline; Godot's `CanvasLayer` and `stretch` settings handle other screen sizes.
- One ball is in play at any given time; multi-ball power-ups are out of scope for this specification.
- Sound assets will be procedurally generated via `AudioStreamGenerator` or sourced from royalty-free libraries (not commissioned); format is `.ogg` for Android compatibility.
- No persistent data (high scores, settings) is required in this initial specification; `GameManager` state is in-memory only.
- The Godot editor version is **Godot 4.3** (stable); no Godot 4.4+ features should be assumed.
- The Windows build machine has Godot CLI, Android SDK (API 33 platform), and the Android build template pre-installed; the spec does not cover initial SDK setup.
- GDScript is the sole scripting language; no C# or GDNative.
