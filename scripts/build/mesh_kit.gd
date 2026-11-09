extends RefCounted
## Collects primitive shapes into one ArrayMesh with one surface per material key.
## Every triangle is wound so its front face matches the normal it was given
## (Godot treats clockwise as front), so materials can use back-face culling.

var _tools := {}
var mats := {}
## Placement applied to everything drawn.
var xf := Transform3D.IDENTITY
var _uv := Vector2.ZERO


func _init(materials: Dictionary = {}) -> void:
	mats = materials


func _st(mat: String) -> SurfaceTool:
	var st: SurfaceTool = _tools.get(mat)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[mat] = st
	return st


func _v(st: SurfaceTool, p: Vector3, n: Vector3, uv := Vector2.ZERO) -> void:
	st.set_normal((xf.basis * n).normalized())
	st.set_uv(uv)
	st.add_vertex(xf * p)


## One triangle with a flat normal. Winding is fixed up to face along `n`.
func tri(mat: String, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	var st := _st(mat)
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tmp := b
		b = c
		c = tmp
	_v(st, a, n)
	_v(st, b, n)
	_v(st, c, n)


## Triangle with per-vertex normals and optional UVs.
func tri_n(mat: String, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
	var st := _st(mat)
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		_v(st, a, na, ua)
		_v(st, c, nc, uc)
		_v(st, b, nb, ub)
	else:
		_v(st, a, na, ua)
		_v(st, b, nb, ub)
		_v(st, c, nc, uc)


## Flat quad; `inside` is any point on the inner side, used to orient the normal.
func quad(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		n = (c - a).cross(d - a)
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	if n.dot((a + b + c + d) * 0.25 - inside) < 0.0:
		n = -n
	tri(mat, a, b, c, n)
	tri(mat, a, c, d, n)


## Flat quad facing a given direction.
func quad_dir(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	tri(mat, a, b, c, n)
	tri(mat, a, c, d, n)


## Smooth quad with per-vertex normals.
func quad_n(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3) -> void:
	tri_n(mat, a, b, c, na, nb, nc)
	tri_n(mat, a, c, d, na, nc, nd)


## Textured rectangle: centre, normal, up direction, size, UV rectangle.
func rect_uv(mat: String, c: Vector3, n: Vector3, up: Vector3, size: Vector2, uv := Rect2(0, 0, 1, 1)) -> void:
	n = n.normalized()
	var r := up.cross(n).normalized()
	var u := n.cross(r).normalized()
	var hx := r * size.x * 0.5
	var hy := u * size.y * 0.5
	var p0 := c - hx - hy
	var p1 := c + hx - hy
	var p2 := c + hx + hy
	var p3 := c - hx + hy
	var u0 := Vector2(uv.position.x, uv.end.y)
	var u1 := uv.end
	var u2 := Vector2(uv.end.x, uv.position.y)
	var u3 := uv.position
	tri_n(mat, p0, p1, p2, n, n, n, u0, u1, u2)
	tri_n(mat, p0, p2, p3, n, n, n, u0, u2, u3)


## Convex hexahedron from 8 corners: bottom face 0..3 then top face 4..7, same winding.
func hexa(mat: String, p: Array, top_mat := "", skip_bottom := false) -> void:
	var c := Vector3.ZERO
	for v in p:
		c += v
	c /= 8.0
	if not skip_bottom:
		quad(mat, p[0], p[1], p[2], p[3], c)
	quad(top_mat if top_mat != "" else mat, p[4], p[5], p[6], p[7], c)
	for i in 4:
		var j := (i + 1) % 4
		quad(mat, p[i], p[j], p[j + 4], p[i + 4], c)


## Box centred at `c` with full size `s`, optionally rotated.
func box(mat: String, c: Vector3, s: Vector3, basis := Basis.IDENTITY, top_mat := "") -> void:
	var h := s * 0.5
	var p := []
	for v in [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1),
			Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]:
		p.append(c + basis * (v * h))
	hexa(mat, p, top_mat)


## Box between two corner points (axis aligned).
func box_ab(mat: String, a: Vector3, b: Vector3, top_mat := "") -> void:
	box(mat, (a + b) * 0.5, (b - a).abs(), Basis.IDENTITY, top_mat)


## Tapered block: bottom (w0 x l0) at y0, top (w1 x l1) at y1, centred on (x, z).
## `shift` moves the top face along z (raked fronts are negative shift at the front).
func block(mat: String, x: float, z: float, y0: float, y1: float, w0: float, l0: float,
		w1: float, l1: float, shift := 0.0, top_mat := "") -> void:
	hexa(mat, [
		Vector3(x - w0 / 2, y0, z - l0 / 2), Vector3(x + w0 / 2, y0, z - l0 / 2),
		Vector3(x + w0 / 2, y0, z + l0 / 2), Vector3(x - w0 / 2, y0, z + l0 / 2),
		Vector3(x - w1 / 2, y1, z - l1 / 2 + shift), Vector3(x + w1 / 2, y1, z - l1 / 2 + shift),
		Vector3(x + w1 / 2, y1, z + l1 / 2 + shift), Vector3(x - w1 / 2, y1, z + l1 / 2 + shift)], top_mat)


## Deckhouse: block from z0 (front) to z1 (back) with independently raked front and back.
func house(mat: String, z0: float, z1: float, y0: float, y1: float, w: float, rake_f := 0.0,
		rake_b := 0.0, taper := 0.0, top_mat := "", cx := 0.0) -> void:
	var wt := w - taper * 2.0
	hexa(mat, [
		Vector3(cx - w / 2, y0, z0), Vector3(cx + w / 2, y0, z0), Vector3(cx + w / 2, y0, z1), Vector3(cx - w / 2, y0, z1),
		Vector3(cx - wt / 2, y1, z0 + rake_f), Vector3(cx + wt / 2, y1, z0 + rake_f),
		Vector3(cx + wt / 2, y1, z1 - rake_b), Vector3(cx - wt / 2, y1, z1 - rake_b)], top_mat, true)


## Cylinder or cone from a to b. Smooth sides, flat caps.
func cyl(mat: String, a: Vector3, b: Vector3, r0: float, r1: float, segs := 12, caps := true,
		cap_mat := "") -> void:
	var axis := b - a
	if axis.length_squared() < 1e-10:
		return
	var up := axis.normalized()
	var ref := Vector3.UP if absf(up.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var u := up.cross(ref).normalized()
	var v := up.cross(u).normalized()
	var slope := (r0 - r1) / axis.length()
	var ring0 := []
	var ring1 := []
	var norms := []
	for i in segs + 1:
		var ang := TAU * float(i) / segs
		var d := u * cos(ang) + v * sin(ang)
		ring0.append(a + d * r0)
		ring1.append(b + d * r1)
		norms.append((d + up * slope).normalized())
	for i in segs:
		quad_n(mat, ring0[i], ring0[i + 1], ring1[i + 1], ring1[i], norms[i], norms[i + 1], norms[i + 1], norms[i])
	if caps:
		var cm := cap_mat if cap_mat != "" else mat
		for i in segs:
			if r1 > 0.0:
				tri(cm, b, ring1[i], ring1[i + 1], up)
			if r0 > 0.0:
				tri(cm, a, ring0[i + 1], ring0[i], -up)


## Surface of revolution around the a->b axis. `prof` is an array of Vector2(t, r)
## with t in 0..1 along the axis. Optional y-scale gives elliptical sections.
func lathe(mat: String, a: Vector3, b: Vector3, prof: Array, segs := 16, squash := 1.0) -> void:
	var axis := b - a
	var len := axis.length()
	if len < 1e-6:
		return
	var up := axis / len
	var ref := Vector3.UP if absf(up.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var u := up.cross(ref).normalized()
	var v := up.cross(u).normalized()
	for k in prof.size() - 1:
		var p0: Vector2 = prof[k]
		var p1: Vector2 = prof[k + 1]
		var dt := (p1.x - p0.x) * len
		var dr := p1.y - p0.y
		var sl := -dr / maxf(dt, 1e-5) if absf(dt) > 1e-5 else (-1.0 if dr > 0.0 else 1.0) * 1e3
		for i in segs:
			var a0 := TAU * float(i) / segs
			var a1 := TAU * float(i + 1) / segs
			var d0 := u * cos(a0) + v * sin(a0) * squash
			var d1 := u * cos(a1) + v * sin(a1) * squash
			var n0 := (u * cos(a0) + v * sin(a0) / squash).normalized()
			var n1 := (u * cos(a1) + v * sin(a1) / squash).normalized()
			var nn0 := (n0 + up * sl).normalized()
			var nn1 := (n1 + up * sl).normalized()
			var c0 := a + up * (p0.x * len)
			var c1 := a + up * (p1.x * len)
			if p0.y < 1e-5 and p1.y < 1e-5:
				continue
			quad_n(mat, c0 + d0 * p0.y, c0 + d1 * p0.y, c1 + d1 * p1.y, c1 + d0 * p1.y, nn0, nn1, nn1, nn0)


func sphere(mat: String, c: Vector3, r: float, segs := 12, rings := 8, scale := Vector3.ONE,
		top_only := false) -> void:
	var j0 := rings / 2 if top_only else 0
	for j in range(j0, rings):
		var t0 := PI * float(j) / rings - PI / 2
		var t1 := PI * float(j + 1) / rings - PI / 2
		for i in segs:
			var p0 := TAU * float(i) / segs
			var p1 := TAU * float(i + 1) / segs
			var n00 := Vector3(cos(t0) * cos(p0), sin(t0), cos(t0) * sin(p0))
			var n01 := Vector3(cos(t0) * cos(p1), sin(t0), cos(t0) * sin(p1))
			var n11 := Vector3(cos(t1) * cos(p1), sin(t1), cos(t1) * sin(p1))
			var n10 := Vector3(cos(t1) * cos(p0), sin(t1), cos(t1) * sin(p0))
			quad_n(mat, c + n00 * r * scale, c + n01 * r * scale, c + n11 * r * scale, c + n10 * r * scale,
				(n00 / scale).normalized(), (n01 / scale).normalized(), (n11 / scale).normalized(), (n10 / scale).normalized())


## Vertical prism from a polygon of Vector2(x, z) points.
func prism(mat: String, poly: Array, y0: float, y1: float, top_mat := "", bottom := true) -> void:
	var n := poly.size()
	var c := Vector3.ZERO
	for p in poly:
		c += Vector3(p.x, (y0 + y1) * 0.5, p.y)
	c /= n
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		quad(mat, Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y), c)
	var tm := top_mat if top_mat != "" else mat
	var ctop := Vector3(c.x, y1, c.z)
	var cbot := Vector3(c.x, y0, c.z)
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		tri(tm, ctop, Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y), Vector3.UP)
		if bottom:
			tri(mat, cbot, Vector3(b.x, y0, b.y), Vector3(a.x, y0, a.y), Vector3.DOWN)


## Thin bar (square section) between two points: cheap struts, rails and rungs.
func bar(mat: String, a: Vector3, b: Vector3, w: float) -> void:
	var d := b - a
	var l := d.length()
	if l < 1e-4:
		return
	var f := d / l
	var ref := Vector3.UP if absf(f.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var s := f.cross(ref).normalized() * (w * 0.5)
	var u := f.cross(s).normalized() * (w * 0.5)
	var p := [a - s - u, a + s - u, a + s + u, a - s + u, b - s - u, b + s - u, b + s + u, b - s + u]
	var c := (a + b) * 0.5
	for i in 4:
		var j := (i + 1) % 4
		quad(mat, p[i], p[j], p[j + 4], p[i + 4], c)


## Railing along a polyline of points at deck level: posts plus three rails.
func railing(mat: String, pts: Array, h := 1.05, spacing := 1.6, w := 0.045) -> void:
	for k in pts.size() - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var l := a.distance_to(b)
		var n := maxi(1, int(ceil(l / spacing)))
		for i in n + (1 if k == pts.size() - 2 else 0):
			var p := a.lerp(b, float(i) / n)
			bar(mat, p, p + Vector3(0, h, 0), w)
		for f: float in [0.35, 0.68, 1.0]:
			bar(mat, a + Vector3(0, h * f, 0), b + Vector3(0, h * f, 0), w * 0.8)


## Lattice mast leg pair with cross bracing, from a (bottom) to b (top) on two rails.
func truss(mat: String, a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3, bays: int, w: float) -> void:
	bar(mat, a0, b0, w * 1.4)
	bar(mat, a1, b1, w * 1.4)
	for i in bays:
		var t0 := float(i) / bays
		var t1 := float(i + 1) / bays
		var p0 := a0.lerp(b0, t0)
		var q0 := a1.lerp(b1, t0)
		var p1 := a0.lerp(b0, t1)
		var q1 := a1.lerp(b1, t1)
		bar(mat, p0, q1, w)
		bar(mat, q0, p1, w)
		bar(mat, p1, q1, w)


## Four-sided tapering lattice tower: base half-widths (bx, bz) at y0, top (tx, tz) at y1.
func lattice_tower(mat: String, c: Vector3, y0: float, y1: float, bx: float, bz: float, tx: float,
		tz: float, bays := 6, w := 0.12) -> void:
	var b := [Vector3(-bx, y0, -bz), Vector3(bx, y0, -bz), Vector3(bx, y0, bz), Vector3(-bx, y0, bz)]
	var t := [Vector3(-tx, y1, -tz), Vector3(tx, y1, -tz), Vector3(tx, y1, tz), Vector3(-tx, y1, tz)]
	for i in 4:
		var j := (i + 1) % 4
		truss(mat, c + b[i], c + b[j], c + t[i], c + t[j], bays, w)


## Torus (wheel rims). Axis along `n`.
func torus(mat: String, c: Vector3, n: Vector3, R: float, r: float, segs := 24, sides := 8) -> void:
	n = n.normalized()
	var ref := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var u := n.cross(ref).normalized()
	var v := n.cross(u).normalized()
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		var d0 := u * cos(a0) + v * sin(a0)
		var d1 := u * cos(a1) + v * sin(a1)
		for j in sides:
			var b0 := TAU * float(j) / sides
			var b1 := TAU * float(j + 1) / sides
			var n00 := d0 * cos(b0) + n * sin(b0)
			var n01 := d0 * cos(b1) + n * sin(b1)
			var n10 := d1 * cos(b0) + n * sin(b0)
			var n11 := d1 * cos(b1) + n * sin(b1)
			quad_n(mat, c + d0 * R + n00 * r, c + d0 * R + n01 * r, c + d1 * R + n11 * r, c + d1 * R + n10 * r,
				n00, n01, n11, n10)


## Flat disc facing `n`.
func disc(mat: String, c: Vector3, n: Vector3, r: float, segs := 16) -> void:
	n = n.normalized()
	var ref := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var u := n.cross(ref).normalized()
	var v := n.cross(u).normalized()
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		tri(mat, c, c + (u * cos(a0) + v * sin(a0)) * r, c + (u * cos(a1) + v * sin(a1)) * r, n)


## Textured disc facing `n` (dial faces).
func disc_uv(mat: String, c: Vector3, n: Vector3, r: float, segs := 24) -> void:
	n = n.normalized()
	var ref := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var u := ref.cross(n).normalized()
	var v := n.cross(u).normalized()
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var p0 := c + (u * cos(a0) + v * sin(a0)) * r
		var p1 := c + (u * cos(a1) + v * sin(a1)) * r
		tri_n(mat, c, p0, p1, n, n, n, Vector2(0.5, 0.5),
			Vector2(0.5 + 0.5 * cos(a0), 0.5 - 0.5 * sin(a0)), Vector2(0.5 + 0.5 * cos(a1), 0.5 - 0.5 * sin(a1)))


## Grid of square hatches (VLS cells) on a plane at height y.
func hatch_grid(mat: String, edge_mat: String, x0: float, z0: float, nx: int, nz: int, cell: float,
		y: float, gap := 0.08) -> void:
	box(edge_mat, Vector3(x0 + nx * cell * 0.5, y - 0.06, z0 + nz * cell * 0.5),
		Vector3(nx * cell + 0.3, 0.12, nz * cell + 0.3))
	for i in nx:
		for j in nz:
			var c := Vector3(x0 + (i + 0.5) * cell, y + 0.02, z0 + (j + 0.5) * cell)
			box(mat, c, Vector3(cell - gap, 0.05, cell - gap))


func is_empty() -> bool:
	return _tools.is_empty()


func commit(into: ArrayMesh = null) -> ArrayMesh:
	var mesh := into if into != null else ArrayMesh.new()
	for key in _tools:
		var st: SurfaceTool = _tools[key]
		st.commit(mesh)
		var idx := mesh.get_surface_count() - 1
		if mats.has(key):
			mesh.surface_set_material(idx, mats[key])
	_tools.clear()
	return mesh


## Commit into a MeshInstance3D (returns null when nothing was drawn).
func instance(name := "Mesh", shadows := true) -> MeshInstance3D:
	if _tools.is_empty():
		return null
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = commit()
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
