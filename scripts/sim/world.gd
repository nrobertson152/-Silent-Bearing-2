class_name SimWorld
extends RefCounted
## The battle: ships, aircraft and munitions, sensors, air defence and events.
## No rendering here; the view reads state and the events list.

const U := preload("res://scripts/util.gd")
const Weapons := preload("res://scripts/data/weapons.gd")
const ShipData := preload("res://scripts/data/ships.gd")

var t := 0.0
var units := []
var air := []
var muns := []
var ground := []
var land := []
var terrain: SimTerrain = null
var events := []
var player = null
var rng := RandomNumberGenerator.new()
var known := {"us": {}, "su": {}}
var known_air := {"us": {}, "su": {}}
var weather := {"vis": 25.0, "sea": 3.0}
var night := false
var difficulty := 1
var awacs := {"us": false, "su": false}
var ad_mode := "auto"
var mission = null
var _sense_t := 0.0
var _ad_t := 0.0
var _later := []
var _uid := 0
var origin := Vector2(60.0, 0.0)
var stats := {"shots": 0, "hits": 0, "missiles": 0, "kills": 0, "intercepts": 0, "damage_taken": 0.0}


func _init(seed_val := 0) -> void:
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()


func next_id() -> int:
	_uid += 1
	return _uid


func emit(ev: Dictionary) -> void:
	ev["time"] = t
	events.append(ev)


func radio(from: String, text: String, kind := "radio") -> void:
	emit({"t": "radio", "from": from, "text": text, "kind": kind})


func later(delay: float, fn: Callable) -> void:
	_later.append([t + delay, fn])


# ------------------------------------------------------------------ setup
func add_unit(class_id: String, team: String, p: Vector3, hdg: float, speed_kn := 0.0, opts := {}) -> SimUnit:
	var u := SimUnit.new(self, class_id, team)
	u.uid = next_id()
	u.pos = p
	u.heading = hdg
	u.speed = speed_kn * U.KN
	u.tag = opts.get("tag", "")
	if opts.has("name"):
		u.name = opts["name"]
	if u.is_sub:
		u.depth = opts.get("depth", 60.0)
		u.depth_order = u.depth
		u.pos.y = -u.depth
	var f := clampf(speed_kn * U.KN / maxf(u.max_speed, 1.0), -1.0, 1.0)
	if speed_kn > 0.0:
		u.plant.order_fraction(f)
		for s in u.plant.shafts:
			u.plant.answered[s] = u.plant.bell[s]
			if u.plant.is_lever():
				u.plant.rpm[s] = maxf(0.33, f)
				u.plant.pitch[s] = minf(1.0, f / 0.33) if f < 0.33 else 1.0
			else:
				u.plant.rpm[s] = u.plant.bell_rpm(u.plant.bell[s])
	u.course_order = hdg
	u.autopilot = true
	if opts.get("player", false):
		u.player = true
		player = u
	else:
		var ai := SimAI.new(u, self, opts.get("ai", "patrol"))
		ai.waypoints = opts.get("waypoints", [])
		ai.cruise = opts.get("cruise", f if f > 0.0 else 0.5)
		ai.aggression = opts.get("aggression", 1.0)
		ai.zig = opts.get("zig", 0.0)
		ai.hold_fire = opts.get("hold_fire", false)
		u.ai = ai
	units.append(u)
	known[team][u.uid] = 1e9
	return u


func add_air(type: String, team: String, p: Vector3, hdg: float, opts := {}) -> SimAir:
	var a := SimAir.new(self, type, team, p, hdg)
	a.uid = next_id()
	a.tag = opts.get("tag", "")
	a.friendly_callsign = opts.get("callsign", "")
	if opts.has("state"):
		a.state = opts["state"]
	if opts.has("orbit"):
		a.orbit_c = opts["orbit"]
	if opts.has("target"):
		a.target = opts["target"]
	if opts.has("home"):
		a.home = opts["home"]
	air.append(a)
	return a


func add_ground(name: String, p: Vector3, kind: String, hp := 1.0, team := "su") -> Dictionary:
	var g := {"name": name, "pos": p, "kind": kind, "hp": hp, "alive": true, "side": team, "r": 45.0, "fire_t": rng.randf_range(20.0, 60.0), "uid": next_id()}
	ground.append(g)
	return g


