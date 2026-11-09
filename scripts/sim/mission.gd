class_name SimMission
extends RefCounted
## Builds a scenario from a mission definition and runs it: objectives,
## scripted radio traffic and reinforcements, victory and defeat.
## Positions in mission data are [km east, km north] of the mission origin.

const U := preload("res://scripts/util.gd")

var w
var def := {}
var objectives := []
var pending := []
var result := ""
var result_t := 0.0
var _eval_t := 0.0
var flags := {}
var player_side := "us"


func _init(world, mission: Dictionary) -> void:
	w = world
	def = mission
	w.mission = self


static func km(p) -> Vector3:
	return Vector3(float(p[0]) * 1000.0, 0.0, -float(p[1]) * 1000.0)


func setup() -> void:
	player_side = def.get("side", "us")
	var wx: Dictionary = def.get("weather", {})
	w.weather = {"vis": wx.get("vis", 25.0), "sea": wx.get("sea", 3.0)}
	w.awacs[player_side] = def.get("awacs", false)
	w.awacs["su" if player_side == "us" else "us"] = def.get("enemy_awacs", false)
	var lands: Array = def.get("land", []).duplicate()
	if def.has("geo"):
		var f := FileAccess.open("res://data/geo/%s.json" % def["geo"], FileAccess.READ)
		if f != null:
			var polys = JSON.parse_string(f.get_as_text())
			if polys is Array:
				for poly in polys:
					lands.append({"pts": poly, "h": def.get("land_h", 120.0)})
	for l in lands:
		var pts := PackedVector2Array()
		for p in l["pts"]:
			pts.append(Vector2(float(p[0]) * 1000.0, -float(p[1]) * 1000.0))
		var parts := [pts]
		if pts.size() > 2 and Geometry2D.triangulate_polygon(pts).is_empty():
			# Simplified coastlines can cross themselves: untangle into simple polygons.
			parts = Geometry2D.merge_polygons(pts, PackedVector2Array())
		for part: PackedVector2Array in parts:
			w.land.append({"pts": part, "h": l.get("h", 40.0), "name": l.get("name", "")})
	w.build_terrain(float(def.get("land_h", 140.0)))
	var pl: Dictionary = def.get("player", {})
	w.add_unit(def["ship"], player_side, km(pl.get("pos", [0, 0])), float(pl.get("hdg", 0.0)), float(pl.get("speed", 12.0)),
		{"player": true, "depth": pl.get("depth", 40.0)})
	for ud in def.get("units", []):
		_spawn_unit(ud)
	for ad in def.get("air", []):
		if ad.has("at"):
			pending.append({"at": float(ad["at"]), "spawn_air": ad})
		else:
			_spawn_air(ad)
	for gd in def.get("ground", []):
		var gp := km(gd["pos"])
		gp.y = maxf(w.land_h(gp.x, gp.z), 2.0) + 2.0 + float(gd.get("h", 0.0)) * 0.1
		var g: Dictionary = w.add_ground(gd["name"], gp, gd.get("kind", "target"),
			float(gd.get("hp", 1.0)), gd.get("side", "su" if player_side == "us" else "us"))
		g["tag"] = gd.get("tag", "")
	for o in def.get("objectives", []):
		var oc: Dictionary = o.duplicate(true)
		oc["state"] = "active"
		objectives.append(oc)
	for e in def.get("events", []):
		pending.append(e.duplicate(true))


