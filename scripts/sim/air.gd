class_name SimAir
extends RefCounted
## An aircraft: bomber raids that launch missiles from range, fighters flying
## combat air patrol, maritime patrol aircraft and helicopters hunting subs.

const U := preload("res://scripts/util.gd")
const AirData := preload("res://scripts/data/aircraft.gd")

var w
var uid := 0
var type := ""
var ad := {}
var side := "us"
var role := "bomber"
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var heading := 0.0
var speed := 200.0
var alt := 1000.0
var state := "ingress"
var target = null
var group := ""
var weapons := 0
var aam := 0
var alive := true
var home := Vector3.ZERO
var orbit_c := Vector3.ZERO
var tag := ""
var fire_t := 0.0
var bank := 0.0
var friendly_callsign := ""
var engaged := 0


func _init(world, aircraft: String, team: String, p: Vector3, hdg: float) -> void:
	w = world
	type = aircraft
	ad = AirData.spec(aircraft)
	side = team
	role = ad.get("role", "bomber")
	pos = p
	heading = hdg
	speed = ad.get("speed", 200.0)
	alt = ad.get("alt", 1000.0)
	pos.y = alt
	weapons = ad.get("n", 0)
	aam = ad.get("aam", 0)
	home = p
	orbit_c = p
	state = {"bomber": "ingress", "fighter": "cap", "patrol": "patrol", "helo": "patrol", "recon": "ingress"}.get(role, "ingress")


func update(dt: float) -> void:
	if not alive:
		return
	var want_h := heading
	var want_alt: float = ad.get("alt", 1000.0)
	match state:
		"ingress":
			var tp := _target_pos()
			want_h = U.brg(pos, tp)
			var d := U.flat_dist(pos, tp)
			if role == "bomber":
				if d < float(ad.get("launch", 100000.0)) and weapons > 0:
					state = "attack"
				if float(ad.get("alt", 0.0)) < 1000.0 and d < 160000.0:
					want_alt = 60.0
			elif role == "recon" and d < 60000.0:
				state = "orbit"
				orbit_c = tp
		"attack":
			want_h = U.brg(pos, _target_pos())
			fire_t -= dt
			if fire_t <= 0.0 and weapons > 0:
				w.air_launch(self)
				weapons -= 1
				fire_t = 2.0
			if weapons <= 0:
				state = "egress"
		"egress":
			want_h = U.brg(pos, home) if U.flat_dist(pos, home) > 1000.0 else heading
			if U.flat_dist(pos, w.focus()) > 330000.0 or U.flat_dist(pos, home) < 2000.0:
				alive = false
		"cap", "orbit":
			var to_c := U.flat_dist(pos, orbit_c)
			want_h = U.brg(pos, orbit_c) + (70.0 if to_c < 15000.0 else 0.0)
			if role == "fighter" and aam > 0:
				var foe = w.nearest_air(self, 160000.0)
				if foe != null:
					target = foe
					state = "intercept"
		"intercept":
			if target == null or not target.alive:
				state = "cap" if aam > 0 else "egress"
				target = null
			else:
				want_h = U.brg(pos, target.pos)
				want_alt = target.pos.y
				fire_t -= dt
				if U.flat_dist(pos, target.pos) < 45000.0 and fire_t <= 0.0 and aam > 0:
					aam -= 1
					fire_t = 8.0
					w.aam_shot(self, target)
		"patrol":
			var sub = w.nearest_enemy_sub(self, 9000.0 if role == "helo" else 6000.0)
			if sub != null and weapons > 0:
				want_h = U.brg(pos, sub.pos)
				want_alt = 120.0
				if U.flat_dist(pos, sub.pos) < float(ad.get("launch", 1500.0)):
					fire_t -= dt
					if fire_t <= 0.0:
						w.air_drop_torpedo(self, sub)
						weapons -= 1
						fire_t = 25.0
			else:
				var to_c := U.flat_dist(pos, orbit_c)
				want_h = U.brg(pos, orbit_c) + (80.0 if to_c < 6000.0 else 0.0)
			if weapons <= 0:
				state = "egress"
	var turn: float = ad.get("turn", 3.0)
	var dh := clampf(U.adiff(heading, want_h), -turn * dt, turn * dt)
	heading = U.wrap360(heading + dh)
	bank = lerpf(bank, clampf(dh / maxf(dt, 1e-4) * 8.0, -60.0, 60.0), clampf(dt * 2.0, 0.0, 1.0))
	alt = move_toward(alt, want_alt, 40.0 * dt)
	vel = U.fwd(heading) * speed
	pos += vel * dt
	pos.y = alt


func _target_pos() -> Vector3:
	if target is SimUnit and target.alive():
		return target.pos
	var t = w.nearest_enemy_ship(side, pos, 600000.0)
	if t != null:
		target = t
		return t.pos
	return w.focus()


func name() -> String:
	return ad.get("name", type)
