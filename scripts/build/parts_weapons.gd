extends RefCounted
## Weapon mount models. Every mount gets a training node (rotates about Y), an
## optional elevation node (rotates about X) and per-barrel recoil nodes.
## Guns point down -Z at train 0. Muzzle positions are in elevation-node space
## (or train-node space for launchers without one).

const MeshKit := preload("res://scripts/build/mesh_kit.gd")
const Weapons := preload("res://scripts/data/weapons.gd")

## Gunhouse and barrel proportions: w, l, h, front (z of the face at the base),
## slope (how far the roof edge sits behind the face), taper, n barrels, spacing,
## bl barrel length, br/bt root/tip radius, ty/tz trunnion, barbette radius, rf
## rangefinder length, bag (blast bags), round (domed gunhouse).
const GUNS := {
	"mk7": {"w": 12.6, "l": 17.6, "h": 3.9, "front": -6.6, "slope": 2.7, "taper": 0.7, "n": 3, "sp": 3.05, "bl": 20.3, "br": 0.42, "bt": 0.24, "ty": 2.0, "tz": -3.9, "barb": 6.4, "rf": 14.0, "bag": true},
	"b37": {"w": 13.8, "l": 19.0, "h": 4.3, "front": -7.0, "slope": 3.0, "taper": 0.6, "n": 3, "sp": 3.2, "bl": 20.3, "br": 0.43, "bt": 0.25, "ty": 2.1, "tz": -4.1, "barb": 6.6, "rf": 12.0, "bag": true},
	"mk16": {"w": 9.0, "l": 12.2, "h": 3.4, "front": -4.6, "slope": 1.9, "taper": 0.5, "n": 3, "sp": 1.95, "bl": 11.2, "br": 0.26, "bt": 0.15, "ty": 1.7, "tz": -3.0, "barb": 4.6, "rf": 0.0, "bag": true},
	"b38": {"w": 8.0, "l": 10.4, "h": 3.1, "front": -4.2, "slope": 1.4, "taper": 0.4, "n": 3, "sp": 1.6, "bl": 8.7, "br": 0.21, "bt": 0.12, "ty": 1.5, "tz": -2.6, "barb": 4.0, "rf": 8.0, "bag": true},
	"mk4_152": {"w": 6.4, "l": 8.6, "h": 3.0, "front": -3.6, "slope": 1.3, "taper": 0.4, "n": 2, "sp": 1.8, "bl": 8.7, "br": 0.21, "bt": 0.12, "ty": 1.5, "tz": -2.2, "barb": 3.4, "rf": 6.0, "bag": true},
	"sm5": {"w": 4.2, "l": 5.6, "h": 2.4, "front": -2.4, "slope": 1.0, "taper": 0.3, "n": 2, "sp": 1.1, "bl": 5.6, "br": 0.13, "bt": 0.08, "ty": 1.2, "tz": -1.5, "barb": 2.0, "rf": 0.0, "bag": false},
	"mk38": {"w": 4.6, "l": 6.2, "h": 2.8, "front": -2.6, "slope": 0.9, "taper": 0.3, "n": 2, "sp": 1.2, "bl": 4.85, "br": 0.14, "bt": 0.085, "ty": 1.3, "tz": -1.6, "barb": 2.4, "rf": 0.0, "bag": true},
	"ak130": {"w": 4.4, "l": 7.0, "h": 2.8, "front": -3.0, "slope": 1.5, "taper": 0.65, "n": 2, "sp": 1.3, "bl": 7.0, "br": 0.17, "bt": 0.1, "ty": 1.3, "tz": -1.8, "barb": 2.6, "rf": 0.0, "bag": false},
	"ak100": {"w": 3.4, "l": 5.6, "h": 2.4, "front": -2.4, "slope": 1.35, "taper": 0.5, "n": 1, "sp": 0.0, "bl": 5.9, "br": 0.13, "bt": 0.08, "ty": 1.15, "tz": -1.4, "barb": 1.9, "rf": 0.0, "bag": false},
	"mk45": {"w": 3.4, "l": 5.4, "h": 2.4, "front": -2.2, "slope": 1.65, "taper": 0.6, "n": 1, "sp": 0.0, "bl": 6.86, "br": 0.13, "bt": 0.075, "ty": 1.25, "tz": -1.0, "barb": 1.9, "rf": 0.0, "bag": false},
	"ak726": {"w": 3.0, "l": 4.0, "h": 1.9, "front": -1.8, "n": 2, "sp": 0.75, "bl": 4.4, "br": 0.1, "bt": 0.07, "ty": 1.1, "tz": -0.9, "barb": 1.6, "round": true},
	"mk75": {"w": 3.4, "l": 4.6, "h": 2.2, "front": -2.2, "n": 1, "sp": 0.0, "bl": 4.7, "br": 0.11, "bt": 0.08, "ty": 1.1, "tz": -0.9, "barb": 1.7, "round": true, "brake": true},
}


