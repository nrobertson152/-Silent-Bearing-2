class_name SimDamage
extends RefCounted
## Hit resolution: armour penetration, blast, module damage, flooding, fire.
##
## Penetration scales the muzzle figure with impact velocity (DeMarre exponent).
## Effective armour depends on the plate (belt, deck, turret) and the angle the
## shell meets it, so plunging long-range fire tends to strike decks and
## flat close-range fire tends to strike belts.

const DIFF := [0.7, 1.0, 1.25]


static func penetration(md: Dictionary, impact_speed: float) -> float:
	var pen0: float = md.get("pen", 10.0)
	var v0: float = md.get("v0", maxf(impact_speed, 1.0))
	return pen0 * pow(clampf(impact_speed / v0, 0.05, 1.6), 1.4283)


static func local_dir(u, v: Vector3) -> Vector3:
	var f: Vector3 = u.fwd()
	var r := Vector3(-f.z, 0, f.x)
	return Vector3(v.dot(r), v.y, -v.dot(f)).normalized()


## Effective armour (mm) met at local point lp travelling along local dir ld.
static func armor_at(u, lp: Vector3, ld: Vector3) -> Dictionary:
	var arm: Dictionary = u.cls.get("armor", {})
	var x: float = lp.z + u.L * 0.5
	for m in u.mounts:
		if m.armor > 0.0 and m.alive():
			var r := 6.6 if m.armor > 300.0 else 4.6
			var d := Vector2(lp.x - m.lpos.x, lp.z - m.lpos.z).length()
			if d < r and lp.y > m.lpos.y - 2.5 and lp.y < m.lpos.y + 4.6:
				var face := maxf(absf(ld.z) * 0.8 + absf(ld.x) * 0.5, 0.35)
				return {"mm": m.armor / face, "plate": "turret", "mount": m}
	var deck_y := SimMount._deck_y(u.cls.get("hull", {}), x)
	var belt: float = arm.get("belt", 0.0)
	var bx: Array = arm.get("belt_x", [0.0, 0.0])
	var inside := x > float(bx[0]) and x < float(bx[1])
	if belt > 0.0 and inside and lp.y < deck_y - 0.4 and lp.y > -3.5:
		var slope := deg_to_rad(float(arm.get("belt_slope", 0.0)))
		var n := Vector3(signf(lp.x) * cos(slope), -sin(slope), 0.0)
		var c := absf(ld.dot(n))
		return {"mm": belt / maxf(c, 0.22), "plate": "belt", "mount": null}
	var deck: float = arm.get("deck", 0.0)
	if deck > 0.0 and inside and lp.y >= deck_y - 0.6:
		var c := absf(ld.y)
		return {"mm": deck / maxf(c, 0.12), "plate": "deck", "mount": null}
	var ct: float = arm.get("ct", 0.0)
	var br: Dictionary = u.modules.get("bridge", {})
	if ct > 0.0 and absf(x - float(br.get("x", -999.0)) + 4.0) < 4.0 and lp.y > deck_y and lp.y < float(br.get("y", 0.0)):
		return {"mm": ct, "plate": "conning tower", "mount": null}
	return {"mm": 0.0, "plate": "", "mount": null}


static func shell_hit(w, u, m, wp: Vector3) -> void:
	var lp: Vector3 = u.to_local(wp)
	var ld := local_dir(u, m.vel)
	var v: float = m.vel.length()
	var md: Dictionary = m.md
	var he: float = md.get("he", 1.0)
	var mass: float = md.get("mass", 10.0)
	var ke := 0.5 * mass * v * v / 1.0e6
	var pen := penetration(md, v)
	var a := armor_at(u, lp, ld)
	var result := "hit"
	var dmg := 0.0
	var inside := true
	var ap: bool = md.get("ap", false)
	if a["mm"] <= 0.0:
		if ap and pen > 60.0 and u.disp < 25000.0 and w.rng.randf() < 0.65:
			dmg = he * 8.0 + ke * 6.0
			result = "overpen"
		else:
			dmg = he * 22.0 + ke * 12.0
	elif pen > a["mm"]:
		dmg = he * 28.0 + ke * 14.0
		result = "pen"
	else:
		dmg = he * 5.0 + ke * 2.5
		inside = false
		result = "ricochet" if a["mm"] > pen * 1.5 else "nopen"
	if md.has("nuke"):
		w.nuke(wp, md["nuke"], m.side)
		return
	dmg *= _diff(w, u)
	u.hp -= dmg
	u.last_hit_t = w.t
	if a["mount"] != null:
		var mt = a["mount"]
		mt.hp -= 0.7 if result == "pen" else 0.06
		if result == "pen" and mt.armor > 150.0 and w.rng.randf() < 0.12:
			w.magazine_explosion(u, u.comp_of(mt.x))
	_blast(w, u, lp, he * (1.0 if inside else 0.25), inside)
	var comp: int = u.comp_of(lp.z + u.L * 0.5)
	if lp.y < 1.2 and (inside or a["mm"] <= 0.0):
		var area := pow(float(md.get("cal", 100.0)) / 1000.0, 2.0) * 7.0 + he * 0.004
		_hole(u, comp, area, maxf(1.0, 1.0 - lp.y))
	if inside and w.rng.randf() < clampf(he * 0.03 + 0.08, 0.0, 0.7):
		u.fire[comp] = minf(1.0, u.fire[comp] + 0.25)
	if result == "pen" and a["plate"] in ["belt", "deck"] and u.mag_comps.has(comp):
		if w.rng.randf() < 0.035 * float(md.get("cal", 100.0)) / 406.0:
			w.magazine_explosion(u, comp)
	w.emit({"t": "hit", "unit": u, "pos": wp, "kind": "shell", "result": result, "cal": md.get("cal", 100),
		"plate": a["plate"], "mm": a["mm"], "pen": pen, "by": m.shooter, "player": m.player_fired})


