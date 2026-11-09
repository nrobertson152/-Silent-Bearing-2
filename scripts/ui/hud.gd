extends Control
## In-mission heads-up display: ship status, engine orders, damage, weapons,
## gunsight and fire-control solution, compass, objectives and radio log.

const U := preload("res://scripts/util.gd")
const S := preload("res://scripts/ui/style.gd")
const Weapons := preload("res://scripts/data/weapons.gd")
const ShipData := preload("res://scripts/data/ships.gd")

var g
var msgs := []
var big_msg := ""
var big_t := 0.0
var help := false
var hint := ""
var hint_t := 0.0

const HELP := [
	"CONTROLS",
	"",
	"W / S or Up / Down       Engine orders (telegraph bells or throttle)",
	"A / D or Left / Right    Rudder (hold Shift for hard over), X amidships",
	"C                        Steer the current heading (helmsman holds course)",
	"V                        Bridge / outside view      B   Gun director sight",
	"M or Tab                 Tactical plot (click a contact to target it)",
	"Mouse                    Look / aim  (bridge: right-drag to look, click controls)",
	"Left click               Fire selected weapon at the crosshair or lead",
	"1 - 6                    Weapon group     Z  ammunition / missile type",
	"T                        Designate target near the crosshair",
	"F                        Director: guns follow the fire-control lead",
	"Space                    Launch missile / torpedo at the target",
	"Q                        Air defence AUTO / HOLD     R  Radar on / off",
	"G                        General quarters alarm      H  Ship's whistle",
	"PgUp / PgDn              Submarine depth order       P  Periscope (subs)",
	"V (submarine)            Control room / outside view N  Decoy (subs)",
	"1-9 on the plant panel   Start / stop gas turbines or light boilers (bridge)",
	". and ,                  Time compression            Esc  Pause",
	"",
	"Engines: telegraph ships wait for the engine room to answer and must",
	"pass through STOP before going astern. Gas turbines take ~90 s to start;",
	"boilers take minutes to raise steam. Ring up more than your lit boilers",
	"can supply and steam pressure (and speed) will fall.",
]

const GROUPS := [["main", "1", "MAIN GUNS"], ["sec", "2", "SECONDARY"], ["ashm", "3", "ANTI-SHIP MSL"],
	["sam", "4", "SAM (MANUAL)"], ["asw", "5", "ASW / TORPEDO"], ["strike", "6", "STRIKE / SPECIAL"]]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func message(from: String, text: String, col := S.TEXT) -> void:
	msgs.push_front({"from": from, "text": text, "t": 0.0, "col": col})
	if msgs.size() > 9:
		msgs.pop_back()


func banner(text: String, secs := 4.0) -> void:
	big_msg = text
	big_t = secs


func show_hint(text: String, secs := 3.0) -> void:
	hint = text
	hint_t = secs


func _process(delta: float) -> void:
	for m in msgs:
		m["t"] += delta
	if big_t > 0.0:
		big_t -= delta
	if hint_t > 0.0:
		hint_t -= delta
	queue_redraw()