static func mount(b, w: Dictionary) -> void:
	var md := Weapons.mount(w["m"])
	var model: String = md.get("model", "")
	if model == "":
		return
	var x: float = w["x"]
	var o: float = w.get("o", 0.0)
	var y: float = b.base_y(w, x)
	var face: float = w.get("face", (w["arc"][0] if w.has("arc") else 0.0))
	var pos := Vector3(o, y, b.z(x))
	var train: Node3D = b.node("mount_" + String(w["id"]), pos)
	train.rotation.y = -deg_to_rad(face)
	var info := {"node": train, "elev": null, "muzzles": [], "face": face, "recoil": [], "kind": md["kind"]}
	if GUNS.has(model):
		_gun(b, train, info, GUNS[model], pos, float(w.get("rel", 0.0)))
	else:
		match model:
			"phalanx": _phalanx(b, train, info, pos)
			"ak630": _ak630(b, train, info, pos)
			"mk13": _mk13(b, train, info, pos)
			"mk41": _vls(b, train, info, pos, 8, 8, 0.64, true)
			"sm233": _vls(b, train, info, pos, w.get("grid", [4, 5])[0], w.get("grid", [4, 5])[1], 1.9, false)
			"b203": _revolvers(b, train, info, pos, w.get("grid", [2, 6]))
			"mk143": _abl(b, train, info)
			"mk141": _harpoon(b, train, info)
			"mk29": _mk29(b, train, info, pos)
			"kt106": _metel(b, train, info)
			"zif122": _osa(b, train, info, pos)
			"kt190": _moskit(b, train, info)
			"3s90": _uragan(b, train, info, pos)
			"rbu6000": _rbu(b, train, info, pos, 12, 0.11)
			"rbu1000": _rbu(b, train, info, pos, 6, 0.15)
			"mk32": _tubes(b, train, info, pos, 3, 0.18, 3.2, true)
			"pta53": _tubes(b, train, info, pos, 4, 0.33, 7.4, false)
			"dta53": _tubes(b, train, info, pos, 2, 0.33, 7.4, false)
	b.mounts[w["id"]] = info


static func _elev(train: Node3D, pos: Vector3) -> Node3D:
	var e := Node3D.new()
	e.name = "Elev"
	e.position = pos
	train.add_child(e)
	return e