func _spawn_unit(ud: Dictionary):
	var n: int = ud.get("n", 1)
	var out = null
	var lead = null
	for i in n:
		var p := km(ud["pos"])
		var spacing: float = ud.get("spacing", 1.2) * 1000.0
		var hdg: float = ud.get("hdg", 0.0)
		var f := U.fwd(hdg)
		var r := Vector3(-f.z, 0, f.x)
		var cols: int = ud.get("cols", 1 if n < 4 else 2)
		p += r * (float(i % cols) - (cols - 1) * 0.5) * spacing - f * float(i / cols) * spacing
		var wps := []
		for wp in ud.get("waypoints", []):
			wps.append(km(wp) + (p - km(ud["pos"])))
		var opts := {"tag": ud.get("tag", ""), "ai": ud.get("ai", "patrol"), "waypoints": wps, "depth": ud.get("depth", 60.0),
			"aggression": ud.get("aggression", 1.0), "zig": ud.get("zig", 0.0)}
		# Units hold the speed the mission gives them unless told otherwise.
		if ud.has("cruise"):
			opts["cruise"] = ud["cruise"]
		if ud.has("names") and i < (ud["names"] as Array).size():
			opts["name"] = ud["names"][i]
		elif ud.has("name"):
			opts["name"] = ud["name"] if n == 1 else "%s %d" % [ud["name"], i + 1]
		var u: SimUnit = w.add_unit(ud["cls"], ud.get("side", "su"), p, hdg, float(ud.get("speed", 10.0)), opts)
		if ud.get("ai", "") == "escort":
			var leader = _find_tag(ud.get("lead", ""))
			if leader != null:
				u.ai.lead = leader
				var off: Array = ud.get("offset", [2.0, -1.0])
				u.ai.offset = Vector3(float(off[0]) * 1000.0 * (1.0 if i % 2 == 0 else -1.0), 0, -float(off[1]) * 1000.0)
		if lead == null:
			lead = u
		out = u
	return out


func _find_tag(tag: String):
	if tag == "player":
		return w.player
	for u in w.units:
		if u.tag == tag and u.alive():
			return u
	return null


func _spawn_air(ad: Dictionary) -> void:
	var n: int = ad.get("n", 1)
	for i in n:
		var p := km(ad["pos"]) + Vector3(float(i) * 1800.0, 0, float(i % 2) * 1500.0)
		var opts := {"tag": ad.get("tag", ""), "callsign": ad.get("callsign", "")}
		if ad.has("orbit"):
			opts["orbit"] = km(ad["orbit"])
			opts["state"] = "cap" if String(ad.get("type", "")) in ["f15", "f14", "mig31"] else "patrol"
		if ad.has("target_tag"):
			opts["target"] = _find_tag(ad["target_tag"])
		w.add_air(ad["type"], ad.get("side", "su"), p, float(ad.get("hdg", 0.0)), opts)
	if ad.has("radio"):
		w.radio(ad["radio"][0], ad["radio"][1])


func update(dt: float) -> void:
	var keep := []
	for e in pending:
		if _due(e):
			_fire(e)
		else:
			keep.append(e)
	pending = keep
	_eval_t -= dt
	if _eval_t > 0.0 or result != "":
		return
	_eval_t = 1.0
	for o in objectives:
		if o["state"] != "active":
			continue
		var st := _evaluate(o)
		if st != "active":
			o["state"] = st
			flags[String(o.get("id", "")) + "_" + st] = true
			w.emit({"t": "objective", "obj": o, "state": st})
	if w.player != null and (w.player.sinking or w.player.sunk):
		_finish("lost", "Your ship has been lost.")
		return
	var all_done := true
	var any_failed := false
	for o in objectives:
		if o.get("optional", false):
			continue
		if o["state"] == "failed":
			any_failed = true
		elif o["state"] != "done":
			all_done = false
	if any_failed:
		_finish("lost", "A primary objective has failed.")
	elif all_done and not objectives.is_empty():
		_finish("won", "All objectives complete.")
	elif def.has("time_limit") and w.t > float(def["time_limit"]):
		_finish("lost", "Time has run out.")


func _due(e: Dictionary) -> bool:
	if e.has("at") and w.t < float(e["at"]):
		return false
	if e.has("when") and not flags.get(e["when"], false):
		return false
	if e.has("near"):
		var q = _find_tag(e["near"][0])
		if q == null or w.player == null or U.flat_dist(q.pos, w.player.pos) > float(e["near"][1]) * 1000.0:
			return false
	return true


