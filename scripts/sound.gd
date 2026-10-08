extends Node
## Music, effects and voices. In a race the sounds follow the local player's
## kart state (watch()), so solo races and online players hear the same.

const LINE_SELECT := 0
const LINE_HIT := 1
const LINE_ITEM := 2
const LINE_WIN := 3

var music_player := AudioStreamPlayer.new()
var engine := AudioStreamPlayer.new()
var pool: Array[AudioStreamPlayer] = []
var cache := {}
var music_name := ""
var prev := {}  # the watched kart's state last frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)
	music_player.volume_db = -6
	add_child(engine)
	engine.stream = _load("res://assets/sound/sfx/engine.wav")
	engine.volume_db = -18
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)


func _load(path: String) -> AudioStream:
	if not cache.has(path):
		cache[path] = load(path)
	return cache[path]


func sfx(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	for p in pool:
		if not p.playing:
			p.stream = _load("res://assets/sound/sfx/%s.wav" % name)
			p.pitch_scale = pitch
			p.volume_db = volume_db
			p.play()
			return


func voice(ch: int, line: int) -> void:
	sfx("v%d%d" % [ch, line], 1.0, 2.0)


func music(name: String) -> void:
	if name == music_name:
		return
	music_name = name
	var s: AudioStreamOggVorbis = _load("res://assets/sound/music/%s.ogg" % name)
	s.loop = true
	music_player.stream = s
	music_player.play()


func race_over() -> void:
	engine.stop()
	prev = {}


## One frame of the local player's race: turn state changes into sounds.
func watch(k: Kart, countdown: float, laps: int, act: int) -> void:
	var now := {"cd": ceili(countdown), "asking": k.asking, "verdict": k.verdict_t > 0, "boost": k.boost_t,
		"spin": k.spin_t, "bump": k.bump_t, "lap": k.lap, "fin": k.finished, "item": k.item, "roulette": k.roulette_t}
	if prev.is_empty():
		prev = now
	if countdown > 0 and now.cd != prev.cd and now.cd <= 3:
		sfx("beep")
	if countdown <= 0 and prev.cd > 0:
		sfx("go")
	if now.asking and not prev.asking:
		sfx("box")
	if now.verdict and not prev.verdict:
		sfx("right" if k.verdict_ok else "wrong")
	if now.boost > prev.boost + 0.2:
		sfx("boost", 1.0, -3)
		Controls.rumble(0.3, 0.0, 0.2)
	if now.spin > prev.spin + 0.2:
		sfx("spin")
		voice(k.ch, LINE_HIT)
		Controls.rumble(0.6, 1.0, 0.45)
	elif now.bump > prev.bump + 0.1:
		sfx("bonk", 1.2, -6)
		Controls.rumble(0.5, 0.2, 0.12)
	if now.lap > prev.lap and now.lap > 0 and not now.fin:
		sfx("lap")
		if now.lap == laps - 1:
			music("act%d_final" % (act + 1))
	if now.fin and not prev.fin:
		sfx("fanfare")
		voice(k.ch, LINE_WIN)
		music("results")
	if prev.item >= 0 and now.item < 0 and not now.fin:
		voice(k.ch, LINE_ITEM)
		if prev.item in [Kart.IT_SKULL, Kart.IT_LETTER]:
			sfx("throw")
	if now.roulette > 0 and int(now.roulette * 14) != int(prev.roulette * 14):
		sfx("tick", 1.0, -10)
	prev = now
	# the engine hums with speed
	if not engine.playing and countdown < 3.5:
		engine.play()
	engine.pitch_scale = 0.7 + clampf(absf(k.speed) / Kart.TOP_SPEED, 0, 1.5) * 0.8
