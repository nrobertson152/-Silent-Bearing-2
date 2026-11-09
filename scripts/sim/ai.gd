class_name SimAI
extends RefCounted
## Captain for computer-controlled ships and submarines.
## Modes: patrol (waypoints), convoy (route at set speed), escort (station on a
## lead ship), engage, evade, flee, hold, bombard.

const U := preload("res://scripts/util.gd")
const Weapons := preload("res://scripts/data/weapons.gd")

var u
var w
var mode := "patrol"
var base_mode := "patrol"
var waypoints := []
var wp_i := 0
var cruise := 0.55
var lead = null
var offset := Vector3.ZERO
var target = null
var think := 0.0
var shots := {}
var fc_q := {}
var aggression := 1.0
var evade_t := 0.0
var zig := 0.0
var salvo_t := 0.0
var hold_fire := false
var torp_t := 0.0
var detect_r := 60000.0


func _init(unit, world, m := "patrol") -> void:
	u = unit
	w = world
	mode = m
	base_mode = m
	think = world.rng.randf() * 0.5


func update(dt: float) -> void:
	if not u.alive():
		return
	think -= dt
	_track_solutions(dt)
	if think > 0.0:
		return
	think = 0.4
	_pick_target()
	_threats()
	if u.health() < 0.3 and mode != "flee" and base_mode != "convoy":
		mode = "flee"
	match mode:
		"patrol":
			_follow_route()
			if target != null:
				mode = "engage"
		"convoy":
			_follow_route()
		"escort":
			_escort()
			if target != null and U.flat_dist(u.pos, target.pos) < 45000.0:
				mode = "engage"
		"hold":
			u.plant.order_fraction(0.0)
		"engage":
			if target == null:
				mode = base_mode
			else:
				_engage()
		"evade":
			evade_t -= 0.4
			if evade_t <= 0.0:
				mode = "engage" if target != null else base_mode
		"flee":
			var foe = target if target != null else w.nearest_enemy_ship(u.side, u.pos, 100000.0)
			if foe != null:
				u.steer(U.brg(foe.pos, u.pos))
			u.plant.order_fraction(1.0)
			if u.is_sub:
				u.depth_order = minf(float(u.cls.get("test_depth", 300.0)) * 0.8, 250.0)
	if not hold_fire:
		_weapons()


func _follow_route() -> void:
	if waypoints.is_empty():
		u.plant.order_fraction(cruise)
		return
	var wp: Vector3 = waypoints[wp_i % waypoints.size()]
	if U.flat_dist(u.pos, wp) < maxf(u.L * 2.0, 600.0):
		wp_i += 1
		if wp_i >= waypoints.size() and base_mode == "convoy":
			wp_i = waypoints.size() - 1
	wp = waypoints[wp_i % waypoints.size()]
	var c := U.brg(u.pos, wp)
	if base_mode == "convoy" and zig > 0.0:
		c += sin(w.t / 240.0 + u.uid) * zig
	u.steer(c)
	u.plant.order_fraction(cruise)
	if u.is_sub:
		u.depth_order = 60.0


func _escort() -> void:
	if lead == null or not lead.alive():
		mode = "patrol"
		base_mode = "patrol"
		return
	var f: Vector3 = lead.fwd()
	var r := Vector3(-f.z, 0, f.x)
	var station: Vector3 = lead.pos + r * offset.x - f * offset.z
	var d := U.flat_dist(u.pos, station)
	var c := U.brg(u.pos, station)
	if d < 400.0:
		c = lead.heading
	u.steer(c)
	var lead_frac: float = lead.speed / maxf(u.max_speed, 1.0)
	u.plant.order_fraction(clampf(lead_frac + d / 4000.0, 0.15, 1.0))


func _pick_target() -> void:
	if target != null and (not target.alive() or not w.known_to(u.side, target)):
		target = null
	if target != null and w.rng.randf() > 0.08:
		return
	var best = null
	var bd := detect_r if not u.is_sub else 40000.0
	for e in w.units:
		if e.side == u.side or not e.alive() or e.side == "neutral":
			continue
		if not w.known_to(u.side, e):
			continue
		var d := U.flat_dist(u.pos, e.pos)
		if e.player:
			d *= 0.85
		if e.navy == "merchant" and u.navy != "merchant":
			# Submarines go for the cargo; warships deal with the escorts first.
			d *= 0.6 if u.is_sub else 1.15
		if d < bd:
			bd = d
			best = e
	if best != null:
		target = best


## Turn away from incoming torpedoes and missiles.
func _threats() -> void:
	for m in w.muns:
		if m.side == u.side or not m.alive:
			continue
		if m.target == u and (m.kind == "torpedo" or (m.kind == "missile" and m.role == "ship")):
			var d = u.pos.distance_to(m.pos)
			if (m.kind == "torpedo" and d < 6000.0) or (m.kind == "missile" and d < 25000.0):
				if mode != "evade":
					var away := U.brg(m.pos, u.pos)
					var beam := U.wrap360(U.brg(u.pos, m.pos) + (90.0 if U.adiff(u.heading, U.brg(u.pos, m.pos)) < 0.0 else -90.0))
					u.steer(away if m.kind == "torpedo" else beam)
					u.plant.order_fraction(1.0)
					if u.is_sub:
						u.depth_order = clampf(u.depth + 120.0, 60.0, float(u.cls.get("test_depth", 300.0)) * 0.85)
						w.sub_decoy(u)
					evade_t = 40.0 if m.kind == "torpedo" else 25.0
					mode = "evade"
				return


