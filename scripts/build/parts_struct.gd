extends RefCounted
## Superstructure, bridges, funnels, masts and deck fittings for ship_builder.gd.
## Each function takes the builder `b` and a part dictionary from ships.gd.

const MeshKit := preload("res://scripts/build/mesh_kit.gd")
const Sensors := preload("res://scripts/build/parts_sensors.gd")


static func part(b, p: Dictionary) -> void:
	match String(p["t"]):
		"house": house(b, p)
		"bridge": bridge(b, p)
		"funnel": funnel(b, p)
		"mast": mast(b, p)
		"radar": Sensors.radar(b, p)
		"array": array(b, p)
		"hangar": hangar(b, p)
		"helideck": helideck(b, p)
		"boat": boat(b, p)
		"rafts": rafts(b, p)
		"ecm": ecm(b, p)
		"box": deck_box(b, p)
		"ct": conning_tower(b, p)
		"crane": crane(b, p)
		"vds": vds(b, p)
		"aa37": aa37(b, p)
		"cargo": cargo(b, p)
		"pipes": pipes(b, p)
		_:
			push_warning("unknown part " + String(p["t"]))


## Corners of a deckhouse following the sheer: front at x0, back at x1.
static func _house_pts(b, x0: float, x1: float, rel: float, h: float, w: float, o := 0.0, rf := 0.0,
		rb := 0.0, taper := 0.0, sink := 0.6) -> Array:
	var yf: float = b.dy(x0) + rel
	var ya: float = b.dy(x1) + rel
	var zf: float = b.z(x0)
	var za: float = b.z(x1)
	var hw := w * 0.5
	var tw := hw - taper
	return [Vector3(o - hw, yf - sink, zf), Vector3(o + hw, yf - sink, zf), Vector3(o + hw, ya - sink, za), Vector3(o - hw, ya - sink, za),
		Vector3(o - tw, yf + h, zf + rf), Vector3(o + tw, yf + h, zf + rf), Vector3(o + tw, ya + h, za - rb), Vector3(o - tw, ya + h, za - rb)]


static func house(b, p: Dictionary) -> void:
	var x0: float = p["x0"]
	var x1: float = p["x1"]
	var rel: float = p.get("rel", 0.0)
	var h: float = p["h"]
	var w: float = p.get("w", b.hd((x0 + x1) * 0.5) * 1.6)
	var o: float = p.get("o", 0.0)
	var mat: String = p.get("mat", "super")
	var rf: float = p.get("rake_f", 0.0)
	var rb: float = p.get("rake_b", 0.0)
	var taper: float = p.get("taper", 0.0)
	var pts := _house_pts(b, x0, x1, rel, h, w, o, rf, rb, taper)
	b.k.hexa(mat, pts, "deck", true)
	if rel < 0.1 and w > b.hd((x0 + x1) * 0.5) * 1.7:
		b.cover(x0, x1)
	var win: int = p.get("win", 0)
	var zf: float = b.z(x0)
	var za: float = b.z(x1)
	var yf: float = b.dy(x0) + rel
	var ya: float = b.dy(x1) + rel
	var len := za - zf
	# Windows or scuttles along both sides, doors near each end.
	if win > 0:
		var fy := 0.62
		var n := int(len / (5.5 if win == 1 else 1.8))
		for s: float in [-1.0, 1.0]:
			var nx := s * (w * 0.5 - taper * fy) + o
			var nrm := Vector3(s, taper / h, 0).normalized()
			for i in n:
				var t := (i + 0.5) / n
				var zc := lerpf(zf + rf * fy + 0.8, za - rb * fy - 0.8, t)
				var yc := lerpf(yf, ya, (zc - zf) / len) + h * fy
				b.k.disc("glass", Vector3(nx + s * 0.03, yc, zc), nrm, 0.2, 10)
			for dz: float in [0.18, 0.82]:
				var zc := lerpf(zf, za, dz)
				var yc := lerpf(yf, ya, dz)
				b.k.rect_uv("dark", Vector3(s * (w * 0.5 - taper * 0.18) + o + s * 0.03, yc + 0.95, zc), nrm, Vector3.UP, Vector2(0.75, 1.85))
	# Roof railing and a few vents.
	var top := [pts[4], pts[5], pts[6], pts[7], pts[4]]
	b.kd.railing("wire", top, 1.0, 2.0, 0.04)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x0 * 13.0 + rel * 7.0)
	for i in int(len / 7.0):
		var zc := lerpf(zf + 1.0, za - 1.0, rng.randf())
		var xc := o + rng.randf_range(-0.35, 0.35) * w
		var yc := lerpf(yf, ya, (zc - zf) / len) + h
		b.kd.box("super", Vector3(xc, yc + 0.3, zc), Vector3(0.6, 0.6, 0.8))