func spawn_munition(mid: String, team: String, from, p: Vector3, v: Vector3) -> SimMunition:
	var m := SimMunition.new(self, mid, team, from, p, v)
	m.uid = next_id()
	muns.append(m)
	return m


# ------------------------------------------------------------------ main loop
func step(dt: float) -> void:
	t += dt
	if not _later.is_empty():
		var keep := []
		for l in _later:
			if t >= l[0]:
				l[1].call()
			else:
				keep.append(l)
		_later = keep
	for u in units:
		if u.sunk:
			continue
		u.update(dt)
		for m in u.mounts:
			m.update(dt)
		if u.ai != null:
			u.ai.update(dt)
		_land_check(u)
	for a in air:
		a.update(dt)
	for m in muns:
		m.update(dt)
	_ciws(dt)
	_ad_t -= dt
	if _ad_t <= 0.0:
		_ad_t = 0.25
		_air_defense()
		_ground_fire()
	_sense_t -= dt
	if _sense_t <= 0.0:
		_sense_t = 1.0
		_sensors()
	if mission != null:
		mission.update(dt)
	if muns.size() > 0 and Engine.get_process_frames() % 30 == 0:
		muns = muns.filter(func(m): return m.alive)
		air = air.filter(func(a): return a.alive)


func focus() -> Vector3:
	return player.pos if player != null else Vector3.ZERO


# ------------------------------------------------------------------ sensors
func _size_factor(u) -> float:
	return clampf(pow(u.disp / 5000.0, 0.25), 0.6, 1.5)


func _sensors() -> void:
	var vis := float(weather.get("vis", 25.0)) * 1000.0 * (0.22 if night else 1.0)
	for team in ["us", "su"]:
		var mine := units.filter(func(u): return u.side == team and u.alive())
		for e in units:
			if e.side == team or not e.alive():
				continue
			var seen := false
			for f in mine:
				var d := U.flat_dist(f.pos, e.pos)
				if e.is_sub and e.depth > 14.0:
					if d < sonar_range(f, e):
						seen = true
				else:
					var hz := U.horizon(f.mast_h() if not f.is_sub else 1.5, e.mast_h())
					var sf := _size_factor(e)
					if not f.emcon and f.mod_hp("radar") > 0.1 and not (f.is_sub and f.depth > 20.0):
						if d < minf(f.surf_range * sf * (0.4 + 0.6 * f.mod_hp("radar")), hz):
							seen = true
					if d < minf(vis * sf, hz) and not (f.is_sub and f.depth > 20.0):
						seen = true
					var mineral: float = f.cls.get("sensors", {}).get("mineral", 0.0)
					if mineral > 0.0 and not e.emcon and d < mineral:
						seen = true
					if f.is_sub and f.depth > 14.0:
						if d < sonar_range(f, e):
							seen = true
				if seen:
					break
			if not seen:
				for a in air:
					if a.side == team and a.alive and (a.role == "patrol" or a.role == "helo" or a.role == "recon"):
						if U.flat_dist(a.pos, e.pos) < (60000.0 if not e.is_sub else 5000.0):
							seen = true
							break
			if seen:
				if not known[team].has(e.uid) and team == (player.side if player else "us"):
					emit({"t": "contact", "unit": e})
				known[team][e.uid] = t
		for a in air:
			if a.side == team or not a.alive:
				continue
			var spotted: bool = awacs[team] and U.flat_dist(a.pos, focus()) < 450000.0
			if not spotted:
				for f in mine:
					if f.emcon or f.air_range <= 0.0:
						continue
					if U.flat_dist(f.pos, a.pos) < minf(f.air_range, U.horizon(f.mast_h(), a.pos.y)):
						spotted = true
						break
			if spotted:
				if not known_air[team].has(a.uid) and player != null and team == player.side:
					emit({"t": "air_contact", "air": a})
				known_air[team][a.uid] = t


