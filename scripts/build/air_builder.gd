extends RefCounted
## Aircraft and missile models, kept light because they are seen at range.

const MeshKit := preload("res://scripts/build/mesh_kit.gd")
const Mats := preload("res://scripts/build/materials.gd")
const AirData := preload("res://scripts/data/aircraft.gd")

static var _mats := {}


static func _m() -> Dictionary:
	if _mats.is_empty():
		_mats = Mats.common().duplicate()
		_mats["us_air"] = Mats.std(Color(0.62, 0.65, 0.68), 0.55, 0.2)
		_mats["su_air"] = Mats.std(Color(0.72, 0.74, 0.74), 0.45, 0.35)
		_mats["missile"] = Mats.std(Color(0.86, 0.86, 0.84), 0.5, 0.1)
	return _mats


static func aircraft(type: String) -> Node3D:
	var ad := AirData.spec(type)
	var k := MeshKit.new(_m())
	var mat := "su_air" if ad.get("side", "us") == "su" else "us_air"
	var L: float = ad.get("len", 20.0)
	var S: float = ad.get("span", 15.0)
	var root := Node3D.new()
	root.name = type
	var model: String = ad.get("model", "fighter")
	var helo := model in ["helix", "seahawk"]
	var R := L * (0.055 if not helo else 0.12)
	var prof := [Vector2(0, 0.02), Vector2(0.08, R * 0.6), Vector2(0.2, R), Vector2(0.75, R * 0.9), Vector2(1, R * 0.35)]
	k.lathe(mat, Vector3(0, 0, -L * 0.5), Vector3(0, 0, L * 0.5), prof, 12)
	k.sphere("glass", Vector3(0, R * 0.7, -L * 0.36), R * 0.55, 8, 6, Vector3(0.8, 0.7, 1.6))
	if helo:
		var rot := Node3D.new()
		rot.name = "Rotor"
		rot.position = Vector3(0, R * 1.3, -L * 0.05)
		root.add_child(rot)
		var kr := MeshKit.new(_m())
		var nb := 4 if model == "seahawk" else 3
		for i in nb:
			var a := TAU * i / nb
			kr.box("dark", Vector3(cos(a), 0, sin(a)) * S * 0.25, Vector3(S * 0.5, 0.06, 0.45), Basis(Vector3.UP, -a))
		if model == "helix":
			for i in nb:
				var a := TAU * i / nb + 0.5
				kr.box("dark", Vector3(cos(a), 0.8, sin(a)) * S * 0.25 + Vector3(0, 0.8, 0), Vector3(S * 0.5, 0.06, 0.45), Basis(Vector3.UP, -a))
		rot.add_child(kr.instance("Mesh"))
		root.set_meta("rotor", rot)
		k.box(mat, Vector3(0, R * 0.4, L * 0.55), Vector3(0.4, R * 1.6, L * 0.15))
	else:
		var sweep := 0.5 if model in ["fighter", "backfire"] else 0.2
		var wz := -L * 0.05
		for s: float in [-1.0, 1.0]:
			var root_le := Vector3(s * R * 0.8, 0, wz - L * 0.12)
			var root_te := Vector3(s * R * 0.8, 0, wz + L * 0.12)
			var tip_le := Vector3(s * S * 0.5, 0, wz + S * 0.5 * sweep - L * 0.02)
			var tip_te := Vector3(s * S * 0.5, 0, wz + S * 0.5 * sweep + L * 0.04)
			k.hexa(mat, [root_le, root_te, tip_te, tip_le, root_le + Vector3(0, 0.25, 0), root_te + Vector3(0, 0.25, 0), tip_te + Vector3(0, 0.08, 0), tip_le + Vector3(0, 0.08, 0)])
			if model in ["bear", "orion"]:
				for e in 2:
					var ex := s * S * (0.18 + e * 0.17)
					var ez := wz - L * 0.04 + absf(ex) * sweep
					k.cyl(mat, Vector3(ex, -0.4, ez - 2.5), Vector3(ex, -0.4, ez + 2.0), 0.7, 0.5, 8)
					k.disc("dark", Vector3(ex, -0.4, ez - 2.7), Vector3(0, 0, -1), S * 0.06, 10)
			elif model == "bomber":
				for e in 2:
					var ex := s * S * (0.2 + e * 0.15)
					k.cyl(mat, Vector3(ex, -1.2, wz - 1.0 + absf(ex) * sweep), Vector3(ex, -1.2, wz + 3.0 + absf(ex) * sweep), 0.8, 0.8, 8)
		k.hexa(mat, [Vector3(0, R * 0.5, L * 0.32), Vector3(0, R * 0.5, L * 0.5), Vector3(0, R + L * 0.16, L * 0.5), Vector3(0, R + L * 0.16, L * 0.42),
			Vector3(0.2, R * 0.5, L * 0.32), Vector3(0.2, R * 0.5, L * 0.5), Vector3(0.2, R + L * 0.16, L * 0.5), Vector3(0.2, R + L * 0.16, L * 0.42)])
		for s: float in [-1.0, 1.0]:
			k.box(mat, Vector3(s * L * 0.1, R * 0.3, L * 0.45), Vector3(L * 0.2, 0.12, L * 0.08))
	root.add_child(k.instance("Mesh"))
	return root


static func missile(mid: String, len: float, dia: float) -> Node3D:
	var k := MeshKit.new(_m())
	var root := Node3D.new()
	root.name = mid
	var r := dia * 0.5
	k.lathe("missile", Vector3(0, 0, -len * 0.5), Vector3(0, 0, len * 0.5),
		[Vector2(0, 0.0), Vector2(0.1, r * 0.8), Vector2(0.18, r), Vector2(1.0, r)], 10)
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var d := Vector3(cos(a), sin(a), 0)
		k.box("missile", d * (r + dia * 0.6) + Vector3(0, 0, len * 0.42), (Vector3(absf(d.x), absf(d.y), 0) * dia * 1.2 + Vector3(0.04, 0.04, len * 0.12)))
		k.box("missile", d * (r + dia * 0.45) + Vector3(0, 0, -len * 0.05), (Vector3(absf(d.x), absf(d.y), 0) * dia * 0.9 + Vector3(0.03, 0.03, len * 0.15)))
	root.add_child(k.instance("Mesh"))
	return root
