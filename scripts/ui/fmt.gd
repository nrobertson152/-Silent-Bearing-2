extends RefCounted
## Text formatting for briefings, the map and ship cards.

const ShipData := preload("res://scripts/data/ships.gd")
const Weapons := preload("res://scripts/data/weapons.gd")

const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September",
	"October", "November", "December"]
## Typical wind speed (knots) for each sea state.
const WIND_KN := [2, 5, 9, 14, 19, 24, 30, 37, 44]
const PLANTS := {
	"gt_cpp": "gas turbines, controllable-pitch propellers",
	"gt": "gas turbines (COGAG)",
	"steam": "geared steam turbines",
	"nuclear": "pressurised-water reactor, steam turbine",
	"diesel": "diesel",
}


static func date(d: Array, add_days := 0) -> String:
	var unix := Time.get_unix_time_from_datetime_dict({"year": int(d[0]), "month": int(d[1]), "day": int(d[2]), "hour": 12})
	var dt := Time.get_datetime_dict_from_unix_time(unix + add_days * 86400)
	return "%d %s %d" % [dt["day"], MONTHS[int(dt["month"]) - 1], dt["year"]]


static func short_date(d: Array, add_days := 0) -> String:
	var unix := Time.get_unix_time_from_datetime_dict({"year": int(d[0]), "month": int(d[1]), "day": int(d[2]), "hour": 12})
	var dt := Time.get_datetime_dict_from_unix_time(unix + add_days * 86400)
	return "%02d %s %d" % [dt["day"], String(MONTHS[int(dt["month"]) - 1]).substr(0, 3).to_upper(), dt["year"]]


static func hhmm(hour: float) -> String:
	var m := int(round(fposmod(hour, 24.0) * 60.0))
	return "%02d%02d" % [(m / 60) % 24, m % 60]


static func weather(wx: Dictionary) -> String:
	var sea := int(round(float(wx.get("sea", 3.0))))
	var vis := float(wx.get("vis", 20.0))
	var cl := float(wx.get("clouds", 0.4))
	var sky := "clear" if cl < 0.2 else ("scattered cloud" if cl < 0.45 else ("broken cloud" if cl < 0.75 else "overcast"))
	return "Sea state %d  ·  wind %03d° %d kn  ·  visibility %s  ·  %s" % [sea, int(wx.get("wind", 0.0)),
		WIND_KN[clampi(sea, 0, 8)], ("%d km" % int(vis)) if vis >= 2.0 else ("%d m" % int(vis * 1000.0)), sky]


static func ship_name(cls_id: String) -> String:
	var c: Dictionary = ShipData.spec(cls_id)
	var desig: String = c.get("desig", "")
	var n: String = c.get("name", "")
	if c.get("side", "") == "us" and desig != "":
		return "%s (%s)" % [n, desig]
	return n


static func ship_type(cls_id: String) -> String:
	var c: Dictionary = ShipData.spec(cls_id)
	var cl: String = c.get("class", "")
	var base := cl.split(" (")[0]
	var proj := ""
	if cl.contains("("):
		proj = " (" + cl.split(" (")[1]
	return "%s-class %s%s" % [base, c.get("type", "ship"), proj]


## Specification lines for the ship card.
static func ship_specs(cls_id: String) -> Array:
	var c: Dictionary = ShipData.spec(cls_id)
	var out := []
	out.append(["Displacement", "%s tonnes full load" % _thousands(int(c.get("disp", 0)))])
	out.append(["Dimensions", "%.0f m long, %.1f m beam, %.1f m draught" % [c.get("length", 0.0), c.get("beam", 0.0), c.get("draft", 0.0)]])
	var pl: Dictionary = c.get("plant", {})
	var shafts := int(pl.get("shafts", 1))
	out.append(["Machinery", "%s, %s shp, %d shaft%s" % [PLANTS.get(pl.get("kind", ""), "?"), _thousands(int(pl.get("shp", 0))), shafts, "s" if shafts > 1 else ""]])
	var spd := "%.0f knots" % float(c.get("speed", 0.0))
	if c.has("surf_speed"):
		spd = "%.0f knots submerged, %.0f surfaced" % [float(c["speed"]), float(c["surf_speed"])]
	out.append(["Speed", spd])
	if c.has("test_depth"):
		out.append(["Diving depth", "%d m test, %d m collapse" % [int(c["test_depth"]), int(c.get("crush_depth", 0.0))]])
	var arm: Dictionary = c.get("armor", {})
	if arm.has("belt") and float(arm["belt"]) > 0.0:
		out.append(["Armour", "%d mm belt, %d mm deck" % [int(arm["belt"]), int(arm.get("deck", 0.0))]])
	out.append(["Crew", str(int(c.get("crew", 0)))])
	return out


## Armament, one line per mount type with its magazine.
static func armament(cls_id: String) -> Array:
	var c: Dictionary = ShipData.spec(cls_id)
	var counts := {}
	var ammo := {}
	var order := []
	for wd: Dictionary in c.get("weapons", []):
		var mid: String = wd["m"]
		if not counts.has(mid):
			counts[mid] = 0
			ammo[mid] = {}
			order.append(mid)
		counts[mid] += 1
		for a: String in (wd.get("ammo", {}) as Dictionary):
			ammo[mid][a] = int(ammo[mid].get(a, 0)) + int(wd["ammo"][a])
	var out := []
	for mid: String in order:
		var md: Dictionary = Weapons.mount(mid)
		var n: int = counts[mid]
		var line := ("%d × " % n if n > 1 else "") + String(md.get("name", mid))
		var mags := []
		for a: String in ammo[mid]:
			var mu: Dictionary = Weapons.mun(a)
			mags.append("%d %s" % [ammo[mid][a], _short_mun(String(mu.get("name", a)))])
		if not mags.is_empty():
			line += ": " + ", ".join(mags)
		out.append(line)
	return out


static func _short_mun(n: String) -> String:
	# "RGM-84 Harpoon" -> "Harpoon"; keep shell names whole.
	if n.begins_with("RGM-") or n.begins_with("RIM-") or n.begins_with("RUR-") or n.begins_with("BGM-"):
		return n.split(" ", true, 1)[1] if n.contains(" ") else n
	return n


static func _thousands(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


static func duration(secs: float) -> String:
	var s := int(secs)
	if s >= 3600:
		return "%d h %02d min" % [s / 3600, (s / 60) % 60]
	return "%d min %02d s" % [s / 60, s % 60]
