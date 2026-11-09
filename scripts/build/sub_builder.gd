extends RefCounted
## Nuclear attack submarines: Los Angeles (teardrop bow, tall sail with
## fairwater planes, cruciform stern) and Akula (bulky double hull, low
## blended sail, towed-array pod on the rudder).

const MeshKit := preload("res://scripts/build/mesh_kit.gd")
const Mats := preload("res://scripts/build/materials.gd")
const ShipData := preload("res://scripts/data/ships.gd")


static func build(class_id: String) -> Node3D:
	var c := ShipData.spec(class_id)
	var s: Dictionary = c["sub"]
	var L: float = c["length"]
	var D: float = s["hull_d"]
	var R := D * 0.5
	var akula: bool = s.get("fins", "") == "akula"
	var mats := Mats.navy(c["side"])
	var k := MeshKit.new(mats)
	var root := Node3D.new()
	root.name = class_id
	var bow := Vector3(0, 0, -L * 0.5)
	var stern := Vector3(0, 0, L * 0.5)
	var prof := []
	for i in 25:
		var t := float(i) / 24.0
		var r := R
		if t < 0.12:
			r = R * sqrt(1.0 - pow(1.0 - t / 0.12, 2.0))
		elif t > (0.62 if akula else 0.7):
			var t0 := 0.62 if akula else 0.7
			var u := (t - t0) / (1.0 - t0)
			r = R * (1.0 - pow(u, 1.6)) + 0.35 * u
		prof.append(Vector2(t, maxf(r, 0.05)))
	k.lathe("sub", bow, stern, prof, 24, 1.0 if not akula else 0.92)
	if akula:
		# The "hump" of the outer casing ahead of the sail and the flat deck.
		k.lathe("sub", Vector3(0, R * 0.25, -L * 0.18), Vector3(0, R * 0.25, L * 0.2),
			[Vector2(0, 0.1), Vector2(0.15, R * 0.75), Vector2(0.8, R * 0.75), Vector2(1, 0.1)], 18, 0.6)
	# Sail.
	var sx: float = s["sail_x"]
	var sl: float = s["sail_l"]
	var sh: float = s["sail_h"]
	var sw: float = s["sail_w"]
	var sz := sx - L * 0.5
	var poly := []
	for i in 16:
		var a := TAU * i / 16.0
		var px := cos(a) * sw * 0.5
		var pz := sin(a) * sl * 0.5
		if pz > 0.0:
			pz *= 1.0 if not akula else 1.6
		poly.append(Vector2(px, sz + pz))
	k.prism("sub", poly, R * 0.7, R + sh, "sub")
	if akula:
		var back := []
		for p in poly:
			back.append(Vector2(p.x * 0.8, p.y + sl * 0.15))
		k.prism("sub", back, R * 0.7, R + sh * 0.55, "sub")
	# Masts.
	var mast := Node3D.new()
	mast.name = "Masts"
	mast.position = Vector3(0, R + sh, sz - sl * 0.15)
	root.add_child(mast)
	var km := MeshKit.new(mats)
	km.cyl("sub", Vector3(0, 0, 0), Vector3(0, 4.0, 0), 0.22, 0.18, 8)
	km.cyl("dark", Vector3(0, 4.0, 0), Vector3(0, 4.5, 0), 0.18, 0.14, 8)
	km.cyl("sub", Vector3(0.6, 0, 0.8), Vector3(0.6, 3.2, 0.8), 0.18, 0.15, 8)
	km.box("sub", Vector3(-0.5, 2.2, 1.2), Vector3(0.6, 1.0, 0.25))
	var mi := km.instance("Mesh")
	mast.add_child(mi)
	mast.visible = false
	# Planes: fairwater planes on the sail (688) or retractable bow planes (Akula).
	if s.get("planes", "sail") == "sail":
		for side: float in [-1.0, 1.0]:
			k.hexa("sub", _fin(Vector3(side * sw * 0.5, R + sh * 0.6, sz - sl * 0.2), Vector3(side, 0, 0), 3.4, 2.2, 1.4))
	else:
		for side: float in [-1.0, 1.0]:
			k.hexa("sub", _fin(Vector3(side * R * 0.8, -R * 0.1, -L * 0.36), Vector3(side, 0, 0), 2.6, 2.0, 1.4))
	# Stern control surfaces.
	var fz := L * 0.5 - L * 0.11
	var fr := R * 0.55
	for dir in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0)]:
		k.hexa("sub", _fin(Vector3(0, 0, fz) + dir * fr, dir, R * 1.05, 4.6, 2.6))
	if not akula:
		for side: float in [-1.0, 1.0]:
			k.box("sub", Vector3(side * (fr + R * 1.05), 0, fz + 0.5), Vector3(0.15, 1.8, 3.2))
	else:
		k.lathe("sub", Vector3(0, fr + R * 1.0, fz - 3.0), Vector3(0, fr + R * 1.0, fz + 4.0),
			[Vector2(0, 0.2), Vector2(0.2, 1.0), Vector2(0.8, 1.0), Vector2(1, 0.3)], 12)
	# Propeller.
	var pc := Vector3(0, 0, L * 0.5 + 0.4)
	var blades: int = s.get("blades", 7)
	var prop := Node3D.new()
	prop.name = "Prop"
	prop.position = pc
	root.add_child(prop)
	var kp := MeshKit.new(mats)
	kp.cyl("dark", Vector3(0, 0, -0.6), Vector3(0, 0, 0.6), 0.5, 0.3, 10)
	for i in blades:
		var a := TAU * i / blades
		var tip := Vector3(cos(a + 0.4), sin(a + 0.4), 0.2) * R * 0.75
		kp.tri("prop", Vector3(cos(a), sin(a), -0.2) * 0.4, tip, Vector3(cos(a + 0.7), sin(a + 0.7), 0.1) * 0.5, Vector3(0, 0, 1))
	prop.add_child(kp.instance("Mesh"))
	root.add_child(k.instance("Hull"))
	root.set_meta("mounts", {})
	root.set_meta("radars", [])
	root.set_meta("smoke", [])
	root.set_meta("lights", [])
	root.set_meta("bridge", {})
	root.set_meta("class", class_id)
	root.set_meta("length", L)
	root.set_meta("masts", mast)
	root.set_meta("prop", prop)
	return root


## Thin tapered fin rooted at `root` sticking out along `out`.
static func _fin(root: Vector3, out: Vector3, span: float, chord: float, tip_chord: float) -> Array:
	var up := Vector3(0, 1, 0) if absf(out.y) < 0.5 else Vector3(1, 0, 0)
	var t := 0.18
	var tip := root + out * span
	return [root + Vector3(0, 0, -chord * 0.5) - up * t, root + Vector3(0, 0, chord * 0.5) - up * t,
		tip + Vector3(0, 0, chord * 0.5) - up * t * 0.5, tip + Vector3(0, 0, chord * 0.5 - tip_chord) - up * t * 0.5,
		root + Vector3(0, 0, -chord * 0.5) + up * t, root + Vector3(0, 0, chord * 0.5) + up * t,
		tip + Vector3(0, 0, chord * 0.5) + up * t * 0.5, tip + Vector3(0, 0, chord * 0.5 - tip_chord) + up * t * 0.5]
