# ADR-002: PowerUp Token Spawned by Game.gd via Signal, Not by Brick.gd Directly

**Status**: Accepted — **amends task files T052**
**Affects**: T050, T051, T052

---

## Context

When a brick with a `powerup_type` is destroyed, a `PowerUp` token must appear at the brick's world position and fall downward. The question is: which object is responsible for instantiating the token?

The original task file (T052) proposed `Brick.gd` instantiate `PowerUp.tscn` directly:
```gdscript
# T052 original proposal — Brick.gd spawns the token
const PowerUpScene: PackedScene = preload("res://scenes/game/PowerUp.tscn")
func _drop_powerup() -> void:
    var token = PowerUpScene.instantiate()
    get_tree().current_scene.add_child(token)
    ...
```

## Problem with Original Proposal

1. **Brick.gd depends on PowerUp.tscn** — a game entity should not know about specific power-up visuals. Bricks are already coupled to the atlas texture; adding a packed scene dependency increases coupling further.
2. **`get_tree().current_scene`** is fragile — it returns whatever scene is at the root. If the scene tree changes during a transition, this reference is wrong.
3. **Bypasses BrickGrid** — BrickGrid already relays all brick events (`destroyed`, `hit`) upward. Dropping power-up spawning into Brick.gd breaks this pattern and splits event handling across two places.

## Options

| Option | Pros | Cons |
|--------|------|------|
| A: Brick.gd spawns PowerUp directly (original proposal) | Self-contained | Brick→PowerUp coupling; fragile `current_scene` ref |
| B: Brick emits `powerup_dropped(type, pos)` signal; BrickGrid relays; Game.gd spawns | Consistent with existing pattern; Brick stays simple | One extra signal + relay handler |
| C: Brick emits through `destroyed` with extra payload | Reuse existing signal | `destroyed` already has semantics (score, juice); mixing concerns |

## Decision

**Option B**: Brick.gd emits `signal powerup_dropped(type: String, position: Vector2)`. BrickGrid relays it. Game.gd instantiates the `PowerUp.tscn`.

## Implementation

**Brick.gd** (replaces `_drop_powerup()`):
```gdscript
signal powerup_dropped(type: String, position: Vector2)

# In take_hit(), after emit_signal("destroyed"):
if _powerup_type != "":
    emit_signal("powerup_dropped", _powerup_type, global_position)
```

**BrickGrid.gd** (add relay):
```gdscript
# In spawn(), after connecting destroyed/hit:
brick.powerup_dropped.connect(_on_powerup_dropped)

func _on_powerup_dropped(type: String, pos: Vector2) -> void:
    emit_signal("powerup_dropped", type, pos)

signal powerup_dropped(type: String, position: Vector2)
```

**Game.gd** (add handler and PowerUp preload):
```gdscript
const PowerUpScene: PackedScene = preload("res://scenes/game/PowerUp.tscn")

# In _ready():
_grid.powerup_dropped.connect(_on_powerup_dropped)

func _on_powerup_dropped(type: String, pos: Vector2) -> void:
    var token: Area2D = PowerUpScene.instantiate()
    add_child(token)
    token.global_position = pos
    token.setup(type)
    token.caught.connect(_on_powerup_caught)
```

## Trade-offs Accepted

- One additional signal and relay method. Acceptable — BrickGrid already has this relay pattern for `destroyed` and `hit`.
- `PowerUp.tscn` is preloaded in `Game.gd` instead of `Brick.gd`. This is the correct owner — Game.gd manages all spawned game objects.

## Task File Amendment Required

T052 must be updated to use Option B. The `const PowerUpScene` preload and `_drop_powerup()` method described there should be removed from `Brick.gd` and replaced with the signal approach above.
