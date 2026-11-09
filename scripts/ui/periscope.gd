extends Control
## Periscope eyepiece: the round field of view, stadimeter reticle, bearing
## ring and power setting. Goes dark when the head is under the water.

const U := preload("res://scripts/util.gd")
const S := preload("res://scripts/ui/style.gd")

var g


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if g == null or g.player == null:
		return
	var vs := size
	var c := vs * 0.5
	var r := minf(vs.x, vs.y) * 0.46
	var under: bool = g.scope_under()
	if under:
		draw_circle(c, r, Color(0.02, 0.07, 0.08, 0.97))
		S.text(self, "SCOPE UNDER", c + Vector2(-r, -10), 30, Color(0.5, 0.8, 0.8, 0.8), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, S.heavy())
		S.text(self, "Come up to periscope depth (18 m) to look", c + Vector2(-r, 24), 16, Color(0.5, 0.8, 0.8, 0.7), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)
	elif g.scope_wash > 0.0:
		draw_circle(c, r, Color(0.05, 0.2, 0.22, clampf(g.scope_wash, 0.0, 0.85)))
	# Black outside the eyepiece: one thick ring out past the screen corners.
	var ring := PackedVector2Array()
	for i in 97:
		var a := TAU * i / 96.0
		ring.append(c + Vector2(cos(a), sin(a)) * r)
	var far := c.length() + 8.0
	draw_arc(c, (r + far) * 0.5, 0.0, TAU, 160, Color(0, 0, 0), far - r + 2.0)
	draw_polyline(ring, Color(0.1, 0.1, 0.1), 6.0, true)
	if under:
		return
	# Reticle: horizon line with stadimeter ticks and a vertical line.
	var ret := Color(0.05, 0.05, 0.05, 0.85)
	draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), ret, 1.5)
	draw_line(c + Vector2(0, -r * 0.55), c + Vector2(0, r * 0.25), ret, 1.5)
	for i in range(-10, 11):
		if i == 0:
			continue
		var x := c.x + i * r * 0.08
		var h := 10.0 if i % 5 == 0 else 5.0
		draw_line(Vector2(x, c.y - h), Vector2(x, c.y + h), ret, 1.2)
	# Bearing ring.
	var brg: float = g.scope_yaw
	S.text(self, "%s°" % U.p3(brg), c + Vector2(-60, -r + 46), 26, Color(0.9, 0.9, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 120, S.heavy())
	var fov: float = g.cam.fov * vs.x / maxf(vs.y, 1.0)
	for d in range(-30, 31):
		var b := fposmod(brg + d, 360.0)
		var whole := int(round(b))
		var off := U.adiff(brg, float(whole))
		var x := c.x + off / (fov * 0.5) * (vs.x * 0.5)
		if absf(x - c.x) > r * 0.7:
			continue
		var big := whole % 10 == 0
		draw_line(Vector2(x, c.y - r + 60 if big else c.y - r + 66), Vector2(x, c.y - r + 72), Color(0.9, 0.9, 0.85, 0.7), 1.0)
	var power := "HIGH POWER 6×" if g.zoom else "LOW POWER 1.5×"
	S.text(self, power, c + Vector2(-r, -r + 100), 15, Color(0.85, 0.85, 0.8, 0.8), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)
	S.text(self, "Mouse: train   Wheel / right click: power   T: mark target   Space: fire   P: lower scope",
		Vector2(0, 22), 14, Color(0.7, 0.7, 0.65, 0.8), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var tg = g.target
	if tg != null and tg.alive() and g.w.known_to(g.player.side, tg):
		var d := U.flat_dist(g.player.pos, tg.pos)
		S.text(self, "MARK  %s  %s  %s" % [tg.name, U.p3(U.brg(g.player.pos, tg.pos)), U.km(d)], c + Vector2(-r, -r + 124), 16, S.AMBER, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)