static func bridge(b, p: Dictionary) -> void:
	var x0: float = p["x0"]
	var x1: float = p["x1"]
	var rel: float = p.get("rel", 0.0)
	var h: float = p["h"]
	var w: float = p["w"]
	var wings: float = p.get("wings", w)
	var old: bool = p.get("old", false)
	var mat: String = p.get("mat", "super")
	var rf := 0.0 if old else -0.45
	var pts := _house_pts(b, x0, x1, rel, h, w, 0.0, rf, 0.0, 0.0, 0.3)
	b.kb.hexa(mat, pts, "deck", true)
	var yb: float = b.dy((x0 + x1) * 0.5) + rel
	var zf: float = b.z(x0)
	var za: float = b.z(x1)
	b.bridge = {"x0": x0, "x1": x1, "y": yb, "w": w, "h": h, "wings": wings, "z0": zf, "z1": za, "rake": rf, "old": old}
	# Front windows.
	var nwin := int(w / (1.15 if not old else 0.95))
	var wy0 := yb + 1.1
	var wy1 := yb + h - 0.35
	var fz0 := zf - 0.03
	var fn := Vector3(0, -rf / h, -1).normalized()
	for i in nwin:
		var t := (i + 0.5) / nwin
		var xc := lerpf(-w * 0.5 + 0.25, w * 0.5 - 0.25, t)
		var fy := 0.5 * (wy0 + wy1)
		var zc := fz0 + rf * ((fy - yb) / h)
		b.kb.rect_uv("glass", Vector3(xc, fy, zc), fn, Vector3(0, 1, rf / h).normalized(), Vector2(w / nwin - 0.14, wy1 - wy0))
	# Side windows on the forward part.
	for s: float in [-1.0, 1.0]:
		var nside := int((za - zf) * 0.55 / 1.2)
		for i in nside:
			var zc := zf + 0.8 + i * 1.2
			b.kb.rect_uv("glass", Vector3(s * (w * 0.5 + 0.03), 0.5 * (wy0 + wy1), zc), Vector3(s, 0, 0), Vector3.UP, Vector2(1.0, wy1 - wy0))
	# Visor over the windows.
	b.k.box(mat, Vector3(0, yb + h - 0.08, zf + rf - 0.25), Vector3(w + 0.3, 0.16, 0.7))
	# Bridge wings (outside the shell so they stay in view from inside).
	if wings > w + 0.5:
		var wl := minf(3.6, (za - zf) * 0.6)
		for s: float in [-1.0, 1.0]:
			var x_in := s * w * 0.5
			var x_out := s * wings * 0.5
			b.k.box(mat, Vector3((x_in + x_out) * 0.5, yb - 0.12, zf + wl * 0.5), Vector3(absf(x_out - x_in), 0.24, wl))
			b.k.box(mat, Vector3(x_out - s * 0.06, yb + 0.55, zf + wl * 0.5), Vector3(0.12, 1.1, wl))
			b.k.box(mat, Vector3((x_in + x_out) * 0.5, yb + 0.55, zf + 0.06), Vector3(absf(x_out - x_in), 1.1, 0.12))
			b.k.bar("super", Vector3(x_out, yb - 0.2, zf + wl), Vector3(x_in * 0.6, yb - 2.4, zf + wl), 0.2)
			b.kd.box("dark", Vector3(x_out - s * 0.5, yb + 1.35, zf + 0.6), Vector3(0.4, 0.5, 0.6))
	b.kd.railing("wire", [pts[4], pts[5], pts[6], pts[7], pts[4]], 0.9, 2.0, 0.04)


