extends RefCounted
## Parametric hull form. Positions along the hull are measured in metres from the
## bow (x), heights from the waterline (y). The model puts the bow at -Z.
##
## Spec keys: L, B, T (length, beam, draft), fb ([[x, deck height], ...] sheer
## profile), bow ("raked", "clipper", "cruiser"), stern ("transom", "cruiser"),
## rake (stem overhang at the keel, m), forefoot, bulb/bulb_y (sonar dome or bulb),
## entrance, run (fractions of L), fine, mid_n, end_n (section fullness), flare,
## transom_w (fraction of half-beam), transom_y, keel_rise, overhang, camber.

const MeshKit := preload("res://scripts/build/mesh_kit.gd")

var s: Dictionary
var L: float
var B: float
var T: float
var fb: Array
var bow: String
var stern: String
const NU := 84
const NV := 18
var grid := []


func _init(spec: Dictionary) -> void:
	s = spec
	L = spec["L"]
	B = spec["B"]
	T = spec["T"]
	fb = spec["fb"]
	bow = spec.get("bow", "raked")
	stern = spec.get("stern", "transom")


func deck_y(x: float) -> float:
	if x <= fb[0][0]:
		return fb[0][1]
	for i in fb.size() - 1:
		var a: Array = fb[i]
		var b: Array = fb[i + 1]
		if x <= b[0]:
			return lerpf(a[1], b[1], (x - a[0]) / maxf(b[0] - a[0], 1e-4))
	return fb[fb.size() - 1][1]


func keel_y(x: float) -> float:
	var xn := x / L
	var k0: float = s.get("keel_rise", 0.68)
	var ty: float = s.get("transom_y", -0.25 * T)
	var dome := 0.0
	if s.has("dome"):
		var dm: Array = s["dome"]
		dome = float(dm[2]) * exp(-pow((x - float(dm[0])) / float(dm[1]), 2.0))
	if xn <= k0:
		return -T - dome
	var t := clampf((xn - k0) / (1.0 - k0), 0.0, 1.0)
	return lerpf(-T, ty, t * t * (3.0 - 2.0 * t))


func stem_x(y: float) -> float:
	var d := deck_y(0.0)
	var h := clampf((d - y) / (d + T), 0.0, 1.0)
	var rake: float = s.get("rake", 0.05 * L)
	var x := 0.0
	match bow:
		"clipper":
			x = rake * pow(h, 0.55)
		"cruiser":
			x = rake * pow(h, 0.8)
		_:
			x = rake * h
	x += float(s.get("forefoot", 0.035 * L)) * pow(h, 5.0)
	var bulb: float = s.get("bulb", 0.0)
	if bulb > 0.0:
		var by: float = s.get("bulb_y", -0.65 * T)
		var bh: float = s.get("bulb_h", 0.3 * T)
		x -= bulb * exp(-pow((y - by) / bh, 2.0))
	return x


func stern_x(y: float) -> float:
	if stern == "transom":
		return L
	var d := deck_y(L)
	var h := clampf((d - y) / (d + 0.3 * T), 0.0, 1.0)
	return L - float(s.get("overhang", 0.035 * L)) * pow(h, 1.5)


## Half-breadth of the hull at station x (from bow) and height y.
func half_breadth(x: float, y: float) -> float:
	var sx := stem_x(y)
	var ex := stern_x(y)
	if x <= sx or x > ex + 1e-3:
		return 0.0
	var e: float = float(s.get("entrance", 0.4)) * L
	var rr: float = float(s.get("run", 0.35)) * L
	var d := x - sx
	var w := 1.0
	if d < e:
		w = pow(sin(d / e * PI * 0.5), float(s.get("fine", 0.85)))
	var to_end := ex - x
	if to_end < rr:
		var t := 1.0 - to_end / rr
		if stern == "transom":
			var ty: float = s.get("transom_y", -0.25 * T)
			var dy := deck_y(L)
			var tw_deck: float = s.get("transom_w", 0.8)
			var tw := lerpf(tw_deck * 0.62, tw_deck, clampf((y - ty) / maxf(dy - ty, 0.1), 0.0, 1.0))
			w *= 1.0 - (1.0 - tw) * pow(t, 1.7)
		else:
			w *= sqrt(maxf(0.0, 1.0 - pow(t, 2.4)))
	var m := clampf(minf(d / e, to_end / rr), 0.0, 1.0)
	var f := 1.0
	if y < 0.0:
		var ky := keel_y(x)
		var rel := clampf(y / minf(ky, -0.05), 0.0, 1.0)
		var n := lerpf(float(s.get("end_n", 1.9)), float(s.get("mid_n", 4.0)), m)
		f = pow(maxf(0.0, 1.0 - pow(rel, n)), 1.0 / n)
	else:
		var rel := clampf(y / maxf(deck_y(x), 0.1), 0.0, 1.0)
		f = 1.0 + float(s.get("flare", 0.3)) * (1.0 - m) * pow(rel, 1.4) - float(s.get("tumble", 0.0)) * rel * rel
	return 0.5 * B * w * f


