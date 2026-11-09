class_name SimBallistics
extends RefCounted
## Exterior ballistics with air drag that thins with altitude. Each shell's
## drag constant is fitted so its maximum range at 45 degrees matches published
## figures; firing tables then give elevation, time of flight and angle of fall
## for any range.

const Weapons := preload("res://scripts/data/weapons.gd")
const STEP := 0.1

static var _cd := {}
static var _tab := {}


static func accel(v: Vector3, y: float, c: float) -> Vector3:
	var rho := exp(-maxf(y, 0.0) / 8500.0)
	return Vector3(0.0, -9.81, 0.0) - v * (v.length() * c * rho)


## Fly from the origin; returns [range, time, fall angle deg, impact speed].
static func fly(v0: float, elev: float, c: float, y0 := 0.0) -> Array:
	var e := deg_to_rad(elev)
	var v := Vector3(0.0, sin(e), cos(e)) * v0
	var p := Vector3(0.0, y0, 0.0)
	var t := 0.0
	while t < 400.0:
		var a := accel(v, p.y, c)
		var vm := v + a * STEP * 0.5
		var pn := p + vm * STEP
		var vn := v + accel(vm, (p.y + pn.y) * 0.5, c) * STEP
		if pn.y < 0.0 and vn.y < 0.0:
			var f := p.y / maxf(p.y - pn.y, 1e-6)
			p = p.lerp(pn, f)
			v = v.lerp(vn, f)
			t += STEP * f
			break
		p = pn
		v = vn
		t += STEP
	return [p.z, t, rad_to_deg(atan2(-v.y, v.z)), v.length()]


static func drag(mid: String) -> float:
	if _cd.has(mid):
		return _cd[mid]
	var md := Weapons.mun(mid)
	var v0: float = md.get("v0", 800.0)
	var target: float = md.get("range", 20000.0)
	var lo := 1e-8
	var hi := 1e-2
	for i in 34:
		var m := sqrt(lo * hi)
		var r: float = fly(v0, 45.0, m)[0]
		if r > target:
			lo = m
		else:
			hi = m
	_cd[mid] = sqrt(lo * hi)
	return _cd[mid]


## Firing table: rows of [elevation, range, time, fall angle, impact speed].
static func table(mid: String) -> Array:
	if _tab.has(mid):
		return _tab[mid]
	var c := drag(mid)
	var v0: float = Weapons.mun(mid).get("v0", 800.0)
	var rows := []
	var e := 0.0
	while e <= 45.01:
		var r := fly(v0, e, c)
		rows.append([e, r[0], r[1], r[2], r[3]])
		e += 0.5 if e < 10.0 else 1.0
	_tab[mid] = rows
	return rows


static func max_range(mid: String) -> float:
	var t := table(mid)
	var best := 0.0
	for row in t:
		best = maxf(best, row[1])
	return best


## Interpolated table row for a range (low-angle solution). Returns [] if out of range.
static func solve(mid: String, rng: float) -> Array:
	var t := table(mid)
	if rng <= 0.0:
		return [0.0, 0.0, 0.0, 0.0, Weapons.mun(mid).get("v0", 800.0)]
	for i in t.size() - 1:
		var a: Array = t[i]
		var b: Array = t[i + 1]
		if rng >= a[1] and rng <= b[1]:
			var f := (rng - float(a[1])) / maxf(float(b[1]) - float(a[1]), 1e-3)
			var out := []
			for k in 5:
				out.append(lerpf(a[k], b[k], f))
			return out
	return []


static func elevation_for(mid: String, rng: float) -> float:
	var s := solve(mid, rng)
	return s[0] if not s.is_empty() else 45.0


static func time_for(mid: String, rng: float) -> float:
	var s := solve(mid, rng)
	return s[2] if not s.is_empty() else 0.0


## Muzzle velocity vector for a world heading/elevation.
static func launch_vel(v0: float, hdg: float, elev: float) -> Vector3:
	var e := deg_to_rad(elev)
	var h := deg_to_rad(hdg)
	return Vector3(sin(h) * cos(e), sin(e), -cos(h) * cos(e)) * v0