func _fire(e: Dictionary) -> void:
	if e.has("radio"):
		w.radio(e["radio"][0], e["radio"][1], e.get("kind", "radio"))
	if e.has("spawn"):
		for ud in e["spawn"]:
			_spawn_unit(ud)
	if e.has("spawn_air"):
		_spawn_air(e["spawn_air"])
	if e.has("set"):
		flags[e["set"]] = true
	if e.has("awacs"):
		w.awacs[player_side] = e["awacs"]


func _units(tag: String) -> Array:
	return w.units.filter(func(u): return u.tag == tag)


func _evaluate(o: Dictionary) -> String:
	match String(o["type"]):
		"destroy":
			var us := _units(o["tag"])
			if us.is_empty():
				return "active"
			var need: int = o.get("count", us.size())
			var dead := us.filter(func(u): return not u.alive() or u.destroyed).size()
			return "done" if dead >= need else "active"
		"protect":
			var us := _units(o["tag"])
			var alive := us.filter(func(u): return u.alive()).size()
			if alive < int(o.get("min", 1)):
				return "failed"
			if o.has("until") and w.t >= float(o["until"]):
				return "done"
			if o.has("until_flag") and flags.get(o["until_flag"], false):
				return "done"
			if o.has("reach"):
				var p := km(o["reach"])
				var arrived := us.filter(func(u): return u.alive() and U.flat_dist(u.pos, p) < float(o.get("r", 5.0)) * 1000.0).size()
				if arrived >= int(o.get("min", 1)):
					return "done"
			return "active"
		"deny":
			var us := _units(o["tag"])
			if us.is_empty():
				return "active"
			var p := km(o["pos"])
			for u in us:
				if u.alive() and U.flat_dist(u.pos, p) < float(o.get("r", 5.0)) * 1000.0:
					return "failed"
			var dead := us.filter(func(u): return not u.alive() or u.destroyed).size()
			return "done" if dead >= us.size() else "active"
		"survive":
			return "done" if w.t >= float(o["time"]) else "active"
		"bombard":
			var gs: Array = w.ground.filter(func(g): return g.get("tag", "") == o["tag"])
			if gs.is_empty():
				return "active"
			var need: int = o.get("count", gs.size())
			var dead := gs.filter(func(g): return not g["alive"]).size()
			return "done" if dead >= need else "active"
		"reach":
			if w.player != null and U.flat_dist(w.player.pos, km(o["pos"])) < float(o.get("r", 3.0)) * 1000.0:
				return "done"
			return "active"
		"intercept":
			if flags.get(o.get("flag", "raid_over"), false):
				return "done"
			return "active"
		"flag":
			return "done" if flags.get(o["flag"], false) else "active"
	return "active"


func _finish(r: String, why: String) -> void:
	result = r
	result_t = w.t
	w.emit({"t": "mission_end", "result": r, "why": why})


func objective_lines() -> Array:
	var out := []
	for o in objectives:
		var mark := "[ ]"
		if o["state"] == "done":
			mark = "[x]"
		elif o["state"] == "failed":
			mark = "[!]"
		var extra := ""
		if o["type"] == "survive" and o["state"] == "active":
			extra = "  (%s)" % U.clock(maxf(0.0, float(o["time"]) - w.t))
		elif (o["type"] == "destroy" or o["type"] == "deny") and o["state"] == "active":
			var us := _units(o["tag"])
			var dead := us.filter(func(u): return not u.alive() or u.destroyed).size()
			extra = "  (%d/%d)" % [dead, int(o.get("count", us.size()))]
		elif o["type"] == "bombard" and o["state"] == "active":
			var gs: Array = w.ground.filter(func(g): return g.get("tag", "") == o["tag"])
			extra = "  (%d/%d)" % [gs.filter(func(g): return not g["alive"]).size(), int(o.get("count", gs.size()))]
		out.append([mark, String(o["text"]) + extra, o["state"], o.get("optional", false)])
	return out
