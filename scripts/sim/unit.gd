class_name SimUnit
extends RefCounted
## A ship or submarine: hull dynamics, steering gear, depth keeping, damage
## state (compartments, flooding, fires, modules) and its weapon mounts.
## Positions are world metres (Godot axes); heading in compass degrees.

const U := preload("res://scripts/util.gd")
const ShipData := preload("res://scripts/data/ships.gd")
const NCOMP := 12

var w
var uid := 0
var cls_id := ""
var cls := {}
var side := "us"
var navy := "us"
var name := ""
var tag := ""
var player := false
var is_sub := false
var pos := Vector3.ZERO
var heading := 0.0
var speed := 0.0
var yaw_rate := 0.0
var rudder := 0.0
var rudder_order := 0.0
var heel := 0.0
var pitch_deg := 0.0
var depth := 0.0
var depth_order := 0.0
var vspeed := 0.0
var plant: SimPlant
var L := 100.0
var B := 12.0
var T := 4.0
var disp := 4000.0
var max_speed := 15.0
var c_turn := 2.0
var rudder_rate := 2.5
var _kacc := 0.0
var course_order := -1.0
var autopilot := false
var helm_delay := 0.0
# damage
var hp := 1000.0
var hp_max := 1000.0
var flood := []
var flood_rate := []
var fire := []
var comp_cap := 100.0
var reserve := 1000.0
var list_deg := 0.0
var trim_deg := 0.0
var sinking := false
var sunk := false
var sink_t := 0.0
var destroyed := false
var modules := {}
var dc_teams := 2
var mag_comps := []
# weapons and sensors
var mounts := []
var target = null
var emcon := false
var radar_h := 20.0
var air_range := 0.0
var surf_range := 30000.0
var sonar := 0.0
var towed := 0.0
var fc_channels := 2
var noise := 1.0
var ai = null
var wake_t := 0.0
var last_hit_t := -100.0
var kills := 0
var score := 0
var surfaced := true
var crushed := false


func _init(world, class_id: String, team: String) -> void:
	w = world
	cls_id = class_id
	cls = ShipData.spec(class_id)
	side = team
	navy = cls.get("side", "us")
	name = cls.get("name", cls.get("class", class_id))
	is_sub = cls.get("type", "") == "submarine"
	L = cls["length"]
	B = cls["beam"]
	T = cls["draft"]
	disp = cls["disp"]
	max_speed = float(cls["speed"]) * U.KN
	c_turn = cls.get("turn", 2.0)
	rudder_rate = cls.get("rudder_rate", 2.5)
	plant = SimPlant.new(cls["plant"], "su" if navy == "su" else "us")
	var p_w: float = float(plant.shp) * 745.7 * 0.55
	var thrust := p_w / max_speed
	_kacc = thrust / (disp * 1000.0 * 1.08) / (max_speed * max_speed)
	var sens: Dictionary = cls.get("sensors", {})
	radar_h = sens.get("radar_h", 20.0)
	air_range = sens.get("air", 0.0)
	surf_range = sens.get("surf", 30000.0)
	sonar = sens.get("sonar", 0.0)
	towed = sens.get("towed", 0.0)
	fc_channels = sens.get("fc", 2)
	hp_max = 60.0 * pow(disp, 0.6)
	hp = hp_max
	reserve = disp * (0.42 if not is_sub else 0.14)
	comp_cap = disp * 0.11
	for i in NCOMP:
		flood.append(0.0)
		flood_rate.append(0.0)
		fire.append(0.0)
	dc_teams = clampi(int(disp / 2500.0) + 2, 2, 8)
	_modules()
	for wd in cls.get("weapons", []):
		var m := SimMount.new(self, wd)
		mounts.append(m)
		if m.group == "main" or m.kind == "vls" or m.group == "strike":
			var c := comp_of(m.x)
			if not mag_comps.has(c):
				mag_comps.append(c)
	if is_sub:
		surfaced = false