## Passive sonar detection range of unit f against unit e, in metres. Noisier
## (faster) targets are heard further; own speed deafens; a submarine on the
## other side of the thermal layer (about 80 m) is harder to hear.
func sonar_range(f, e) -> float:
	if e.is_sub and e.depth > 14.0:
		var s: float = f.sonar * f.mod_hp("sonar") * 7000.0 + f.towed * 15000.0
		if f.is_sub:
			s = f.sonar * 22000.0
		var en := 0.35 + absf(e.speed) / maxf(e.max_speed, 1.0) * 1.4
		var own := 0.6 + absf(f.speed) / maxf(f.max_speed, 1.0) * 0.9
		var layer := 0.55 if (f.depth < 80.0) != (e.depth < 80.0) else 1.0
		return s * en / own * layer
	return f.sonar * 26000.0 * (0.45 + absf(e.speed) / maxf(e.max_speed, 1.0))


func known_to(team: String, u) -> bool:
	if u.side == team:
		return true
	var last: float = known[team].get(u.uid, -1000.0)
	return t - last < 25.0


func air_known(team: String, a) -> bool:
	return t - float(known_air[team].get(a.uid, -1000.0)) < 15.0


# ------------------------------------------------------------------ queries
func nearest_enemy_ship(team: String, p: Vector3, max_r: float):
	var best = null
	var bd := max_r
	for u in units:
		if u.side == team or not u.alive() or (u.is_sub and u.depth > 15.0):
			continue
		var d := U.flat_dist(p, u.pos)
		if d < bd:
			bd = d
			best = u
	return best


func nearest_air(a, max_r: float):
	var best = null
	var bd := max_r
	for o in air:
		if o.side == a.side or not o.alive or o.role == "helo":
			continue
		var d := U.flat_dist(a.pos, o.pos)
		if d < bd:
			bd = d
			best = o
	return best


func nearest_enemy_sub(a, max_r: float):
	for u in units:
		if u.side != a.side and u.alive() and u.is_sub and U.flat_dist(a.pos, u.pos) < max_r:
			return u
	return null


func target_alive(tg) -> bool:
	if tg == null:
		return false
	if tg is SimUnit:
		return tg.alive()
	return tg.alive


## Ship nearest the missile's track inside a cone ahead of it (seeker lock).
func find_ship_in_cone(m, half_deg: float, max_r: float):
	var dir := Vector2(m.vel.x, m.vel.z)
	if dir.length() < 1.0:
		return null
	dir = dir.normalized()
	var best = null
	var bs := 1e12
	for u in units:
		if not u.alive() or u.side == m.side or (u.is_sub and u.depth > 3.0):
			continue
		var rel := Vector2(u.pos.x - m.pos.x, u.pos.z - m.pos.z)
		var d := rel.length()
		if d > max_r or d < 1.0:
			continue
		var ang := rad_to_deg(absf(dir.angle_to(rel / d)))
		if ang > half_deg:
			continue
		var score := d * (1.0 + ang / half_deg) / _size_factor(u)
		if score < bs:
			bs = score
			best = u
	return best


# ------------------------------------------------------------------ collisions and hits
func _hull_box(u) -> Array:
	var top: float = u.deck_h() + (u.radar_h * 0.45 if not u.is_sub else 3.0)
	return [u.L * 0.5, u.B * 0.5, -u.T, top]


## Shell segment p0->p1 against ship hulls; applies damage on a hit.
func shell_collide(m, p0: Vector3, p1: Vector3):
	if p1.y > 60.0 and p0.y > 60.0:
		return null
	for u in units:
		if not u.alive() or (u.is_sub and u.depth > 6.0) or u == m.shooter:
			continue
		var c: Vector3 = u.pos
		if U.flat_dist(c, p1) > u.L * 0.7 + 30.0:
			continue
		var hb := _hull_box(u)
		var a: Vector3 = u.to_local(p0)
		var b: Vector3 = u.to_local(p1)
		var hit := _seg_box(a, b, Vector3(-hb[1], hb[2], -hb[0]), Vector3(hb[1], hb[3], hb[0]))
		if hit >= 0.0:
			var lp := a.lerp(b, hit)
			var wp: Vector3 = u.to_world(lp)
			stats["hits"] += 1 if m.player_fired else 0
			SimDamage.shell_hit(self, u, m, wp)
			return u
	if terrain != null:
		var lh := land_h(p1.x, p1.z)
		if lh > 0.0 and p1.y < lh:
			m.alive = false
			land_impact(m, Vector3(p1.x, lh, p1.z))
			return self
	return null


