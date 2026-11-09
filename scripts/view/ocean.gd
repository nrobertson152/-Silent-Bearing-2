extends Node3D
## Near wave grid that follows the camera, plus flat rings out to the horizon.
## height() mirrors the shader's big waves so ships can float on them.

const SHADER := preload("res://shaders/ocean.gdshader")
const WAVES := [[0.0, 0.16, 96.0], [0.42, 0.13, 61.0], [-0.55, 0.12, 43.0], [0.9, 0.10, 29.0],
	[-0.25, 0.10, 19.0], [1.3, 0.08, 13.0], [-1.1, 0.07, 8.7], [0.6, 0.06, 5.9]]

var mat: ShaderMaterial
var far_mat: ShaderMaterial
var near: MeshInstance3D
var far: MeshInstance3D
var amp := 1.0
var choppy := 1.0
var wind := Vector2(1.0, 0.25)
var t := 0.0
var _dirs := []


func _init() -> void:
	name = "Ocean"
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	far_mat = ShaderMaterial.new()
	far_mat.shader = SHADER
	far_mat.set_shader_parameter("flat_far", 1.0)
	near = MeshInstance3D.new()
	near.mesh = _grid(1700.0, 200, 3.0)
	near.material_override = mat
	near.extra_cull_margin = 40.0
	near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(near)
	far = MeshInstance3D.new()
	far.mesh = _ring(820.0, 120000.0, 96)
	far.material_override = far_mat
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	far.extra_cull_margin = 2000.0
	add_child(far)
	set_sea(1.0, Vector2(1.0, 0.25))


## Square grid with finer cells near the middle (cells grow by `grow` at the edge).
static func _grid(size: float, n: int, grow: float) -> ArrayMesh:
	var coords := PackedFloat32Array()
	for i in n + 1:
		var u := float(i) / n * 2.0 - 1.0
		var g := signf(u) * pow(absf(u), grow) if grow != 1.0 else u
		coords.append(lerpf(g, u, 0.25) * size * 0.5)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for j in n + 1:
		for i in n + 1:
			verts.append(Vector3(coords[i], 0, coords[j]))
			norms.append(Vector3.UP)
	var idx := PackedInt32Array()
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			idx.append_array([a, a + 1, a + n + 2, a, a + n + 2, a + n + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func _ring(r0: float, r1: float, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := [r0 * 0.98, r0 * 1.4, r0 * 2.2, r0 * 4.0, r0 * 8.0, r1 * 0.12, r1 * 0.4, r1]
	for j in radii.size() - 1:
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var p := [Vector3(cos(a0) * radii[j], 0, sin(a0) * radii[j]), Vector3(cos(a1) * radii[j], 0, sin(a1) * radii[j]),
				Vector3(cos(a1) * radii[j + 1], 0, sin(a1) * radii[j + 1]), Vector3(cos(a0) * radii[j + 1], 0, sin(a0) * radii[j + 1])]
			for v in [p[0], p[2], p[1], p[0], p[3], p[2]]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	return st.commit()


## Sea state 0..7 (WMO) -> wave amplitude scale and choppiness.
func set_sea(sea_state: float, wind_dir: Vector2) -> void:
	# Significant wave height (m) for WMO sea states 0..8; the wave table gives ~8.3 m at amp 1.
	var hs := [0.05, 0.15, 0.4, 0.9, 1.9, 3.2, 5.0, 7.5, 11.0]
	var i := clampi(int(floor(sea_state)), 0, 7)
	var h: float = lerpf(hs[i], hs[i + 1], sea_state - floor(sea_state))
	amp = maxf(h / 8.3, 0.01)
	choppy = clampf(0.7 + sea_state * 0.07, 0.6, 1.2)
	wind = wind_dir.normalized()
	_dirs.clear()
	for w in WAVES:
		var a: float = w[0]
		_dirs.append(Vector2(wind.x * cos(a) - wind.y * sin(a), wind.x * sin(a) + wind.y * cos(a)).normalized())
	for m in [mat, far_mat]:
		m.set_shader_parameter("amp", amp)
		m.set_shader_parameter("choppy", choppy)
		m.set_shader_parameter("wind", wind)
		m.set_shader_parameter("foam_amount", clampf((sea_state - 2.0) / 3.0, 0.0, 1.2))


func set_colors(deep: Color, scatter: Color, under: Color) -> void:
	for m in [mat, far_mat]:
		m.set_shader_parameter("deep", deep)
		m.set_shader_parameter("scatter", scatter)
		m.set_shader_parameter("under", under)


func set_sun(dir: Vector3, col: Color, energy: float) -> void:
	for m in [mat, far_mat]:
		m.set_shader_parameter("sun_dir", dir)
		m.set_shader_parameter("sun_col", col)
		m.set_shader_parameter("sun_energy", energy)


func set_detail(d: float) -> void:
	mat.set_shader_parameter("detail", d)


func follow(cam_pos: Vector3, time_s: float) -> void:
	t = time_s
	near.global_position = Vector3(snappedf(cam_pos.x, 20.0), 0.0, snappedf(cam_pos.z, 20.0))
	far.global_position = Vector3(cam_pos.x, -0.05, cam_pos.z)
	for m in [mat, far_mat]:
		m.set_shader_parameter("t", time_s)


## Surface height at world x/z (big waves only, no curvature).
func height(x: float, z: float) -> float:
	var y := 0.0
	var p := Vector2(x, z)
	for i in WAVES.size():
		var w: Array = WAVES[i]
		var k: float = TAU / float(w[2])
		var c := sqrt(9.81 / k)
		var d: Vector2 = _dirs[i]
		var f := k * (d.dot(p) - c * t)
		y += float(w[1]) * amp / k * sin(f)
	return y


## Approximate surface normal at x/z from finite differences of height().
func normal(x: float, z: float, h := 4.0) -> Vector3:
	var hx := height(x + h, z) - height(x - h, z)
	var hz := height(x, z + h) - height(x, z - h)
	return Vector3(-hx, 2.0 * h, -hz).normalized()