## Elliptical stack of rings, raked aft by `rake` over its height.
static func _ellipse_stack(kk: MeshKit, mat: String, o: float, zc: float, y0: float, y1: float,
		a0: float, b0: float, a1: float, b1: float, rake: float, segs := 18, cap := "") -> void:
	var rings := 4
	var prev := []
	for r in rings + 1:
		var t := float(r) / rings
		var y := lerpf(y0, y1, t)
		var a := lerpf(a0, a1, t)
		var bb := lerpf(b0, b1, t)
		var zo := zc + rake * t
		var ring := []
		for i in segs + 1:
			var ang := TAU * i / segs
			ring.append(Vector3(o + cos(ang) * bb, y, zo + sin(ang) * a))
		if r > 0:
			for i in segs:
				var n0 := Vector3(cos(TAU * i / segs) / bb, 0, sin(TAU * i / segs) / a).normalized()
				var n1 := Vector3(cos(TAU * (i + 1) / segs) / bb, 0, sin(TAU * (i + 1) / segs) / a).normalized()
				kk.quad_n(mat, prev[i], prev[i + 1], ring[i + 1], ring[i], n0, n1, n1, n0)
		prev = ring
	if cap != "":
		var c := Vector3(o, y1, zc + rake)
		for i in segs:
			kk.tri(cap, c, prev[i], prev[i + 1], Vector3.UP)


static func funnel(b, p: Dictionary) -> void:
	var x: float = p["x"]
	var l: float = p["l"]
	var w: float = p["w"]
	var o: float = p.get("o", 0.0)
	var h: float = p["h"]
	var rake: float = p.get("rake", 0.0)
	var yb: float = b.dy(x) + float(p.get("rel", 0.0)) - 0.4
	var yt: float = yb + 0.4 + h
	var zc: float = b.z(x)
	match String(p.get("style", "box")):
		"ww2":
			_ellipse_stack(b.k, "super", o, zc, yb - 0.2, yt - 1.3, l * 0.55, w * 0.55, l * 0.5, w * 0.5, rake * (h - 1.3) / h)
			_ellipse_stack(b.k, "soot", o, zc + rake * (h - 1.3) / h, yt - 1.3, yt, l * 0.5, w * 0.5, l * 0.49, w * 0.49, rake * 1.3 / h, 18, "black")
			b.k.box("dark", Vector3(o, yt + 0.6, zc + rake - l * 0.12), Vector3(0.12, 1.2, 0.12))
			for i in 3:
				b.k.cyl("soot", Vector3(o + (i - 1) * w * 0.25, yt - 0.4, zc + rake), Vector3(o + (i - 1) * w * 0.25, yt + 0.45, zc + rake), 0.35, 0.35, 8)
			_ellipse_stack(b.k, "super", o, zc - 0.3, yb - 0.2, yb + 1.0, l * 0.7, w * 0.68, l * 0.58, w * 0.58, 0.1)
		"gt":
			b.k.block("super", o, zc, yb, yt, w, l, w * 0.94, l * 0.9, rake)
			b.k.block("black", o, zc + rake, yt - 0.05, yt + 0.12, w * 0.9, l * 0.86, w * 0.9, l * 0.86)
			for i in 4:
				var px := o + (-0.25 if i % 2 == 0 else 0.25) * w
				var pz := zc + rake + (-0.22 if i < 2 else 0.22) * l
				b.k.cyl("soot", Vector3(px, yt - 0.2, pz), Vector3(px, yt + 1.4, pz), 0.42, 0.42, 10, true, "black")
			for sd: float in [-1.0, 1.0]:
				for i in 5:
					b.kd.box("super", Vector3(o + sd * (w * 0.47 + 0.05), yt - 1.2 - i * 0.35, zc + rake * 0.85), Vector3(0.08, 0.08, l * 0.6))
		"su":
			b.k.block("super", o, zc, yb, yt - 0.9, w, l, w * 0.82, l * 0.86, rake)
			b.k.block("soot", o, zc + rake, yt - 0.9, yt, w * 0.82, l * 0.86, w * 0.78, l * 0.7, 0.4)
			b.k.box("black", Vector3(o, yt + 0.02, zc + rake + 0.3), Vector3(w * 0.7, 0.06, l * 0.55))
			b.k.box("super", Vector3(o, yt + 0.25, zc + rake - l * 0.38), Vector3(w * 0.84, 0.5, 0.6))
		"su_gt":
			b.k.block("super", o, zc, yb, yt, w, l, w * 0.9, l * 0.8, rake)
			for i in 2:
				b.k.box("soot", Vector3(o + (i - 0.5) * w * 0.42, yt + 0.25, zc + rake), Vector3(w * 0.36, 0.5, l * 0.6))
				b.k.box("black", Vector3(o + (i - 0.5) * w * 0.42, yt + 0.52, zc + rake), Vector3(w * 0.3, 0.04, l * 0.5))
		_:
			b.k.block("super", o, zc, yb, yt, w, l, w * 0.9, l * 0.82, rake)
			b.k.block("black", o, zc + rake, yt - 0.7, yt + 0.02, w * 0.91, l * 0.83, w * 0.9, l * 0.82)
			for i in 2:
				b.k.cyl("soot", Vector3(o + (i - 0.5) * w * 0.4, yt - 0.3, zc + rake), Vector3(o + (i - 0.5) * w * 0.4, yt + 0.9, zc + rake), 0.35, 0.35, 8, true, "black")
	b.smoke.append(Vector3(o, yt + 0.4, zc + rake))


