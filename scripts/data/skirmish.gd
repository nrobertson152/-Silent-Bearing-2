extends RefCounted
## Free battle: builds a one-off mission from a ship, a kind of battle, a
## place, a time of day and the sea state. The opposition is matched to the
## tier of the ship you choose.

const ShipData := preload("res://scripts/data/ships.gd")

const KINDS := [
	["sag", "Surface action", "Your ship against an enemy surface group."],
	["duel", "Duel", "One enemy ship of your own tier, closing at speed."],
	["convoy_def", "Convoy defence", "Bring a convoy through a submarine and a bomber raid."],
	["convoy_atk", "Convoy attack", "Find and sink an escorted enemy convoy."],
	["air", "Air raid", "Survive two waves of strike aircraft and keep the oiler afloat."],
]

## [name, lat, lon, aurora]
const PLACES := [
	["Norwegian Sea", 66.0, 2.0, 0.0],
	["Denmark Strait", 66.6, -26.0, 0.5],
	["Off North Cape", 71.6, 25.0, 1.0],
	["South of Iceland", 62.5, -18.0, 0.2],
	["Off Cape Cod", 41.6, -68.5, 0.0],
]

## [name, local solar hour] on 22 September, the equinox.
const TIMES := [["Dawn", 6.3], ["Morning", 9.5], ["Afternoon", 14.5], ["Dusk", 18.1], ["Night", 23.0]]


static func foe_of(side: String) -> String:
	return "su" if side == "us" else "us"


## Surface classes of a side, by tier (the submarine tier maps to the frigate).
static func surface(side: String, tier: int) -> String:
	var order: Array = ShipData.ORDER[side]
	var t := clampi(tier, 0, 5)
	if t == 1:
		t = 0
	return order[t]


static func sub_of(side: String) -> String:
	return ShipData.ORDER[side][1]


