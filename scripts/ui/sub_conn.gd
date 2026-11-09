extends Control
## Submarine control room: broadband sonar waterfall, contact tracker, tubes
## and torpedoes in the water, depth, speed and helm, with clickable controls.

const U := preload("res://scripts/util.gd")
const S := preload("res://scripts/ui/style.gd")
const Weapons := preload("res://scripts/data/weapons.gd")
const ShipData := preload("res://scripts/data/ships.gd")

const W := 360
const H := 240
## Sim seconds per waterfall row.
const ROW_DT := 1.0
const PD := 18.0
const LAYER := 80.0
const PHOS := Color(0.45, 0.95, 0.62)

var g
var img: Image
var tex: ImageTexture
var data := PackedByteArray()
var row_t := 0.0
var last_t := 0.0
var trackers := {}
var first_heard := {}
var next_tracker := 1
var buttons := []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	data.resize(W * H * 3)
	data.fill(0)
	img = Image.create_from_data(W, H, false, Image.FORMAT_RGB8, data)
	tex = ImageTexture.create_from_image(img)
	rng.seed = 5


func _process(_delta: float) -> void:
	if g == null or g.w == null or not visible:
		return
	var t: float = g.w.t
	var steps := 0
	while t - last_t >= ROW_DT and steps < 6:
		last_t += ROW_DT
		_add_row()
		steps += 1
	if t - last_t > ROW_DT * 6.0:
		last_t = t
	if steps > 0:
		img.set_data(W, H, false, Image.FORMAT_RGB8, data)
		tex.update(img)
	_track()
	queue_redraw()


## How loud each source is on our sonar, 0..1.
func _contacts() -> Array:
	var p = g.player
	var out := []
	for e in g.w.units:
		if e == p or not e.alive():
			continue
		var d := U.flat_dist(p.pos, e.pos)
		var ratio := d / maxf(g.w.sonar_range(p, e), 1.0)
		# Faint before the tracker can hold it (ratio > 1), strong when close.
		var q := clampf((1.3 - ratio) / 0.3, 0.0, 1.0) * 0.3 if ratio > 1.0 else clampf(0.35 + 0.65 * (1.0 - ratio) / 0.6, 0.0, 1.0)
		if q > 0.0:
			out.append([U.brg(p.pos, e.pos), q, e])
	for m in g.w.muns:
		if m.alive and m.kind == "torpedo" and m.shooter != p:
			var d := U.flat_dist(p.pos, m.pos)
			var q := clampf((15000.0 - d) / 7000.0, 0.0, 1.0)
			if q > 0.0:
				out.append([U.brg(p.pos, m.pos), q, m])
	return out


func _add_row() -> void:
	var p = g.player
	var row := PackedFloat32Array()
	row.resize(W)
	var floor_n := 0.07 + 0.22 * absf(p.speed) / maxf(p.max_speed, 1.0)
	for i in W:
		row[i] = floor_n * (0.5 + rng.randf())
	for c: Array in _contacts():
		var b: float = c[0] + rng.randf_range(-0.8, 0.8)
		var q: float = c[1]
		var rel := U.adiff(p.heading, b)
		if absf(rel) > 150.0:
			q *= 0.12
		for k in range(-2, 3):
			var col := posmod(int(round(b)) + k, W)
			row[col] += q * exp(-float(k * k) / 1.2) * (0.75 + 0.25 * rng.randf())
	var bytes := PackedByteArray()
	bytes.resize(W * 3)
	for i in W:
		var rel := absf(U.adiff(p.heading, float(i)))
		var v := clampf(row[i], 0.0, 1.0)
		if rel > 150.0:
			v = clampf(v * 0.5 + 0.12 * rng.randf(), 0.0, 1.0)
		bytes[i * 3] = int(v * 60.0)
		bytes[i * 3 + 1] = int(v * 245.0)
		bytes[i * 3 + 2] = int(v * 120.0)
	var keep := data.slice(0, (H - 1) * W * 3)
	data = bytes
	data.append_array(keep)