static func mast(b, p: Dictionary) -> void:
	var x: float = p["x"]
	var o: float = p.get("o", 0.0)
	var yb: float = b.base_y(p, x)
	var y1: float = p["y1"]
	var w: float = p.get("w", 1.5)
	var zc: float = b.z(x)
	var top := y1
	match String(p.get("style", "pole")):
		"pole":
			b.k.cyl("super", Vector3(o, yb - 0.3, zc), Vector3(o, y1, zc), w * 0.5, w * 0.2, 10)
		"lattice":
			var y2 := y1 - 3.0
			b.k.lattice_tower("super", Vector3(o, 0, zc), yb - 0.2, y2, w * 0.5, w * 0.5, w * 0.2, w * 0.2, maxi(3, int((y2 - yb) / 2.4)), 0.11)
			b.k.box("super", Vector3(o, y2, zc), Vector3(w * 0.5, 0.2, w * 0.5))
			b.k.cyl("super", Vector3(o, y2, zc), Vector3(o, y1, zc), 0.16, 0.08, 6)
		"su_lattice":
			var y2 := y1 - 3.0
			b.k.lattice_tower("super", Vector3(o, 0, zc), yb - 0.2, y2, w * 0.55, w * 0.7, w * 0.3, w * 0.35, maxi(3, int((y2 - yb) / 2.0)), 0.13)
			for f: float in [0.45, 0.8]:
				var yy := lerpf(yb, y2, f)
				var ww := lerpf(w * 1.1, w * 0.6, f) + 1.0
				b.k.box("super", Vector3(o, yy, zc), Vector3(ww, 0.18, ww))
				b.kd.railing("wire", _square(o, yy, zc, ww * 0.5), 0.9, 1.5, 0.035)
			b.k.cyl("super", Vector3(o, y2, zc), Vector3(o, y1, zc), 0.2, 0.08, 6)
		"tripod":
			b.k.cyl("super", Vector3(o, yb - 0.3, zc), Vector3(o, y1, zc), w * 0.32, w * 0.16, 10)
			for s: float in [-1.0, 1.0]:
				b.k.cyl("super", Vector3(o + s * w * 1.8, yb - 0.3, zc + w * 2.4), Vector3(o, lerpf(yb, y1, 0.72), zc), w * 0.2, w * 0.14, 8)
		"tower":
			var y2 := y1 - 9.0
			b.k.cyl("super", Vector3(o, yb - 0.3, zc), Vector3(o, y2, zc), w, w * 0.55, 8)
			b.k.lattice_tower("super", Vector3(o, 0, zc), y2, y1 - 2.0, w * 0.4, w * 0.4, w * 0.16, w * 0.16, 4, 0.1)
			b.k.cyl("super", Vector3(o, y1 - 2.0, zc), Vector3(o, y1, zc), 0.14, 0.07, 6)
		"pyramid":
			var y2 := y1 - 6.0
			b.k.block("super", o, zc, yb - 0.3, y2, w * 1.5, w * 1.9, w * 0.45, w * 0.55, 0.2)
			for f: float in [0.3, 0.62]:
				var yy := lerpf(yb, y2, f)
				var ww := lerpf(w * 1.5, w * 0.45, f) + 1.4
				b.k.box("super", Vector3(o, yy, zc), Vector3(ww, 0.2, lerpf(w * 1.9, w * 0.55, f) + 1.4))
			b.k.lattice_tower("super", Vector3(o, 0, zc), y2, y1 - 1.5, w * 0.22, w * 0.27, w * 0.15, w * 0.15, 3, 0.1)
			b.k.cyl("super", Vector3(o, y1 - 1.5, zc), Vector3(o, y1, zc), 0.12, 0.06, 6)
	for yd in p.get("yards", []):
		var yh: float = yd[0]
		var yw: float = yd[1]
		b.k.bar("super", Vector3(o - yw * 0.5, yh, zc), Vector3(o + yw * 0.5, yh, zc), 0.16)
		for s: float in [-1.0, 1.0]:
			b.kd.bar("wire", Vector3(o + s * yw * 0.45, yh, zc), Vector3(o + s * yw * 0.42, yh - 2.2, zc), 0.03)
			b.kd.bar("wire", Vector3(o + s * yw * 0.3, yh, zc), Vector3(o + s * yw * 0.3, yh + 2.6, zc), 0.035)
	if p.has("platform"):
		var pf: Array = p["platform"]
		b.k.box("super", Vector3(o, pf[0], zc), Vector3(pf[1], 0.18, pf[1]))
		b.kd.railing("wire", _square(o, pf[0], zc, pf[1] * 0.5), 0.9, 1.4, 0.035)
	if p.get("tacan", false):
		b.k.cyl("dome", Vector3(o, top, zc), Vector3(o, top + 1.3, zc), 0.55, 0.5, 12)
		top += 1.3
	if p.get("lights", false):
		b.k.sphere("lamp_w", Vector3(o, top + 0.15, zc), 0.16, 6, 4)
		b.lights.append([Vector3(o, top + 0.15, zc), "mast"])
	b.kd.bar("wire", Vector3(o, top, zc), Vector3(o, top + 3.0, zc), 0.04)