static func build(cls: String, kind: String, place: int, time_idx: int, sea: float) -> Dictionary:
	var c: Dictionary = ShipData.spec(cls)
	var side: String = c.get("side", "us")
	var foe := foe_of(side)
	var tier := int(c.get("tier", 0))
	var is_sub := ShipData.is_sub(cls)
	if is_sub and kind == "air":
		kind = "convoy_def"
	var pl: Array = PLACES[clampi(place, 0, PLACES.size() - 1)]
	var tm: Array = TIMES[clampi(time_idx, 0, TIMES.size() - 1)]
	var kname := ""
	for k: Array in KINDS:
		if k[0] == kind:
			kname = k[1]
	var def := {
		"title": "Free battle: %s" % kname, "side": side, "ship": cls, "date": [1988, 9, 22], "time": float(tm[1]),
		"lat": float(pl[1]), "lon": float(pl[2]), "location": pl[0], "awacs": tier >= 3,
		"weather": {"sea": sea, "wind": 230.0, "vis": clampf(36.0 - sea * 3.5, 6.0, 32.0), "clouds": clampf(0.25 + sea * 0.08, 0.2, 0.85),
			"aurora": float(pl[3]) if float(tm[1]) > 20.0 or float(tm[1]) < 5.0 else 0.0},
		"player": {"pos": [0, 0], "hdg": 20.0, "speed": 8.0 if is_sub else 18.0, "depth": 60.0},
		"start_view": "external" if is_sub else "bridge",
		"units": [], "air": [], "objectives": [], "events": [],
	}
	var units: Array = def["units"]
	var air: Array = def["air"]
	var objs: Array = def["objectives"]
	var ev: Array = def["events"]
	match kind:
		"sag":
			var lead := surface(foe, 2 if is_sub else tier)
			units.append({"cls": lead, "side": foe, "pos": [6, 34], "hdg": 200.0, "speed": 20.0, "tag": "enemy", "ai": "patrol", "waypoints": [[0, 0]]})
			if tier >= 2 or is_sub:
				units.append({"cls": surface(foe, maxi(0, tier - 2)), "side": foe, "pos": [9, 37], "hdg": 200.0, "speed": 20.0, "tag": "enemy",
					"ai": "escort", "lead": "enemy", "offset": [3.0, 1.5]})
			if tier >= 5:
				units.append({"cls": surface(foe, 2), "side": foe, "pos": [3, 37], "hdg": 200.0, "speed": 20.0, "tag": "enemy",
					"ai": "escort", "lead": "enemy", "offset": [-3.0, 1.5]})
			objs.append({"id": "o1", "text": "Destroy the enemy surface group", "type": "destroy", "tag": "enemy"})
			ev.append({"at": 4.0, "radio": ["Fleet", "Enemy surface group to the north-north-east, about 35 km. Weapons free."]})
		"duel":
			var e := sub_of(foe) if is_sub else surface(foe, tier)
			var u := {"cls": e, "side": foe, "pos": [4, 30], "hdg": 195.0, "speed": 10.0 if is_sub else 24.0, "tag": "enemy", "ai": "patrol",
				"waypoints": [[0, 0]], "aggression": 1.2}
			if is_sub:
				u["depth"] = 120.0
				u["pos"] = [5, 22]
			units.append(u)
			objs.append({"id": "o1", "text": "Sink the enemy %s" % String(ShipData.spec(e).get("type", "ship")), "type": "destroy", "tag": "enemy"})
			ev.append({"at": 4.0, "radio": ["Fleet", "Single enemy %s closing from the north. It's you or them." % String(ShipData.spec(e).get("type", "ship"))]})
		"convoy_def":
			units.append({"cls": "merchant", "side": side, "pos": [-3, -3], "hdg": 20.0, "speed": 12.0, "n": 3, "cols": 3, "spacing": 1.2,
				"tag": "convoy", "ai": "convoy", "waypoints": [[25, 70]]})
			units.append({"cls": sub_of(foe), "side": foe, "pos": [12, 28], "hdg": 200.0, "speed": 5.0, "depth": 90.0, "tag": "sub",
				"ai": "patrol", "waypoints": [[2, 8], [12, 28]]})
			if not is_sub:
				air.append(_raid(foe, 420.0, [-60, 260], 160.0, 4))
			objs.append({"id": "o1", "text": "Keep at least two ships of the convoy afloat for 25 minutes", "type": "protect", "tag": "convoy", "min": 2, "until": 1500.0})
			objs.append({"id": "o2", "text": "Sink the enemy submarine", "type": "destroy", "tag": "sub", "optional": true})
			ev.append({"at": 4.0, "radio": ["Commodore", "Convoy is formed up, course zero-two-zero. Submarine reported ahead of us."]})
		"convoy_atk":
			units.append({"cls": "merchant", "side": foe, "pos": [8, 40], "hdg": 250.0, "speed": 12.0, "n": 3, "cols": 3, "spacing": 1.3,
				"tag": "convoy", "ai": "convoy", "waypoints": [[-60, 20]]})
			units.append({"cls": surface(foe, 0 if tier < 3 else 2), "side": foe, "pos": [8, 38], "hdg": 250.0, "speed": 12.0,
				"tag": "escort", "ai": "escort", "lead": "convoy", "offset": [2.5, -1.5]})
			if is_sub:
				def["player"]["pos"] = [-6, 18]
				def["player"]["hdg"] = 60.0
			objs.append({"id": "o1", "text": "Sink the convoy", "type": "destroy", "tag": "convoy"})
			objs.append({"id": "o2", "text": "Sink the escort", "type": "destroy", "tag": "escort", "optional": true})
			ev.append({"at": 4.0, "radio": ["Fleet", "Enemy convoy, three ships and an escort, bearing about zero-one-zero, 40 km, heading west."]})
		_:
			units.append({"cls": "tanker", "side": side, "pos": [-2, -2], "hdg": 20.0, "speed": 12.0, "tag": "convoy", "ai": "convoy",
				"waypoints": [[25, 70]], "name": "USNS Neosho" if side == "us" else "Dubna"})
			air.append(_raid(foe, 60.0, [40, 260], 190.0, 4))
			air.append(_raid(foe, 540.0, [-120, 230], 150.0, 6))
			objs.append({"id": "o1", "text": "Survive both raids (15 minutes)", "type": "survive", "time": 900.0})
			objs.append({"id": "o2", "text": "Keep the oiler afloat", "type": "protect", "tag": "convoy", "min": 1})
			ev.append({"at": 4.0, "radio": ["Fleet", "Strike aircraft are massing to the north. Expect two waves. Defend the oiler."]})
	return def


static func _raid(foe: String, at: float, pos: Array, hdg: float, n: int) -> Dictionary:
	var type := "tu22m" if foe == "su" else "a6"
	var name := "Backfires" if foe == "su" else "Intruders"
	return {"type": type, "side": foe, "at": at, "pos": pos, "hdg": hdg, "n": n, "tag": "raid",
		"radio": ["CIC", "Raid warning: %d %s inbound." % [n, name]]}