static func _gun(b, train: Node3D, info: Dictionary, s: Dictionary, pos: Vector3, rel: float) -> void:
	var kt: MeshKit = b.kit()
	var w: float = s["w"]
	var l: float = s["l"]
	var h: float = s["h"]
	var f: float = s["front"]
	var back := f + l
	if s.get("round", false):
		kt.cyl("super", Vector3(0, -0.1, (f + back) * 0.5), Vector3(0, h * 0.45, (f + back) * 0.5), w * 0.5, w * 0.5, 16, false)
		kt.sphere("super", Vector3(0, h * 0.45, (f + back) * 0.5), 1.0, 16, 8, Vector3(w * 0.5, h * 0.62, l * 0.5), true)
	else:
		var sl: float = s["slope"]
		var tp: float = s.get("taper", 0.3)
		var hw := w * 0.5
		kt.hexa("super", [Vector3(-hw, 0, f), Vector3(hw, 0, f), Vector3(hw, 0, back), Vector3(-hw, 0, back),
			Vector3(-hw + tp, h, f + sl), Vector3(hw - tp, h, f + sl), Vector3(hw - tp, h, back - tp * 0.5), Vector3(-hw + tp, h, back - tp * 0.5)], "super")
		# Overhang at the rear and roof fittings.
		kt.box("super", Vector3(0, h * 0.55, back + 0.3), Vector3(w - tp * 2.0, h * 0.8, 0.6))
		kt.box("super", Vector3(-w * 0.25, h + 0.25, back - l * 0.35), Vector3(0.7, 0.5, 0.9))
		kt.box("super", Vector3(w * 0.25, h + 0.25, back - l * 0.35), Vector3(0.7, 0.5, 0.9))
		if l > 9.0:
			kt.box("dark", Vector3(0, h + 0.05, back - l * 0.55), Vector3(w * 0.5, 0.1, 1.0))
			for i in 6:
				kt.cyl("dark", Vector3(-w * 0.35 + i * w * 0.14, h - 0.2, back - 1.2), Vector3(-w * 0.35 + i * w * 0.14, h + 0.25, back - 1.2), 0.12, 0.12, 6)
	var rf: float = s.get("rf", 0.0)
	if rf > 0.0:
		var rz := back - 2.2
		kt.cyl("super", Vector3(-rf * 0.5, h * 0.7, rz), Vector3(rf * 0.5, h * 0.7, rz), 0.42, 0.42, 10)
		for sd: float in [-1.0, 1.0]:
			kt.box("super", Vector3(sd * rf * 0.5, h * 0.7, rz), Vector3(0.8, 1.2, 1.4))
			kt.box("black", Vector3(sd * rf * 0.5, h * 0.7, rz - 0.71), Vector3(0.5, 0.35, 0.02))
	b.attach(train, kt, "House")
	var elev := _elev(train, Vector3(0, s["ty"], s["tz"]))
	info["elev"] = elev
	var n: int = s["n"]
	var bl: float = s["bl"]
	var br: float = s["br"]
	var bt: float = s["bt"]
	var face_z: float = f + (s.get("slope", 0.0) * (float(s["ty"]) / h)) - float(s["tz"])
	for i in n:
		var bx := (i - (n - 1) * 0.5) * float(s["sp"])
		var bn := Node3D.new()
		bn.name = "Barrel%d" % i
		bn.position = Vector3(bx, 0, 0)
		elev.add_child(bn)
		var kb: MeshKit = b.kit()
		kb.cyl("gun", Vector3(0, 0, 0.8), Vector3(0, 0, face_z - 0.4), br * 1.05, br, 12, false)
		kb.cyl("gun", Vector3(0, 0, face_z - 0.4), Vector3(0, 0, -bl * 0.45), br, lerpf(br, bt, 0.55), 12, false)
		kb.cyl("gun", Vector3(0, 0, -bl * 0.45), Vector3(0, 0, -bl + 0.4), lerpf(br, bt, 0.55), bt, 12, false)
		kb.cyl("gun", Vector3(0, 0, -bl + 0.4), Vector3(0, 0, -bl), bt * 1.18, bt * 1.18, 12, true, "black")
		if s.get("bag", false):
			kb.cyl("canvas", Vector3(0, 0, face_z + 0.3), Vector3(0, 0, face_z - 0.9), br * 1.7, br * 1.25, 12, false)
		if s.get("brake", false):
			kb.cyl("gun", Vector3(0, 0, -bl * 0.55), Vector3(0, 0, -bl * 0.42), br * 1.6, br * 1.6, 10)
			kb.cyl("gun", Vector3(0, 0, -bl + 0.35), Vector3(0, 0, -bl), bt * 1.9, bt * 1.9, 10)
		b.attach(bn, kb, "Barrel")
		info["recoil"].append(bn)
		info["muzzles"].append(Vector3(bx, 0, -bl))
	var barb: float = s.get("barb", 0.0)
	if barb > 0.0:
		var depth := rel + 0.6 if rel > 0.5 else 0.6
		b.k.cyl("super", pos + Vector3(0, -depth, 0), pos + Vector3(0, 0.05, 0), barb, barb, 24, true, "deck")


