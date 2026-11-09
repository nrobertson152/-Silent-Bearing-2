extends Node
## Every sound is synthesised at startup, so the game ships no audio files.
## Distant sounds are delayed by their travel time through the air.

const RATE := 22050
const SOUND := 340.0
const Settings := preload("res://scripts/core/settings.gd")

var streams := {}
var pool: Array = []
var loops := {}
var delayed: Array = []
var t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 11
	_build()
	for i in 24:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	for name in ["engine", "sea", "wind", "hum", "ciws_loop"]:
		var p := AudioStreamPlayer.new()
		p.stream = streams[name]
		p.volume_db = -80.0
		add_child(p)
		p.play()
		loops[name] = p


func play(name: String, vol := 1.0, delay := 0.0, pitch := 1.0) -> void:
	if not streams.has(name) or vol <= 0.01:
		return
	if delay > 0.05:
		delayed.append([t + delay, name, vol, pitch])
		return
	for p in pool:
		if not p.playing:
			p.stream = streams[name]
			p.volume_db = linear_to_db(clampf(vol * Settings.volume, 0.0, 2.0))
			p.pitch_scale = pitch * _rng.randf_range(0.95, 1.05)
			p.play()
			return


func set_loop(name: String, vol: float, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = loops.get(name)
	if p == null:
		return
	var target := linear_to_db(maxf(vol * Settings.volume, 0.0001))
	p.volume_db = lerpf(p.volume_db, target, 0.08)
	p.pitch_scale = maxf(pitch, 0.05)


func _process(delta: float) -> void:
	t += delta
	if delayed.is_empty():
		return
	var keep := []
	for d in delayed:
		if t >= d[0]:
			play(d[1], d[2], 0.0, d[3])
		else:
			keep.append(d)
	delayed = keep


## Sound for a simulation event heard from the camera position.
func event(ev: Dictionary, ear: Vector3, player) -> void:
	var pos: Vector3 = ev.get("pos", ear) if ev.get("pos", null) is Vector3 else ear
	var d := ear.distance_to(pos)
	var delay := d / SOUND
	var att := clampf(1.0 / (1.0 + d / 900.0), 0.02, 1.0)
	match String(ev["t"]):
		"fire":
			var cal := float(ev.get("cal", 100))
			var nm := "gun_big" if cal >= 300.0 else ("gun_med" if cal >= 140.0 else "gun_small")
			play(nm, att * (1.6 if cal >= 300.0 else 1.0), delay, 1.0)
		"launch", "sam_launch", "air_launch":
			play("launch", att * 1.2, delay)
		"hit":
			var u = ev["unit"]
			play("explosion" if d < 4000.0 else "rumble", maxf(att, 0.15) * (1.4 if u == player else 1.0), delay if u != player else 0.0)
			if u == player:
				play("alarm", 0.5, 0.4)
		"splash":
			play("splash", att * clampf(float(ev.get("size", 1.0)), 0.3, 2.0), delay)
		"intercept", "air_kill":
			play("rumble", att * 0.8, delay, 1.4)
		"ciws":
			play("ciws", att, delay)
		"magazine", "nuke":
			play("rumble", 1.5, delay, 0.6)
			play("explosion", 1.2, delay, 0.7)
		"sinking":
			play("rumble", 0.6, delay, 0.5)
		"radio":
			play("radio", 0.35)
		"contact", "air_contact":
			play("beep", 0.4)
		"objective":
			play("beep", 0.6, 0.0, 1.3)
		"depth_bomb":
			play("rumble", att * 1.2, delay, 0.7)
		"torpedo_launch":
			play("launch", att * 0.5, delay, 0.6)
		"ground_hit":
			play("rumble", att, delay, 0.9)


func update_ship(p, dt: float, mode: String, ear: Vector3) -> void:
	if p == null:
		return
	var out := absf(p.plant.output())
	var inside := mode == "bridge"
	set_loop("engine", (0.04 + out * 0.22) * (0.6 if inside else 0.9), 0.55 + out * 0.6)
	var sea := 0.12 + absf(p.speed) / maxf(p.max_speed, 1.0) * 0.35
	set_loop("sea", sea * (0.35 if inside else 1.0), 1.0)
	set_loop("wind", 0.18 if not inside else 0.05, 1.0)
	set_loop("hum", 0.12 if inside else 0.0, 1.0)
	var ciws := false
	for m in p.mounts:
		if m.kind == "ciws" and p.w.t - m.last_shot < 0.2:
			ciws = true
	set_loop("ciws_loop", 0.7 if ciws else 0.0, 1.0)


# ------------------------------------------------------------------ synthesis
func _n() -> float:
	return _rng.randf() * 2.0 - 1.0


static func _alpha(fc: float) -> float:
	return 1.0 - exp(-TAU * fc / RATE)


func _wav(s: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var peak := 0.0001
	for v in s:
		peak = maxf(peak, absf(v))
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	var gain := 0.9 / peak
	for i in s.size():
		bytes.encode_s16(i * 2, int(clampf(s[i] * gain, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w


func _buf(secs: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(RATE * secs))
	return b


## Low-passed noise burst with a pitched thump and a crack at the start.
func _boom(secs: float, fc: float, decay: float, crack: float, thump: float, f0: float) -> PackedFloat32Array:
	var b := _buf(secs)
	var a := _alpha(fc)
	var y := 0.0
	var y2 := 0.0
	var ph := 0.0
	for i in b.size():
		var tt := float(i) / RATE
		var x := _n()
		y += a * (x - y)
		y2 += a * (y - y2)
		ph += TAU * (f0 + f0 * 0.8 * exp(-tt * 6.0)) / RATE
		b[i] = y2 * 6.0 * exp(-tt * decay) + sin(ph) * exp(-tt * 3.0) * thump + x * exp(-tt * 40.0) * crack
	return b


func _tone(secs: float, freqs: Array, decay: float, attack := 0.005) -> PackedFloat32Array:
	var b := _buf(secs)
	for i in b.size():
		var tt := float(i) / RATE
		var v := 0.0
		for k in freqs.size():
			v += sin(TAU * float(freqs[k]) * tt) / (k + 1.0)
		b[i] = v * minf(1.0, tt / attack) * exp(-tt * decay)
	return b


func _noise_loop(secs: float, fc: float, mod_f := 0.0, mod_d := 0.0) -> PackedFloat32Array:
	var b := _buf(secs)
	var a := _alpha(fc)
	var y := 0.0
	var y2 := 0.0
	for i in b.size():
		var tt := float(i) / RATE
		y += a * (_n() - y)
		y2 += a * (y - y2)
		b[i] = y2 * (1.0 - mod_d + mod_d * (0.5 + 0.5 * sin(TAU * mod_f * tt)))
	var fade := int(RATE * 0.2)
	for i in fade:
		var f := float(i) / fade
		b[i] = b[i] * f + b[b.size() - fade + i] * (1.0 - f)
	b.resize(b.size() - fade)
	return b


func _build() -> void:
	streams["gun_small"] = _wav(_boom(1.6, 900.0, 4.0, 0.9, 0.5, 70.0))
	streams["gun_med"] = _wav(_boom(2.4, 600.0, 2.6, 0.7, 0.9, 50.0))
	streams["gun_big"] = _wav(_boom(4.5, 300.0, 1.2, 0.5, 1.4, 32.0))
	streams["explosion"] = _wav(_boom(3.5, 700.0, 1.6, 0.8, 1.0, 40.0))
	streams["rumble"] = _wav(_boom(5.0, 180.0, 0.8, 0.05, 0.8, 28.0))
	# Missile launch: rising roar.
	var b := _buf(3.5)
	var a := _alpha(1200.0)
	var y := 0.0
	for i in b.size():
		var tt := float(i) / RATE
		y += a * (_n() - y)
		b[i] = y * minf(1.0, tt * 8.0) * exp(-maxf(tt - 0.8, 0.0) * 1.2) + _n() * 0.15 * exp(-tt * 4.0)
	streams["launch"] = _wav(b)
	# Splash: hiss with a fall.
	b = _buf(2.0)
	a = _alpha(2500.0)
	y = 0.0
	for i in b.size():
		var tt := float(i) / RATE
		y += a * (_n() - y)
		b[i] = y * minf(1.0, tt * 30.0) * exp(-tt * 2.2)
	streams["splash"] = _wav(b)
	# CIWS: very fast buzz.
	b = _buf(0.5)
	for i in b.size():
		var tt := float(i) / RATE
		b[i] = (sign(sin(TAU * 75.0 * tt)) * 0.5 + _n() * 0.5) * minf(1.0, tt * 40.0) * exp(-tt * 3.0)
	streams["ciws"] = _wav(b)
	var cl := _buf(1.0)
	for i in cl.size():
		var tt := float(i) / RATE
		cl[i] = (sign(sin(TAU * 75.0 * tt)) * 0.6 + _n() * 0.4)
	streams["ciws_loop"] = _wav(cl, true)
	# General quarters: the US "bong" gong repeated, or a Soviet alarm bell.
	b = _buf(4.0)
	for i in b.size():
		var tt := float(i) / RATE
		var ph := fmod(tt, 0.5)
		b[i] = (sin(TAU * 520.0 * ph) + 0.5 * sin(TAU * 1040.0 * ph) + 0.3 * sin(TAU * 790.0 * ph)) * exp(-ph * 9.0)
	streams["gq"] = _wav(b)
	streams["alarm"] = _wav(_tone(1.2, [880.0, 1760.0], 1.5))
	# Engine-order telegraph: double ding of the bell.
	b = _buf(1.4)
	for i in b.size():
		var tt := float(i) / RATE
		var v := 0.0
		for st in [0.0, 0.32]:
			if tt >= st:
				var q: float = tt - st
				v += (sin(TAU * 1680.0 * q) + 0.6 * sin(TAU * 2520.0 * q) + 0.3 * sin(TAU * 4100.0 * q)) * exp(-q * 7.0)
		b[i] = v + _n() * 0.05 * exp(-tt * 30.0)
	streams["telegraph"] = _wav(b)
	streams["bell"] = _wav(_tone(1.2, [1400.0, 2100.0, 3500.0], 5.0))
	streams["click"] = _wav(_boom(0.08, 4000.0, 60.0, 1.0, 0.0, 200.0))
	streams["beep"] = _wav(_tone(0.18, [1200.0], 8.0))
	# Ship's whistle: deep chord with vibrato.
	b = _buf(2.6)
	for i in b.size():
		var tt := float(i) / RATE
		var env := minf(1.0, tt * 6.0) * (1.0 if tt < 2.1 else maxf(0.0, 1.0 - (tt - 2.1) * 2.0))
		var vib := 1.0 + sin(TAU * 5.0 * tt) * 0.004
		b[i] = (sin(TAU * 110.0 * vib * tt) + 0.6 * sin(TAU * 165.0 * vib * tt) + 0.3 * sin(TAU * 220.0 * vib * tt)) * env
	streams["horn"] = _wav(b)
	# Radio squelch.
	b = _buf(0.35)
	a = _alpha(3000.0)
	y = 0.0
	for i in b.size():
		var tt := float(i) / RATE
		y += a * (_n() - y)
		b[i] = y * (1.0 if tt < 0.08 or tt > 0.27 else 0.2)
	streams["radio"] = _wav(b)
	b = _tone(2.2, [3500.0], 2.0)
	var dl := int(0.5 * RATE)
	for i in range(b.size() - 1, dl, -1):
		b[i] += b[i - dl] * 0.25
	streams["ping"] = _wav(b)
	# Loops.
	var eng := _buf(2.0)
	for i in eng.size():
		var tt := float(i) / RATE
		eng[i] = sin(TAU * 31.0 * tt) * 0.6 + sin(TAU * 62.0 * tt) * 0.3 + sin(TAU * 124.0 * tt) * 0.1 + _n() * 0.15
	streams["engine"] = _wav(eng, true)
	streams["sea"] = _wav(_noise_loop(6.0, 500.0, 0.17, 0.5), true)
	streams["wind"] = _wav(_noise_loop(6.0, 900.0, 0.09, 0.6), true)
	var hum := _buf(1.0)
	for i in hum.size():
		var tt := float(i) / RATE
		hum[i] = sin(TAU * 60.0 * tt) * 0.5 + sin(TAU * 120.0 * tt) * 0.3 + sin(TAU * 400.0 * tt) * 0.05 + _n() * 0.04
	streams["hum"] = _wav(hum, true)