func _track() -> void:
	var p = g.player
	for e in g.w.units:
		if e.side == p.side or not e.alive():
			continue
		if g.w.known_to(p.side, e):
			if not trackers.has(e.uid):
				trackers[e.uid] = next_tracker
				next_tracker += 1
				first_heard[e.uid] = g.w.t


# ------------------------------------------------------------------ drawing
func _draw() -> void:
	if g == null or g.player == null:
		return
	buttons.clear()
	var vs := size
	var p = g.player
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.03, 0.03))
	S.text(self, "CONTROL ROOM  ·  %s" % p.name.to_upper(), Vector2(24, 36), 22, S.side_color(p.side), HORIZONTAL_ALIGNMENT_LEFT, -1, S.heavy())
	S.text(self, "%s   %sL" % [U.clock(g.w.t), U.clock_hm(g.local_hour())], Vector2(24, 60), 15, S.MUTED)
	# The radio log runs between the title and the waterfall (drawn by the HUD).
	var wf := Rect2(24, 170, vs.x * 0.56, vs.y * 0.52)
	_waterfall(wf)
	_ship(Rect2(24, wf.end.y + 16, wf.size.x, vs.y - wf.end.y - 40))
	var rx := wf.end.x + 18
	var rw := vs.x - rx - 24
	_tracker(Rect2(rx, 20, rw, vs.y * 0.36))
	_weapons(Rect2(rx, 20 + vs.y * 0.36 + 14, rw, vs.y * 0.3))
	_controls(Rect2(rx, 20 + vs.y * 0.66 + 28, rw, vs.y * 0.34 - 68))


func _panel(r: Rect2, title: String) -> void:
	draw_rect(r, Color(0.03, 0.05, 0.045))
	draw_rect(r, Color(PHOS, 0.25), false, 1.0)
	S.text(self, title, r.position + Vector2(12, 22), 15, Color(PHOS, 0.8), HORIZONTAL_ALIGNMENT_LEFT, -1, S.heavy())


func _waterfall(r: Rect2) -> void:
	_panel(r, "BROADBAND SONAR  ·  TRUE BEARING  ·  %d MIN" % int(H * ROW_DT / 60.0))
	var area := Rect2(r.position + Vector2(10, 52), r.size - Vector2(20, 62))
	draw_texture_rect(tex, area, false)
	var p = g.player
	for b in range(0, 361, 30):
		var x := area.position.x + area.size.x * b / 360.0
		draw_line(Vector2(x, area.position.y - 6), Vector2(x, area.position.y), Color(PHOS, 0.6), 1.0)
		S.text(self, "%03d" % (b % 360), Vector2(x - 14, area.position.y - 10), 12, Color(PHOS, 0.7))
	# Own heading and the baffles astern.
	var hx: float = area.position.x + area.size.x * p.heading / 360.0
	draw_line(Vector2(hx, area.position.y), Vector2(hx, area.end.y), Color(S.AMBER, 0.5), 1.0)
	var bx := area.position.x + area.size.x * fposmod(p.heading + 180.0, 360.0) / 360.0
	var bw := area.size.x * 60.0 / 360.0
	for seg: Array in [[bx - bw * 0.5, bx + bw * 0.5]]:
		var a: float = seg[0]
		var b2: float = seg[1]
		for o: float in [0.0, -area.size.x, area.size.x]:
			var x0 := clampf(a + o, area.position.x, area.end.x)
			var x1 := clampf(b2 + o, area.position.x, area.end.x)
			if x1 > x0:
				draw_rect(Rect2(x0, area.position.y, x1 - x0, area.size.y), Color(0.0, 0.0, 0.0, 0.35))
				S.text(self, "BAFFLES", Vector2(x0 + 4, area.end.y - 8), 11, Color(S.AMBER, 0.6))
	# Tracker labels on the traces, staggered when contacts share a bearing.
	var placed := []
	for e in g.w.units:
		if not trackers.has(e.uid) or not e.alive():
			continue
		var b := U.brg(p.pos, e.pos)
		var x := area.position.x + area.size.x * b / 360.0
		var col := S.AMBER if e == g.target else Color(PHOS, 0.9)
		var ly := area.position.y + 28.0
		for q: Vector2 in placed:
			if absf(q.x - x) < 30.0 and absf(q.y - ly) < 8.0:
				ly += 15.0
		placed.append(Vector2(x, ly))
		draw_line(Vector2(x, area.position.y + 2), Vector2(x, area.position.y + 14), col, 2.0)
		S.text(self, "S%d" % trackers[e.uid], Vector2(x - 10, ly), 13, col)
	for m in g.w.muns:
		if m.alive and m.kind == "torpedo" and m.shooter != p and U.flat_dist(p.pos, m.pos) < 15000.0:
			var x := area.position.x + area.size.x * U.brg(p.pos, m.pos) / 360.0
			S.text(self, "TORPEDO", Vector2(x - 28, area.position.y + 44), 13, S.ALARM, HORIZONTAL_ALIGNMENT_LEFT, -1, S.heavy())


