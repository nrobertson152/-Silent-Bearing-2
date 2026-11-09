extends RefCounted
## Builds a surface ship model from class data: hull, superstructure, masts,
## sensors and weapon mounts. Turrets, launchers and radars are separate nodes
## so the view can train, elevate and spin them.
##
## Model space: bow at -Z, starboard +X, waterline at y = 0.
## Metadata on the returned node:
##   mounts: {id: {node, elev, muzzles, face, recoil}}  radars: [[node, rpm]]
##   smoke: [Vector3]  bridge: {x0, x1, y, w, z0, z1}  lights: [[Vector3, kind]]

const MeshKit := preload("res://scripts/build/mesh_kit.gd")
const Mats := preload("res://scripts/build/materials.gd")
const Hull := preload("res://scripts/build/hull.gd")
const Struct := preload("res://scripts/build/parts_struct.gd")
const Sensors := preload("res://scripts/build/parts_sensors.gd")
const Arms := preload("res://scripts/build/parts_weapons.gd")
const ShipData := preload("res://scripts/data/ships.gd")
const Weapons := preload("res://scripts/data/weapons.gd")

var id: String
var cls: Dictionary
var side: String
var mats: Dictionary
var hull: Hull
var L: float
var root: Node3D
var k: MeshKit
var kd: MeshKit
var kb: MeshKit
var mounts := {}
var radars := []
var smoke := []
var lights := []
var bridge := {}
var covered := []


func _init(class_id: String) -> void:
	id = class_id
	cls = ShipData.spec(class_id)
	side = cls.get("side", "us")
	mats = Mats.navy(side).duplicate()
	var hs: Dictionary = cls["hull"].duplicate()
	hs["L"] = cls["length"]
	hs["B"] = cls["beam"]
	hs["T"] = cls["draft"]
	hull = Hull.new(hs)
	L = cls["length"]
	if hs.has("ports"):
		var hm: ShaderMaterial = mats["hull"].duplicate()
		var pr: Array = hs["ports"]
		hm.set_shader_parameter("ports_y", float(pr[0]))
		hm.set_shader_parameter("ports_z0", hull.z(pr[1]))
		hm.set_shader_parameter("ports_z1", hull.z(pr[2]))
		mats["hull"] = hm
	k = MeshKit.new(mats)
	kd = MeshKit.new(mats)
	kb = MeshKit.new(mats)
	root = Node3D.new()
	root.name = class_id


static func build(class_id: String) -> Node3D:
	var b = load("res://scripts/build/ship_builder.gd").new(class_id)
	return b.make()


func make() -> Node3D:
	var deck_mat := "wood" if cls["hull"].get("deck", "") == "wood" else "deck"
	hull.build(k, "hull", deck_mat)
	_hull_details()
	for p in cls.get("parts", []):
		Struct.part(self, p)
	for w in cls.get("weapons", []):
		Arms.mount(self, w)
	_railings()
	var mi := k.instance("Hull")
	root.add_child(mi)
	var md := kd.instance("Detail", false)
	if md:
		md.visibility_range_end = 900.0
		md.visibility_range_end_margin = 100.0
		md.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		root.add_child(md)
	var mb := kb.instance("BridgeShell")
	if mb:
		root.add_child(mb)
	_nav_lights()
	root.set_meta("mounts", mounts)
	root.set_meta("radars", radars)
	root.set_meta("smoke", smoke)
	root.set_meta("bridge", bridge)
	root.set_meta("lights", lights)
	root.set_meta("class", id)
	root.set_meta("length", L)
	return root


# ----------------------------------------------------------------- helpers
func z(x: float) -> float:
	return x - L * 0.5


func dy(x: float) -> float:
	return hull.deck_y(clampf(x, 0.0, L))


func hd(x: float) -> float:
	return hull.half_deck(x)


## Height for a part at station x: explicit "y", else deck + "rel".
func base_y(p: Dictionary, x: float) -> float:
	if p.has("y"):
		return float(p["y"])
	return dy(x) + float(p.get("rel", 0.0))


func kit() -> MeshKit:
	return MeshKit.new(mats)


