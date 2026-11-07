<div align="center">

# Deep Break

**A hyper-casual, procedurally generated brick-breaker for mobile, with a bioluminescent deep-sea look.**

![Godot](https://img.shields.io/badge/Godot-4.x-478CBF?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/GDScript-100%25-355570)
[![Google Play](https://img.shields.io/badge/Google%20Play-Live-3DDC84?logo=googleplay&logoColor=white)](https://play.google.com/store/apps/details?id=com.glitchytap.deepbreak)
![Workflow](https://img.shields.io/badge/Workflow-Spec--Driven-8A2BE2)
![PRs](https://img.shields.io/badge/PRs%20merged-48-success)

### [▶ Get it on Google Play](https://play.google.com/store/apps/details?id=com.glitchytap.deepbreak)

</div>

---

## Overview

> **Live on Google Play:** [Deep Break on the Play Store](https://play.google.com/store/apps/details?id=com.glitchytap.deepbreak). The project went from spec to a published Android release.

Deep Break is a portrait-mode, one-thumb breakout game built in **Godot 4 with pure GDScript**. Every level is **generated from a seed**, so the game never runs out of content, and the same seed always produces the same layout. Difficulty ramps up as you go: more rows, tougher bricks, indestructible obstacles, and bricks that sink toward your paddle.

The project was built **spec-first**. A written feature spec, an implementation plan, 66 sized tasks, and 6 Architecture Decision Records came before the code, and each task was delivered as its own reviewed pull request.

## Highlights

| | |
|---|---|
| 🎲 **Deterministic procedural levels** | `LevelGenerator.generate(seed, level)` is a pure function with a local, seeded RNG. Same input, same layout, on any device |
| 📈 **Difficulty curve** | Rows, brick HP, indestructible chance, ball speed and moving bricks all scale with the level number, driven by data tables |
| ⚡ **Power-ups** | **W**ide paddle (1.8×), **S**low-mo ball (0.55×), and **M**ulti-ball. 12% of destructible bricks drop one |
| ⬇️ **Collapsing bricks** | From level 10, some bricks sink toward the paddle. If one reaches it, you lose a life |
| 👆 **Touch-first controls** | Drag anywhere in the lower 40% of the screen. Ignores a second touch (palm rejection) and clamps to the screen edges |
| 🎯 **Ball physics feel** | Bounce angle depends on where the ball hits the paddle, paddle movement adds spin, small random jitter on bounces, and a watchdog frees a stuck ball |
| ✨ **Juice** | Bloom glow, trauma-based screen shake, screen flash, per-tier particle bursts, HP dots on bricks, pooled SFX |

## Gameplay

```
   ●  ●  ●  ●  ●  ●  ●     ← violet: indestructible (level 7+)
   ■  ■  ■  ■  ■  ■  ■     ← amber:  3 HP
   ■  ■  ■  ■  ■  ■  ■     ← cyan:   2 HP
   ■  ■  ■  ■  ■  ■  ■     ← teal:   1 HP   (W / S / M power-ups drop from here)

              o            ← ball (speeds up 8% per level, max 2×)

          ═══════          ← paddle: drag anywhere in the lower 40% of the screen
```

- **3 lives.** You lose one when the last ball falls past the paddle, or when a sinking brick reaches it.
- **Scoring:** `10 × (tier + 1)` points per destroyed brick.
- **Level clear:** destroy every breakable brick and the next, harder level is generated.

### Difficulty curve

| Level | Max rows | Max brick HP | Indestructible | Moving bricks |
|------:|:--------:|:------------:|:--------------:|:-------------:|
| 1–2   | 5  | 1 | –   | – |
| 3–6   | 7  | 2 | –   | – |
| 7–9   | 9  | 3 | 5%  | – |
| 10–14 | 9  | 3 | 5%  | 15% · 30–50 px/s |
| 15–19 | 12 | 3 | 10% | 15% · 30–50 px/s |
| 20+   | 12 | 3 | 10% | 20% · 50–90 px/s |

Ball speed is `400 px/s × min(1 + 0.08 × level, 2)`, so it tops out at 800 px/s from level 13.

## Tech Stack

| | |
|---|---|
| **Engine** | Godot 4 (GDScript only, no C# or GDNative) |
| **Target** | Android API 26+, portrait locked |
| **Viewport** | 360 × 780 logical px (9:19.5), `canvas_items` stretch |
| **Renderer** | Mobile renderer, ETC2/ASTC texture compression |
| **Rendering budget** | 60 fps on a mid-range device, ≤ 30 draw calls, single sprite atlas |
| **Tooling** | VS Code + Godot LSP, a stdlib-only Python atlas generator, headless CLI export |

## Architecture

```
                 ┌──────────────── Autoloads (global singletons) ────────────────┐
                 │ GameManager    state machine · lives · score · level · seed   │
                 │ LevelGenerator pure (seed, level) → brick descriptors         │
                 │ JuiceManager   trauma shake · flash · particle bursts         │
                 │ AudioManager   pooled AudioStreamPlayers                      │
                 └───────────────────────────────────────────────────────────────┘
                                         ▲ signals
 Main.gd ── swaps child scenes ── Title → Game → LevelClear / GameOver
                                         │
                       Game.gd (orchestrator)
             ┌───────────┼─────────────┬──────────────┐
          Paddle       Ball(s)      BrickGrid       PowerUp tokens
                                       └─ Brick × N  (HP dots, tier colour, mobile drift)
```

- **State machine:** `TITLE → WAITING → PLAYING → DEAD / LEVEL_CLEAR / GAME_OVER`. Every transition goes out as a signal and the UI reacts to it.
- **Signal-driven:** bricks emit `hit` / `destroyed` / `powerup_dropped`. `BrickGrid` relays them up and `Game.gd` turns them into score, juice and power-up tokens. No two unrelated nodes call each other directly.
- **Data-driven tuning:** difficulty, power-up and moving-brick behaviour live in constant tables, so balancing the game doesn't touch any logic.

### Architecture Decision Records

Design trade-offs are written down in [`docs/architecture/`](docs/architecture):

| ADR | Decision |
|-----|----------|
| [001](docs/architecture/adr-001-level-generator-return-type.md) | `LevelGenerator` returns a Dictionary wrapper so it can grow without breaking callers |
| [002](docs/architecture/adr-002-powerup-spawn-ownership.md) | Power-up tokens are spawned by `Game.gd` via signals, not by bricks |
| [003](docs/architecture/adr-003-mobile-brick-motion.md) | Moving bricks stay `StaticBody2D` with direct `position.y` updates and a speed cap |
| [004](docs/architecture/adr-004-flip-state-propagation.md) | Flip-mode state propagation *(feature later removed after play-testing)* |
| [005](docs/architecture/adr-005-scene-switching.md) | Scenes are swapped manually in `Main.gd` instead of with `change_scene_to_file` |
| [006](docs/architecture/adr-006-multiball-life-tracking.md) | Multi-ball life tracking is owned by `Game.gd`, not `GameManager` |

## Project Structure

```
deep-break-game/
├── project.godot               # display, stretch, autoloads, input
├── scenes/
│   ├── main/                   # Main (scene switcher), Title, Logo
│   ├── game/                   # Game, Ball, Paddle, Brick, BrickGrid, PowerUp, Walls
│   │   └── effects/            # BrickBurst particles
│   └── ui/                     # HUD, LevelClear, GameOver
├── scripts/
│   ├── Palette.gd              # bioluminescent colour constants (class_name)
│   └── autoloads/              # GameManager, LevelGenerator, JuiceManager, AudioManager
├── assets/                     # sprite atlas, Orbitron font, SFX
├── tools/generate_atlas.py     # builds the sprite atlas (Python stdlib only)
├── docs/                       # build guide + ADRs   (.gdignore, not shipped in APK)
└── specs/                      # spec, plans, 66 task files (.gdignore)
```

## Development Process

The game was built with a **spec-driven workflow** ([GitHub Spec Kit](https://github.com/github/spec-kit)):

1. **Specify:** [`specs/001-deep-break-core.md`](specs/001-deep-break-core.md) has user stories, acceptance scenarios, functional requirements and measurable success criteria (60 fps, ≤ 30 draw calls, a working CLI export within 5 minutes).
2. **Plan:** implementation plans for the core game and the polish phase.
3. **Break down:** [66 tasks](specs/tasks) (`T001`–`T066`), each sized for one session and tagged by the machine it needs (Mac editor or build machine).
4. **Deliver:** one branch and one pull request per task group, with tagged milestones `v0.1.0-phase1` → `v0.4.0-phase4`.

| Phase | Scope | Status |
|-------|-------|:------:|
| 1 | Project scaffold, touch paddle, bouncing ball, walls | ✅ |
| 2 | Bricks, HUD, game-state machine, Level Clear / Game Over, Android export | ✅ |
| 3 | Seeded procedural level generator, ball speed scaling | ✅ |
| 4 | Visual polish: bioluminescent palette, bloom, particles, shake, audio | ✅ |
| 5 | APK build pipeline and on-device verification | ✅ |
| 6 | Polish: title/logo, realistic ball movement, power-ups, collapsing bricks, HP indicators | ✅ |
| 7 | Store assets and **Google Play release** | ✅ |

## Getting Started

### Run in the editor

1. Install [Godot 4](https://godotengine.org/download) (standard build, not .NET).
2. Clone the repo:
   ```bash
   git clone https://github.com/mustafa-elhelbawy/deep-break-game.git
   ```
3. In Godot, choose **Import**, select `project.godot`, and press **Play** (F5). Mouse input emulates touch.

### Build an Android APK

The full walkthrough (SDK, export templates, keystore, `adb install`) is in [`docs/build.md`](docs/build.md). The short version:

```bash
# signing credentials come from environment variables and are never committed
export DEEP_BREAK_KEYSTORE_PATH=/path/to/deep-break.keystore
export DEEP_BREAK_KEY_ALIAS=deepbreak
export DEEP_BREAK_KEY_PASSWORD=********

godot --headless --export-release "Android Release" build/android/DeepBreak.apk
```

## Credits

- **Design & development:** [Mustafa El-Helbawy](https://github.com/mustafa-elhelbawy)
- **Contributions:** [@rami965](https://github.com/rami965) (power-up tuning, brick HP colour mapping and indicators, bug fixes)
- **Font:** [Orbitron](https://fonts.google.com/specimen/Orbitron) by Matt McInerney (SIL Open Font License 1.1)
