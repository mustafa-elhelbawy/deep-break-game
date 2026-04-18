# AudioManager.gd
# Autoload singleton — loads OGG files and plays them on demand.
# Uses a fixed pool of AudioStreamPlayer nodes to allow overlapping sounds.
#
# [GDScript] 'extends Node' — autoload attaches to a plain Node in the scene tree.
# [JS equiv]  class AudioManager { play(id) { new Audio(SFX[id]).play() } }
extends Node

# ── Sound pool size ────────────────────────────────────────────────────────────
# How many sounds can play simultaneously without cutting each other off.
# 4 is enough for brick_destroy bursts (≤ 3 bricks per frame in practice).
# [JS equiv]  const POOL_SIZE = 4
const POOL_SIZE: int = 4

# ── Stream map ─────────────────────────────────────────────────────────────────
# Keyed by the string IDs used in AudioManager.play() calls.
# load() at runtime (not preload) so missing files produce a clear warning, not a crash.
# [JS equiv]  const SFX = { ball_lost: new Audio('/sfx/ball_lost.ogg'), ... }
var _streams: Dictionary = {}

# ── Player pool ────────────────────────────────────────────────────────────────
# Round-robin index into the player array.
# [JS equiv]  const _pool = Array.from({length: POOL_SIZE}, () => new Audio())
var _players: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Build AudioStreamPlayer pool.
	# [JS equiv]  for (let i = 0; i < POOL_SIZE; i++) _pool.push(new Audio())
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

	# Load all known SFX files into the stream map.
	# If a file is missing, _load_stream() records null and play() skips silently.
	# [JS equiv]  Object.entries(SFX_PATHS).forEach(([k, v]) => SFX[k] = new Audio(v))
	_load_stream("ball_lost",     "res://assets/audio/sfx/ball_lost.wav")
	_load_stream("brick_destroy", "res://assets/audio/sfx/brick_destroy.wav")
	_load_stream("game_over",     "res://assets/audio/sfx/game_over.wav")
	_load_stream("level_clear",   "res://assets/audio/sfx/level_clear.wav")

# ── Public API ─────────────────────────────────────────────────────────────────

## Play a sound by its string ID (e.g. "brick_destroy").
## Uses round-robin pool — never blocks; silently skips unknown IDs.
## [JS equiv]  play(id) { SFX[id]?.cloneNode(true).play() }
func play(sound_id: String) -> void:
	if not _streams.has(sound_id):
		return
	var stream: AudioStream = _streams[sound_id]
	if stream == null:
		return

	# Pick the next player in the pool (round-robin).
	# [JS equiv]  const player = _pool[_poolIdx++ % POOL_SIZE]
	var player: AudioStreamPlayer = _players[_pool_idx]
	_pool_idx = (_pool_idx + 1) % POOL_SIZE

	player.stream = stream
	player.play()

# ── Private helpers ────────────────────────────────────────────────────────────

func _load_stream(id: String, path: String) -> void:
	# ResourceLoader.exists() avoids a hard error on missing files.
	# [JS equiv]  try { SFX[id] = new Audio(path) } catch { SFX[id] = null }
	if ResourceLoader.exists(path):
		_streams[id] = load(path)
	else:
		_streams[id] = null
		push_warning("AudioManager: missing SFX file — " + path)
