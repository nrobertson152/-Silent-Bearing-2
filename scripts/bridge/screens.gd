extends Control
## Live displays on the bridge, rendered into SubViewports: a surface-search
## radar PPI with a rotating sweep and afterglow, and the navigator's chart.

const U := preload("res://scripts/util.gd")

var kind := "radar"
var g
var su := false
var sweep := 0.0
var range_km := 24.0
var track := []
var track_t := 0.0


func _process(delta: float) -> void:
	sweep = fposmod(sweep + delta * 360.0 / 2.5, 360.0)
	if kind == "chart" and g != null and g.player != null:
		track_t -= delta
		if track_t <= 0.0:
			track_t = 4.0
			track.append(g.player.pos)
			if track.size() > 400:
				track.pop_front()
	queue_redraw()


func _draw() -> void:
	if g == null or g.player == null:
		return
	if kind == "radar":
		_radar()
	else:
		_chart()


func _radar() -> void:
	var s := size
	var c := s * 0.5
	var r := minf(s.x, s.y) * 0.48
	var phos := Color(1.0, 0.62, 0.15) if su else Color(0.35, 1.0, 0.45)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.01, 0.015, 0.012))
	draw_circle(c, r, Color(phos.r * 0.04, phos.g * 0.05, phos.b * 0.03))
	for i in range(1, 5):
		draw_arc(c, r * i / 4.0, 0, TAU, 64, Color(phos, 0.18), 1.5)
	for a in range(0, 360, 30):
		var d := Vector2(sin(deg_to_rad(a)), -cos(deg_to_rad(a)))
		draw_line(c, c + d * r, Color(phos, 0.08), 1.0)
	var p = g.player
	var k := r / (range_km * 1000.0)
	var hd: float = p.heading
	# Head-up display: the ship's heading at the top.
	for land in g.w.land:
		var pts := PackedVector2Array()
		for q in land["pts"]:
			var rel := Vector2(q.x - p.pos.x, q.y - p.pos.z).rotated(deg_to_rad(-hd))
			pts.append(c + rel * k)
		if pts.size() > 2:
			pts.append(pts[0])
			draw_polyline(pts, Color(phos, 0.55), 2.5)
	for e in g.w.units:
		if e == p or not e.alive() or (e.is_sub and e.depth > 3.0):
			continue
		var rel := Vector2(e.pos.x - p.pos.x, e.pos.z - p.pos.z)
		if rel.length() > range_km * 1000.0:
			continue
		if rel.length() > U.horizon(p.radar_h, e.mast_h()):
			continue
		var brg := rad_to_deg(atan2(rel.x, -rel.y)) - hd
		var age := fposmod(sweep - fposmod(brg, 360.0), 360.0) / 360.0
		var a := clampf(1.0 - age, 0.15, 1.0)
		var sp := c + rel.rotated(deg_to_rad(-hd)) * k
		var blob := clampf(e.L / 60.0, 2.0, 6.0)
		draw_circle(sp, blob, Color(phos, a))
	for m in g.w.muns:
		if m.alive and m.kind == "missile" and m.pos.y < 400.0:
			var rel := Vector2(m.pos.x - p.pos.x, m.pos.z - p.pos.z)
			if rel.length() < range_km * 1000.0:
				draw_circle(c + rel.rotated(deg_to_rad(-hd)) * k, 1.5, Color(phos, 0.8))
	var sd := Vector2(sin(deg_to_rad(sweep)), -cos(deg_to_rad(sweep)))
	for i in 24:
		var aa := deg_to_rad(sweep - i * 1.5)
		draw_line(c, c + Vector2(sin(aa), -cos(aa)) * r, Color(phos, 0.35 * (1.0 - i / 24.0)), 2.0)
	draw_line(c, c + sd * r, Color(phos, 0.9), 2.0)
	draw_line(c, c + Vector2(0, -r), Color(phos, 0.4), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(14, 28), "%d KM  HDG %s" % [int(range_km), U.p3(hd)], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(phos, 0.8))


func _chart() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.86, 0.85, 0.76))
	var p = g.player
	var span := 40000.0
	var k := s.x / span
	var c := s * 0.5
	for i in range(-6, 7):
		var x := c.x + i * 5000.0 * k
		draw_line(Vector2(x, 0), Vector2(x, s.y), Color(0.55, 0.6, 0.65, 0.35), 1.0)
		var y := c.y + i * 5000.0 * k
		draw_line(Vector2(0, y), Vector2(s.x, y), Color(0.55, 0.6, 0.65, 0.35), 1.0)
	for land in g.w.land:
		var pts := PackedVector2Array()
		for q in land["pts"]:
			pts.append(c + Vector2(q.x - p.pos.x, q.y - p.pos.z) * k)
		if pts.size() > 2:
			draw_colored_polygon(pts, Color(0.82, 0.74, 0.55))
			pts.append(pts[0])
			draw_polyline(pts, Color(0.35, 0.3, 0.2), 1.5)
	if track.size() > 1:
		var tp := PackedVector2Array()
		for q in track:
			tp.append(c + Vector2(q.x - p.pos.x, q.z - p.pos.z) * k)
		draw_polyline(tp, Color(0.15, 0.2, 0.35), 1.5)
	for e in g.w.units:
		if e == p or not e.alive() or not g.w.known_to(p.side, e):
			continue
		var sp := c + Vector2(e.pos.x - p.pos.x, e.pos.z - p.pos.z) * k
		var col := Color(0.15, 0.2, 0.6) if e.side == p.side else Color(0.7, 0.1, 0.08)
		draw_circle(sp, 4.0, col)
	var hv := Vector2(sin(deg_to_rad(p.heading)), -cos(deg_to_rad(p.heading)))
	draw_circle(c, 5.0, Color(0.1, 0.1, 0.1))
	draw_line(c, c + hv * 30.0, Color(0.1, 0.1, 0.1), 2.0)
	var ll := U.local_to_ll(p.pos, float(g.mission.get("lat", 60.0)), float(g.mission.get("lon", 0.0)))
	draw_string(ThemeDB.fallback_font, Vector2(12, s.y - 14), U.ll_text(ll.x, ll.y), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.2, 0.2, 0.25))
	draw_string(ThemeDB.fallback_font, Vector2(12, 26), "5 km grid", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.3, 0.3, 0.35))
