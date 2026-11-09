extends Control
## Strategic map of the North Atlantic and Arctic: real coastlines (Natural
## Earth), who holds the contested regions, the land front in Europe and the
## campaign's missions. Lambert azimuthal equal-area projection.

signal mission_selected(idx: int)

const Campaigns := preload("res://scripts/data/campaigns.gd")
const S := preload("res://scripts/ui/style.gd")
const Save := preload("res://scripts/core/save.gd")

## The map always shows at least these places ([lon, lat]).
const VIEW_POINTS := [[-77.5, 31.0], [-63.5, 31.0], [-70.0, 78.5], [22.0, 79.5], [46.0, 70.5], [44.0, 62.0],
	[13.0, 50.0], [-6.0, 48.5]]

static var _tri_pts := PackedVector2Array()
static var _tri_idx := PackedInt32Array()
static var _coasts := []
static var _grat := []
static var _view := Rect2()

var side := "us"
var front := {}
var sel := 0
var unlocked := 0
var interactive := true
var t := 0.0
var hover := -1
var highlight := -1


static func project(lat: float, lon: float) -> Vector2:
	var p0 := deg_to_rad(Campaigns.MAP_CENTER.x)
	var l0 := deg_to_rad(Campaigns.MAP_CENTER.y)
	var p := deg_to_rad(lat)
	var dl := deg_to_rad(lon) - l0
	var k := sqrt(2.0 / maxf(1.0 + sin(p0) * sin(p) + cos(p0) * cos(p) * cos(dl), 1e-6))
	return Vector2(k * cos(p) * sin(dl), -k * (cos(p0) * sin(p) - sin(p0) * cos(p) * cos(dl)))


## Loads the coastlines once and triangulates the land for fast drawing.
static func load_world() -> void:
	if not _coasts.is_empty():
		return
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for q: Array in VIEW_POINTS:
		var v := project(q[1], q[0])
		lo = lo.min(v)
		hi = hi.max(v)
	_view = Rect2(lo, hi - lo).grow(0.03)
	var f := FileAccess.open("res://data/geo/world.json", FileAccess.READ)
	if f == null:
		return
	var polys = JSON.parse_string(f.get_as_text())
	if not (polys is Array):
		return
	for poly in polys:
		var pts := PackedVector2Array()
		for q in poly:
			pts.append(project(float(q[1]), float(q[0])))
		var closed := pts.duplicate()
		closed.append(pts[0])
		_coasts.append(closed)
		var parts := [pts]
		if Geometry2D.triangulate_polygon(pts).is_empty():
			# Simplified coastlines can cross themselves; let Clipper untangle them.
			parts = Geometry2D.merge_polygons(pts, PackedVector2Array())
		for part: PackedVector2Array in parts:
			var tri := Geometry2D.triangulate_polygon(part)
			var base := _tri_pts.size()
			_tri_pts.append_array(part)
			for i in tri:
				_tri_idx.append(base + i)
	for lat in range(30, 90, 10):
		var pts := PackedVector2Array()
		for lon in range(-100, 82, 2):
			pts.append(project(lat, lon))
		_grat.append(pts)
	for lon in range(-100, 90, 10):
		var pts := PackedVector2Array()
		for lat in range(20, 88, 2):
			pts.append(project(lat, lon))
		_grat.append(pts)


func _ready() -> void:
	load_world()
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE


func setup(campaign_side: String, front_state: Dictionary, selected: int) -> void:
	side = campaign_side
	front = front_state
	sel = selected
	unlocked = Save.unlocked(side)
	queue_redraw()


## Projected map coordinates to control coordinates.
func xform() -> Transform2D:
	var k := minf(size.x / _view.size.x, size.y / _view.size.y)
	var off := (size - _view.size * k) * 0.5 - _view.position * k
	return Transform2D(0.0, Vector2(k, k), 0.0, off)


func ll(lat: float, lon: float) -> Vector2:
	return xform() * project(lat, lon)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _missions() -> Array:
	return Campaigns.campaign(side)["missions"]


func _gui_input(ev: InputEvent) -> void:
	if not interactive:
		return
	if ev is InputEventMouseMotion:
		hover = _marker_at(ev.position)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var i := _marker_at(ev.position)
		if i >= 0 and i <= unlocked:
			sel = i
			mission_selected.emit(i)


func _marker_at(p: Vector2) -> int:
	var ms := _missions()
	for i in ms.size():
		if ll(ms[i]["lat"], ms[i]["lon"]).distance_to(p) < 20.0:
			return i
	return -1


