class_name SimMount
extends RefCounted
## One weapon mount: training and elevation at real rates within its arc,
## reload cycle, magazine and the currently selected munition.

const U := preload("res://scripts/util.gd")
const Weapons := preload("res://scripts/data/weapons.gd")

var u
var id := ""
var mtype := ""
var md := {}
var kind := "gun"
var group := "main"
var x := 0.0
var lpos := Vector3.ZERO
var face := 0.0
var arc_c := 0.0
var arc_w := 180.0
var train := 0.0
var elev := 0.0
var want_train := 0.0
var want_elev := 0.0
var train_rate := 20.0
var elev_rate := 10.0
var emin := -5.0
var emax := 45.0
var ammo := {}
var sel := ""
var reload := 0.0
var cycle := 3.0
var barrels := 1
var hp := 1.0
var armor := 0.0
var fixed := false
var cells := 0
var tubes := 0
var rounds := 0
var target = null
var aim_point := Vector3.ZERO
var has_aim := false
var auto := true
var last_shot := -100.0
var ready_t := 0.0


func _init(unit, wd: Dictionary) -> void:
	u = unit
	id = wd["id"]
	mtype = wd["m"]
	md = Weapons.mount(mtype)
	kind = md.get("kind", "gun")
	group = wd.get("g", "main")
	x = wd["x"]
	face = float(wd.get("face", (wd["arc"][0] if wd.has("arc") else 0.0)))
	if wd.has("arc"):
		arc_c = float(wd["arc"][0])
		arc_w = float(wd["arc"][1])
	else:
		arc_c = face
		arc_w = 180.0
	train = face
	want_train = face
	train_rate = md.get("train", 20.0)
	elev_rate = md.get("elev", 10.0)
	emin = md.get("emin", -5.0)
	emax = md.get("emax", 45.0)
	barrels = md.get("barrels", 1)
	armor = md.get("armor", 0.0)
	fixed = md.get("fixed", false) or kind == "vls"
	cells = wd.get("cells", 0)
	tubes = wd.get("tubes", 0)
	ammo = wd.get("ammo", {}).duplicate()
	if kind == "ciws":
		rounds = md.get("rounds", 1500)
	for k in ammo:
		sel = k
		break
	if kind == "gun":
		var rof: float = md.get("rof", 10.0)
		cycle = 60.0 / rof
	else:
		cycle = md.get("cycle", 3.0)
	var yrel: float = float(wd.get("rel", 0.0))
	var hull: Dictionary = u.cls.get("hull", {})
	var dy := _deck_y(hull, x)
	lpos = Vector3(float(wd.get("o", 0.0)), float(wd.get("y", dy + yrel)), x - u.L * 0.5)


static func _deck_y(hull: Dictionary, x: float) -> float:
	var fb: Array = hull.get("fb", [[0, 5.0]])
	if x <= fb[0][0]:
		return fb[0][1]
	for i in fb.size() - 1:
		if x <= fb[i + 1][0]:
			return lerpf(fb[i][1], fb[i + 1][1], (x - fb[i][0]) / maxf(fb[i + 1][0] - fb[i][0], 0.01))
	return fb[fb.size() - 1][1]


func alive() -> bool:
	return hp > 0.05


func world_pos() -> Vector3:
	return u.to_world(lpos)


func count() -> int:
	var n := 0
	for k in ammo:
		n += int(ammo[k])
	return n


func has(mun: String) -> bool:
	return int(ammo.get(mun, 0)) > 0


func mun() -> Dictionary:
	return Weapons.mun(sel)


## Relative bearing (deg from bow, clockwise) of a world point from this mount.
func rel_brg(p: Vector3) -> float:
	return U.wrap360(U.brg(world_pos(), p) - u.heading)


func in_arc(rel: float) -> bool:
	return absf(U.adiff(arc_c, rel)) <= arc_w + 0.01


func can_bear(p: Vector3) -> bool:
	if fixed:
		return true
	return in_arc(rel_brg(p))


## Point the mount (train) toward a world position and set desired elevation.
func aim_at(p: Vector3, el: float) -> void:
	var rel := rel_brg(p)
	if not in_arc(rel):
		var lo := U.wrap360(arc_c - arc_w)
		var hi := U.wrap360(arc_c + arc_w)
		rel = lo if absf(U.adiff(rel, lo)) < absf(U.adiff(rel, hi)) else hi
	want_train = rel
	want_elev = clampf(el, emin, emax)


func on_target(tol := 1.0) -> bool:
	if fixed:
		return true
	return absf(U.adiff(train, want_train)) <= tol and absf(elev - want_elev) <= tol * 0.7


func update(dt: float) -> void:
	if reload > 0.0:
		reload -= dt
	if fixed or not alive():
		return
	var dmg := 0.35 + 0.65 * hp
	var d := U.adiff(train, want_train)
	# Train the short way, but never through the blind arc.
	var mid := U.wrap360(train + d * 0.5)
	if not in_arc(mid) and absf(d) > 5.0:
		d = d - 360.0 * signf(d)
	train = U.wrap360(train + clampf(d, -train_rate * dmg * dt, train_rate * dmg * dt))
	elev = move_toward(elev, want_elev, elev_rate * dmg * dt)


func ready() -> bool:
	if not alive() or reload > 0.0:
		return false
	if kind == "ciws":
		return rounds > 0
	return has(sel)


## Consume one round/missile of the selected type; returns false when empty.
func take(n := 1) -> bool:
	var have := int(ammo.get(sel, 0))
	if have < n:
		return false
	ammo[sel] = have - n
	return true


func select_next() -> void:
	var keys := ammo.keys()
	if keys.is_empty():
		return
	var i := keys.find(sel)
	for k in keys.size():
		var j := (i + 1 + k) % keys.size()
		if int(ammo[keys[j]]) > 0:
			sel = keys[j]
			return


func select_role(role: String) -> bool:
	for k in ammo:
		var m := Weapons.mun(k)
		if int(ammo[k]) > 0 and String(m.get("role", "")) == role and not m.has("nuke"):
			sel = k
			return true
	return false