func _draw() -> void:
	if g == null or g.player == null:
		return
	var vs := get_viewport_rect().size
	var p = g.player
	if g.mode == "conn":
		_messages(Vector2(24, 92), vs.x * 0.56, 2, true, 2)
		if big_t > 0.0:
			S.text(self, big_msg, Vector2(0, vs.y * 0.3), 38, Color(S.AMBER, clampf(big_t, 0.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, vs.x, S.heavy())
		if hint_t > 0.0:
			S.text(self, hint, Vector2(0, vs.y - 40), 20, Color(S.TEXT, clampf(hint_t, 0, 1)), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		if help:
			_help(vs)
		return
	if g.mode != "map" and g.mode != "scope":
		_crosshair(vs)
		_compass(vs)
	_ship_panel(Rect2(14, 14, 400, 296), p)
	_damage_panel(Rect2(14, vs.y - 196, 400, 182), p)
	_weapons_panel(Rect2(vs.x - 444, vs.y - 330, 430, 316), p)
	_mission_panel(Rect2(vs.x - 444, 14, 430, 230))
	_messages(Vector2(430, vs.y - 196))
	if big_t > 0.0:
		var a := clampf(big_t, 0.0, 1.0)
		S.text(self, big_msg, Vector2(0, vs.y * 0.3), 38, Color(S.AMBER, a), HORIZONTAL_ALIGNMENT_CENTER, vs.x, S.heavy())
	if hint_t > 0.0:
		S.text(self, hint, Vector2(0, vs.y - 230), 20, Color(S.TEXT, clampf(hint_t, 0, 1)), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	if g.tc > 1.0:
		S.text(self, "TIME x%d" % int(g.tc), Vector2(vs.x * 0.5 - 60, 90), 22, S.AMBER, HORIZONTAL_ALIGNMENT_CENTER, 120)
	if help:
		_help(vs)


func _bar(r: Rect2, frac: float, col: Color, label: String, value: String) -> void:
	draw_rect(r, Color(0.1, 0.12, 0.12, 0.9))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)
	draw_rect(r, S.EDGE, false, 1.0)
	S.text(self, label, r.position + Vector2(6, r.size.y - 5), 14, S.TEXT)
	S.text(self, value, r.position + Vector2(0, r.size.y - 5), 14, S.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 6)


func _ship_panel(r: Rect2, p) -> void:
	S.panel(self, r)
	var x := r.position.x + 12
	var y := r.position.y + 24
	S.text(self, p.name.to_upper(), Vector2(x, y), 20, S.side_color(p.side), HORIZONTAL_ALIGNMENT_LEFT, -1, S.heavy())
	S.text(self, "%s  %s" % [p.cls.get("class", ""), p.cls.get("desig", "")], Vector2(x, y + 20), 14, S.MUTED)
	var kn: float = p.speed / U.KN
	S.text(self, "%4.1f" % kn, Vector2(x, y + 64), 40, S.PHOS)
	S.text(self, "KTS", Vector2(x + 104, y + 64), 14, S.MUTED)
	S.text(self, U.p3(p.heading), Vector2(x + 170, y + 64), 40, S.PHOS)
	S.text(self, "HDG", Vector2(x + 250, y + 64), 14, S.MUTED)
	if p.is_sub:
		S.text(self, "%3d m" % int(p.depth), Vector2(x + 300, y + 52), 22, S.AMBER)
		S.text(self, "ORD %d" % int(p.depth_order), Vector2(x + 300, y + 72), 14, S.MUTED)
	var ord := "RUDDER %s %d°" % ["RIGHT" if p.rudder_order > 0.5 else ("LEFT" if p.rudder_order < -0.5 else "AMIDSHIPS"), int(absf(p.rudder_order))]
	if p.autopilot and p.course_order >= 0.0:
		ord = "STEER %s" % U.p3(p.course_order)
	S.text(self, ord, Vector2(x, y + 92), 16, S.AMBER)
	var rr := Rect2(x, y + 100, r.size.x - 24, 14)
	draw_rect(rr, Color(0.1, 0.12, 0.12))
	var mid := rr.position.x + rr.size.x * 0.5
	var rx := mid + rr.size.x * 0.5 * clampf(p.rudder / 35.0, -1.0, 1.0)
	draw_rect(Rect2(minf(mid, rx), rr.position.y + 2, absf(rx - mid), rr.size.y - 4), S.GOOD)
	draw_line(Vector2(mid, rr.position.y - 2), Vector2(mid, rr.end.y + 2), S.TEXT, 1.0)
	var ox := mid + rr.size.x * 0.5 * clampf(p.rudder_order / 35.0, -1.0, 1.0)
	draw_line(Vector2(ox, rr.position.y - 3), Vector2(ox, rr.end.y + 3), S.AMBER, 2.0)
	var pl = p.plant
	var ey := y + 136
	if pl.is_lever():
		S.text(self, "THROTTLE %+d%%   PITCH %+d%%" % [int(pl.lever[0] * 100.0), int(pl.pitch[0] * 100.0)], Vector2(x, ey), 16, S.TEXT)
	else:
		var names: Array = pl.bell_names_en()
		var ordered: String = names[pl.bell[0]]
		var ans: String = names[pl.answered[0]]
		S.text(self, ordered, Vector2(x, ey), 16, S.AMBER)
		S.text(self, ("ANSWERED" if pl.bell[0] == pl.answered[0] else "ANSWERING...") if ans == ordered else "ANS: " + ans,
			Vector2(x + 200, ey), 14, S.GOOD if pl.bell[0] == pl.answered[0] else S.ALARM)
	var rpms := []
	for s in pl.shafts:
		rpms.append("%d" % int(pl.shaft_rpm(s)))
	S.text(self, "SHAFT RPM  " + " / ".join(rpms), Vector2(x, ey + 20), 15, S.TEXT)
	var uy := ey + 42
	if pl.kind == "steam" and not pl.nuclear:
		_bar(Rect2(x, ey + 28, r.size.x - 24, 14), pl.steam / 1.05, S.GOOD if pl.steam > 0.85 else S.ALARM, "STEAM PRESSURE", "%d%%" % int(pl.steam / 1.05 * 100))
		uy = ey + 60
	var col := 0
	for i in pl.units.size():
		var un: Dictionary = pl.units[i]
		var st: String = un["state"]
		var c := S.GOOD if st == "online" else (S.AMBER if st == "starting" else (S.ALARM if st == "failed" else S.MUTED))
		var tag := "ONLINE" if st == "online" else ("START %ds" % int(un["timer"]) if st == "starting" else ("STANDBY" if st == "standby" else "DAMAGED"))
		var px := x + (col % 2) * 190
		var py := uy + (col / 2) * 17
		S.text(self, "%s %s" % [String(un["name"]).to_upper(), tag], Vector2(px, py), 13, c)
		col += 1


func _damage_panel(r: Rect2, p) -> void:
	S.panel(self, r)
	var x := r.position.x + 12
	var y := r.position.y + 22
	S.text(self, "DAMAGE CONTROL", Vector2(x, y), 16, S.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, S.heavy())
	var hp: float = clampf(p.hp / p.hp_max, 0.0, 1.0)
	_bar(Rect2(x, y + 10, r.size.x - 24, 18), hp, S.GOOD if hp > 0.6 else (S.AMBER if hp > 0.3 else S.ALARM), "STRUCTURE", "%d%%" % int(hp * 100))
	var fl: float = p.flooded() / p.reserve
	_bar(Rect2(x, y + 34, r.size.x - 24, 18), fl, S.US_BLUE if fl < 0.5 else S.ALARM, "FLOODING", "%d t" % int(p.flooded()))
	var fires := 0
	for f in p.fire:
		if f > 0.05:
			fires += 1
	S.text(self, "FIRES: %d   DC TEAMS: %d" % [fires, p.dc_teams], Vector2(x, y + 74), 15, S.ALARM if fires > 0 else S.TEXT)
	var mx := x
	for k in ["engine", "steering", "radar", "fc", "bridge", "sonar"]:
		if not p.modules.has(k):
			continue
		var h: float = p.mod_hp(k)
		var c := S.GOOD if h > 0.7 else (S.AMBER if h > 0.3 else S.ALARM)
		S.text(self, k.to_upper(), Vector2(mx, y + 100), 13, c)
		mx += S.mono().get_string_size(k.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0
	if p.sinking:
		S.text(self, "ABANDON SHIP", Vector2(x, y + 140), 26, S.ALARM, HORIZONTAL_ALIGNMENT_LEFT, -1, S.heavy())
	elif p.is_sub:
		var td: float = p.cls.get("test_depth", 300.0)
		S.text(self, "TEST DEPTH %d m   CRUSH %d m" % [int(td), int(p.cls.get("crush_depth", 450.0))], Vector2(x, y + 140), 14, S.ALARM if p.depth > td else S.MUTED)
	else:
		S.text(self, "AIR DEFENCE: %s   RADAR: %s" % [g.w.ad_mode.to_upper(), "SILENT" if p.emcon else "ACTIVE"], Vector2(x, y + 140), 14, S.MUTED)


func _weapons_panel(r: Rect2, p) -> void:
	S.panel(self, r)
	var x := r.position.x + 12
	var y := r.position.y + 22
	S.text(self, "WEAPONS", Vector2(x, y), 16, S.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, S.heavy())
	var yy := y + 24
	for gr in GROUPS:
		var ms: Array = p.mounts.filter(func(m): return g.group_of(m) == gr[0])
		if ms.is_empty():
			continue
		var sel: bool = g.group == gr[0]
		var ammo := {}
		var ready := 0
		for m in ms:
			if m.ready():
				ready += 1
			for k in m.ammo:
				ammo[k] = int(ammo.get(k, 0)) + int(m.ammo[k])
		var c := S.AMBER if sel else S.TEXT
		if sel:
			draw_rect(Rect2(r.position.x + 4, yy - 16, r.size.x - 8, 22 + 16 * ammo.size()), Color(0.3, 0.25, 0.1, 0.35))
		S.text(self, "%s  %s" % [gr[1], gr[2]], Vector2(x, yy), 15, c)
		S.text(self, "%d/%d READY" % [ready, ms.size()], Vector2(x, yy), 13, S.GOOD if ready > 0 else S.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 24)
		yy += 17
		for k in ammo:
			var md := Weapons.mun(k)
			var is_sel: bool = sel and g.ammo_sel == k
			var nm: String = md.get("name", k)
			if md.has("nuke"):
				nm = "☢ " + nm
			S.text(self, ("> " if is_sel else "   ") + nm, Vector2(x + 8, yy), 13, S.ALARM if md.has("nuke") else (S.PHOS if is_sel else S.MUTED))
			S.text(self, str(ammo[k]), Vector2(x, yy), 13, S.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 24)
			yy += 16
		yy += 6
	var tg = g.target
	var ty := r.end.y - 52
	draw_line(Vector2(r.position.x + 8, ty - 18), Vector2(r.end.x - 8, ty - 18), S.EDGE, 1.0)
	if tg != null and tg.alive():
		var d := U.flat_dist(p.pos, tg.pos)
		S.text(self, "TARGET  %s" % tg.name.to_upper(), Vector2(x, ty), 15, S.side_color(tg.side))
		S.text(self, "%s  BRG %s  SOLN %d%%" % [U.km(d), U.p3(U.brg(p.pos, tg.pos)), int(g.fc_q * 100.0)], Vector2(x, ty + 20), 14, S.TEXT)
	else:
		S.text(self, "NO TARGET  (T to designate)", Vector2(x, ty + 8), 14, S.MUTED)


func _mission_panel(r: Rect2) -> void:
	S.panel(self, r)
	var x := r.position.x + 12
	var y := r.position.y + 24
	var m = g.w.mission
	S.text(self, g.mission.get("title", "").to_upper(), Vector2(x, y), 16, S.AMBER, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24, S.heavy())
	S.text(self, "%s   %sL" % [U.clock(g.w.t), U.clock_hm(g.local_hour())], Vector2(x, y + 22), 15, S.MUTED)
	var yy := y + 50
	if m != null:
		for line in m.objective_lines():
			var c := S.GOOD if line[2] == "done" else (S.ALARM if line[2] == "failed" else S.TEXT)
			if line[3]:
				c = c.darkened(0.25)
			var txt := "%s %s" % [line[0], line[1]]
			var w := r.size.x - 24
			draw_multiline_string(S.mono(), Vector2(x, yy), txt, HORIZONTAL_ALIGNMENT_LEFT, w, 14, 3, c)
			yy += S.mono().get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, w, 14, 3).y + 4.0


## The radio log. Newest at the bottom, older lines climbing above it; long
## messages wrap. In the control room a short list runs down from the top.
func _messages(pos: Vector2, width := 980.0, max_n := 9, downward := false, max_lines := 3) -> void:
	var f := S.mono()
	var fh := f.get_height(16)
	var y := pos.y + (0.0 if downward else 170.0)
	var n := 0
	for m in msgs:
		var a := clampf(1.0 - (float(m["t"]) - 18.0) / 6.0, 0.0, 1.0)
		if a <= 0.0:
			continue
		n += 1
		if n > max_n:
			break
		var from: String = m["from"]
		var s := ("[%s]  " % from.to_upper() if from != "" else "") + String(m["text"])
		var lines := mini(max_lines, maxi(1, int(round(f.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, width, 16, max_lines).y / fh))))
		var top := y if downward else y - (lines - 1) * fh
		draw_multiline_string(f, Vector2(pos.x, top), s, HORIZONTAL_ALIGNMENT_LEFT, width, 16, max_lines, Color(m["col"], a))
		if downward:
			y = top + lines * fh + 4.0
		else:
			y = top - fh - 4.0


func _compass(vs: Vector2) -> void:
	var hdg: float = g.view_bearing()
	var w := 600.0
	var x0 := vs.x * 0.5 - w * 0.5
	var y0 := 20.0
	draw_rect(Rect2(x0, y0, w, 34), Color(0.03, 0.04, 0.045, 0.55))
	for d in range(-60, 61, 5):
		var b := U.wrap360(roundf(hdg / 5.0) * 5.0 + d)
		var off := U.adiff(hdg, b)
		if absf(off) > 60.0:
			continue
		var x := vs.x * 0.5 + off / 60.0 * w * 0.5
		var big := int(b) % 15 == 0
		draw_line(Vector2(x, y0 + 34), Vector2(x, y0 + (18 if big else 26)), S.TEXT, 1.0)
		if int(b) % 30 == 0:
			var lab = {0: "N", 90: "E", 180: "S", 270: "W"}.get(int(b), U.p3(b))
			S.text(self, lab, Vector2(x - 20, y0 + 15), 14, S.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 40)
	draw_line(Vector2(vs.x * 0.5, y0 - 4), Vector2(vs.x * 0.5, y0 + 38), S.AMBER, 2.0)
	var sh := U.adiff(hdg, g.player.heading)
	if absf(sh) < 60.0:
		var x := vs.x * 0.5 + sh / 60.0 * w * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(x, y0 + 36), Vector2(x - 6, y0 + 46), Vector2(x + 6, y0 + 46)]), S.PHOS)