## Segment/box intersection: returns t in 0..1 or -1.
static func _seg_box(a: Vector3, b: Vector3, lo: Vector3, hi: Vector3) -> float:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for i in 3:
		if absf(d[i]) < 1e-9:
			if a[i] < lo[i] or a[i] > hi[i]:
				return -1.0
		else:
			var ta := (lo[i] - a[i]) / d[i]
			var tb := (hi[i] - a[i]) / d[i]
			if ta > tb:
				var tmp := ta
				ta = tb
				tb = tmp
			t0 = maxf(t0, ta)
			t1 = minf(t1, tb)
			if t0 > t1:
				return -1.0
	return t0


func shell_splash(m, p: Vector3) -> void:
	var cal: float = m.md.get("cal", 100.0)
	emit({"t": "splash", "pos": Vector3(p.x, 0, p.z), "size": cal / 100.0, "player": m.player_fired, "shell": true})
	if m.md.has("nuke"):
		nuke(Vector3(p.x, 0, p.z), m.md["nuke"], m.side)


func missile_contact(m, u) -> bool:
	var lp: Vector3 = u.to_local(m.pos)
	var hb := _hull_box(u)
	if absf(lp.z) < hb[0] + 3.0 and absf(lp.x) < hb[1] + 3.0 and lp.y < hb[3] + 4.0 and lp.y > -2.0:
		var hp := Vector3(clampf(lp.x, -hb[1], hb[1]), clampf(lp.y, 0.5, hb[3]), clampf(lp.z, -hb[0], hb[0]))
		SimDamage.missile_hit(self, u, m, u.to_world(hp))
		return true
	return false


func torpedo_hit(m, u) -> void:
	SimDamage.torpedo_hit(self, u, m)


func depth_charge_check(m):
	for u in units:
		if u.alive() and u.is_sub and u.side != m.side and m.pos.distance_to(u.pos) < 14.0:
			return u
	return null


func depth_charge_explode(m) -> void:
	var he: float = m.md.get("he", 23.0)
	emit({"t": "depth_bomb", "pos": m.pos, "size": he / 25.0})
	for u in units:
		if u.alive() and u.is_sub and u.side != m.side:
			SimDamage.depth_damage(self, u, he, m.pos.distance_to(u.pos))


func land_impact(m, p: Vector3) -> void:
	var he: float = m.md.get("he", 10.0)
	emit({"t": "ground_hit", "pos": p, "size": maxf(1.0, pow(he, 0.33)), "player": m.player_fired})
	if m.md.has("nuke"):
		nuke(p, m.md["nuke"], m.side)
		return
	var r := 12.0 + pow(he, 0.4) * 9.0
	for g in ground:
		if g["alive"] and g["side"] != m.side and U.flat_dist(g["pos"], p) < r + g["r"]:
			var f := clampf(1.0 - U.flat_dist(g["pos"], p) / (r + g["r"]), 0.15, 1.0)
			g["hp"] -= f * clampf(he / 40.0, 0.04, 1.0)
			if g["hp"] <= 0.0:
				g["alive"] = false
				emit({"t": "ground_destroyed", "ground": g, "pos": g["pos"], "player": m.player_fired})


func sam_result(m, tg) -> void:
	var pk: float = m.md.get("pk", 0.6)
	if tg is SimMunition:
		pk *= 1.0 - float(tg.md.get("agile", 0.3)) * 0.45
	if rng.randf() < pk:
		tg.alive = false
		if tg is SimMunition:
			stats["intercepts"] += 1
			emit({"t": "intercept", "pos": tg.pos, "by": m.shooter, "mun": tg})
		else:
			emit({"t": "air_kill", "pos": tg.pos, "air": tg, "by": m.shooter})
	else:
		tg.engaged = maxi(0, tg.engaged - 1) if tg is SimMunition else 0
		emit({"t": "sam_miss", "pos": m.pos})


func on_sinking(u) -> void:
	emit({"t": "sinking", "unit": u})
	if u.side != (player.side if player else ""):
		stats["kills"] += 1


func on_sunk(u) -> void:
	emit({"t": "sunk", "unit": u})


func magazine_explosion(u, comp: int) -> void:
	if not u.alive():
		return
	u.hp = 0.0
	u.flood_rate[comp] += u.disp * 0.05
	emit({"t": "magazine", "unit": u, "pos": u.to_world(Vector3(0, 2.0, (comp + 0.5) / u.NCOMP * u.L - u.L * 0.5))})