static func _square(o: float, y: float, zc: float, r: float) -> Array:
	return [Vector3(o - r, y, zc - r), Vector3(o + r, y, zc - r), Vector3(o + r, y, zc + r), Vector3(o - r, y, zc + r), Vector3(o - r, y, zc - r)]


## Aegis SPY-1 array face: an octagonal plate mounted on a deckhouse wall.
static func array(b, p: Dictionary) -> void:
	var x: float = p["x"]
	var y: float = b.base_y(p, x)
	var face: float = p.get("face", 0.0)
	var r: float = float(p.get("size", 3.8)) * 0.5
	var n: Vector3 = (Vector3(sin(deg_to_rad(face)), 0.18, -cos(deg_to_rad(face)))).normalized()
	var c: Vector3
	if absf(fposmod(face, 180.0) - 90.0) < 1.0:
		var o: float = p.get("o", b.hd(x) * 0.8)
		c = Vector3((1.0 if face < 180.0 else -1.0) * o + n.x * 0.15, y, b.z(x))
	else:
		c = Vector3(p.get("o", 0.0), y, b.z(x) + n.z * 0.15)
	var up := Vector3.UP - n * n.dot(Vector3.UP)
	up = up.normalized()
	var rt := up.cross(n).normalized()
	var ring := []
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		ring.append(c + (rt * cos(a) + up * sin(a)) * r)
	for i in 8:
		b.k.tri("radar", c + n * 0.25, ring[i] + n * 0.25, ring[(i + 1) % 8] + n * 0.25, n)
		b.k.quad("dark", ring[i], ring[(i + 1) % 8], ring[(i + 1) % 8] + n * 0.25, ring[i] + n * 0.25, c)


