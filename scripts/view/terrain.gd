extends Node3D
## Meshes the simulation heightfield (only cells near or above sea level) and
## draws shore installations: gun batteries, SAM sites and radars.

const MeshKit := preload("res://scripts/build/mesh_kit.gd")
const Mats := preload("res://scripts/build/materials.gd")
const SHADER := preload("res://shaders/terrain.gdshader")

var targets := {}


func build(t: SimTerrain, lat: float, month: int) -> void:
	name = "Terrain"
	var n := t.n
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize((n + 1) * (n + 1))
	norms.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			var h := t.at(i, j)
			var k := j * (n + 1) + i
			verts[k] = Vector3(t.origin.x + i * t.cell, h, t.origin.y + j * t.cell)
			var dx := t.at(i + 1, j) - t.at(i - 1, j)
			var dz := t.at(i, j + 1) - t.at(i, j - 1)
			norms[k] = Vector3(-dx, 2.0 * t.cell, -dz).normalized()
	var idx := PackedInt32Array()
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			if maxf(maxf(t.heights[a], t.heights[a + 1]), maxf(t.heights[a + n + 1], t.heights[a + n + 2])) < -8.0:
				continue
			idx.append_array([a, a + 1, a + n + 2, a, a + n + 2, a + n + 1])
	if idx.is_empty():
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var m := ShaderMaterial.new()
	m.shader = SHADER
	if lat > 62.0:
		m.set_shader_parameter("grass", Color(0.27, 0.26, 0.17) if lat > 66.0 else Color(0.22, 0.25, 0.16))
		m.set_shader_parameter("rock", Color(0.2, 0.19, 0.18))
		m.set_shader_parameter("sand", Color(0.17, 0.16, 0.15))
		m.set_shader_parameter("snow", 0.85 if month >= 10 else 0.4)
		m.set_shader_parameter("snow_line", 35.0 if lat > 66.0 else 70.0)
	elif lat < 34.0:
		m.set_shader_parameter("grass", Color(0.2, 0.33, 0.14))
		m.set_shader_parameter("sand", Color(0.72, 0.66, 0.52))
	else:
		m.set_shader_parameter("grass", Color(0.3, 0.31, 0.17))
		m.set_shader_parameter("sand", Color(0.62, 0.57, 0.44))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.extra_cull_margin = 3000.0
	add_child(mi)


func add_target(g: Dictionary) -> void:
	var k := MeshKit.new(Mats.navy("su" if g.get("side", "su") == "su" else "us"))
	var kind: String = g["kind"]
	match kind:
		"battery":
			for i in 3:
				var c := Vector3((i - 1) * 22.0, 0, 0)
				k.cyl("deck", c + Vector3(0, -1.5, 0), c + Vector3(0, 1.0, 0), 7.0, 6.0, 16)
				k.cyl("dark", c + Vector3(0, 1.0, 0), c + Vector3(0, 2.6, 0), 2.4, 2.0, 12)
				k.cyl("gun", c + Vector3(0, 2.0, 0), c + Vector3(0, 4.0, -8.0), 0.22, 0.18, 8)
			k.box("deck", Vector3(0, 1.0, 14.0), Vector3(20.0, 3.0, 8.0))
		"sam":
			for i in 4:
				var a := TAU * i / 4.0
				var c := Vector3(cos(a), 0, sin(a)) * 30.0
				k.box("dark", c + Vector3(0, 1.2, 0), Vector3(3.0, 2.4, 9.0), Basis(Vector3.UP, a))
				k.box("pale", c + Vector3(0, 3.2, 0), Vector3(2.2, 1.6, 7.5), Basis(Vector3.RIGHT, 0.9) * Basis(Vector3.UP, a))
			k.box("dark", Vector3(0, 2.5, 0), Vector3(4.0, 5.0, 4.0))
			k.box("radar", Vector3(0, 7.0, 0), Vector3(5.0, 4.0, 0.4))
		"radar":
			k.lattice_tower("dark", Vector3.ZERO, 0.0, 26.0, 3.0, 3.0, 1.2, 1.2, 6, 0.25)
			k.box("radar", Vector3(0, 28.0, 0), Vector3(12.0, 4.0, 0.6))
			k.box("deck", Vector3(8, 2.0, 0), Vector3(8.0, 4.0, 6.0))
		_:
			k.box("deck", Vector3(0, 2.0, 0), Vector3(10.0, 4.0, 10.0))
	var node := Node3D.new()
	node.position = g["pos"] - Vector3(0, 2.0, 0)
	var mi := k.instance("Target")
	node.add_child(mi)
	add_child(node)
	targets[g["uid"]] = {"node": node, "g": g, "burning": false}


func sync(fx) -> void:
	for uid in targets:
		var r: Dictionary = targets[uid]
		if not r["g"]["alive"] and not r["burning"]:
			r["burning"] = true
			fx.fire_column(r["node"], Vector3(0, 3, 0), 1.2)
			(r["node"].get_child(0) as Node3D).scale = Vector3(1.0, 0.4, 1.0)