func nuke(p: Vector3, kt: float, team: String) -> void:
	var r := 950.0 * pow(kt / 15.0, 1.0 / 3.0)
	if player != null and team == player.side:
		stats["nuclear"] = int(stats.get("nuclear", 0)) + 1
	emit({"t": "nuke", "pos": Vector3(p.x, 0, p.z), "kt": kt, "r": r, "side": team})
	for u in units:
		if not u.alive():
			continue
		var d := U.flat_dist(u.pos, p)
		if d < r:
			u.hp = 0.0
			u.flood_rate[u.NCOMP / 2] += u.disp * 0.1
		elif d < r * 2.4:
			var f := 1.0 - (d - r) / (r * 1.4)
			u.hp -= u.hp_max * 0.6 * f
			for k in u.modules:
				u.modules[k]["hp"] = maxf(0.0, float(u.modules[k]["hp"]) - f)
			for i in u.NCOMP:
				u.fire[i] = maxf(u.fire[i], f * 0.8)
	for a in air:
		if a.alive and a.pos.distance_to(p) < r * 3.0:
			a.alive = false
	for m in muns:
		if m.alive and m.pos.distance_to(p) < r * 1.5:
			m.alive = false
	for g in ground:
		if g["alive"] and U.flat_dist(g["pos"], p) < r * 1.5:
			g["alive"] = false


func _land_check(u) -> void:
	if terrain == null or u.is_sub and u.depth > 30.0:
		return
	var bow: Vector3 = u.pos + u.fwd() * u.L * 0.5
	if land_h(bow.x, bow.z) > -2.0:
		if absf(u.speed) > 0.5:
			emit({"t": "aground", "unit": u})
			u.hp -= u.hp_max * 0.03 * absf(u.speed) / u.max_speed
			u.flood_rate[0] += 2.0
		u.speed = minf(u.speed, 0.0)


# ------------------------------------------------------------------ terrain
func is_land(x: float, z: float) -> bool:
	return terrain != null and terrain.height(x, z) > 0.5


func land_h(x: float, z: float) -> float:
	return terrain.height(x, z) if terrain != null else -50.0


func build_terrain(max_h: float) -> void:
	if land.is_empty():
		return
	var polys := []
	for l in land:
		polys.append(l["pts"])
	terrain = SimTerrain.new()
	terrain.build(polys, max_h, 66000.0)


# ------------------------------------------------------------------ weapons
## Fire a gun mount at a world aim point. Returns true if it fired.
func fire_gun(u, m, aim: Vector3, player_fired := false, disp_mult := 1.0) -> bool:
	if m.kind != "gun" or not m.alive():
		return false
	var mp: Vector3 = m.world_pos()
	var rngd := U.flat_dist(mp, aim)
	var el := SimBallistics.elevation_for(m.sel, rngd)
	el += rad_to_deg(atan2(aim.y - mp.y, maxf(rngd, 1.0))) * 0.5
	m.aim_at(aim, el)
	if not m.ready() or not m.on_target(1.2) or not m.can_bear(aim):
		return false
	var md: Dictionary = m.mun()
	var v0: float = md.get("v0", 800.0)
	var disp: float = float(m.md.get("disp", 0.004)) * disp_mult * (1.0 + (1.0 - m.hp) * 2.0)
	var crew = 1.0 + (1.0 - u.health()) * 0.6
	var fired := 0
	for i in m.barrels:
		if not m.take():
			break
		var hd: float = u.heading + m.train + U.gauss(rng) * rad_to_deg(disp) * 0.5
		var ev: float = m.elev + U.gauss(rng) * rad_to_deg(disp) * 0.9 + u.heel * 0.02
		var v = SimBallistics.launch_vel(v0 * (1.0 + U.gauss(rng) * 0.002), hd, ev) + u.vel()
		var s := spawn_munition(m.sel, u.side, u, mp + Vector3(0, 1.5, 0), v)
		s.player_fired = player_fired
		fired += 1
	if fired == 0:
		return false
	m.reload = m.cycle * crew
	m.last_shot = t
	if player_fired:
		stats["shots"] += fired
	emit({"t": "fire", "unit": u, "mount": m, "cal": md.get("cal", 100), "pos": mp, "player": player_fired})
	return true