static func missile_hit(w, u, m, wp: Vector3) -> void:
	var lp: Vector3 = u.to_local(wp)
	var md: Dictionary = m.md
	if md.has("nuke"):
		w.nuke(wp, md["nuke"], m.side)
		return
	var he: float = md.get("he", 200.0)
	var pen: float = md.get("pen", 50.0)
	var ld := local_dir(u, m.vel)
	var a := armor_at(u, lp, ld)
	var inside: bool = pen >= a["mm"]
	var dmg := he * (24.0 if inside else 7.0)
	dmg *= _diff(w, u)
	u.hp -= dmg
	u.last_hit_t = w.t
	_blast(w, u, lp, he * (1.0 if inside else 0.3), inside)
	var comp: int = u.comp_of(lp.z + u.L * 0.5)
	u.fire[comp] = minf(1.0, u.fire[comp] + (0.65 if inside else 0.25))
	if lp.y < 2.5 and inside:
		_hole(u, comp, he * 0.006, 1.5)
	if a["mount"] != null:
		a["mount"].hp -= 0.5 if inside else 0.1
	w.emit({"t": "hit", "unit": u, "pos": wp, "kind": "missile", "result": "pen" if inside else "nopen",
		"plate": a["plate"], "mm": a["mm"], "pen": pen, "by": m.shooter, "player": m.player_fired, "name": md.get("name", "")})


static func torpedo_hit(w, u, m) -> void:
	var md: Dictionary = m.md
	var he: float = md.get("he", 200.0)
	var tds := 0.5 if float(u.cls.get("armor", {}).get("belt", 0.0)) > 250.0 else 1.0
	var dmg := he * 30.0 * tds * _diff(w, u)
	u.hp -= dmg
	u.last_hit_t = w.t
	var lp: Vector3 = u.to_local(m.pos)
	var comp: int = u.comp_of(clampf(lp.z + u.L * 0.5, 0.0, u.L))
	var area := he * 0.08 * tds * (2.5 if u.is_sub else 1.0)
	_hole(u, comp, area, u.T + 1.0)
	if comp + 1 < u.NCOMP:
		_hole(u, comp + 1, area * 0.4, u.T)
	if he * 30.0 > u.hp_max * 0.45:
		u.hp = minf(u.hp, u.hp_max * 0.1)
		_hole(u, comp, area * 3.0, u.T)
	_blast(w, u, lp, he * 0.6, true)
	w.emit({"t": "hit", "unit": u, "pos": Vector3(m.pos.x, 0, m.pos.z), "kind": "torpedo", "result": "pen",
		"by": m.shooter, "player": m.player_fired, "name": md.get("name", "")})


static func depth_damage(w, u, he: float, dist: float) -> void:
	var f := clampf(1.0 - dist / (6.0 + pow(he, 0.4) * 2.0), 0.0, 1.0)
	if f <= 0.0:
		return
	u.hp -= he * 26.0 * f * _diff(w, u)
	_hole(u, u.NCOMP / 2, he * 0.02 * f, 50.0)
	u.last_hit_t = w.t
	w.emit({"t": "hit", "unit": u, "pos": u.pos, "kind": "depth", "result": "pen" if f > 0.5 else "near"})


## Water rushing in through a hole of `area` m^2 at `head` metres below the surface.
static func _hole(u, comp: int, area: float, head: float) -> void:
	var q := 0.6 * area * sqrt(2.0 * 9.81 * clampf(head, 0.5, 40.0))
	u.flood_rate[comp] = float(u.flood_rate[comp]) + q


static func _blast(w, u, lp: Vector3, he: float, inside: bool) -> void:
	var r := 2.5 + pow(maxf(he, 0.1), 0.34) * (2.2 if inside else 1.2)
	for k in u.modules:
		var mo: Dictionary = u.modules[k]
		var mp := Vector3(0, float(mo["y"]), float(mo["x"]) - u.L * 0.5)
		var d := Vector2(lp.z - mp.z, (lp.y - mp.y) * 0.7).length() - float(mo["r"])
		if d < r:
			var f := clampf(1.0 - maxf(d, 0.0) / r, 0.0, 1.0)
			mo["hp"] = maxf(0.0, float(mo["hp"]) - f * clampf(he / 90.0, 0.05, 0.9))
	for m in u.mounts:
		if m.armor > 0.0:
			continue
		var d := lp.distance_to(m.lpos)
		if d < r + 1.5:
			m.hp = maxf(0.0, m.hp - clampf(1.0 - d / (r + 1.5), 0.0, 1.0) * clampf(he / 30.0, 0.15, 1.0))


static func _diff(w, u) -> float:
	# Difficulty scales damage taken by the player's side.
	if u.player or (w.player != null and u.side == w.player.side):
		return DIFF[clampi(w.difficulty, 0, 2)]
	return 1.0