func _engage() -> void:
	var tp: Vector3 = target.pos
	var d := U.flat_dist(u.pos, tp)
	var brg := U.brg(u.pos, tp)
	if u.is_sub:
		# Close submerged and quiet, fire from inside 12 km, then clear the datum.
		u.depth_order = 90.0 if not target.is_sub else clampf(-tp.y, 60.0, 250.0)
		if d > 14000.0:
			u.steer(brg)
			u.plant.order_fraction(0.35)
		else:
			u.steer(U.wrap360(brg + 50.0))
			u.plant.order_fraction(0.25)
		return
	var gun_r := 0.0
	var msl_r := 0.0
	for m in u.mounts:
		if not m.alive():
			continue
		if m.kind == "gun" and (m.group == "main" or m.group == "sec") and m.count() > 0:
			gun_r = maxf(gun_r, SimBallistics.max_range(m.sel) * 0.8)
		elif m.group == "ashm" or m.group == "strike":
			for k in m.ammo:
				var md := Weapons.mun(k)
				if int(m.ammo[k]) > 0 and String(md.get("role", "")) == "ship" and not md.has("nuke"):
					msl_r = maxf(msl_r, float(md.get("range", 0.0)) * 0.85)
	var want := gun_r * 0.75 if gun_r > 0.0 else 30000.0
	if msl_r > 0.0 and gun_r < 15000.0:
		want = maxf(want, minf(msl_r * 0.6, 60000.0))
	want *= clampf(1.0 / aggression, 0.6, 1.4)
	var c := brg
	if d < want * 0.8:
		c = U.wrap360(brg + 150.0 * signf(U.adiff(brg, u.heading) + 0.01))
	elif d < want * 1.15:
		# Run across the bearing so all guns bear.
		var a := U.wrap360(brg + 70.0)
		var b := U.wrap360(brg - 70.0)
		c = a if absf(U.adiff(u.heading, a)) < absf(U.adiff(u.heading, b)) else b
	u.steer(c)
	u.plant.order_fraction(0.85 if d > want else 0.7)


func _track_solutions(dt: float) -> void:
	if target == null:
		return
	var q: float = fc_q.get(target.uid, 0.0)
	var rate := 1.0 / (10.0 if u.cls.get("tier", 0) >= 4 and u.navy == "us" else 14.0)
	q += dt * rate * (0.4 + 0.6 * u.mod_hp("fc"))
	q -= absf(target.yaw_rate) * 0.02 * dt + absf(u.yaw_rate) * 0.012 * dt
	fc_q[target.uid] = clampf(q, 0.0, 0.92)


func _weapons() -> void:
	if target == null or not target.alive():
		return
	var d := U.flat_dist(u.pos, target.pos)
	salvo_t -= 0.4
	torp_t -= 0.4
	var q: float = fc_q.get(target.uid, 0.0)
	for m in u.mounts:
		if not m.alive():
			continue
		match m.kind:
			"gun":
				if m.group == "main" or m.group == "sec":
					if target.is_sub and target.depth > 3.0:
						continue
					w.ai_gun(u, m, target, q)
			"launcher", "vls":
				if (m.group == "ashm" or m.group == "strike") and salvo_t <= 0.0 and not target.is_sub:
					if m.select_role("ship"):
						var md: Dictionary = m.mun()
						if d < float(md.get("range", 0.0)) * 0.9 and d > 3000.0:
							var n := clampi(int(target.disp / 6000.0) + 2, 2, 6)
							var fired := 0
							for i in n:
								if m.ready() and w.launch_missile(u, m, target):
									fired += 1
							if fired > 0:
								salvo_t = 60.0
				elif m.group == "asw" and target.is_sub:
					if m.select_role("sub") and d < float(m.mun().get("range", 9000.0)) * 0.9 and m.ready():
						w.launch_missile(u, m, target)
			"tubes":
				if torp_t <= 0.0 and m.ready() and m.count() > 0 and _torpedoes_at(target) < (2 if target.disp > 9000.0 else 1):
					var r: float = m.mun().get("range", 10000.0)
					# Submarines close to a sure firing range before they shoot.
					if d < (r * 0.45 if not u.is_sub else minf(r * 0.6, 12000.0)):
						if u.is_sub:
							_pick_torpedo(m, target)
						if w.launch_torpedo(u, m, target):
							torp_t = 50.0 if u.is_sub else 90.0
			"rocket":
				if target.is_sub and m.ready() and d < float(m.mun().get("range", 3000.0)) and m.can_bear(target.pos):
					w.fire_rbu(u, m, target.pos, target.depth)


## Our torpedoes still running at this target: one at a time is the rule,
## two for a big ship.
func _torpedoes_at(tgt) -> int:
	var n := 0
	for mu in w.muns:
		if mu.alive and mu.kind == "torpedo" and mu.shooter == u and mu.target == tgt:
			n += 1
	return n


func _pick_torpedo(m, tgt) -> void:
	for k in m.ammo:
		var md := Weapons.mun(k)
		if int(m.ammo[k]) <= 0 or String(md.get("kind", "")) != "torpedo":
			continue
		if tgt.is_sub and String(md.get("guidance", "")) == "wake":
			continue
		m.sel = k
		return