static func _phalanx(b, train: Node3D, info: Dictionary, pos: Vector3) -> void:
	b.k.cyl("super", pos + Vector3(0, -0.5, 0), pos + Vector3(0, 0.6, 0), 0.8, 0.75, 12, true, "deck")
	var kt: MeshKit = b.kit()
	kt.cyl("super", Vector3(0, 0.6, 0), Vector3(0, 0.9, 0), 0.7, 0.7, 12)
	kt.box("super", Vector3(0, 1.4, 0.15), Vector3(1.1, 1.0, 1.3))
	kt.cyl("dome", Vector3(0, 1.9, 0.1), Vector3(0, 2.8, 0.1), 0.56, 0.56, 14)
	kt.sphere("dome", Vector3(0, 2.8, 0.1), 0.56, 14, 8, Vector3.ONE, true)
	kt.box("dome", Vector3(0, 2.2, -0.42), Vector3(0.8, 0.6, 0.2))
	b.attach(train, kt, "House")
	var elev := _elev(train, Vector3(0, 1.45, -0.3))
	info["elev"] = elev
	var kb: MeshKit = b.kit()
	kb.cyl("gun", Vector3(0, 0, 0.3), Vector3(0, 0, -0.5), 0.2, 0.2, 10)
	kb.cyl("dark", Vector3(0, 0, -0.5), Vector3(0, 0, -1.7), 0.13, 0.11, 8)
	b.attach(elev, kb, "Gun")
	info["muzzles"].append(Vector3(0, 0, -1.7))


static func _ak630(b, train: Node3D, info: Dictionary, pos: Vector3) -> void:
	b.k.cyl("super", pos + Vector3(0, -0.5, 0), pos + Vector3(0, 0.3, 0), 0.9, 0.9, 12, true, "deck")
	var kt: MeshKit = b.kit()
	kt.cyl("super", Vector3(0, 0.3, 0), Vector3(0, 0.8, 0), 0.85, 0.82, 14)
	kt.sphere("super", Vector3(0, 0.8, 0.05), 1.0, 14, 8, Vector3(0.82, 0.7, 0.9), true)
	b.attach(train, kt, "House")
	var elev := _elev(train, Vector3(0, 1.0, -0.4))
	info["elev"] = elev
	var kb: MeshKit = b.kit()
	kb.cyl("gun", Vector3(0, 0, 0.2), Vector3(0, 0, -0.9), 0.2, 0.18, 10)
	kb.cyl("dark", Vector3(0, 0, -0.9), Vector3(0, 0, -1.8), 0.15, 0.14, 8)
	b.attach(elev, kb, "Gun")
	info["muzzles"].append(Vector3(0, 0, -1.8))


static func _mk13(b, train: Node3D, info: Dictionary, pos: Vector3) -> void:
	b.k.cyl("super", pos + Vector3(0, -0.5, 0), pos + Vector3(0, 0.45, 0), 2.3, 2.3, 24, true, "deck")
	var kt: MeshKit = b.kit()
	kt.cyl("super", Vector3(0, 0.45, 0), Vector3(0, 1.7, 0), 0.65, 0.55, 12)
	kt.box("super", Vector3(0, 1.5, 0.2), Vector3(1.2, 0.9, 1.0))
	b.attach(train, kt, "Base")
	var elev := _elev(train, Vector3(0, 1.8, 0))
	info["elev"] = elev
	var kb: MeshKit = b.kit()
	kb.box("super", Vector3(0, 0, -1.2), Vector3(0.45, 0.45, 3.4))
	kb.cyl("white", Vector3(0, 0.42, 1.0), Vector3(0, 0.42, -3.3), 0.17, 0.17, 10)
	kb.cyl("white", Vector3(0, 0.42, -3.3), Vector3(0, 0.42, -3.8), 0.17, 0.0, 10)
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		kb.box("white", Vector3(cos(a) * 0.32, 0.42 + sin(a) * 0.32, 0.6), Vector3(0.04 + absf(cos(a)) * 0.3, 0.04 + absf(sin(a)) * 0.3, 0.6))
	b.attach(elev, kb, "Arm")
	info["muzzles"].append(Vector3(0, 0.42, -3.8))