func _modules() -> void:
	var br: Dictionary = cls.get("bridge", {})
	var bx: float = br.get("x0", L * 0.3)
	modules["bridge"] = {"hp": 1.0, "x": bx + 4.0, "y": float(br.get("y", 10.0)), "r": 8.0}
	modules["engine"] = {"hp": 1.0, "x": L * 0.55, "y": -T * 0.4, "r": L * 0.16}
	modules["steering"] = {"hp": 1.0, "x": L * 0.95, "y": -T * 0.3, "r": L * 0.05}
	modules["radar"] = {"hp": 1.0, "x": bx + 14.0, "y": radar_h, "r": 9.0}
	modules["fc"] = {"hp": 1.0, "x": bx + 8.0, "y": float(br.get("y", 10.0)) + 4.0, "r": 10.0}
	if sonar > 0.0:
		modules["sonar"] = {"hp": 1.0, "x": L * 0.08, "y": -T, "r": L * 0.08}


# ------------------------------------------------------------------ helpers
func fwd() -> Vector3:
	return U.fwd(heading)


func vel() -> Vector3:
	return U.fwd(heading) * speed + Vector3(0, vspeed, 0)


## Station along the hull (m from bow) of a world point.
func station(p: Vector3) -> float:
	return L * 0.5 + (p - pos).dot(fwd())


## World point -> model space (bow -Z, starboard +X).
func to_local(p: Vector3) -> Vector3:
	var d := p - pos
	var f := fwd()
	var r := Vector3(-f.z, 0, f.x)
	return Vector3(d.dot(r), d.y, -d.dot(f))


func to_world(lp: Vector3) -> Vector3:
	var f := fwd()
	var r := Vector3(-f.z, 0, f.x)
	return pos + r * lp.x + Vector3.UP * lp.y - f * lp.z


func comp_of(x: float) -> int:
	return clampi(int(x / L * NCOMP), 0, NCOMP - 1)


func alive() -> bool:
	return not sunk and not sinking


func deck_h() -> float:
	return 0.0 if is_sub and not surfaced else float(cls.get("hull", {}).get("fb", [[0, 6.0]])[0][1]) * 0.8


## Height of the tallest structure, for radar horizon and visual detection.
func mast_h() -> float:
	if is_sub:
		return 0.0 if depth > 18.0 else (6.0 if depth < 1.0 else 2.0)
	return radar_h + 4.0


func flooded() -> float:
	var f := 0.0
	for v in flood:
		f += v
	return f


func fires() -> float:
	var f := 0.0
	for v in fire:
		f += v
	return f


func mod_hp(k: String) -> float:
	return modules.get(k, {}).get("hp", 1.0)


func health() -> float:
	return clampf(minf(hp / hp_max, 1.0 - flooded() / reserve), 0.0, 1.0)


# ------------------------------------------------------------------ physics
func update(dt: float) -> void:
	if sunk:
		return
	plant.update(dt)
	if helm_delay > 0.0:
		helm_delay -= dt
	if autopilot and course_order >= 0.0:
		var err := U.adiff(heading, course_order)
		rudder_order = clampf(err * 1.6 - yaw_rate * 4.0, -30.0, 30.0)
	var steer_ok := mod_hp("steering")
	var rr := rudder_rate * (0.3 + 0.7 * steer_ok)
	if steer_ok > 0.05:
		rudder = move_toward(rudder, clampf(rudder_order, -35.0, 35.0), rr * dt)
	var eng := clampf(0.15 + 0.85 * mod_hp("engine"), 0.0, 1.0)
	var out := plant.output() * eng
	var vmax := max_speed
	if is_sub and depth < 12.0:
		vmax = float(cls.get("surf_speed", 15.0)) * U.KN
	var flood_frac := flooded() / reserve
	vmax *= clampf(1.0 - flood_frac * 0.7, 0.2, 1.0)
	if sinking:
		vmax *= maxf(0.0, 1.0 - sink_t / 30.0)
	var u_cmd := out * vmax
	var acc := _kacc * (u_cmd * absf(u_cmd) - speed * absf(speed)) * (max_speed * max_speed) / maxf(vmax * vmax, 1.0)
	acc -= absf(deg_to_rad(yaw_rate)) * speed * 0.55
	speed += acc * dt
	# Steering: Nomoto first-order yaw response. Prop wash gives some steerage when slow.
	var u_eff := absf(speed) + 0.35 * absf(out) * max_speed
	var r_ss := rad_to_deg(u_eff * deg_to_rad(rudder) / (L * c_turn))
	if speed < -0.3:
		r_ss = -r_ss * 0.45
	r_ss += plant.torque_bias() * 0.35
	var tn := clampf(1.1 * L / maxf(absf(speed), 2.0), 4.0, 45.0)
	yaw_rate += (r_ss - yaw_rate) * clampf(dt / tn, 0.0, 1.0)
	heading = U.wrap360(heading + yaw_rate * dt)
	var heel_t := clampf(rad_to_deg(speed * deg_to_rad(yaw_rate) / U.G) * 2.2, -12.0, 12.0) + list_deg
	heel += (heel_t - heel) * clampf(dt * 0.6, 0.0, 1.0)
	pos += U.fwd(heading) * speed * dt
	if is_sub:
		_depth(dt)
	_damage_tick(dt)