## AI gunnery: aim at the predicted impact point with errors from the solution quality.
func ai_gun(u, m, tg, q: float) -> void:
	if not m.alive() or m.count() <= 0:
		return
	var mp: Vector3 = m.world_pos()
	var d := U.flat_dist(mp, tg.pos)
	if m.has("203_he") or m.has("152_he") or m.has("406_he") or m.has("406_su_he"):
		var want_he: bool = tg.cls.get("armor", {}).get("belt", 0.0) < 60.0
		for k in m.ammo:
			if int(m.ammo[k]) > 0 and (String(k).ends_with("_he") == want_he):
				m.sel = k
				break
	var maxr := SimBallistics.max_range(m.sel)
	if d > maxr * 0.95:
		m.aim_at(tg.pos, 10.0)
		return
	var tof := SimBallistics.time_for(m.sel, d)
	var lead: Vector3 = tg.pos + tg.vel() * tof
	var err_r := ((1.0 - q) * 0.07 + 0.008) * d * U.gauss(rng)
	var err_b := ((1.0 - q) * 0.7 + 0.1) * U.gauss(rng)
	var dirv: Vector3 = (lead - mp)
	dirv.y = 0.0
	dirv = dirv.normalized()
	var side_v := Vector3(-dirv.z, 0, dirv.x)
	var aim := lead + dirv * err_r + side_v * deg_to_rad(err_b) * d
	if q > 0.12 and m.can_bear(lead):
		fire_gun(u, m, aim, false, 1.0)
	else:
		m.aim_at(lead, SimBallistics.elevation_for(m.sel, d))


func launch_missile(u, m, tg, player_fired := false, aim_point = null) -> bool:
	if not m.ready():
		return false
	var md: Dictionary = m.mun()
	if md.is_empty() or not m.take():
		return false
	var mp: Vector3 = m.world_pos() + Vector3(0, 2.0, 0)
	var to = (tg.pos if tg != null else (aim_point if aim_point != null else mp + u.fwd() * 1000.0))
	var hd := U.brg(mp, to)
	if not m.fixed:
		m.aim_at(to, 25.0)
	var up := 0.85 if m.kind == "vls" else 0.35
	var dir := (U.fwd(hd if m.kind == "vls" else (u.heading + m.face if m.fixed else hd)) * (1.0 - up) + Vector3.UP * up).normalized()
	var mm := spawn_munition(m.sel, u.side, u, mp, dir * float(md.get("speed", 300.0)) * 0.55)
	mm.target = tg
	mm.player_fired = player_fired
	if aim_point != null:
		mm.aim = aim_point
		mm.aim_set = true
	elif tg != null:
		mm.aim = tg.pos
	m.reload = m.cycle
	m.last_shot = t
	if player_fired:
		stats["missiles"] += 1
	emit({"t": "launch", "unit": u, "mount": m, "mun": mm, "pos": mp, "player": player_fired})
	return true


func launch_torpedo(u, m, tg, player_fired := false) -> bool:
	if not m.ready() or not m.take():
		return false
	var mp: Vector3 = m.world_pos() if not u.is_sub else u.pos + u.fwd() * u.L * 0.42
	var hd = U.brg(mp, tg.pos + tg.vel() * 30.0) if tg != null else u.heading
	var md: Dictionary = m.mun()
	var tm := spawn_munition(m.sel, u.side, u, Vector3(mp.x, -2.0 if not u.is_sub else mp.y, mp.z), U.fwd(hd) * float(md.get("speed", 20.0)))
	tm.target = tg
	tm.depth = -tm.pos.y
	tm.run_depth = 6.0 if tg == null or not tg.is_sub else maxf(10.0, tg.depth)
	tm.player_fired = player_fired
	m.reload = m.cycle
	emit({"t": "torpedo_launch", "unit": u, "mount": m, "mun": tm, "pos": mp, "player": player_fired})
	return true