func node(name: String, pos: Vector3, parent: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	(parent if parent else root).add_child(n)
	return n


func attach(n: Node3D, kt: MeshKit, name := "Mesh") -> void:
	var mi := kt.instance(name)
	if mi:
		n.add_child(mi)


func add_radar(n: Node3D, rpm: float) -> void:
	radars.append([n, rpm])


## Record that a stretch of deck edge is covered by a house (no railing there).
func cover(x0: float, x1: float) -> void:
	covered.append([x0, x1])


# ----------------------------------------------------------------- details
func _hull_details() -> void:
	# Hawse pipes and anchors near the bow on both sides.
	var xa := L * 0.045 + float(cls["hull"].get("rake", 0.0)) * 0.6
	var ya := dy(xa) - 1.6
	for s: float in [-1.0, 1.0]:
		var hb := hull.half_breadth(xa, ya)
		var c := Vector3(s * (hb + 0.05), ya, z(xa))
		var n := Vector3(s, 0, -0.25).normalized()
		k.disc("black", c + n * 0.02, n, 0.55 + L * 0.0015, 12)
		var ar := 0.3 + L * 0.0018
		k.box("black", c + Vector3(s * 0.12, -ar * 1.2, 0), Vector3(0.25, ar * 2.0, ar * 0.5))
		k.hexa("black", [c + Vector3(s * 0.1, -ar * 2.0, -ar * 1.1), c + Vector3(s * 0.3, -ar * 2.0, -ar * 1.1),
			c + Vector3(s * 0.3, -ar * 2.0, ar * 1.1), c + Vector3(s * 0.1, -ar * 2.0, ar * 1.1),
			c + Vector3(s * 0.1, -ar * 2.7, -ar * 0.3), c + Vector3(s * 0.3, -ar * 2.7, -ar * 0.3),
			c + Vector3(s * 0.3, -ar * 2.7, ar * 0.3), c + Vector3(s * 0.1, -ar * 2.7, ar * 0.3)])
	# Hull numbers.
	var num: String = cls.get("number", "")
	if num != "" and side != "merchant":
		var xn := L * 0.11 + float(cls["hull"].get("rake", 0.0)) * 0.5
		var hgt := clampf(dy(xn) * 0.42, 2.0, 4.2)
		var yn := dy(xn) - hgt * 0.75
		var half_w := hgt * 0.33 * num.length()
		for s: float in [-1.0, 1.0]:
			var hb := 0.0
			for dx: float in [-half_w, 0.0, half_w]:
				for dyy: float in [-hgt * 0.5, 0.0, hgt * 0.5]:
					hb = maxf(hb, hull.half_breadth(xn + dx, yn + dyy))
			var hb2 := hull.half_breadth(xn + half_w, yn)
			var hb1 := hull.half_breadth(xn - half_w, yn)
			var slope := atan2(hb2 - hb1, half_w * 2.0)
			hb = hull.half_breadth(xn, yn)
			for dyy: float in [-hgt * 0.5, hgt * 0.5]:
				hb = maxf(hb, hull.half_breadth(xn, yn + dyy))
			var lab := Label3D.new()
			lab.text = num
			lab.font_size = 128
			lab.pixel_size = hgt / 110.0
			lab.modulate = Color(0.93, 0.93, 0.9)
			lab.outline_modulate = Color(0.02, 0.02, 0.02)
			lab.outline_size = 10 if side == "su" else 4
			lab.shaded = true
			lab.double_sided = false
			lab.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
			lab.position = Vector3(s * (hb + 0.06), yn, z(xn))
			lab.rotation = Vector3(0, s * (PI / 2 + slope), 0)
			root.add_child(lab)
	# Name across the transom (US custom).
	if side == "us" and hull.stern == "transom":
		var lab := Label3D.new()
		lab.text = String(cls.get("name", "")).to_upper().replace("USS ", "")
		lab.font_size = 64
		lab.pixel_size = 0.012
		lab.modulate = Color(0.9, 0.9, 0.88)
		lab.outline_size = 3
		lab.outline_modulate = Color(0, 0, 0)
		lab.shaded = true
		lab.double_sided = false
		lab.position = Vector3(0, dy(L) - 1.3, z(L) + 0.05)
		root.add_child(lab)
	# Propellers and rudders (seen when she rolls, broaches or sinks).
	var shafts: int = cls["plant"]["shafts"]
	var pr := clampf(cls["draft"] * 0.36, 1.4, 3.6)
	for i in shafts:
		var o := 0.0
		if shafts == 2:
			o = (i - 0.5) * cls["beam"] * 0.42
		elif shafts == 3:
			o = (i - 1) * cls["beam"] * 0.3
		elif shafts == 4:
			o = [-0.36, -0.14, 0.14, 0.36][i] * cls["beam"]
		var xp := L * (0.9 if hull.stern == "transom" else 0.86) - absf(o) * 0.5
		var yp: float = -float(cls["draft"]) * 0.62
		var pc := Vector3(o, yp, z(xp))
		k.cyl("dark", pc + Vector3(0, 0, -L * 0.18), pc, 0.3, 0.3, 8, false)
		for bi in 5:
			var a := TAU * bi / 5.0
			var tip := pc + Vector3(cos(a), sin(a), 0) * pr
			k.tri("prop", pc + Vector3(0, 0, -0.3), tip, pc + Vector3(cos(a + 0.5), sin(a + 0.5), 0) * pr * 0.6, Vector3(0, 0, 1))
	var nr := 1 if shafts != 2 else 2
	for i in nr:
		var o: float = 0.0 if nr == 1 else (i - 0.5) * float(cls["beam"]) * 0.3
		var xr := L * (0.955 if hull.stern == "transom" else 0.92)
		k.box("hull", Vector3(o, -cls["draft"] * 0.45, z(xr)), Vector3(0.5, cls["draft"] * 0.7, L * 0.025))


func _railings() -> void:
	var start := L * 0.035
	var segs := []
	var x := start
	var x_end := L - 0.6
	covered.sort_custom(func(a, b): return a[0] < b[0])
	for c in covered:
		if c[0] > x + 3.0:
			segs.append([x, c[0] - 0.5])
		x = maxf(x, c[1] + 0.5)
	if x < x_end:
		segs.append([x, x_end])
	for sg in segs:
		for s: float in [-1.0, 1.0]:
			kd.railing("wire", hull.edge_points(sg[0], sg[1], 6.0, s))
	if hull.stern == "transom":
		var w := hd(L - 0.2) - 0.2
		kd.railing("wire", [Vector3(-w, dy(L), z(L) - 0.15), Vector3(w, dy(L), z(L) - 0.15)])


func _nav_lights() -> void:
	var xb: float = cls.get("bridge", {}).get("x0", L * 0.3)
	if bridge.has("x0"):
		xb = bridge["x0"]
		var w: float = bridge.get("wings", bridge["w"]) * 0.5
		lights.append([Vector3(w, bridge["y"] + 1.6, z(xb + 2.0)), "green"])
		lights.append([Vector3(-w, bridge["y"] + 1.6, z(xb + 2.0)), "red"])
	lights.append([Vector3(0, dy(L) + 1.5, z(L) - 0.5), "white"])
	for l in lights:
		var mat := "lamp_g" if l[1] == "green" else ("lamp_r" if l[1] == "red" else "lamp_w")
		k.sphere(mat, l[0], 0.14, 6, 4)
