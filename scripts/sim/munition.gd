class_name SimMunition
extends RefCounted
## Shells, missiles (anti-ship, land attack, surface-to-air), torpedoes and
## anti-submarine rockets in flight.

const U := preload("res://scripts/util.gd")
const Weapons := preload("res://scripts/data/weapons.gd")

var w
var mid := ""
var md := {}
var kind := "shell"
var role := ""
var side := "us"
var shooter = null
var target = null
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var t := 0.0
var alive := true
var drag_c := 0.0
var speed := 0.0
var alt := 10.0
var phase := "boost"
var range_left := 0.0
var seeker := false
var aim := Vector3.ZERO
var aim_set := false
var depth := 0.0
var nuke := 0.0
var uid := 0
var weave := 0.0
var engaged := 0
var player_fired := false
var max_t := 120.0
var run_depth := 6.0


func _init(world, munition_id: String, team: String, from, p: Vector3, v: Vector3) -> void:
	w = world
	mid = munition_id
	md = Weapons.mun(munition_id)
	kind = md.get("kind", "shell")
	role = md.get("role", "")
	side = team
	shooter = from
	pos = p
	vel = v
	nuke = md.get("nuke", 0.0)
	speed = v.length()
	range_left = md.get("range", 10000.0)
	weave = randf() * TAU
	if kind == "shell":
		drag_c = SimBallistics.drag(mid)
		max_t = 200.0
	elif kind == "missile":
		alt = md.get("alt", 10.0)
		max_t = float(md.get("range", 10000.0)) / maxf(float(md.get("speed", 300.0)), 50.0) * 1.25 + 10.0
	elif kind == "torpedo":
		speed = md.get("speed", 20.0)
		max_t = float(md.get("range", 10000.0)) / speed
	elif kind == "rocket":
		max_t = 90.0


func update(dt: float) -> void:
	if not alive:
		return
	t += dt
	if t > max_t:
		_expire()
		return
	match kind:
		"shell":
			_shell(dt)
		"missile":
			if role == "air":
				_sam(dt)
			else:
				_missile(dt)
		"torpedo":
			_torpedo(dt)
		"rocket":
			_rocket(dt)


func _expire() -> void:
	alive = false
	if kind == "missile" and role != "air" and pos.y < 200.0:
		w.emit({"t": "splash", "pos": Vector3(pos.x, 0, pos.z), "size": 3.0})


# ------------------------------------------------------------------ shells
func _shell(dt: float) -> void:
	var steps := maxi(1, int(ceil(dt / 0.05)))
	var h := dt / steps
	for i in steps:
		var a := SimBallistics.accel(vel, pos.y, drag_c)
		var vm := vel + a * h * 0.5
		var np := pos + vm * h
		vel += SimBallistics.accel(vm, pos.y, drag_c) * h
		var hit = w.shell_collide(self, pos, np)
		if hit != null:
			alive = false
			return
		pos = np
		if pos.y < 0.0:
			alive = false
			w.shell_splash(self, pos)
			return


# ------------------------------------------------------------------ anti-ship / strike missiles
func _missile(dt: float) -> void:
	var spd: float = md.get("speed", 280.0)
	var term: String = md.get("term", "skim")
	var tgt_pos := aim
	var tgt_vel := Vector3.ZERO
	if target != null and is_instance_valid_unit(target):
		tgt_pos = target.pos
		tgt_vel = target.vel()
	elif role == "ship" and not aim_set:
		target = w.find_ship_in_cone(self, 60.0, 60000.0)
		if target != null:
			tgt_pos = target.pos
	var flat := U.flat_dist(pos, tgt_pos)
	var tti := flat / maxf(spd, 1.0)
	var lead := tgt_pos + tgt_vel * minf(tti, 60.0)
	# Seeker: switch on near the target and lock whatever ship is in the cone.
	var seek_r: float = md.get("seeker", 20000.0)
	if role == "ship" and not seeker and flat < seek_r:
		seeker = true
		var lock = w.find_ship_in_cone(self, 22.0, seek_r * 1.3)
		if lock != null:
			target = lock
		w.emit({"t": "seeker", "mun": self})
	var cruise: float = md.get("alt", 10.0)
	var want_alt := cruise
	if phase == "boost":
		want_alt = maxf(cruise, 30.0)
		if t > 2.5:
			phase = "cruise"
	match term:
		"popup":
			if flat < 6000.0 and flat > 2200.0:
				want_alt = 320.0
			elif flat <= 2200.0:
				want_alt = 0.0
		"dive":
			if flat < cruise * 1.2 + 4000.0:
				want_alt = 0.0
		"weave":
			want_alt = 8.0 if flat < 15000.0 else cruise
		_:
			want_alt = cruise if flat > 10000.0 else 4.0
	if role == "land" and flat < 1500.0:
		want_alt = 0.0
	if role == "sub":
		_asw_carrier(dt, flat, tgt_pos)
		return
	var d3 := lead - pos
	var hd := Vector2(d3.x, d3.z).normalized()
	if term == "weave" and flat < 12000.0:
		var off := sin(t * 2.2 + weave) * 0.35
		hd = hd.rotated(off)
	var cur := Vector2(vel.x, vel.z)
	if cur.length() < 1.0:
		cur = hd
	var turn := (9.81 * (12.0 if spd > 500.0 else 9.0)) / maxf(spd, 50.0) * dt
	var ang := cur.angle_to(hd)
	cur = cur.normalized().rotated(clampf(ang, -turn, turn))
	var vy := clampf((want_alt - pos.y) * 0.8, -spd * 0.6, spd * 0.5)
	if term == "dive" and want_alt == 0.0:
		vy = -maxf(pos.y, 50.0) / maxf(flat / spd, 0.5)
	var hs := sqrt(maxf(spd * spd - vy * vy, spd * spd * 0.25))
	vel = Vector3(cur.x * hs, vy, cur.y * hs)
	pos += vel * dt
	range_left -= spd * dt
	if range_left <= 0.0:
		_expire()
		return
	if role == "land":
		if flat < 60.0 and pos.y < 40.0:
			alive = false
			w.land_impact(self, pos)
		return
	if target != null and is_instance_valid_unit(target):
		if w.missile_contact(self, target):
			alive = false
			return
	if pos.y < -0.5:
		_expire()