func _tracker(r: Rect2) -> void:
	_panel(r, "CONTACTS")
	var p = g.player
	var y := r.position.y + 48
	var ids := trackers.keys()
	ids.sort_custom(func(a, b): return trackers[a] < trackers[b])
	var shown := 0
	for uid in ids:
		var e = null
		for u in g.w.units:
			if u.uid == uid:
				e = u
		if e == null:
			continue
		var held: float = g.w.t - float(first_heard.get(uid, g.w.t))
		var known: bool = g.w.known_to(p.side, e) and e.alive()
		var col := S.AMBER if e == g.target else (Color(PHOS, 0.9) if known else S.MUTED)
		var cls := "classifying..."
		if held > 20.0:
			cls = String(e.cls.get("class", "?")).split(" (")[0] + "-class " + String(e.cls.get("type", ""))
			if e.navy == "merchant":
				cls = "merchant ship"
		var rng_txt := "range unknown"
		if held > 45.0:
			var d := U.flat_dist(p.pos, e.pos)
			rng_txt = "~%d km" % int(round(d / 2000.0) * 2.0)
		var status := "" if known else ("  LOST" if e.alive() else "  SUNK")
		var line := "S%-2d  %s  %-14s %s%s" % [trackers[uid], U.p3(U.brg(p.pos, e.pos)), rng_txt, cls, status]
		S.text(self, line, Vector2(r.position.x + 12, y), 14, col, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24)
		var hit := Rect2(r.position.x + 6, y - 16, r.size.x - 12, 21)
		buttons.append([hit, "target:%d" % uid])
		y += 22
		shown += 1
		if y > r.end.y - 30:
			break
	if shown == 0:
		S.text(self, "No contacts. Slow down and listen: own noise deafens the sonar.", Vector2(r.position.x + 12, y), 14, S.MUTED, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24)
	var tg = g.target
	if tg != null and tg.alive():
		S.text(self, "TARGET  S%s  %s" % [str(trackers.get(tg.uid, "?")), tg.name], Vector2(r.position.x + 12, r.end.y - 12), 15, S.AMBER)


func _weapons(r: Rect2) -> void:
	_panel(r, "WEAPONS")
	var p = g.player
	var x := r.position.x + 12
	var y := r.position.y + 48
	for m in p.mounts:
		var state := "READY" if m.ready() else ("RELOADING %ds" % int(ceil(m.reload)) if m.alive() else "DAMAGED")
		S.text(self, "%s  ·  %d tubes  ·  %s" % [m.md.get("name", m.id), maxi(m.tubes, 1), state], Vector2(x, y), 14, S.GOOD if m.ready() else S.AMBER)
		y += 20
		for a: String in m.ammo:
			var sel: bool = a == g.ammo_sel
			S.text(self, "%s %-34s %d" % [">" if sel else " ", Weapons.mun(a).get("name", a), int(m.ammo[a])], Vector2(x, y), 14, S.AMBER if sel else S.TEXT)
			y += 18
	y += 6
	var n := 0
	for mu in g.w.muns:
		if not mu.alive or mu.kind != "torpedo" or mu.shooter != p:
			continue
		n += 1
		var tgt = mu.target
		var dist_txt := ""
		var st := "RUNNING"
		if tgt != null and g.w.target_alive(tgt):
			var d: float = mu.pos.distance_to(tgt.pos)
			dist_txt = "%.1f km to target" % (d / 1000.0)
			if String(mu.md.get("guidance", "")) == "wire" and mu.t < 600.0:
				st = "WIRE GUIDED"
			if d < float(mu.md.get("seeker", 1500.0)):
				st = "HOMING"
		var words := String(mu.md.get("name", "torpedo")).split(" ")
		var short := " ".join(words.slice(0, 2))
		S.text(self, "#%d  %s  run %s  %s  %s" % [n, short, U.clock(mu.t), dist_txt, st], Vector2(x, y), 14, S.ALARM if st == "HOMING" else PHOS)
		y += 18
		if y > r.end.y - 8:
			break
	if n == 0:
		S.text(self, "No torpedoes in the water.", Vector2(x, y), 14, S.MUTED)