func _draw() -> void:
	if _view.size.x <= 0.0 or size.x < 10.0:
		return
	var xf := xform()
	var k := xf.get_scale().x
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.07, 0.1))
	# Static geography in projected coordinates.
	draw_set_transform_matrix(xf)
	for g: PackedVector2Array in _grat:
		draw_polyline(g, Color(0.3, 0.45, 0.55, 0.22), 1.0 / k)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _tri_idx, _tri_pts, PackedColorArray([Color(0.17, 0.19, 0.16)]))
	for c: PackedVector2Array in _coasts:
		draw_polyline(c, Color(0.5, 0.57, 0.46), 1.3 / k, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# Who holds the contested regions.
	for key: String in Campaigns.REGIONS:
		var who: String = front.get(key, "")
		if who == "":
			continue
		var col := S.US_BLUE if who == "us" else (S.SU_RED if who == "su" else S.AMBER)
		var pts := PackedVector2Array()
		for q: Array in Campaigns.REGIONS[key]:
			pts.append(ll(q[1], q[0]))
		var a := 0.3 + (0.15 * sin(t * 3.0) if who == "contested" else 0.0)
		draw_colored_polygon(pts, Color(col, a))
		pts.append(pts[0])
		draw_polyline(pts, Color(col, 0.85), 2.0, true)
	# The land front in Europe.
	var fr: String = front.get("europe", "")
	if fr != "" and Campaigns.FRONTS.has(fr):
		var pts := PackedVector2Array()
		for q: Array in Campaigns.FRONTS[fr]:
			pts.append(ll(q[1], q[0]))
		draw_polyline(pts, Color(0.05, 0.05, 0.05, 0.6), 7.0, true)
		draw_polyline(pts, Color(1.0, 0.82, 0.3, 0.95), 4.0, true)
		S.text(self, "FRONT", pts[pts.size() - 1] + Vector2(8, 14), 13, Color(1.0, 0.85, 0.35), HORIZONTAL_ALIGNMENT_LEFT, -1, S.heavy())
	# Places.
	for l: Array in Campaigns.LABELS:
		var p := ll(l[2], l[1])
		var off: Vector2 = Vector2(l[3][0], l[3][1]) if l.size() > 3 else Vector2(6, -5)
		draw_circle(p, 2.5, Color(0.85, 0.85, 0.75, 0.85))
		S.text(self, l[0], p + off, 13, Color(0.82, 0.84, 0.76, 0.8), HORIZONTAL_ALIGNMENT_LEFT, -1, S.sans())
	_draw_missions()
	_legend()
	draw_rect(Rect2(Vector2.ZERO, size), S.EDGE, false, 1.0)


func _legend() -> void:
	var y := size.y - 16.0
	S.text(self, "NORTH ATLANTIC AND ARCTIC  ·  1988", Vector2(12, y), 13, S.MUTED)
	var x := size.x - 470.0
	for e: Array in [[S.US_BLUE, "NATO"], [S.SU_RED, "WARSAW PACT"], [S.AMBER, "CONTESTED"]]:
		draw_rect(Rect2(Vector2(x, y - 11), Vector2(14, 12)), Color(e[0], 0.55))
		draw_rect(Rect2(Vector2(x, y - 11), Vector2(14, 12)), e[0], false, 1.0)
		S.text(self, e[1], Vector2(x + 20, y), 13, S.MUTED)
		x += 40.0 + 9.0 * String(e[1]).length()
	draw_line(Vector2(x, y - 5), Vector2(x + 22, y - 5), Color(1.0, 0.82, 0.3), 3.0)
	S.text(self, "LAND FRONT", Vector2(x + 28, y), 13, S.MUTED)


func _draw_missions() -> void:
	var ms := _missions()
	var col := S.side_color(side)
	var prev := Vector2.ZERO
	for i in ms.size():
		var p := ll(ms[i]["lat"], ms[i]["lon"])
		if i > 0 and i <= unlocked:
			_dashed(prev, p, Color(col, 0.65), 2.0)
		prev = p
	for i in ms.size():
		var m: Dictionary = ms[i]
		var p := ll(m["lat"], m["lon"])
		var done := Save.is_done(side, m["id"])
		var open := i <= unlocked
		var rad := 14.0
		if open and not done:
			var pulse := 0.5 + 0.5 * sin(t * 4.0)
			draw_arc(p, rad + 5.0 + pulse * 6.0, 0, TAU, 32, Color(col, 0.65 - pulse * 0.45), 2.0)
		draw_circle(p, rad, Color(col, 0.92) if done else Color(0.06, 0.08, 0.1, 0.95))
		draw_arc(p, rad, 0, TAU, 32, col if open else Color(0.4, 0.43, 0.43), 2.0)
		S.text(self, str(i + 1), p + Vector2(-12, 6), 16, Color(0.04, 0.05, 0.05) if done else (S.TEXT if open else S.MUTED),
			HORIZONTAL_ALIGNMENT_CENTER, 24, S.heavy())
		if i == sel or i == hover or i == highlight:
			for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var o: Vector2 = p + c * (rad + 7.0)
				draw_line(o, o - Vector2(c.x * 7, 0), S.AMBER, 2.0)
				draw_line(o, o - Vector2(0, c.y * 7), S.AMBER, 2.0)
			var title: String = String(m["title"]).to_upper()
			var tp := p + Vector2(rad + 12, 6)
			var tw := S.heavy().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			if tp.x + tw > size.x - 8.0:
				tp.x = p.x - rad - 12.0 - tw
			draw_rect(Rect2(tp + Vector2(-4, -17), Vector2(tw + 8, 22)), Color(0.02, 0.03, 0.04, 0.8))
			S.text(self, title, tp, 16, S.AMBER if open else S.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, S.heavy())


func _dashed(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d := a.distance_to(b)
	var n := maxi(int(d / 10.0), 1)
	for i in n:
		if i % 2 == 0:
			draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), col, w)
