# Deep Break Constitution

## Core Principles

### I. GDScript with JS/TS Commentary (NON-NEGOTIABLE)

Every non-trivial GDScript block must include inline comments explaining:
- What the GDScript syntax does
- The JS/TS equivalent for mental-model anchoring

Examples to always annotate: typed variables (`var x: int`), signals, `@export`, `@onready`, `_ready()` / `_process()` lifecycle, `match` vs `switch`, pass-by-reference vs value, `null` vs no-value.

Comments are part of the deliverable — removing them is a breaking change. New contributors (or future-you) should be able to read any file without prior GDScript experience.

### II. Android-First, Touch-Only

All input handling must use Godot's touch input API (`InputEventScreenTouch`, `InputEventScreenDrag`). No mouse fallback, no keyboard shortcuts, no `Input.is_key_pressed()` in game logic.

UI must be designed for portrait-mode touch targets (min 48dp equivalent). Test interactions at 360×800 logical resolution as the baseline.

Do not assume physical device features beyond a touchscreen: no accelerometer, no haptic feedback, no multi-touch beyond two fingers.

### III. Tight Scope Per Session (NON-NEGOTIABLE)

Each working session delivers exactly one well-defined, completable feature or fix. No speculative code, no "while we're here" additions, no hooks for future features that don't exist yet.

If a session uncovers a larger problem, stop — document it as a new issue and finish the current scope. Gold-plating (extra animations, polish, config flags for one-off options) is a hard stop.

The definition of done: the feature works on an Android build, not just in the Godot editor.

### IV. No Third-Party Plugins Unless Justified

Use Godot 4's built-in APIs exclusively. Any third-party plugin requires:
1. A written justification explaining why the built-in API is insufficient
2. Confirmation the plugin is actively maintained and supports Godot 4 + Android
3. A fallback plan if the plugin breaks on a Godot version bump

Prefer one extra day of implementation over adding a dependency.

### V. Performance-Conscious by Default

Target: 60 fps sustained on a mid-range Android device (≈2019–2021, 3 GB RAM, Mali/Adreno 600-series GPU).

Hard limits per scene:
- Draw calls: ≤ 30 (use `CanvasItem` batching, avoid unnecessary `SubViewport`)
- Texture atlases: all sprites in a single atlas per scene
- `_process()` must not allocate objects — no `Vector2(...)` created inside the loop; cache them as member variables
- Avoid `get_node()` calls in `_process()` — use `@onready` to cache node references at startup

Profile before optimising. Do not pre-optimise code that hasn't been measured.

### VI. Cross-Machine Workflow Discipline

Editing happens on Mac (VS Code). Builds and APK exports happen on Windows PC. The project must always be in a state where a clean `git pull` on Windows produces a buildable APK without manual intervention.

All file paths in GDScript must use `res://` or `user://` — never OS-level absolute paths. Export presets are committed to the repo (`export_presets.cfg`). Keystore credentials are documented in the project README, never hardcoded.

Document any step that must be done manually on Windows in `docs/build.md`.

## Development Workflow

### Session Structure

1. Pull latest from `main`
2. Create a feature branch via `speckit.git.feature`
3. Implement exactly the scoped feature — nothing more
4. Run a device/emulator test (not just editor play)
5. Commit via `speckit.git.commit` with a clear message describing the gameplay impact
6. Open a PR; do not merge without a successful Android build

### Code Style

- `snake_case` for variables, functions, and file names (mirrors GDScript convention)
- `PascalCase` for class names and scene names
- One script per scene node — avoid monolithic scripts
- Max function length: 30 lines. If longer, extract a helper with a descriptive name
- No magic numbers: name every constant (`const GRAVITY: float = 980.0`)

### Comment Conventions

```gdscript
# [GDScript] @onready assigns the node reference after the scene tree is ready.
# [JS equiv]  Similar to document.querySelector() called inside DOMContentLoaded.
@onready var _label: Label = $ScoreLabel
```

Use `# TODO(scope):` for deferred work; `# PERF:` for known perf concerns; `# JS:` for cross-language annotations.

## Governance

This constitution supersedes all other practices and style preferences. Every PR must verify compliance with all six principles before merging.

Amendments require:
1. A written rationale explaining what broke or what was learned
2. A note on which existing code would need updating
3. Version bump in the footer

CLAUDE.md is the runtime companion for session-by-session guidance. If constitution and CLAUDE.md conflict, the constitution wins.

**Version**: 1.0.0 | **Ratified**: 2026-04-13 | **Last Amended**: 2026-04-13
