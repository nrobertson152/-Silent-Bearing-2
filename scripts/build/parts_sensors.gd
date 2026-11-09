extends RefCounted
## Radars, directors and radomes. Rotating antennas are separate nodes
## registered with the builder (b.add_radar) so the view can spin them.

const MeshKit := preload("res://scripts/build/mesh_kit.gd")


static func radar(b, p: Dictionary) -> void:
	var x: float = p["x"]
	var o: float = p.get("o", 0.0)
	var y: float = b.base_y(p, x)
	var c := Vector3(o, y, b.z(x))
	var ped: float = p.get("pedestal", 0.0)
	if ped > 0.0:
		b.k.lattice_tower("super", Vector3(c.x, 0, c.z), y - ped - 0.3, y - 0.3, 0.9, 0.9, 0.5, 0.5, 2, 0.1)
		b.k.box("super", c + Vector3(0, -0.3, 0), Vector3(1.4, 0.2, 1.4))
	var t: String = p["type"]
	match t:
		"sps49":
			_spinner(b, c, 12.0, func(kk): _dish(kk, Vector3(0, 1.9, 0), 7.0, 3.3, 0.8, 0.12); _feed(kk, Vector3(0, 0.4, 0), Vector3(0, 1.4, -2.3)); kk.cyl("super", Vector3(0, -0.2, 0), Vector3(0, 0.6, 0), 0.5, 0.45, 10))
		"sps40":
			_spinner(b, c, 7.5, func(kk): _dish(kk, Vector3(0, 1.6, 0), 5.4, 2.6, 0.7, 0.1); _feed(kk, Vector3(0, 0.4, 0), Vector3(0, 1.2, -1.9)); kk.cyl("super", Vector3(0, -0.2, 0), Vector3(0, 0.5, 0), 0.4, 0.36, 10))
		"sps10":
			_spinner(b, c, 15.0, func(kk): _dish(kk, Vector3(0, 0.8, 0), 3.0, 1.1, 0.4, 0.08); _feed(kk, Vector3(0, 0.3, 0), Vector3(0, 0.6, -1.0)); kk.cyl("super", Vector3(0, -0.1, 0), Vector3(0, 0.3, 0), 0.3, 0.28, 8))
		"sps55", "sps67", "don2", "palm_frond":
			var l := 3.6 if t == "sps55" else (3.0 if t == "sps67" else 2.2)
			var rpm := 16.0 if t.begins_with("sps") else 24.0
			_spinner(b, c, rpm, func(kk):
				kk.cyl("super", Vector3(0, -0.1, 0), Vector3(0, 0.45, 0), 0.22, 0.18, 8)
				kk.box("radar", Vector3(0, 0.62, -0.08), Vector3(l, 0.34, 0.16))
				kk.box("dark", Vector3(0, 0.62, 0.06), Vector3(l * 0.98, 0.26, 0.1))
				if t == "sps55":
					kk.box("radar", Vector3(0, 0.62, 0.22), Vector3(l * 0.9, 0.3, 0.14)))
		"head_net":
			_spinner(b, c, 15.0, func(kk):
				kk.cyl("super", Vector3(0, -0.2, 0), Vector3(0, 0.6, 0), 0.35, 0.3, 8)
				kk.box("radar", Vector3(0, 1.1, -0.35), Vector3(5.8, 0.85, 0.18), Basis(Vector3.FORWARD, 0.0).rotated(Vector3.RIGHT, -0.32))
				kk.box("radar", Vector3(0, 1.1, 0.35), Vector3(5.8, 0.85, 0.18), Basis(Vector3.FORWARD, 0.0).rotated(Vector3.RIGHT, 0.32))
				kk.box("super", Vector3(0, 0.75, 0), Vector3(0.4, 0.4, 0.9)))
		"top_steer":
			_spinner(b, c, 12.0, func(kk):
				kk.cyl("super", Vector3(0, -0.2, 0), Vector3(0, 0.8, 0), 0.5, 0.45, 10)
				kk.box("super", Vector3(0, 1.0, 0), Vector3(1.0, 0.5, 1.6))
				kk.box("radar", Vector3(0, 2.0, -0.7), Vector3(5.2, 2.2, 0.25), Basis(Vector3.RIGHT, -0.18))
				kk.box("radar", Vector3(0, 1.7, 0.7), Vector3(3.6, 1.4, 0.22), Basis(Vector3.RIGHT, 0.2)))
		"top_pair":
			_spinner(b, c, 6.0, func(kk):
				kk.cyl("super", Vector3(0, -0.3, 0), Vector3(0, 1.0, 0), 0.8, 0.7, 12)
				kk.box("super", Vector3(0, 1.3, 0), Vector3(1.6, 0.7, 2.6))
				_dish(kk, Vector3(0, 3.0, -1.4), 7.6, 3.6, 0.9, 0.14)
				kk.box("radar", Vector3(0, 2.6, 1.6), Vector3(6.4, 2.6, 0.3), Basis(Vector3.RIGHT, 0.22))
				_feed(kk, Vector3(0, 1.4, -0.8), Vector3(0, 2.4, -3.6)))
		"band_stand":
			b.k.cyl("super", c + Vector3(0, -0.2, 0), c + Vector3(0, 1.2, 0), 2.1, 2.0, 18)
			b.k.sphere("dome", c + Vector3(0, 1.2, 0), 2.3, 18, 10, Vector3.ONE, true)
		"front_dome":
			b.k.cyl("super", c + Vector3(0, -0.2, 0), c + Vector3(0, 0.7, 0), 0.55, 0.5, 10)
			b.k.sphere("dome", c + Vector3(0, 0.95, 0), 0.78, 12, 8, Vector3.ONE)
		"top_dome":
			b.k.cyl("super", c + Vector3(0, -0.2, 0), c + Vector3(0, 1.4, 0), 2.7, 2.6, 20)
			b.k.sphere("dome", c + Vector3(0, 1.4, 0), 2.6, 20, 10, Vector3.ONE, true)
			b.k.rect_uv("dark", c + Vector3(0, 2.4, -2.2), Vector3(0, 0.5, -1).normalized(), Vector3.UP, Vector2(2.4, 1.4))
		"spq9", "mk92_cas":
			var egg := t == "mk92_cas"
			b.k.cyl("super", c + Vector3(0, -0.3, 0), c + Vector3(0, 0.9, 0), 0.5, 0.4, 10)
			b.k.sphere("dome", c + Vector3(0, 1.0 + (0.9 if egg else 0.4), 0), 1.0, 14, 10, Vector3(1.0, 1.4 if egg else 0.85, 1.0))
		"spg60", "stir", "spg62":
			var r := 1.25 if t == "spg62" else 1.2
			_director(b, c, 0.0, func(kk):
				kk.box("super", Vector3(0, 0.55, 0.2), Vector3(1.3, 1.1, 1.4))
				_round_dish(kk, Vector3(0, 1.5, -0.6), r, 0.4)
				kk.cyl("super", Vector3(0, 1.5, 0), Vector3(0, 1.5, -0.6), 0.25, 0.25, 8))
		"mk37", "mk38", "kdp":
			var rl := 4.6 if t == "mk37" else (7.6 if t == "mk38" else 8.0)
			var hw := 1.8 if t == "mk37" else 2.3
			_director(b, c, 0.0, func(kk):
				kk.block("super", 0, 0, -0.3, 2.3, hw * 2.0, 4.4, hw * 1.7, 3.6, 0.4)
				kk.cyl("super", Vector3(-rl * 0.5, 1.7, -0.6), Vector3(rl * 0.5, 1.7, -0.6), 0.32, 0.32, 10)
				for s: float in [-1.0, 1.0]:
					kk.box("super", Vector3(s * rl * 0.5, 1.7, -0.6), Vector3(0.7, 0.9, 0.9))
				kk.cyl("super", Vector3(0, 2.3, 0.2), Vector3(0, 2.8, 0.2), 0.3, 0.3, 8)
				_round_dish(kk, Vector3(0, 3.4, 0.1), 0.95 if t != "kdp" else 0.8, 0.3))
		"kite_screech", "owl_screech":
			var big := t == "kite_screech"
			_director(b, c, 0.0, func(kk):
				kk.cyl("super", Vector3(0, -0.2, 0), Vector3(0, 0.5, 0), 0.6, 0.55, 10)
				kk.box("super", Vector3(0, 1.2, 0.2), Vector3(2.0 if big else 1.6, 1.4, 1.8))
				_round_dish(kk, Vector3(0, 1.3, -0.8), 1.0 if big else 0.8, 0.35)
				kk.box("dark", Vector3(0.7, 1.9, -0.75), Vector3(0.4, 0.4, 0.2)))
		"bass_tilt":
			_director(b, c, 0.0, func(kk):
				kk.cyl("super", Vector3(0, -0.2, 0), Vector3(0, 0.7, 0), 0.4, 0.35, 8)
				kk.box("super", Vector3(0, 1.0, 0.1), Vector3(0.9, 0.7, 0.9))
				_round_dish(kk, Vector3(0, 1.1, -0.45), 0.62, 0.22))
		"pop_group", "eye_bowl":
			var n := 3 if t == "pop_group" else 2
			_director(b, c, 0.0, func(kk):
				kk.cyl("super", Vector3(0, -0.2, 0), Vector3(0, 0.5, 0), 0.5, 0.45, 10)
				kk.box("super", Vector3(0, 1.1, 0.2), Vector3(1.9, 1.2, 1.6))
				for i in n:
					_round_dish(kk, Vector3((i - (n - 1) * 0.5) * 0.75, 1.15, -0.7), 0.42 if n == 3 else 0.55, 0.18))
		_:
			push_warning("unknown radar " + t)