static func _vls(b, train: Node3D, info: Dictionary, pos: Vector3, nx: int, nz: int, cell: float, us: bool) -> void:
	var kt: MeshKit = b.kit()
	var x0 := -nx * cell * 0.5
	var z0 := -nz * cell * 0.5
	kt.hatch_grid("dark" if us else "super", "deck", x0, z0, nx, nz, cell, 0.08, 0.06 if us else 0.18)
	if us:
		kt.box("super", Vector3(x0 + cell * 1.5, 0.6, z0 + nz * cell - cell * 0.75), Vector3(cell * 3.0, 1.2, cell * 1.5))
	b.attach(train, kt, "Cells")
	for i in nx:
		for j in nz:
			info["muzzles"].append(Vector3(x0 + (i + 0.5) * cell, 0.2, z0 + (j + 0.5) * cell))


static func _revolvers(b, train: Node3D, info: Dictionary, pos: Vector3, grid: Array) -> void:
	var kt: MeshKit = b.kit()
	var nx: int = grid[0]
	var nz: int = grid[1]
	var sp := 2.9
	for i in nx:
		for j in nz:
			var c := Vector3((i - (nx - 1) * 0.5) * sp, 0.06, (j + 0.5) * sp)
			kt.cyl("super", c - Vector3(0, 0.2, 0), c, 1.35, 1.35, 20, true, "deck")
			kt.disc("dark", c + Vector3(0, 0.01, 0), Vector3.UP, 1.15, 20)
			for k in 8:
				var a := TAU * k / 8.0
				kt.box("super", c + Vector3(cos(a) * 0.55, 0.03, sin(a) * 0.55), Vector3(0.06 + absf(sin(a)) * 1.0, 0.03, 0.06 + absf(cos(a)) * 1.0))
			info["muzzles"].append(c + Vector3(0.6, 0.2, 0))
	b.attach(train, kt, "Cells")


static func _abl(b, train: Node3D, info: Dictionary) -> void:
	var kt: MeshKit = b.kit()
	kt.box("super", Vector3(0, 1.05, 0), Vector3(1.9, 1.5, 6.4))
	kt.box("super", Vector3(0, 0.15, 0), Vector3(2.4, 0.3, 6.0))
	kt.box("dark", Vector3(0, 1.05, -3.21), Vector3(1.6, 1.2, 0.02))
	for s: float in [-1.0, 1.0]:
		kt.bar("dark", Vector3(s * 1.0, 0.3, 2.6), Vector3(s * 1.0, 1.6, 1.6), 0.15)
	b.attach(train, kt, "Box")
	info["muzzles"].append(Vector3(0, 1.4, -3.3))


static func _harpoon(b, train: Node3D, info: Dictionary) -> void:
	var kt: MeshKit = b.kit()
	var bas := Basis(Vector3.RIGHT, deg_to_rad(35.0))
	kt.box("super", Vector3(0, 0.4, 0), Vector3(1.8, 0.8, 2.6))
	for i in 2:
		for j in 2:
			var c := Vector3((i - 0.5) * 0.78, 1.25 + j * 0.74, 0.2)
			var a := c + bas * Vector3(0, 0, 2.3)
			var e := c + bas * Vector3(0, 0, -2.3)
			kt.cyl("pale", a, e, 0.34, 0.34, 10, true, "dark")
			for r in 3:
				var rc := a.lerp(e, 0.2 + r * 0.3)
				kt.cyl("super", rc + bas * Vector3(0, 0, 0.08), rc - bas * Vector3(0, 0, 0.08), 0.37, 0.37, 10, false)
			info["muzzles"].append(e)
	kt.bar("super", Vector3(-0.9, 0.8, 1.4), Vector3(-0.9, 2.2, -0.6), 0.14)
	kt.bar("super", Vector3(0.9, 0.8, 1.4), Vector3(0.9, 2.2, -0.6), 0.14)
	b.attach(train, kt, "Canisters")