## Half-width of the weather deck at x.
func half_deck(x: float) -> float:
	return half_breadth(clampf(x, 0.05, L), deck_y(x) - 0.01)


func z(x: float) -> float:
	return x - L * 0.5


func _point(u: float, v: float) -> Vector3:
	var x := u * L
	var y := 0.0
	for it in 5:
		y = lerpf(keel_y(x), deck_y(x), v)
		x = lerpf(stem_x(y), stern_x(y), u)
	return Vector3(half_breadth(x, y), y, z(x))


func build(k: MeshKit, hull_mat := "hull", deck_mat := "deck") -> void:
	grid = []
	var us := []
	for i in NU + 1:
		var t := float(i) / NU
		us.append(0.5 - 0.5 * cos(PI * t) * 0.9 + (t - 0.5) * 0.1)
	us[0] = 0.0
	us[NU] = 1.0
	for i in NU + 1:
		var col := []
		for j in NV + 1:
			var v := float(j) / NV
			col.append(_point(us[i], v))
		grid.append(col)
	var norms := []
	for i in NU + 1:
		var col := []
		for j in NV + 1:
			var du: Vector3 = grid[mini(i + 1, NU)][j] - grid[maxi(i - 1, 0)][j]
			var dv: Vector3 = grid[i][mini(j + 1, NV)] - grid[i][maxi(j - 1, 0)]
			var n := dv.cross(du)
			if n.length_squared() < 1e-10:
				n = Vector3.RIGHT
			n = n.normalized()
			if n.x < 0.0:
				n = -n
			col.append(n)
		norms.append(col)
	for i in NU:
		for j in NV:
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i + 1][j]
			var c: Vector3 = grid[i + 1][j + 1]
			var d: Vector3 = grid[i][j + 1]
			var na: Vector3 = norms[i][j]
			var nb: Vector3 = norms[i + 1][j]
			var nc: Vector3 = norms[i + 1][j + 1]
			var nd: Vector3 = norms[i][j + 1]
			k.quad_n(hull_mat, a, b, c, d, na, nb, nc, nd)
			var m := Vector3(-1, 1, 1)
			k.quad_n(hull_mat, a * m, b * m, c * m, d * m, na * m, nb * m, nc * m, nd * m)
	var camber: float = s.get("camber", 0.012 * B)
	for i in NU:
		var p0: Vector3 = grid[i][NV]
		var p1: Vector3 = grid[i + 1][NV]
		var c0 := Vector3(0, p0.y + camber * minf(1.0, p0.x / (0.5 * B)), p0.z)
		var c1 := Vector3(0, p1.y + camber * minf(1.0, p1.x / (0.5 * B)), p1.z)
		var up := Vector3.UP
		k.quad_n(deck_mat, c0, c1, p1, p0, up, up, up, up)
		k.quad_n(deck_mat, c0, Vector3(-p0.x, p0.y, p0.z), Vector3(-p1.x, p1.y, p1.z), c1, up, up, up, up)
	if stern == "transom":
		var back := Vector3(0, 0, 1)
		for j in NV:
			var a: Vector3 = grid[NU][j]
			var b: Vector3 = grid[NU][j + 1]
			k.quad_dir(hull_mat, a, b, Vector3(-b.x, b.y, b.z), Vector3(-a.x, a.y, a.z), back)
		var top: Vector3 = grid[NU][NV]
		k.tri(deck_mat, top, Vector3(-top.x, top.y, top.z), Vector3(0, top.y + camber, top.z), Vector3.UP)


## Deck edge points (starboard) from x0 to x1, for railings.
func edge_points(x0: float, x1: float, step := 4.0, side := 1.0, inset := 0.15) -> Array:
	var pts := []
	var n := maxi(2, int(ceil((x1 - x0) / step)) + 1)
	for i in n:
		var x := lerpf(x0, x1, float(i) / (n - 1))
		pts.append(Vector3(side * maxf(half_deck(x) - inset, 0.0), deck_y(x), z(x)))
	return pts
