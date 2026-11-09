extends Control
## Tactical plot in the style of a CIC display: NTDS symbols, range rings,
## missiles in flight and land. Left-click designates; right-click orders a course.

const U := preload("res://scripts/util.gd")
const S := preload("res://scripts/ui/style.gd")

var g
var scale_km := 60.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	if visible:
		queue_redraw()


func _center() -> Vector2:
	return get_viewport_rect().size * 0.5


func _radius() -> float:
	return get_viewport_rect().size.y * 0.44


func to_screen(p: Vector3) -> Vector2:
	var me: Vector3 = g.player.pos
	var k := _radius() / (scale_km * 1000.0)
	return _center() + Vector2(p.x - me.x, p.z - me.z) * k


func to_world(s: Vector2) -> Vector3:
	var me: Vector3 = g.player.pos
	var k := (scale_km * 1000.0) / _radius()
	var d := (s - _center()) * k
	return Vector3(me.x + d.x, 0, me.z + d.y)


func click(ev: InputEventMouseButton) -> void:
	if not ev.pressed:
		return
	if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
		scale_km = maxf(5.0, scale_km * 0.8)
	elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		scale_km = minf(600.0, scale_km * 1.25)
	elif ev.button_index == MOUSE_BUTTON_LEFT:
		var best = null
		var bd := 30.0
		for e in g.w.units:
			if e == g.player or not e.alive() or not g.w.known_to(g.player.side, e):
				continue
			var d := to_screen(e.pos).distance_to(ev.position)
			if d < bd:
				bd = d
				best = e
		if best != null and best.side != g.player.side:
			g.set_target(best)
			g.hud.show_hint("Target: %s" % best.name)
	elif ev.button_index == MOUSE_BUTTON_RIGHT:
		var p := to_world(ev.position)
		var c := U.brg(g.player.pos, p)
		g.player.steer(c)
		g.hud.show_hint("Come to course %s" % U.p3(c))


func _draw() -> void:
	if g == null:
		return
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.01, 0.025, 0.03, 0.94))
	var c := _center()
	var r := _radius()
	var grid := Color(0.2, 0.55, 0.4, 0.35)
	for land in g.w.land:
		var pts := PackedVector2Array()
		for p in land["pts"]:
			pts.append(to_screen(Vector3(p.x, 0, p.y)))
		if pts.size() > 2:
			draw_colored_polygon(pts, Color(0.16, 0.2, 0.14, 0.9))
			pts.append(pts[0])
			draw_polyline(pts, Color(0.4, 0.55, 0.35), 1.5)
	for i in range(1, 5):
		draw_arc(c, r * i / 4.0, 0, TAU, 96, grid, 1.0)
		S.text(self, "%d km" % int(scale_km * i / 4.0), c + Vector2(4, -r * i / 4.0 - 4), 13, grid.lightened(0.4))
	for a in range(0, 360, 30):
		var d := Vector2(sin(deg_to_rad(a)), -cos(deg_to_rad(a)))
		draw_line(c + d * r * 0.05, c + d * r, Color(grid, 0.2), 1.0)
		S.text(self, U.p3(a), c + d * (r + 18) - Vector2(16, -6), 13, grid.lightened(0.4), HORIZONTAL_ALIGNMENT_CENTER, 32)
	var me = g.player
	for m in g.w.muns:
		if not m.alive or m.kind == "shell":
			continue
		if m.side != me.side and m.kind == "missile" and m.role == "air":
			continue
		var sp := to_screen(m.pos)
		var col := S.ALARM if m.side != me.side else S.US_BLUE.lightened(0.3)
		if m.kind == "torpedo" and m.side != me.side and not g.w.known_to(me.side, m.shooter if m.shooter is SimUnit else me):
			continue
		draw_circle(sp, 2.5, col)
		var v: Vector3 = m.vel
		draw_line(sp, sp + Vector2(v.x, v.z).normalized() * 12.0, col, 1.0)
	for a in g.w.air:
		if not a.alive:
			continue
		if a.side != me.side and not g.w.air_known(me.side, a):
			continue
		var sp := to_screen(a.pos)
		var col := S.side_color(a.side) if a.side == me.side else S.ALARM
		_sym(sp, a.side == me.side, "air", col)
		S.text(self, a.name().split(" ")[0], sp + Vector2(10, -6), 12, col)
	for e in g.w.units:
		if not e.alive() and not e.sinking:
			continue
		var friend: bool = e.side == me.side
		if not friend and not g.w.known_to(me.side, e):
			continue
		var sp := to_screen(e.pos)
		var col := S.US_BLUE if friend else S.ALARM
		if e.navy == "merchant":
			col = Color(0.75, 0.8, 0.6) if friend else Color(1, 0.6, 0.4)
		if e == me:
			col = S.PHOS
		_sym(sp, friend, "sub" if e.is_sub else "surf", col)
		var hv := Vector2(sin(deg_to_rad(e.heading)), -cos(deg_to_rad(e.heading)))
		draw_line(sp, sp + hv * (10.0 + e.speed * 1.2), col, 1.5)
		if e != me:
			S.text(self, e.name if e.navy != "merchant" else e.cls.get("class", ""), sp + Vector2(11, -6), 12, col)
		if e == g.target:
			draw_arc(sp, 15.0, 0, TAU, 24, S.AMBER, 2.0)
	for gr in g.w.ground:
		var sp := to_screen(gr["pos"])
		var col := S.ALARM if gr["alive"] else S.MUTED
		draw_rect(Rect2(sp - Vector2(5, 5), Vector2(10, 10)), col, false, 1.5)
		if gr["alive"]:
			S.text(self, gr["name"], sp + Vector2(8, -6), 12, col)
	S.text(self, "TACTICAL PLOT   scale %d km   wheel: zoom   left-click: designate   right-click: steer to   Esc/M: close" % int(scale_km),
		Vector2(20, vs.y - 20), 15, S.MUTED)


## NTDS-style symbol: friend circle family, hostile diamond family.
func _sym(p: Vector2, friend: bool, kind: String, col: Color) -> void:
	var s := 8.0
	if friend:
		match kind:
			"air":
				draw_arc(p, s, PI, TAU, 12, col, 1.5)
			"sub":
				draw_arc(p, s, 0, PI, 12, col, 1.5)
			_:
				draw_arc(p, s, 0, TAU, 20, col, 1.5)
	else:
		var top := p + Vector2(0, -s)
		var rt := p + Vector2(s, 0)
		var bot := p + Vector2(0, s)
		var lf := p + Vector2(-s, 0)
		match kind:
			"air":
				draw_polyline(PackedVector2Array([lf, top, rt]), col, 1.5)
			"sub":
				draw_polyline(PackedVector2Array([lf, bot, rt]), col, 1.5)
			_:
				draw_polyline(PackedVector2Array([top, rt, bot, lf, top]), col, 1.5)
