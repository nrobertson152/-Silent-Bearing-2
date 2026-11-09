class_name SimTerrain
extends RefCounted
## Heightfield built from coastline polygons: land rises from the shore over a
## few hundred metres into noisy hills. The simulation samples it for shell
## impacts, grounding and shore targets; the view meshes the same grid.

var n := 320
var extent := 60000.0
var cell := 375.0
var heights := PackedFloat32Array()
var hmax := 120.0
var origin := Vector2.ZERO
var has_land := false


func build(polys: Array, max_h: float, ext: float, seed_val := 7) -> void:
	extent = ext
	hmax = max_h
	cell = extent * 2.0 / n
	origin = Vector2(-extent, -extent)
	heights.resize((n + 1) * (n + 1))
	var inside := PackedByteArray()
	inside.resize((n + 1) * (n + 1))
	var dist := PackedFloat32Array()
	dist.resize((n + 1) * (n + 1))
	var big := 1e9
	for j in n + 1:
		for i in n + 1:
			var p := origin + Vector2(i, j) * cell
			var land := false
			for poly in polys:
				if Geometry2D.is_point_in_polygon(p, poly):
					land = true
					break
			var k := j * (n + 1) + i
			inside[k] = 1 if land else 0
			dist[k] = big if land else 0.0
			if land:
				has_land = true
	# Two-pass chamfer distance (in cells) from the shore, inland only.
	var d1 := 1.0
	var d2 := 1.4142
	for j in n + 1:
		for i in n + 1:
			var k := j * (n + 1) + i
			if inside[k] == 0:
				continue
			var v := dist[k]
			if i > 0:
				v = minf(v, dist[k - 1] + d1)
			if j > 0:
				v = minf(v, dist[k - n - 1] + d1)
				if i > 0:
					v = minf(v, dist[k - n - 2] + d2)
				if i < n:
					v = minf(v, dist[k - n] + d2)
			dist[k] = v
	for j in range(n, -1, -1):
		for i in range(n, -1, -1):
			var k := j * (n + 1) + i
			if inside[k] == 0:
				continue
			var v := dist[k]
			if i < n:
				v = minf(v, dist[k + 1] + d1)
			if j < n:
				v = minf(v, dist[k + n + 1] + d1)
				if i < n:
					v = minf(v, dist[k + n + 2] + d2)
				if i > 0:
					v = minf(v, dist[k + n] + d2)
			dist[k] = v
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.frequency = 0.00012
	noise.fractal_octaves = 5
	noise.fractal_lacunarity = 2.1
	for j in n + 1:
		for i in n + 1:
			var k := j * (n + 1) + i
			var p := origin + Vector2(i, j) * cell
			if inside[k] == 0:
				heights[k] = -18.0
				continue
			var dm := dist[k] * cell
			var shore := clampf(dm / 1400.0, 0.0, 1.0)
			shore = shore * shore * (3.0 - 2.0 * shore)
			var nz := noise.get_noise_2d(p.x, p.y) * 0.5 + 0.5
			heights[k] = 4.0 + hmax * shore * (0.25 + 0.95 * nz * nz) + 10.0 * shore
	# Shoreline cells that touch the sea get a gentle drop below the waterline.
	for j in n + 1:
		for i in n + 1:
			var k := j * (n + 1) + i
			if inside[k] == 0:
				var near := false
				for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var ii: int = i + o.x
					var jj: int = j + o.y
					if ii >= 0 and jj >= 0 and ii <= n and jj <= n and inside[jj * (n + 1) + ii] == 1:
						near = true
				if near:
					heights[k] = -4.0


func height(x: float, z: float) -> float:
	if not has_land:
		return -50.0
	var fx := (x - origin.x) / cell
	var fz := (z - origin.y) / cell
	if fx < 0.0 or fz < 0.0 or fx >= n or fz >= n:
		return -50.0
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var a := heights[j * (n + 1) + i]
	var b := heights[j * (n + 1) + i + 1]
	var c := heights[(j + 1) * (n + 1) + i]
	var d := heights[(j + 1) * (n + 1) + i + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


func at(i: int, j: int) -> float:
	return heights[clampi(j, 0, n) * (n + 1) + clampi(i, 0, n)]