static func hangar(b, p: Dictionary) -> void:
	var x0: float = p["x0"]
	var x1: float = p["x1"]
	var h: float = p["h"]
	var w: float = p["w"]
	var pts := _house_pts(b, x0, x1, 0.0, h, w)
	b.k.hexa("super", pts, "deck", true)
	if w > b.hd(x1) * 1.6:
		b.cover(x0, x1)
	var za: float = b.z(x1) + 0.03
	var ya: float = b.dy(x1)
	var nd: int = p.get("doors", 1)
	var dw := (w - 1.0) / nd
	for i in nd:
		var xc := -w * 0.5 + 0.5 + dw * (i + 0.5)
		b.k.rect_uv("pale", Vector3(xc, ya + (h - 0.6) * 0.5, za), Vector3(0, 0, 1), Vector3.UP, Vector2(dw - 0.5, h - 0.6))
		for j in int((h - 0.6) / 0.45):
			b.kd.box("super", Vector3(xc, ya + 0.3 + j * 0.45, za + 0.02), Vector3(dw - 0.6, 0.06, 0.04))
	if p.get("tele", false):
		for i in 3:
			var zz := za + 0.9 * (i + 1)
			b.k.box("super", Vector3(0, ya + h * (0.5 - i * 0.04), zz - 0.45), Vector3(w * (0.96 - i * 0.04), h * (1.0 - i * 0.08), 0.9))


static func helideck(b, p: Dictionary) -> void:
	var x0: float = p["x0"]
	var x1: float = p["x1"]
	var y: float = b.dy((x0 + x1) * 0.5) + 0.03
	var z0: float = b.z(x0)
	var z1: float = b.z(x1)
	var circle: bool = p.get("circle", false) or b.side == "su"
	var hw: float = b.hd((x0 + x1) * 0.5) - 0.6
	var up := Vector3.UP
	if circle:
		var c := Vector3(0, y, (z0 + z1) * 0.5)
		var r := minf(hw, (z1 - z0) * 0.42)
		_ring(b.k, "white", c, r - 0.3, r, 40)
		if b.side == "su":
			b.k.box("white", c, Vector3(0.3, 0.01, r * 1.4))
			b.k.box("white", c, Vector3(r * 1.4, 0.01, 0.3))
		else:
			_ring(b.k, "yellow", c, r * 0.32, r * 0.36, 24)
	else:
		for i in int((z1 - z0) / 2.4):
			var zz := z0 + 0.8 + i * 2.4
			b.k.box("white", Vector3(0, y, zz), Vector3(0.25, 0.01, 1.3))
		b.k.box("yellow", Vector3(0, y, lerpf(z0, z1, 0.45)), Vector3(hw * 1.6, 0.01, 0.3))
		_ring(b.k, "white", Vector3(0, y, lerpf(z0, z1, 0.45)), 3.2, 3.5, 28)
	for s: float in [-1.0, 1.0]:
		b.k.box("white", Vector3(s * (hw + 0.1), y, (z0 + z1) * 0.5), Vector3(0.2, 0.01, z1 - z0 - 0.6))
		b.kd.quad("wire", Vector3(s * (hw + 0.6), y - 0.05, z0), Vector3(s * (hw + 0.6), y - 0.05, z1),
			Vector3(s * (hw + 1.8), y + 0.25, z1), Vector3(s * (hw + 1.8), y + 0.25, z0), Vector3(0, y + 5.0, (z0 + z1) * 0.5))
	if p.get("elevator", false):
		b.k.rect_uv("dark", Vector3(0, y + 0.005, lerpf(z0, z1, 0.2)), up, Vector3.FORWARD, Vector2(5.0, 9.0))


static func _ring(kk: MeshKit, mat: String, c: Vector3, r0: float, r1: float, segs: int) -> void:
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		kk.quad_dir(mat, c + d0 * r0, c + d1 * r0, c + d1 * r1, c + d0 * r1, Vector3.UP)