func fire_rbu(u, m, at: Vector3, tdepth: float, player_fired := false) -> bool:
	if not m.ready():
		return false
	var mp: Vector3 = m.world_pos()
	var n: int = m.md.get("salvo", 12)
	var fired := 0
	for i in n:
		if not m.take():
			break
		var a := TAU * i / n
		var spot := at + Vector3(cos(a), 0, sin(a)) * (60.0 + rng.randf() * 40.0)
		var d := U.flat_dist(mp, spot)
		var v0 := sqrt(9.81 * maxf(d, 50.0))
		var hd := U.brg(mp, spot)
		var r := spawn_munition(m.sel, u.side, u, mp + Vector3(0, 1.5, 0), SimBallistics.launch_vel(v0, hd, 45.0))
		r.aim = Vector3(0, -tdepth, 0)
		r.aim_set = true
		r.player_fired = player_fired
		fired += 1
	if fired > 0:
		m.reload = m.cycle
		emit({"t": "rbu", "unit": u, "mount": m, "pos": mp, "player": player_fired})
	return fired > 0


func sub_decoy(u) -> void:
	for m in muns:
		if m.alive and m.kind == "torpedo" and m.target == u and String(m.md.get("guidance", "")) != "wake":
			if rng.randf() < 0.35:
				m.target = null
				emit({"t": "decoy", "unit": u})


func air_launch(a) -> void:
	var wid: String = a.ad.get("weapon", "")
	if wid == "":
		return
	var tg = a.target if a.target is SimUnit else nearest_enemy_ship(a.side, a.pos, 500000.0)
	if tg == null:
		return
	var md := Weapons.mun(wid)
	var dir = (tg.pos - a.pos).normalized()
	var m := spawn_munition(wid, a.side, a, a.pos + Vector3(0, -20, 0), dir * float(md.get("speed", 300.0)) * 0.7)
	m.target = tg
	m.aim = tg.pos
	m.phase = "cruise"
	emit({"t": "air_launch", "air": a, "mun": m, "pos": a.pos})


func air_drop_torpedo(a, sub) -> void:
	var wid: String = a.ad.get("weapon", "mk46")
	var m := spawn_munition(wid, a.side, a, Vector3(sub.pos.x + rng.randf_range(-200, 200), -5.0, sub.pos.z + rng.randf_range(-200, 200)), U.fwd(rng.randf() * 360.0) * 5.0)
	m.target = sub
	m.run_depth = sub.depth
	emit({"t": "splash", "pos": Vector3(m.pos.x, 0, m.pos.z), "size": 1.0})
	emit({"t": "torpedo_drop", "air": a, "mun": m})


func aam_shot(a, tg) -> void:
	emit({"t": "aam", "air": a, "target": tg})
	var tof := clampf(U.flat_dist(a.pos, tg.pos) / 900.0, 5.0, 40.0)
	later(tof, func():
		if tg.alive and a.alive and rng.randf() < 0.62:
			tg.alive = false
			emit({"t": "air_kill", "pos": tg.pos, "air": tg, "by": a}))


# ------------------------------------------------------------------ air defence
func _threats_for(u) -> Array:
	var out := []
	for m in muns:
		if not m.alive or m.side == u.side or m.kind != "missile" or m.role == "air" or m.role == "sub":
			continue
		var d = u.pos.distance_to(m.pos)
		if d > 160000.0:
			continue
		var seen = d < U.horizon(u.mast_h(), maxf(m.pos.y, 1.0)) and (u.air_range > 0.0 or d < 25000.0)
		if not seen and awacs[u.side] and d < 60000.0:
			seen = true
		if not seen:
			continue
		var threat_to_me: bool = m.target == u or d < 9000.0
		var near_friend = d < 30000.0 and u.cls.get("sensors", {}).get("aegis", false)
		if threat_to_me or near_friend or (m.target != null and m.target is SimUnit and m.target.side == u.side and U.flat_dist(m.target.pos, u.pos) < 15000.0):
			out.append([d / maxf(m.vel.length(), 1.0), m])
	for a in air:
		if a.alive and a.side != u.side and air_known(u.side, a) and a.role != "recon":
			var d = u.pos.distance_to(a.pos)
			if d < 160000.0:
				out.append([d / 250.0 + 30.0, a])
	out.sort_custom(func(x, y): return x[0] < y[0])
	return out