static func _mk29(b, train: Node3D, info: Dictionary, pos: Vector3) -> void:
	b.k.cyl("super", pos + Vector3(0, -0.5, 0), pos + Vector3(0, 0.3, 0), 1.3, 1.3, 14, true, "deck")
	var kt: MeshKit = b.kit()
	kt.cyl("super", Vector3(0, 0.3, 0), Vector3(0, 1.2, 0), 0.6, 0.5, 10)
	for s: float in [-1.0, 1.0]:
		kt.box("super", Vector3(s * 1.15, 1.6, 0), Vector3(0.25, 1.2, 0.6))
	b.attach(train, kt, "Base")
	var elev := _elev(train, Vector3(0, 1.8, 0))
	info["elev"] = elev
	var kb: MeshKit = b.kit()
	kb.box("super", Vector3(0, 0, -0.6), Vector3(1.9, 1.4, 4.0))
	for i in 4:
		for j in 2:
			kb.rect_uv("dark", Vector3(-0.66 + i * 0.44, -0.3 + j * 0.6, -2.61), Vector3(0, 0, -1), Vector3.UP, Vector2(0.36, 0.5))
	b.attach(elev, kb, "Box")
	info["muzzles"].append(Vector3(0, 0, -2.7))


static func _metel(b, train: Node3D, info: Dictionary) -> void:
	var kt: MeshKit = b.kit()
	var bas := Basis(Vector3.RIGHT, deg_to_rad(12.0))
	var c := Vector3(0, 1.9, 0.6)
	kt.box("super", c, Vector3(4.6, 2.8, 9.4), bas)
	kt.box("super", Vector3(0, 0.6, 0.6), Vector3(4.2, 1.2, 7.0))
	for i in 2:
		for j in 2:
			var dc := c + bas * Vector3((i - 0.5) * 2.0, (j - 0.5) * 1.3, -4.71)
			kt.disc("dark", dc, bas * Vector3(0, 0, -1), 0.5, 14)
			info["muzzles"].append(dc)
	b.attach(train, kt, "Box")


static func _osa(b, train: Node3D, info: Dictionary, pos: Vector3) -> void:
	b.k.cyl("super", pos + Vector3(0, -0.5, 0), pos + Vector3(0, 0.9, 0), 2.2, 2.2, 24, true, "deck")
	b.k.box("dark", pos + Vector3(0, 0.91, 0), Vector3(0.08, 0.02, 4.2))
	var kt: MeshKit = b.kit()
	kt.cyl("super", Vector3(0, 0.9, 0), Vector3(0, 1.8, 0), 0.4, 0.35, 10)
	b.attach(train, kt, "Base")
	var elev := _elev(train, Vector3(0, 1.9, 0))
	info["elev"] = elev
	var kb: MeshKit = b.kit()
	for s: float in [-1.0, 1.0]:
		kb.box("super", Vector3(s * 0.45, 0, -0.6), Vector3(0.25, 0.25, 2.6))
		kb.cyl("white", Vector3(s * 0.45, 0.25, 0.8), Vector3(s * 0.45, 0.25, -2.2), 0.11, 0.11, 8)
		kb.cyl("white", Vector3(s * 0.45, 0.25, -2.2), Vector3(s * 0.45, 0.25, -2.5), 0.11, 0.0, 8)
		info["muzzles"].append(Vector3(s * 0.45, 0.25, -2.5))
	b.attach(elev, kb, "Rails")