## Rotating antenna node.
static func _spinner(b, c: Vector3, rpm: float, draw: Callable) -> Node3D:
	var n: Node3D = b.node("radar", c)
	var kk: MeshKit = b.kit()
	draw.call(kk)
	b.attach(n, kk)
	b.add_radar(n, rpm)
	return n


## Trainable director (fire-control radar); rpm 0 means it tracks rather than spins.
static func _director(b, c: Vector3, rpm: float, draw: Callable) -> Node3D:
	var n: Node3D = b.node("director", c)
	var kk: MeshKit = b.kit()
	draw.call(kk)
	b.attach(n, kk)
	b.add_radar(n, rpm)
	return n


## Curved reflector of width w and height h, concave side facing -Z.
static func _dish(kk: MeshKit, c: Vector3, w: float, h: float, depth: float, thick: float) -> void:
	var nu := 10
	var nv := 5
	var pts := []
	for i in nu + 1:
		var col := []
		for j in nv + 1:
			var u := float(i) / nu * 2.0 - 1.0
			var v := float(j) / nv * 2.0 - 1.0
			col.append(c + Vector3(u * w * 0.5, v * h * 0.5, depth * (u * u * 0.8 + v * v * 0.2)))
		pts.append(col)
	for i in nu:
		for j in nv:
			var a: Vector3 = pts[i][j]
			var bb: Vector3 = pts[i + 1][j]
			var cc: Vector3 = pts[i + 1][j + 1]
			var d: Vector3 = pts[i][j + 1]
			var n := (bb - a).cross(d - a).normalized()
			if n.z > 0.0:
				n = -n
			kk.quad_dir("radar", a, bb, cc, d, n)
			var off := -n * thick
			kk.quad_dir("dark", a + off * -0.0 + Vector3(0, 0, thick), bb + Vector3(0, 0, thick), cc + Vector3(0, 0, thick), d + Vector3(0, 0, thick), -n)
	kk.box("super", c + Vector3(0, 0, depth + 0.25), Vector3(0.5, h * 0.6, 0.4))


static func _round_dish(kk: MeshKit, c: Vector3, r: float, depth: float) -> void:
	var segs := 14
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var p0 := c + Vector3(cos(a0) * r, sin(a0) * r, -depth * 0.1)
		var p1 := c + Vector3(cos(a1) * r, sin(a1) * r, -depth * 0.1)
		var q := c + Vector3(0, 0, depth * 0.6)
		kk.tri("radar", p0, p1, q, Vector3(0, 0, -1))
		kk.tri("dark", p0, p1, q + Vector3(0, 0, 0.08), Vector3(0, 0, 1))
	kk.cyl("dark", c + Vector3(0, 0, -0.1), c + Vector3(0, 0, -depth - 0.2), 0.08, 0.06, 6)


static func _feed(kk: MeshKit, base: Vector3, horn: Vector3) -> void:
	kk.bar("super", base, horn, 0.1)
	kk.box("dark", horn, Vector3(0.35, 0.3, 0.3))