func _air_defense() -> void:
	for u in units:
		if not u.alive() or u.is_sub:
			continue
		if u.player and ad_mode != "auto":
			continue
		var sams := []
		for m in u.mounts:
			if m.alive() and m.ready() and (m.group == "sam" or m.kind == "vls" or m.mtype == "mk13"):
				for k in m.ammo:
					if int(m.ammo[k]) > 0 and String(Weapons.mun(k).get("role", "")) == "air":
						sams.append([m, k])
						break
		if sams.is_empty():
			continue
		var busy := 0
		for mm in muns:
			if mm.alive and mm.kind == "missile" and mm.role == "air" and mm.shooter == u:
				busy += 1
		var chans: int = maxi(1, int(u.fc_channels * (0.3 + 0.7 * u.mod_hp("fc"))))
		for th in _threats_for(u):
			if busy >= chans:
				break
			var tg = th[1]
			var d = u.pos.distance_to(tg.pos)
			var limit := 2 if tg is SimMunition else 1
			var eng: int = tg.engaged if tg is SimMunition else 0
			if tg is SimMunition and eng >= limit:
				continue
			for s in sams:
				var m = s[0]
				var md := Weapons.mun(s[1])
				if not m.ready() or d > float(md.get("range", 10000.0)) * 0.95 or d < 600.0:
					continue
				var prev: String = m.sel
				m.sel = s[1]
				var dir = (tg.pos - m.world_pos()).normalized()
				if m.take():
					var sm := spawn_munition(s[1], u.side, u, m.world_pos() + Vector3(0, 2, 0), (dir * 0.4 + Vector3.UP * 0.6).normalized() * float(md.get("speed", 800.0)) * 0.5)
					sm.target = tg
					m.reload = m.cycle
					if tg is SimMunition:
						tg.engaged += 1
					busy += 1
					emit({"t": "sam_launch", "unit": u, "mount": m, "mun": sm, "pos": m.world_pos()})
				if prev != "" and int(m.ammo.get(prev, 0)) > 0:
					m.sel = prev
				break


func _ciws(dt: float) -> void:
	for u in units:
		if not u.alive() or u.is_sub:
			continue
		for m in u.mounts:
			if m.kind != "ciws" or not m.alive() or m.rounds <= 0:
				continue
			var rng_c: float = m.md.get("range", 2000.0)
			var best = null
			var bd := rng_c
			var mp: Vector3 = m.world_pos()
			for mm in muns:
				if not mm.alive or mm.side == u.side or mm.kind != "missile" or mm.role == "air" or mm.role == "sub":
					continue
				var d := mp.distance_to(mm.pos)
				if d < bd and m.can_bear(mm.pos):
					bd = d
					best = mm
			if best == null:
				m.target = null
				continue
			m.target = best
			m.aim_at(best.pos, rad_to_deg(atan2(best.pos.y - mp.y, maxf(U.flat_dist(mp, best.pos), 1.0))))
			if not m.on_target(4.0):
				continue
			m.rounds -= int(float(m.md.get("rof", 4000)) / 60.0 * dt)
			m.last_shot = t
			if Engine.get_process_frames() % 3 == 0:
				emit({"t": "ciws", "unit": u, "mount": m, "pos": mp, "target": best.pos})
			var pk: float = float(m.md.get("pk", 0.5)) * (1.0 - float(best.md.get("agile", 0.3)) * 0.5) * (0.5 + 0.5 * m.hp)
			if rng.randf() < 1.0 - pow(1.0 - pk, dt):
				best.alive = false
				stats["intercepts"] += 1
				emit({"t": "intercept", "pos": best.pos, "by": u, "mun": best, "ciws": true})


func _ground_fire() -> void:
	for g in ground:
		if not g["alive"] or g["kind"] != "battery":
			continue
		g["fire_t"] -= 0.25
		if g["fire_t"] > 0.0:
			continue
		g["fire_t"] = rng.randf_range(14.0, 26.0)
		var tg = nearest_enemy_ship(g["side"], g["pos"], 22000.0)
		if tg == null:
			continue
		var d := U.flat_dist(g["pos"], tg.pos)
		var mid := "152_he"
		var tof := SimBallistics.time_for(mid, d)
		var aim: Vector3 = tg.pos + tg.vel() * tof + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * d * 0.02
		var el := SimBallistics.elevation_for(mid, U.flat_dist(g["pos"], aim))
		var v := SimBallistics.launch_vel(950.0, U.brg(g["pos"], aim), el)
		spawn_munition(mid, g["side"], null, g["pos"] + Vector3(0, 5, 0), v)
		emit({"t": "battery_fire", "pos": g["pos"]})
