extends RefCounted
## Units, bearings and geometry shared by the simulation and the view.
## World axes (Godot): +X east, +Y up, +Z south. Headings are compass degrees
## (0 = north, clockwise). Ship models point their bow at -Z.

const KN := 0.514444
const NM := 1852.0
const EARTH_R := 6371000.0
const G := 9.81


static func wrap360(a: float) -> float:
	return fposmod(a, 360.0)


## Signed difference b - a in -180..180.
static func adiff(a: float, b: float) -> float:
	return fposmod(b - a + 180.0, 360.0) - 180.0


## Unit vector for a compass heading, in the horizontal plane.
static func fwd(h: float) -> Vector3:
	var r := deg_to_rad(h)
	return Vector3(sin(r), 0.0, -cos(r))


## Compass bearing from a to b (only x/z are used).
static func brg(a: Vector3, b: Vector3) -> float:
	return wrap360(rad_to_deg(atan2(b.x - a.x, -(b.z - a.z))))


static func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Node rotation.y for a compass heading.
static func yaw(h: float) -> float:
	return -deg_to_rad(h)


static func p3(a: float) -> String:
	return "%03d" % int(round(wrap360(a))) if int(round(wrap360(a))) != 360 else "000"


static func clock(s: float) -> String:
	var t := int(s)
	return "%02d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]


static func clock_hm(hours: float) -> String:
	var m := int(round(fposmod(hours, 24.0) * 60.0))
	return "%02d%02d" % [(m / 60) % 24, m % 60]


static func km(m: float) -> String:
	return "%.1f km" % (m / 1000.0) if m < 20000.0 else "%d km" % int(m / 1000.0)


static func gauss(rng: RandomNumberGenerator = null) -> float:
	var u1 := maxf(rng.randf() if rng else randf(), 1e-6)
	var u2 := rng.randf() if rng else randf()
	return sqrt(-2.0 * log(u1)) * cos(TAU * u2)


## Distance to the radar or visual horizon between two heights, standard refraction.
static func horizon(h1: float, h2: float) -> float:
	return 4120.0 * (sqrt(maxf(h1, 0.0)) + sqrt(maxf(h2, 0.0)))


## How far the sea surface drops below a flat plane at distance d.
static func curvature_drop(d: float) -> float:
	return d * d / (2.0 * EARTH_R * 1.17)


## Time for a projectile of speed `spd` from the origin to meet a target at `rel`
## moving with `vel`. Returns -1 when it can never catch it.
static func intercept_time(rel: Vector3, vel: Vector3, spd: float) -> float:
	var a := vel.dot(vel) - spd * spd
	var b := 2.0 * rel.dot(vel)
	var c := rel.dot(rel)
	if absf(a) < 1e-6:
		return -c / b if b < 0.0 else -1.0
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return -1.0
	var s := sqrt(disc)
	var t1 := (-b - s) / (2.0 * a)
	var t2 := (-b + s) / (2.0 * a)
	var t := minf(t1, t2)
	if t < 0.0:
		t = maxf(t1, t2)
	return t if t > 0.0 else -1.0


## Local tangent-plane position (metres) of a lat/lon relative to an origin.
static func ll_to_local(lat: float, lon: float, olat: float, olon: float) -> Vector3:
	var x := deg_to_rad(lon - olon) * EARTH_R * cos(deg_to_rad(olat))
	var n := deg_to_rad(lat - olat) * EARTH_R
	return Vector3(x, 0.0, -n)


static func local_to_ll(p: Vector3, olat: float, olon: float) -> Vector2:
	var lat := olat + rad_to_deg(-p.z / EARTH_R)
	var lon := olon + rad_to_deg(p.x / (EARTH_R * cos(deg_to_rad(olat))))
	return Vector2(lat, lon)


static func ll_text(lat: float, lon: float) -> String:
	var ns := "N" if lat >= 0.0 else "S"
	var ew := "E" if lon >= 0.0 else "W"
	var la := absf(lat)
	var lo := absf(lon)
	return "%02d°%02d'%s %03d°%02d'%s" % [int(la), int(fmod(la, 1.0) * 60.0), ns, int(lo), int(fmod(lo, 1.0) * 60.0), ew]


## Sun elevation and azimuth (degrees) for a latitude, day of year and local solar hour.
static func sun_position(lat: float, day: int, hour: float) -> Vector2:
	var decl := deg_to_rad(-23.44) * cos(TAU / 365.0 * (day + 10))
	var ha := deg_to_rad((hour - 12.0) * 15.0)
	var la := deg_to_rad(lat)
	var sin_el := sin(la) * sin(decl) + cos(la) * cos(decl) * cos(ha)
	var el := asin(clampf(sin_el, -1.0, 1.0))
	var cos_az := (sin(decl) - sin(el) * sin(la)) / maxf(cos(el) * cos(la), 1e-6)
	var az := rad_to_deg(acos(clampf(cos_az, -1.0, 1.0)))
	if hour > 12.0:
		az = 360.0 - az
	return Vector2(rad_to_deg(el), az)


static func day_of_year(month: int, dom: int) -> int:
	var cum := [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
	return cum[clampi(month - 1, 0, 11)] + dom


## World direction pointing at a body with this elevation/azimuth.
static func sky_dir(el: float, az: float) -> Vector3:
	var e := deg_to_rad(el)
	var a := deg_to_rad(az)
	return Vector3(sin(a) * cos(e), sin(e), -cos(a) * cos(e))