func _crosshair(vs: Vector2) -> void:
	var c := vs * 0.5
	var cam: Camera3D = g.cam
	if g.mode == "external" or g.mode == "sight":
		var col := Color(1, 1, 1, 0.85)
		draw_arc(c, 18.0, 0, TAU, 32, col, 1.5)
		draw_line(c + Vector2(-34, 0), c + Vector2(-22, 0), col, 1.5)
		draw_line(c + Vector2(22, 0), c + Vector2(34, 0), col, 1.5)
		draw_line(c + Vector2(0, 22), c + Vector2(0, 34), col, 1.5)
		if g.aim_valid:
			var d := U.flat_dist(g.player.pos, g.aim_point)
			S.text(self, U.km(d), c + Vector2(26, -22), 16, col)
			var tof: float = g.aim_tof
			if tof > 0.0:
				S.text(self, "%.0f s" % tof, c + Vector2(26, 36), 14, S.MUTED)
		if g.mode == "sight":
			for i in range(-4, 5):
				if i == 0:
					continue
				draw_line(c + Vector2(i * 40, -4), c + Vector2(i * 40, 4), col, 1.0)
				draw_line(c + Vector2(-4, i * 40), c + Vector2(4, i * 40), col, 1.0)
		# Mount readiness pips under the crosshair.
		var ms: Array = g.player.mounts.filter(func(m): return g.group_of(m) == g.group)
		var px := c.x - ms.size() * 8.0
		for m in ms:
			var mc := S.GOOD if m.ready() and m.on_target(2.0) else (S.AMBER if m.ready() else S.MUTED)
			if not m.alive():
				mc = S.ALARM
			draw_rect(Rect2(px, c.y + 48, 12, 6), mc)
			px += 16
	var tg = g.target
	if tg != null and tg.alive() and cam != null:
		var tp: Vector3 = g.view.ship_node(tg).global_position if g.view.ship_node(tg) else tg.pos
		if not cam.is_position_behind(tp + Vector3(0, 10, 0)):
			var sp := cam.unproject_position(tp + Vector3(0, 10, 0))
			var bs := 22.0
			var col := S.side_color(tg.side)
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var o = sp + corner * bs
				draw_line(o, o - Vector2(corner.x * 9, 0), col, 2.0)
				draw_line(o, o - Vector2(0, corner.y * 9), col, 2.0)
			S.text(self, tg.name, sp + Vector2(bs + 6, -bs), 14, col)
		if g.lead_valid and not cam.is_position_behind(g.lead_point):
			var lp := cam.unproject_position(g.lead_point)
			var lc := Color(S.AMBER, 0.4 + 0.6 * g.fc_q)
			draw_arc(lp, 9.0, 0, TAU, 20, lc, 2.0)
			draw_line(lp + Vector2(-14, 0), lp + Vector2(14, 0), lc, 1.0)
	var used := []
	for e in g.w.units:
		if e == g.player or e == tg or not e.alive() or not g.w.known_to(g.player.side, e):
			continue
		var n: Node3D = g.view.ship_node(e)
		if n == null or cam.is_position_behind(n.global_position):
			continue
		var d := U.flat_dist(g.player.pos, e.pos)
		if d > 60000.0 or (e.is_sub and e.depth > 10.0 and g.mode != "map"):
			continue
		var sp := cam.unproject_position(n.global_position + Vector3(0, 12, 0))
		var col := Color(S.side_color(e.side), 0.7)
		if e.navy == "merchant":
			col = Color(0.8, 0.8, 0.7, 0.7)
		draw_rect(Rect2(sp - Vector2(5, 5), Vector2(10, 10)), col, false, 1.5)
		var lp := sp + Vector2(8, -6)
		for tries in 6:
			var clash := false
			for q: Vector2 in used:
				if absf(q.x - lp.x) < 110.0 and absf(q.y - lp.y) < 13.0:
					clash = true
			if not clash:
				break
			lp.y += 14.0
		used.append(lp)
		S.text(self, "%s %s" % [e.cls.get("class", "").split(" ")[0], U.km(d)], lp, 12, col)


func _help(vs: Vector2) -> void:
	var r := Rect2(vs.x * 0.5 - 430, 120, 860, 760)
	S.panel(self, r, S.BG)
	var lines := HELP
	var y := r.position.y + 40
	for l in lines:
		S.text(self, l, Vector2(r.position.x + 30, y), 17 if l != "CONTROLS" else 24, S.AMBER if l == "CONTROLS" else S.TEXT)
		y += 30