static func _moskit(b, train: Node3D, info: Dictionary) -> void:
	var kt: MeshKit = b.kit()
	var bas := Basis(Vector3.RIGHT, deg_to_rad(15.0))
	for i in 2:
		for j in 2:
			var c := Vector3((i - 0.5) * 1.25, 1.2 + j * 1.15, 0.0)
			var a := c + bas * Vector3(0, 0, 4.9)
			var e := c + bas * Vector3(0, 0, -4.9)
			kt.cyl("super", a, e, 0.58, 0.58, 12, true, "dark")
			kt.cyl("super", e, e + bas * Vector3(0, 0, -0.05), 0.65, 0.65, 12, false)
			info["muzzles"].append(e)
	kt.box("super", Vector3(0, 0.5, 1.5), Vector3(2.6, 1.0, 5.0))
	kt.bar("super", Vector3(0, 0.5, -3.0), Vector3(0, 1.0, -3.2), 0.6)
	b.attach(train, kt, "Tubes")


static func _uragan(b, train: Node3D, info: Dictionary, pos: Vector3) -> void:
	b.k.cyl("super", pos + Vector3(0, -0.5, 0), pos + Vector3(0, 0.4, 0), 1.6, 1.6, 18, true, "deck")
	var kt: MeshKit = b.kit()
	kt.cyl("super", Vector3(0, 0.4, 0), Vector3(0, 1.6, 0), 0.6, 0.5, 10)
	b.attach(train, kt, "Base")
	var elev := _elev(train, Vector3(0, 1.7, 0))
	info["elev"] = elev
	var kb: MeshKit = b.kit()
	kb.box("super", Vector3(0, 0, -1.3), Vector3(0.45, 0.4, 3.8))
	kb.cyl("white", Vector3(0, 0.45, 1.5), Vector3(0, 0.45, -3.6), 0.2, 0.2, 10)
	kb.cyl("white", Vector3(0, 0.45, -3.6), Vector3(0, 0.45, -4.0), 0.2, 0.0, 10)
	b.attach(elev, kb, "Arm")
	info["muzzles"].append(Vector3(0, 0.45, -4.0))


static func _rbu(b, train: Node3D, info: Dictionary, pos: Vector3, n: int, r: float) -> void:
	b.k.cyl("super", pos + Vector3(0, -0.4, 0), pos + Vector3(0, 0.3, 0), 0.9, 0.9, 12, true, "deck")
	var kt: MeshKit = b.kit()
	kt.cyl("super", Vector3(0, 0.3, 0), Vector3(0, 1.0, 0), 0.5, 0.45, 10)
	b.attach(train, kt, "Base")
	var elev := _elev(train, Vector3(0, 1.2, 0))
	info["elev"] = elev
	var kb: MeshKit = b.kit()
	for i in n:
		var a := PI * (0.15 + 0.7 * float(i) / maxf(n - 1, 1))
		var c := Vector3(cos(a) * 0.55, sin(a) * 0.55 - 0.1, 0)
		kb.cyl("gun", c + Vector3(0, 0, 0.7), c + Vector3(0, 0, -1.1), r, r, 8, true, "black")
	b.attach(elev, kb, "Tubes")
	info["muzzles"].append(Vector3(0, 0.3, -1.1))


static func _tubes(b, train: Node3D, info: Dictionary, pos: Vector3, n: int, r: float, l: float, stacked: bool) -> void:
	b.k.cyl("super", pos + Vector3(0, -0.4, 0), pos + Vector3(0, 0.4, 0), 0.6, 0.6, 10, true, "deck")
	var kt: MeshKit = b.kit()
	kt.box("super", Vector3(0, 0.6, 0), Vector3(r * n * 2.4 + 0.3, 0.4, 1.2))
	for i in n:
		var c := Vector3((i - (n - 1) * 0.5) * r * 2.3, 0.6 + r + 0.15, 0)
		if stacked:
			c = Vector3((i % 2 - 0.5) * r * 2.2 if i < 2 else 0.0, 0.6 + r + 0.15 + (r * 1.9 if i == 2 else 0.0), 0)
		kt.cyl("super", c + Vector3(0, 0, l * 0.45), c + Vector3(0, 0, -l * 0.55), r, r, 10, true, "dark")
		info["muzzles"].append(c + Vector3(0, 0, -l * 0.55))
	b.attach(train, kt, "Tubes")