static func boat(b, p: Dictionary) -> void:
	var x: float = p["x"]
	var o: float = p.get("o", 0.0)
	var y: float = b.base_y(p, x) + 1.4
	var l: float = p.get("len", 7.0)
	var bw := l * 0.32
	var zc: float = b.z(x)
	var s := signf(o) if o != 0.0 else 1.0
	var hull := [Vector2(o, zc - l * 0.5), Vector2(o + bw * 0.5, zc - l * 0.22), Vector2(o + bw * 0.5, zc + l * 0.5),
		Vector2(o - bw * 0.5, zc + l * 0.5), Vector2(o - bw * 0.5, zc - l * 0.22)]
	b.k.prism("rubber" if b.side == "us" else "pale", hull, y - 0.5, y + 0.15, "pale")
	b.k.box("pale", Vector3(o, y + 0.45, zc + l * 0.05), Vector3(bw * 0.6, 0.6, l * 0.35))
	b.k.box("orange" if b.side == "su" else "dark", Vector3(o, y + 0.1, zc + l * 0.3), Vector3(bw * 0.7, 0.3, l * 0.2))
	for dz: float in [-0.3, 0.3]:
		var zz := zc + dz * l
		b.kd.bar("dark", Vector3(o - s * bw * 0.9, y - 1.6, zz), Vector3(o - s * bw * 0.9, y + 1.0, zz), 0.16)
		b.kd.bar("dark", Vector3(o - s * bw * 0.9, y + 1.0, zz), Vector3(o + s * bw * 0.1, y + 1.3, zz), 0.14)
		b.kd.bar("wire", Vector3(o + s * bw * 0.1, y + 1.3, zz), Vector3(o, y + 0.2, zz), 0.03)


static func rafts(b, p: Dictionary) -> void:
	var x0: float = p["x0"]
	var x1: float = p["x1"]
	var o: float = p["o"]
	var n := int((x1 - x0) / 1.5)
	for i in n:
		var x := x0 + (i + 0.5) * 1.5
		var y: float = b.dy(x) + float(p.get("rel", 0.0)) + 0.5
		var zc: float = b.z(x)
		b.kd.cyl("white", Vector3(o - 0.6, y, zc), Vector3(o + 0.6, y, zc), 0.36, 0.36, 10)
		b.kd.box("dark", Vector3(o, y - 0.38, zc), Vector3(1.4, 0.08, 0.9))


static func ecm(b, p: Dictionary) -> void:
	var x: float = p["x"]
	var y: float = b.base_y(p, x)
	var o: float = p["o"]
	var zc: float = b.z(x)
	var s := signf(o)
	b.k.block("super", o, zc, y, y + 2.2, 1.4, 2.6, 1.0, 2.2)
	b.k.box("dome", Vector3(o + s * 0.72, y + 1.1, zc), Vector3(0.06, 1.6, 2.0))
	b.k.cyl("dome", Vector3(o, y + 2.2, zc), Vector3(o, y + 2.9, zc), 0.5, 0.45, 10)


static func deck_box(b, p: Dictionary) -> void:
	var pts := _house_pts(b, p["x0"], p["x1"], p.get("rel", 0.0), p["h"], p["w"], p.get("o", 0.0))
	b.k.hexa(p.get("mat", "super"), pts, "deck", true)


static func conning_tower(b, p: Dictionary) -> void:
	var x: float = p["x"]
	var y: float = b.base_y(p, x)
	var r: float = p["r"]
	var h: float = p["h"]
	var zc: float = b.z(x)
	_ellipse_stack(b.k, "super", 0.0, zc, y - 0.4, y + h, r * 1.15, r, r * 1.12, r * 0.97, 0.0, 20, "deck")
	for i in 16:
		var a := -PI * 0.5 + (i - 7.5) / 16.0 * PI * 1.1
		var c := Vector3(cos(a) * r * 0.985, y + h - 0.7, zc + sin(a) * r * 1.13)
		b.k.rect_uv("black", c, Vector3(cos(a), 0, sin(a)), Vector3.UP, Vector2(r * 0.28, 0.16))
	b.k.cyl("super", Vector3(0, y + h, zc), Vector3(0, y + h + 0.5, zc), r * 0.5, r * 0.45, 12)


static func crane(b, p: Dictionary) -> void:
	var x: float = p["x"]
	var o: float = p.get("o", 0.0)
	var y: float = b.base_y(p, x)
	var h: float = p.get("h", 8.0)
	var boom: float = p.get("boom", 10.0)
	var zc: float = b.z(x)
	b.k.cyl("super", Vector3(o, y - 0.3, zc), Vector3(o, y + h, zc), 0.55, 0.45, 10)
	b.k.box("super", Vector3(o, y + h * 0.5, zc + 0.7), Vector3(1.1, 1.6, 1.2))
	var dir := Vector3(0, 0, 1) if o == 0.0 else Vector3(-signf(o) * 0.3, 0, 0.95).normalized()
	var tip := Vector3(o, y + 2.0, zc) + dir * boom + Vector3(0, boom * 0.25, 0)
	b.k.bar("super", Vector3(o, y + 1.6, zc), tip, 0.38)
	b.kd.bar("wire", Vector3(o, y + h, zc), tip, 0.04)
	b.kd.bar("wire", tip, tip - Vector3(0, 2.5, 0), 0.03)
	b.kd.box("dark", tip - Vector3(0, 2.7, 0), Vector3(0.3, 0.4, 0.3))


