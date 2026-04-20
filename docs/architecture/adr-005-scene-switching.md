# ADR-005: Manual Child Scene Swapping in Main.gd (Not change_scene_to_file)

**Status**: Accepted
**Affects**: T046 — and the restart flow change in GameManager + GameOver

---

## Context

Phase 6 introduces a Title screen. The game needs to switch between `Title.tscn` and `Game.tscn`. Godot provides `get_tree().change_scene_to_file()` as a built-in mechanism.

## Options

| Option | Mechanism | Autoload behaviour | Signal safety | Complexity |
|--------|-----------|-------------------|---------------|------------|
| A: `change_scene_to_file()` | Engine built-in | Autoloads survive | All in-flight signals from old scene are dropped safely | Minimal code |
| B: Manual `add_child` / `queue_free` in Main.gd | Script-managed | Autoloads survive | Explicit control; old scene freed after signals are done | ~20 lines |

## Analysis

`change_scene_to_file()` works but has one subtle issue: it calls `queue_free()` on the ENTIRE current scene tree, then instantiates the new scene next frame. Any signals emitted in the same frame as the switch (e.g., `GameManager.restart()` → state_changed → Main reacts → switches scene) can be received by nodes that are about to be freed. Godot handles this gracefully, but it makes the flow harder to reason about.

Manual swapping (Option B) gives us explicit control: we free the old scene FIRST, then instantiate the new one. The sequence in `Main.gd._swap_to()` is deterministic.

The second issue is `resource_path` comparison. The task file T046 checks:
```gdscript
if _current_scene.scene_file_path == TitleScene.resource_path:
```
`scene_file_path` is a property on Node that returns the path the scene was loaded from. This is reliable.

## Decision

**Option B**: Manual child scene swapping. `Main.gd` holds `_current_scene: Node`. `_swap_to(PackedScene)` frees the old, instantiates the new.

## Critical: GameManager.restart() flow change

**Current flow**:
```
GameOver button → GameManager.restart() → start_game() → state=WAITING
→ Game.gd reacts: hides overlays, spawns level
```

**Phase 6 flow**:
```
GameOver button → GameManager.restart() → state=TITLE
→ Main.gd reacts: queue_free(Game.tscn), add_child(Title.tscn)
→ Title.tscn shows; player taps
→ GameManager.start_game() → state=WAITING
→ Main.gd reacts: queue_free(Title.tscn), add_child(Game.tscn)
→ Game.gd._ready() runs, GameManager.start_game() NOT called again (already WAITING)
```

**Problem**: `Game.gd._ready()` calls `GameManager.start_game()`. If `Main.gd` loads Game.tscn AFTER `start_game()` was already called by Title.gd, then `Game.gd._ready()` calls `start_game()` again — resetting score/lives.

**Fix**: `Game.gd._ready()` should NOT call `GameManager.start_game()`. Instead, it should call `GameManager.state_changed` listener to react to the CURRENT state. Since Main.gd loads Game.tscn after `start_game()` transitions to WAITING, `Game.gd._ready()` just needs to subscribe and react:

```gdscript
func _ready() -> void:
    JuiceManager.register_camera(_camera)
    GameManager.state_changed.connect(_on_state_changed)
    _grid.all_cleared.connect(_on_all_cleared)
    _grid.brick_destroyed.connect(_on_brick_destroyed)
    _ball.lost.connect(_on_primary_ball_lost)

    # React to current state — Main.gd loaded us because state is already WAITING.
    # Manually trigger the WAITING handler to spawn the first level.
    _on_state_changed(GameManager.state)
```

This replaces the direct `GameManager.start_game()` call in `Game.gd._ready()`.

## Trade-offs Accepted

- `Main.gd` is a thin routing layer — it adds one file but makes the entry flow explicit.
- `Game.gd` no longer calls `start_game()` — it reacts to state. This is correct: Game.gd should be a consumer of GameManager state, not a producer.
- The `scene_file_path` check in `Main.gd` is slightly fragile if scenes are moved. Acceptable for a single-developer project.

## Revisit Trigger

If more than 2 scenes need switching (e.g., settings screen), consider a scene stack or enum-keyed registry in Main.gd.