func _ship(r: Rect2) -> void:
	_panel(r, "SHIP CONTROL")
	var p = g.player
	var x := r.position.x + 14
	var y := r.position.y + 62
	S.text(self, "%3d m" % int(round(p.depth)), Vector2(x, y), 44, S.AMBER)
	S.text(self, "DEPTH   ordered %d m" % int(p.depth_order), Vector2(x, y + 22), 14, S.MUTED)
	S.text(self, "%4.1f" % (absf(p.speed) / U.KN), Vector2(x + 230, y), 44, PHOS)
	S.text(self, "KNOTS", Vector2(x + 230, y + 22), 14, S.MUTED)
	S.text(self, U.p3(p.heading), Vector2(x + 420, y), 44, PHOS)
	var steer := "STEER %s" % U.p3(p.course_order) if p.autopilot and p.course_order >= 0.0 else "RUDDER %d° %s" % [int(absf(p.rudder_order)), "RIGHT" if p.rudder_order > 0.5 else ("LEFT" if p.rudder_order < -0.5 else "")]
	S.text(self, "HEADING   " + steer, Vector2(x + 420, y + 22), 14, S.MUTED)
	var pl = p.plant
	var names: Array = pl.bell_names_en()
	S.text(self, "%s%s" % [names[pl.bell[0]], "" if pl.bell[0] == pl.answered[0] else "  (answering)"], Vector2(x, y + 56), 18, S.AMBER)
	var td: float = p.cls.get("test_depth", 300.0)
	var cd: float = p.cls.get("crush_depth", 450.0)
	var warn := ""
	if p.depth > td:
		warn = "BELOW TEST DEPTH"
	elif p.depth <= PD + 2.0:
		warn = "PERISCOPE DEPTH: scope and masts can be raised (P)"
	elif absf(p.speed) / U.KN > 12.0 and p.depth < 60.0:
		warn = "Fast and shallow: cavitating, you can be heard"
	S.text(self, warn, Vector2(x, y + 82), 15, S.ALARM if p.depth > td else S.MUTED)
	# Depth gauge: surface to collapse depth.
	var gx := r.end.x - 70
	var g0 := r.position.y + 40
	var g1 := r.end.y - 16
	draw_rect(Rect2(gx, g0, 26, g1 - g0), Color(0.06, 0.09, 0.08))
	for mark: Array in [[PD, "PD"], [LAYER, "LAYER"], [td, "TEST"], [cd, "CRUSH"]]:
		var my: float = lerpf(g0, g1, float(mark[0]) / cd)
		draw_line(Vector2(gx - 6, my), Vector2(gx + 32, my), S.ALARM if mark[1] == "CRUSH" or mark[1] == "TEST" else Color(PHOS, 0.5), 1.0)
		S.text(self, mark[1], Vector2(gx - 64, my + 4), 11, Color(PHOS, 0.7))
	var dy: float = lerpf(g0, g1, clampf(p.depth / cd, 0.0, 1.0))
	draw_rect(Rect2(gx + 2, g0, 22, dy - g0), Color(PHOS, 0.25))
	var oy: float = lerpf(g0, g1, clampf(p.depth_order / cd, 0.0, 1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(gx + 28, oy), Vector2(gx + 40, oy - 6), Vector2(gx + 40, oy + 6)]), S.AMBER)


