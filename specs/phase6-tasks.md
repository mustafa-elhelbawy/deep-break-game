# Tasks: Deep Break — Phase 6 Polish

**Plan**: `specs/phase6-polish-plan.md`
**Spec**: `specs/phase6-polish.md`
**Scope**: Game polish — logo, realistic physics, power-ups, collapsing bricks, flipped layouts, SFX.
**Updated**: 2026-04-21

---

## Machine Legend

| Badge | Meaning |
|-------|---------|
| `[MAC]` | Mac editing machine only |
| `[BUILD]` | Requires build machine (Windows/Mac + Android SDK + device) |
| `[EITHER]` | Either machine |

---

## Session 1 — Logo + Title Screen

**Goal**: Player sees the Deep Break bioluminescent logo on a title screen before the game starts.

- [ ] **T044** `[MAC]` — Add Orbitron-Bold font + create `Logo.tscn` (floating animated logo component)
- [ ] **T045** `[MAC]` — Create `Title.tscn` (navy BG, logo, teal particles, pulsing "TAP TO PLAY")
- [ ] **T046** `[MAC]` — Wire `Main.tscn` scene switcher (Title → Game → Title on restart)

---

## Session 2 — Realistic Ball Movement + Missing SFX

**Goal**: Ball bounces feel less deterministic. Two missing SFX events are wired.

- [ ] **T047** `[MAC]` — `Ball.gd`: ±5° angle jitter on wall/brick bounces
- [ ] **T048** `[MAC]` — `Paddle.gd` velocity tracking + `Ball.gd` paddle spin effect (±20° max)
- [ ] **T049** `[MAC]` — Add `brick_hit.wav` + `paddle_hit.wav` silent placeholders; wire AudioManager calls

---

## Session 3 — Power-Up Foundation

**Goal**: Power-up tokens fall from destroyed bricks. LevelGenerator assigns types. Brick.gd drops them.

- [ ] **T050** `[MAC]` — Create `PowerUp.tscn` + `PowerUp.gd` (falling Area2D token, 200 px/s)
- [ ] **T051** `[MAC]` — `LevelGenerator.gd`: `powerup_type` field + level gating (W≥5, S≥10, M≥20) + layout wrapper
- [ ] **T052** `[MAC]` — `Brick.gd`: drop token on destroy; `Game.gd`: `_on_powerup_caught` stub

---

## Session 4 — Power-Up Effects

**Goal**: W, S, M power-ups all activate/revert correctly. HUD shows active effect.

- [ ] **T053** `[MAC]` — Power-up W: Wide Paddle — 1.8× scale, 10 s timer, revert
- [ ] **T054** `[MAC]` — Power-up S: Slow Motion — 0.55× speed modifier, 10 s timer, revert
- [ ] **T055** `[MAC]` — Power-up M: Multi-Ball — second ball spawn, last-ball life logic, cleanup
- [ ] **T056** `[MAC]` — HUD power-up indicator — label + shrinking countdown bar

---

## Session 5 — Collapsing / Mobile Bricks

**Goal**: Some bricks drift downward at levels 10+. Reaching the paddle = life lost.

- [ ] **T057** `[MAC]` — `Brick.gd`: `set_mobile(speed)` — downward drift, red tint, `reached_paddle` signal
- [ ] **T058** `[MAC]` — `LevelGenerator.gd`: `collapse_speed` field; `BrickGrid.gd`: call `set_mobile()`
- [ ] **T059** `[MAC]` — `Game.gd`: connect `reached_paddle` → `GameManager.lose_life()` + flash + shake

---

## Session 6 — Flipped Layout Variant

**Goal**: ~20% of levels from level 3 flip the layout — paddle top, bricks bottom, ball down, top = death.

- [ ] **T060** `[MAC]` — `LevelGenerator.gd`: `layout_flipped` bool (20% chance, level 3+, seeded)
- [ ] **T061** `[MAC]` — `BrickGrid.gd`: `spawn(descriptors, flipped)` — lower-half brick placement
- [ ] **T062** `[MAC]` — `Game.gd` + `Ball.gd`: flip orchestration (paddle pos, wall toggle, launch dir, death edge)
- [ ] **T063** `[MAC]` — `Paddle.gd`: `set_flipped()` — upper 40% touch zone
- [ ] **T064** `[MAC]` — "FLIP LEVEL!" banner — 2-second animated CanvasLayer hint

---

## Session 7 — Smoke Test + Tag

**Goal**: Full on-device verification. Tag v0.6.0-phase6.

- [ ] **T065** `[BUILD]` — Phase 6 on-device smoke test (all 6 feature groups + Phase 1–5 regression)
- [ ] **T066** `[EITHER]` — Tag `v0.6.0-phase6` and push

---

## Dependencies Summary

```
T044 → T045 → T046
T047 → T048 → T049        (can start in parallel with T044)
T050 → T051 → T052
  T052 → T053 (W)
  T052 → T054 (S)
  T052 → T055 (M)
  T053 + T054 + T055 → T056 (HUD)
T057 → T058 → T059        (can start in parallel with T050)
T060 → T061 → T062 → T063 → T064
All T044–T064 → T065 → T066
```

---

## Phase 6 Exit Gate

Before Phase 7 (store assets):

- [ ] All 23 tasks (T044–T066) checked off
- [ ] Title screen loads before game on cold launch (device verified)
- [ ] All 6 SFX events fire without error on device
- [ ] W / S / M power-ups activate and revert correctly
- [ ] Mobile brick reaching paddle Y causes life loss on device
- [ ] Flipped level: paddle at top, ball launches down, top-exit = life lost (device verified)
- [ ] 55+ fps sustained with 2 balls + mobile bricks + particles active
- [ ] `v0.6.0-phase6` tag pushed to remote