## ASROC / Metel: fly to the target area, drop a homing torpedo.
func _asw_carrier(dt: float, flat: float, tgt_pos: Vector3) -> void:
	var spd: float = md.get("speed", 280.0)
	var d := (tgt_pos - pos)
	var hd := Vector2(d.x, d.z).normalized()
	vel = Vector3(hd.x * spd, clampf((float(md.get("alt", 300.0)) - pos.y) * 0.5, -60, 60), hd.y * spd)
	pos += vel * dt
	if flat < 600.0 or range_left <= 0.0:
		alive = false
		var pl: String = md.get("payload", "mk46")
		var tm = w.spawn_munition(pl, side, shooter, Vector3(pos.x, -5.0, pos.z), Vector3.ZERO)
		tm.target = target
		tm.run_depth = (-target.pos.y if target != null and is_instance_valid_unit(target) else 60.0)
		w.emit({"t": "splash", "pos": Vector3(pos.x, 0, pos.z), "size": 1.5})
	range_left -= spd * dt


# ------------------------------------------------------------------ surface-to-air
func _sam(dt: float) -> void:
	var spd: float = md.get("speed", 800.0)
	if target == null or not w.target_alive(target):
		if t > 3.0:
			alive = false
		pos += vel * dt
		return
	var tp: Vector3 = target.pos
	var tv: Vector3 = target.vel if target is SimMunition or target is SimAir else Vector3.ZERO
	var tti := U.intercept_time(tp - pos, tv, spd)
	var aimp := tp + tv * (tti if tti > 0.0 else 0.0)
	var want := (aimp - pos).normalized() * spd
	var turn := 9.81 * 30.0 / spd * dt
	var cur := vel.normalized() if vel.length() > 1.0 else want.normalized()
	var ang := cur.angle_to(want.normalized())
	if ang > 1e-4:
		cur = cur.slerp(want.normalized(), clampf(turn / ang, 0.0, 1.0))
	vel = cur * spd
	var before := pos.distance_to(tp)
	pos += vel * dt
	var after := pos.distance_to(target.pos)
	if after < 25.0 or (after > before and before < 60.0):
		alive = false
		w.sam_result(self, target)


# ------------------------------------------------------------------ torpedoes and rockets
func _torpedo(dt: float) -> void:
	var spd: float = md.get("speed", 20.0)
	var guid: String = md.get("guidance", "active")
	var seek_r: float = md.get("seeker", 1500.0)
	var tgt_ok: bool = target != null and is_instance_valid_unit(target)
	var dir := Vector2(vel.x, vel.z)
	if dir.length() < 0.1:
		dir = Vector2(0, -1)
	dir = dir.normalized()
	var want_depth := run_depth
	if tgt_ok:
		var tp: Vector3 = target.pos
		var dist := pos.distance_to(tp)
		var rel := Vector2(tp.x - pos.x, tp.z - pos.z)
		var homing := dist < seek_r and absf(dir.angle_to(rel.normalized())) < deg_to_rad(50.0)
		if guid == "wire" and t < 600.0:
			homing = true
		if guid == "wake" and dist < seek_r * 1.5:
			homing = true
		if homing or t < 2.0:
			var lead = tp + target.vel() * clampf(dist / spd, 0.0, 30.0) * 0.6
			var want := Vector2(lead.x - pos.x, lead.z - pos.z).normalized()
			var turn := deg_to_rad(12.0) * dt
			dir = dir.rotated(clampf(dir.angle_to(want), -turn, turn))
			want_depth = maxf(2.0, -tp.y + (4.0 if not target.is_sub else 0.0))
		else:
			dir = dir.rotated(sin(t * 0.4) * deg_to_rad(6.0) * dt)
		if dist < maxf(target.B * 0.6, 8.0) + 4.0:
			alive = false
			w.torpedo_hit(self, target)
			return
	depth = move_toward(depth, want_depth, 3.0 * dt)
	vel = Vector3(dir.x * spd, 0.0, dir.y * spd)
	pos += vel * dt
	pos.y = -depth


func _rocket(dt: float) -> void:
	if pos.y > 0.0 or vel.y > 0.0:
		vel += Vector3(0, -9.81, 0) * dt
		pos += vel * dt
		if pos.y <= 0.0:
			w.emit({"t": "splash", "pos": Vector3(pos.x, 0, pos.z), "size": 1.0})
			vel = Vector3(0, -float(md.get("sink", 11.5)), 0)
			pos.y = -0.1
		return
	pos += vel * dt
	var hit = w.depth_charge_check(self)
	if hit != null or (aim_set and pos.y <= aim.y) or pos.y < -400.0:
		alive = false
		w.depth_charge_explode(self)


func is_instance_valid_unit(u) -> bool:
	return u != null and (u.alive() if u is SimUnit else (u.alive if (u is SimAir) else false))
