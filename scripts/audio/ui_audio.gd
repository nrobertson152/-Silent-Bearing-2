extends Node
## Sound for the menus: button clicks, the teleprinter in the story pages, the
## sea under the menu ship and a slow, dark ambient score. All synthesised.

const Settings := preload("res://scripts/core/settings.gd")
const RATE := 22050
## The score is all low drones, so a lower rate halves the synthesis work.
const MUSIC_RATE := 11025

static var _cache := {}

var click_p: AudioStreamPlayer
var type_p: AudioStreamPlayer
var sea_p: AudioStreamPlayer
var music_p: AudioStreamPlayer
var music_on := false
var sea_on := false
var _rng := RandomNumberGenerator.new()
var _thread: Thread


func _ready() -> void:
	_rng.seed = 3
	if not _cache.has("click"):
		_cache["click"] = _wav(_click())
		_cache["type"] = _wav(_type())
		_cache["sea"] = _wav(_sea(), true)
	click_p = _player("click")
	type_p = _player("type")
	sea_p = _player("sea")
	music_p = AudioStreamPlayer.new()
	add_child(music_p)
	sea_p.volume_db = -80.0
	music_p.volume_db = -80.0
	sea_p.play()
	if _cache.has("music"):
		_start_music()
	else:
		# Composing the score takes a moment: do it off the main thread.
		_thread = Thread.new()
		_thread.start(_compose)


func _compose() -> void:
	var w := _wav(_score(), true, MUSIC_RATE)
	_cache["music"] = w
	_start_music.call_deferred()


func _start_music() -> void:
	music_p.stream = _cache["music"]
	music_p.play()


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func _player(name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _cache[name]
	add_child(p)
	return p


func click() -> void:
	click_p.volume_db = linear_to_db(maxf(0.5 * Settings.volume, 0.0001))
	click_p.pitch_scale = _rng.randf_range(0.95, 1.05)
	click_p.play()


func type_key() -> void:
	type_p.volume_db = linear_to_db(maxf(0.22 * Settings.volume, 0.0001))
	type_p.pitch_scale = _rng.randf_range(0.85, 1.2)
	type_p.play()


## Menu ambience on or off; fades in _process.
func set_ambience(music: bool, sea: bool) -> void:
	music_on = music
	sea_on = sea


func _process(delta: float) -> void:
	var a := clampf(delta * 1.5, 0.0, 1.0)
	var mv := 0.55 * Settings.music * Settings.volume if music_on else 0.0
	var sv := 0.35 * Settings.volume if sea_on else 0.0
	music_p.volume_db = lerpf(music_p.volume_db, linear_to_db(maxf(mv, 0.0001)), a)
	sea_p.volume_db = lerpf(sea_p.volume_db, linear_to_db(maxf(sv, 0.0001)), a)


# ------------------------------------------------------------------ synthesis
func _wav(s: PackedFloat32Array, loop := false, rate := RATE) -> AudioStreamWAV:
	var peak := 0.0001
	for v in s:
		peak = maxf(peak, absf(v))
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	for i in s.size():
		bytes.encode_s16(i * 2, int(clampf(s[i] / peak * 0.9, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = s.size()
	return w


func _click() -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(0.06 * RATE))
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * 2200.0 * t) * 0.6 + _rng.randf_range(-1.0, 1.0) * 0.4) * exp(-t * 90.0)
	return b


## One teleprinter keystroke: a hard clack and a short rattle.
func _type() -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(0.05 * RATE))
	var y := 0.0
	for i in b.size():
		var t := float(i) / RATE
		y += 0.35 * (_rng.randf_range(-1.0, 1.0) - y)
		b[i] = (y + sin(TAU * 900.0 * t) * 0.4) * exp(-t * 120.0)
	return b


func _sea() -> PackedFloat32Array:
	var n := int(8.0 * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var y := 0.0
	var y2 := 0.0
	for i in n:
		var t := float(i) / RATE
		y += 0.03 * (_rng.randf_range(-1.0, 1.0) - y)
		y2 += 0.004 * (_rng.randf_range(-1.0, 1.0) - y2)
		# Swells breaking every few seconds.
		var swell := 0.55 + 0.45 * sin(TAU * t / 8.0 * 2.0) * sin(TAU * t / 8.0 * 3.0)
		b[i] = y * swell + y2 * 3.0
	# Crossfade the ends so the loop is seamless.
	var fade := int(0.5 * RATE)
	for i in fade:
		var k := float(i) / fade
		b[i] = b[i] * k + b[n - fade + i] * (1.0 - k)
	return b.slice(0, n - fade)


## A slow, cold ambient score: low string-like drones moving through
## D minor, B-flat, G minor and A, with a distant bell. 24 seconds.
func _score() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var secs := 24.0
	var n := int(secs * MUSIC_RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var chords := [[73.42, 110.0, 146.83, 174.61], [58.27, 116.54, 146.83, 174.61], [49.0, 98.0, 146.83, 233.08], [55.0, 110.0, 138.59, 164.81]]
	var seg := secs / chords.size()
	var lp := 0.0
	for i in n:
		var t := float(i) / MUSIC_RATE
		var ci := int(t / seg) % chords.size()
		var local := fmod(t, seg)
		var xf := clampf((local - (seg - 1.5)) / 1.5, 0.0, 1.0)
		var v := _chord(chords[ci], t) * (1.0 - xf)
		if xf > 0.0:
			v += _chord(chords[(ci + 1) % chords.size()], t) * xf
		v *= 0.12 * (0.75 + 0.25 * sin(TAU * t / 6.0))
		v += sin(TAU * 587.33 * local) * exp(-local * 0.9) * 0.08 + sin(TAU * 880.0 * local) * exp(-local * 1.4) * 0.04
		v += rng.randf_range(-1.0, 1.0) * 0.004
		lp += 0.3 * (v - lp)
		b[i] = lp
	var fade := int(1.0 * MUSIC_RATE)
	for i in fade:
		var k := float(i) / fade
		b[i] = b[i] * k + b[n - fade + i] * (1.0 - k)
	return b.slice(0, n - fade)


func _chord(c: Array, t: float) -> float:
	var v := 0.0
	for f: float in c:
		v += sin(TAU * f * 0.997 * t) + sin(TAU * f * 1.003 * t) + 0.35 * sin(TAU * f * 2.0 * t)
	return v