func _controls(r: Rect2) -> void:
	_panel(r, "ORDERS")
	var x := r.position.x + 12
	var y := r.position.y + 40
	var bw := (r.size.x - 24 - 5 * 8) / 6.0
	var rows := [
		[["▲ 10 m", "depth:-10"], ["PD 18 m", "depth:18"], ["60 m", "depth:60"], ["150 m", "depth:150"], ["250 m", "depth:250"], ["▼ 10 m", "depth:10"]],
		[["BELL −", "bell:-1"], ["STOP", "stop"], ["BELL +", "bell:1"], ["◀ 15°", "rudder:-15"], ["MIDSHIPS", "rudder:0"], ["15° ▶", "rudder:15"]],
		[["NEXT TGT", "next"], ["WEAPON", "ammo"], ["FIRE", "fire"], ["DECOY (%d)" % g.decoys, "decoy"], ["SCOPE", "scope"], ["OUTSIDE", "ext"]],
	]
	for row: Array in rows:
		var bx := x
		for b: Array in row:
			var br := Rect2(bx, y, bw, 34)
			var hot: bool = b[1] == "fire"
			draw_rect(br, Color(0.08, 0.12, 0.1) if not hot else Color(0.22, 0.06, 0.04))
			draw_rect(br, Color(PHOS, 0.45) if not hot else S.ALARM, false, 1.0)
			S.text(self, b[0], br.position + Vector2(0, 22), 13, PHOS if not hot else Color(1.0, 0.75, 0.7), HORIZONTAL_ALIGNMENT_CENTER, bw)
			buttons.append([br, b[1]])
			bx += bw + 8
		y += 42
	S.text(self, "W/S bells · A/D rudder · PgUp/PgDn depth · T target · Space fire · Z weapon · N decoy · P scope · V outside",
		Vector2(x, r.end.y - 8), 12, S.MUTED, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24)


# ------------------------------------------------------------------ input
func _gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton) or not ev.pressed or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	for b: Array in buttons:
		if (b[0] as Rect2).has_point(ev.position):
			_act(String(b[1]))
			accept_event()
			return


func _act(a: String) -> void:
	var p = g.player
	var parts := a.split(":")
	match parts[0]:
		"depth":
			var v := float(parts[1])
			if parts[1] == "-10" or parts[1] == "10":
				p.depth_order = clampf(p.depth_order + v, 0.0, float(p.cls.get("crush_depth", 450.0)))
			else:
				p.depth_order = v
			g.sfx.play("click")
		"bell":
			g.order_speed(int(parts[1]))
		"stop":
			p.plant.ring(4)
			g.sfx.play("telegraph")
		"rudder":
			g.order_rudder(float(parts[1]))
		"next":
			next_target()
		"ammo":
			g._cycle_ammo()
		"fire":
			g._launch()
		"decoy":
			g.launch_decoy()
		"scope":
			g.set_mode("scope")
		"ext":
			g.set_mode("external")
		"target":
			for u in g.w.units:
				if u.uid == int(parts[1]) and u.alive() and g.w.known_to(p.side, u):
					g.set_target(u)
					g.sfx.play("beep")


## Cycle the target through the contacts we hold, in tracker order.
func next_target() -> void:
	var p = g.player
	var held := []
	for u in g.w.units:
		if trackers.has(u.uid) and u.alive() and g.w.known_to(p.side, u):
			held.append(u)
	if held.is_empty():
		g.hud.show_hint("No contacts held")
		return
	held.sort_custom(func(a, b): return trackers[a.uid] < trackers[b.uid])
	var i := held.find(g.target)
	var nxt = held[(i + 1) % held.size()]
	g.set_target(nxt)
	g.sfx.play("beep")
	g.hud.show_hint("Target S%d: %s" % [trackers[nxt.uid], nxt.name if held_long(nxt) else "unclassified contact"])


func held_long(e) -> bool:
	return g.w.t - float(first_heard.get(e.uid, g.w.t)) > 20.0