static func vds(b, p: Dictionary) -> void:
	var x0: float = p["x0"]
	var x1: float = p["x1"]
	var y: float = b.dy(x1)
	var z0: float = b.z(x0)
	var z1: float = b.z(x1)
	b.k.block("super", 0, (z0 + z1) * 0.5, y - 0.3, y + 2.6, 5.0, z1 - z0, 4.4, z1 - z0 - 1.0, 0.5)
	b.k.rect_uv("black", Vector3(0, y + 1.0, z1 + 0.02), Vector3(0, 0, 1), Vector3.UP, Vector2(3.2, 1.7))
	for s: float in [-1.0, 1.0]:
		b.kd.bar("dark", Vector3(s * 1.8, y, z1 - 0.2), Vector3(s * 1.4, y + 3.6, z1 + 0.6), 0.22)


static func aa37(b, p: Dictionary) -> void:
	var x: float = p["x"]
	var o: float = p["o"]
	var y: float = b.base_y(p, x)
	var zc: float = b.z(x)
	var s := signf(o)
	b.k.cyl("super", Vector3(o, y - 0.2, zc), Vector3(o, y + 0.7, zc), 0.8, 0.7, 10)
	b.k.block("super", o, zc, y + 0.7, y + 1.8, 1.8, 1.6, 1.6, 1.2, 0.3)
	for i in 2:
		var bx := o + (i - 0.5) * 0.5
		b.k.cyl("gun", Vector3(bx, y + 1.3, zc - 0.5), Vector3(bx + s * 1.2, y + 2.3, zc - 2.4), 0.07, 0.06, 6)


static func cargo(b, p: Dictionary) -> void:
	var x0: float = p["x0"]
	var x1: float = p["x1"]
	var n: int = p.get("holds", 4)
	var hl := (x1 - x0) / n
	for i in n:
		var xa := x0 + i * hl + 1.5
		var xb := xa + hl - 3.0
		var w: float = b.hd((xa + xb) * 0.5) * 1.3
		b.k.hexa("dark", _house_pts(b, xa, xb, 0.0, 1.4, w), "red", true)
		if i < n - 1:
			var xp := xa + hl - 1.5
			var yb: float = b.dy(xp)
			for s: float in [-1.0, 1.0]:
				b.k.cyl("pale", Vector3(s * 3.0, yb, b.z(xp)), Vector3(s * 3.0, yb + 13.0, b.z(xp)), 0.4, 0.3, 8)
				b.k.bar("pale", Vector3(s * 3.0, yb + 2.0, b.z(xp)), Vector3(s * 2.0, yb + 11.0, b.z(xp) - 6.0), 0.25)
			b.k.bar("pale", Vector3(-3.0, yb + 12.5, b.z(xp)), Vector3(3.0, yb + 12.5, b.z(xp)), 0.3)


static func pipes(b, p: Dictionary) -> void:
	var x0: float = p["x0"]
	var x1: float = p["x1"]
	for o: float in [-2.5, -1.2, 1.2, 2.5]:
		b.k.cyl("red", Vector3(o, b.dy(x0) + 0.6, b.z(x0)), Vector3(o, b.dy(x1) + 0.6, b.z(x1)), 0.32, 0.32, 8, false)
	b.k.box("pale", Vector3(0, b.dy((x0 + x1) * 0.5) + 2.0, b.z((x0 + x1) * 0.5)), Vector3(1.2, 0.15, x1 - x0))
	for i in int((x1 - x0) / 12.0):
		var x := x0 + 6.0 + i * 12.0
		b.k.box("pale", Vector3(0, b.dy(x) + 1.0, b.z(x)), Vector3(1.0, 2.0, 0.3))
	b.k.box("red", Vector3(0, b.dy((x0 + x1) * 0.5) + 1.2, b.z((x0 + x1) * 0.5)), Vector3(14.0, 1.6, 3.0))