func _depth(dt: float) -> void:
	var td := depth_order
	var planes := clampf(absf(speed) / (8.0 * U.KN), 0.08, 1.0)
	var max_v := 1.6 * planes + 0.15
	var dv := clampf((td - depth) * 0.08, -max_v, max_v)
	vspeed = move_toward(vspeed, -dv, 0.12 * dt)
	depth = maxf(0.0, depth - vspeed * dt)
	pos.y = -depth
	pitch_deg = clampf(rad_to_deg(atan2(vspeed, maxf(absf(speed), 1.0))), -20.0, 20.0)
	surfaced = depth < 2.0
	var crush: float = cls.get("crush_depth", 450.0)
	var test: float = cls.get("test_depth", 300.0)
	if depth > test:
		var over := (depth - test) / maxf(crush - test, 1.0)
		hp -= hp_max * 0.004 * over * over * dt * 10.0
		if depth > crush and not crushed:
			crushed = true
			hp = 0.0


func _damage_tick(dt: float) -> void:
	var pump := disp * 0.0006
	var active := 0
	for i in NCOMP:
		if flood_rate[i] > 0.0 or flood[i] > 0.0:
			var inflow: float = flood_rate[i]
			flood[i] = clampf(flood[i] + (inflow - pump / NCOMP * 3.0) * dt, 0.0, comp_cap)
			if flood_rate[i] > 0.0 and active < dc_teams:
				flood_rate[i] = maxf(0.0, flood_rate[i] - disp * 0.00002 * dt)
				active += 1
			if flood[i] >= comp_cap * 0.98 and flood_rate[i] > 0.0:
				var j := i + (1 if w.rng.randf() < 0.5 else -1)
				if j >= 0 and j < NCOMP and w.rng.randf() < 0.004 * dt * 60.0:
					flood_rate[j] += flood_rate[i] * 0.5
		if fire[i] > 0.0:
			hp -= fire[i] * hp_max * 0.0009 * dt
			if active < dc_teams:
				fire[i] = maxf(0.0, fire[i] - 0.012 * dt)
				active += 1
			else:
				fire[i] = minf(1.0, fire[i] + 0.006 * dt)
			if fire[i] > 0.6 and w.rng.randf() < 0.002 * dt * 60.0:
				var j := clampi(i + (1 if w.rng.randf() < 0.5 else -1), 0, NCOMP - 1)
				fire[j] = maxf(fire[j], 0.15)
			if mag_comps.has(i) and fire[i] > 0.85 and w.rng.randf() < 0.0008 * dt * 60.0:
				w.magazine_explosion(self, i)
	# List and trim from uneven flooding.
	var fwd_f := 0.0
	var aft_f := 0.0
	for i in NCOMP:
		if i < NCOMP / 2:
			fwd_f += flood[i]
		else:
			aft_f += flood[i]
	trim_deg = clampf((aft_f - fwd_f) / maxf(disp, 1.0) * 30.0, -15.0, 15.0)
	var ff := flooded() / reserve
	if (ff >= 1.0 or hp <= 0.0) and not sinking:
		sinking = true
		sink_t = 0.0
		w.on_sinking(self)
	if hp <= hp_max * 0.15 and not destroyed:
		destroyed = true
	if sinking:
		sink_t += dt
		list_deg = move_toward(list_deg, 18.0 * signf(list_deg + 0.01), 0.5 * dt)
		if sink_t > 120.0:
			sunk = true
			w.on_sunk(self)


## Steer to a course using the autopilot (helmsman steering an ordered course).
func steer(course: float) -> void:
	course_order = U.wrap360(course)
	autopilot = true


func set_rudder(deg: float) -> void:
	autopilot = false
	rudder_order = clampf(deg, -35.0, 35.0)
