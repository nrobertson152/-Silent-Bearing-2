extends Node3D
## One mission in 3D: simulation, view, cameras, bridge, HUD, sound and input.

signal finished(result: String, stats: Dictionary)
signal pause_requested

const U := preload("res://scripts/util.gd")
const S := preload("res://scripts/ui/style.gd")
const Ocean := preload("res://scripts/view/ocean.gd")
const Atmos := preload("res://scripts/view/atmosphere.gd")
const WorldView := preload("res://scripts/view/world_view.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const Tactical := preload("res://scripts/ui/tactical.gd")
const Bridge := preload("res://scripts/bridge/bridge.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")
const Settings := preload("res://scripts/core/settings.gd")
const Weapons := preload("res://scripts/data/weapons.gd")

const STEP := 1.0 / 30.0

var mission := {}
var w: SimWorld
var sim_mission: SimMission
var player
var ocean
var atm
var view
var cam: Camera3D
var hud
var tac
var bridge
var sfx
var canvas: CanvasLayer
var mode := "external"
var prev_mode := "external"
var tc := 1.0
var acc := 0.0
var orbit_yaw := 200.0
var orbit_pitch := -6.0
var orbit_dist := 400.0
var look_yaw := 0.0
var look_pitch := -4.0
var sight_yaw := 0.0
var sight_pitch := 0.0
var zoom := false
var group := "main"
var ammo_sel := ""
var target = null
var fc_q := 0.0
var director := true
var aim_point := Vector3.ZERO
var aim_valid := false
var aim_tof := 0.0
var lead_point := Vector3.ZERO
var lead_valid := false
var firing := false
var ended := false
var end_t := 0.0
var result := ""
var gq := false
var start_hour := 12.0
var day := 240
var smoke_ok := true
var frozen := false
var auto_exit := -1.0


func start(def: Dictionary) -> void:
	mission = def
	Settings.load_settings()
	w = SimWorld.new()
	w.difficulty = Settings.difficulty
	sim_mission = SimMission.new(w, def)
	sim_mission.setup()
	player = w.player
	start_hour = float(def.get("time", 12.0))
	var dt: Array = def.get("date", [1988, 8, 20])
	day = U.day_of_year(int(dt[1]), int(dt[2]))
	ocean = Ocean.new()
	add_child(ocean)
	atm = Atmos.new()
	add_child(atm)
	atm.setup(def.get("weather", {}), float(def.get("lat", 60.0)), day, start_hour, ocean)
	w.night = atm.is_night()
	view = WorldView.new()
	add_child(view)
	view.setup(w, ocean, atm)
	view.set_night(atm.sun_el < 2.0)
	var wd := deg_to_rad(float(def.get("weather", {}).get("wind", 240.0)) + 180.0)
	view.fx.wind = Vector3(sin(wd), 0, -cos(wd)) * (2.0 + float(def.get("weather", {}).get("sea", 3.0)))
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.near = 0.12
	cam.far = 160000.0
	add_child(cam)
	cam.make_current()
	canvas = CanvasLayer.new()
	add_child(canvas)
	hud = Hud.new()
	hud.g = self
	canvas.add_child(hud)
	tac = Tactical.new()
	tac.g = self
	tac.visible = false
	canvas.add_child(tac)
	sfx = Sfx.new()
	add_child(sfx)
	var pn: Node3D = view.ship_node(player)
	if not player.is_sub:
		bridge = Bridge.new()
		bridge.setup(self, player, pn)
	orbit_dist = player.L * 2.4
	orbit_yaw = U.wrap360(player.heading + 25.0)
	_select_group(_first_group())
	Settings.apply_viewport(get_viewport())
	set_mode("bridge" if bridge != null and def.get("start_view", "bridge") == "bridge" else "external")
	hud.banner(def.get("title", ""), 5.0)
	hud.message("", def.get("location", ""), S.MUTED)
	if def.has("start_radio"):
		for r in def["start_radio"]:
			hud.message(r[0], r[1], S.AMBER)


func _first_group() -> String:
	for gname in ["main", "ashm", "torp", "asw", "sec", "strike", "sam"]:
		for m in player.mounts:
			if group_of(m) == gname:
				return gname
	return "main"


func group_of(m) -> String:
	if m.kind == "ciws":
		return "ciws"
	if m.group == "torp":
		return "asw"
	return m.group


func local_hour() -> float:
	return start_hour + w.t / 3600.0


func view_bearing() -> float:
	if mode == "bridge":
		return U.wrap360(player.heading + look_yaw)
	var f := -cam.global_transform.basis.z
	return U.wrap360(rad_to_deg(atan2(f.x, -f.z)))


# ------------------------------------------------------------------ modes
func set_mode(m: String) -> void:
	if m == "bridge" and bridge == null:
		m = "external"
	if mode != "map":
		prev_mode = mode
	mode = m
	tac.visible = m == "map"
	if bridge != null:
		bridge.set_active(m == "bridge")
	if m == "external" or m == "sight":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if m == "sight":
		sight_yaw = view_bearing()
		sight_pitch = 0.0
	zoom = false


# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	if frozen:
		return
	delta = minf(delta, 0.1)
	if not ended:
		acc += delta * tc
		var steps := 0
		var dt := STEP if tc <= 4.0 else STEP * 3.0
		while acc >= dt and steps < 12:
			_player_fire_control(dt)
			w.step(dt)
			acc -= dt
			steps += 1
		if steps >= 12:
			acc = 0.0
	if not w.events.is_empty():
		for ev in w.events:
			_event(ev)
		w.events.clear()
	if ended:
		end_t += delta
	_continuous_input(delta)
	var hour := local_hour()
	if absf(hour - atm.hour) > 0.02:
		atm.set_time(hour)
		w.night = atm.is_night()
	atm.update(w.t)
	_camera(delta)
	ocean.follow(cam.global_position, w.t)
	view.sync(delta, cam.global_position)
	if bridge != null:
		bridge.update(delta)
	sfx.update_ship(player, delta, mode, cam.global_position)
	if auto_exit > 0.0 and w.t > auto_exit:
		finished.emit("smoke", w.stats)


func _continuous_input(delta: float) -> void:
	if mode == "map" or ended:
		return
	if mode == "bridge" and bridge != null and bridge.dragging:
		return


func _camera(delta: float) -> void:
	var pn: Node3D = view.ship_node(player)
	if pn == null:
		return
	match mode:
		"bridge":
			if bridge != null:
				var head: Transform3D = bridge.head_transform()
				var b := Basis(Vector3.UP, deg_to_rad(-look_yaw)) * Basis(Vector3.RIGHT, deg_to_rad(look_pitch))
				cam.global_transform = Transform3D(head.basis * b, head.origin)
				cam.fov = lerpf(cam.fov, 14.0 if zoom else 62.0, clampf(delta * 8.0, 0.0, 1.0))
		"external", "map":
			# War Thunder style: the camera sits behind and above the ship and looks
			# along the aim line, so the crosshair points at the sea where the guns aim.
			var c := pn.global_position + Vector3(0, player.L * 0.04, 0)
			var yaw := deg_to_rad(orbit_yaw)
			var pit := deg_to_rad(orbit_pitch)
			var look := Vector3(sin(yaw) * cos(pit), sin(pit), -cos(yaw) * cos(pit))
			var flat := Vector3(sin(yaw), 0, -cos(yaw))
			var p := c - flat * orbit_dist + Vector3(0, orbit_dist * 0.28 + player.L * 0.05, 0)
			var floor_y: float = ocean.height(p.x, p.z) + 2.5
			if p.y < floor_y and not (player.is_sub and player.depth > 12.0):
				p.y = floor_y
			cam.global_position = p
			cam.global_transform.basis = Basis.looking_at(look, Vector3.UP)
			cam.fov = lerpf(cam.fov, 12.0 if zoom else 60.0, clampf(delta * 8.0, 0.0, 1.0))
		"sight":
			var br: Dictionary = pn.get_meta("bridge")
			var top := Vector3(0, float(br.get("y", player.deck_h() + 8.0)) + float(br.get("h", 3.0)) + 3.0, float(br.get("z0", -player.L * 0.2)) + 4.0)
			var p := pn.global_transform * top
			cam.global_position = Vector3(p.x, maxf(p.y, 6.0), p.z)
			var yaw := deg_to_rad(sight_yaw)
			var pit := deg_to_rad(sight_pitch)
			cam.global_transform.basis = Basis.looking_at(Vector3(sin(yaw) * cos(pit), sin(pit), -cos(yaw) * cos(pit)), Vector3.UP)
			cam.fov = lerpf(cam.fov, 2.5 if zoom else 8.0, clampf(delta * 8.0, 0.0, 1.0))
	_update_aim()


func _update_aim() -> void:
	aim_valid = false
	if mode != "external" and mode != "sight":
		return
	var o := cam.global_position
	var d := -cam.global_transform.basis.z
	var maxr := _group_range()
	if d.y < -0.0005:
		var t := -o.y / d.y
		aim_point = o + d * t
		aim_valid = true
	else:
		var flat := Vector3(d.x, 0, d.z).normalized()
		aim_point = Vector3(player.pos.x, 0, player.pos.z) + flat * maxr
		aim_valid = true
	if U.flat_dist(player.pos, aim_point) > maxr:
		aim_point = Vector3(player.pos.x, 0, player.pos.z) + (aim_point - player.pos).normalized() * maxr
		aim_point.y = 0.0
	var ms: Array = _group_mounts()
	aim_tof = 0.0
	if not ms.is_empty() and ms[0].kind == "gun":
		aim_tof = SimBallistics.time_for(ms[0].sel, U.flat_dist(player.pos, aim_point))


func _group_mounts() -> Array:
	return player.mounts.filter(func(m): return group_of(m) == group and m.alive())


func _group_range() -> float:
	var r := 2000.0
	for m in _group_mounts():
		if m.kind == "gun":
			r = maxf(r, SimBallistics.max_range(m.sel))
		else:
			r = maxf(r, float(Weapons.mun(m.sel).get("range", 10000.0)))
	return r


## Fire control for the player's guns each simulation step.
func _player_fire_control(dt: float) -> void:
	lead_valid = false
	if target != null and (not target.alive()):
		target = null
	if target != null:
		fc_q = clampf(fc_q + dt / (9.0 if player.navy == "us" else 12.0) * (0.4 + 0.6 * player.mod_hp("fc")) - absf(target.yaw_rate) * 0.02 * dt - absf(player.yaw_rate) * 0.01 * dt, 0.0, 0.95)
		var ms: Array = _group_mounts()
		if not ms.is_empty() and ms[0].kind == "gun":
			var d := U.flat_dist(player.pos, target.pos)
			var tof := SimBallistics.time_for(ms[0].sel, d)
			var err := (1.0 - fc_q) * 0.05 * d
			lead_point = target.pos + target.vel() * tof + (target.pos - player.pos).normalized() * err * sin(w.t * 0.37)
			lead_valid = true
	else:
		fc_q = 0.0
	var aim := aim_point
	var use_lead := director and lead_valid and (mode == "external" or mode == "sight" or mode == "bridge" or mode == "map")
	if use_lead:
		aim = lead_point
	elif not aim_valid:
		if target != null:
			aim = target.pos
		else:
			return
	for m in _group_mounts():
		if m.kind != "gun":
			continue
		if firing and not ended:
			w.fire_gun(player, m, aim, true, 1.0)
		else:
			var rng := U.flat_dist(m.world_pos(), aim)
			m.aim_at(aim, SimBallistics.elevation_for(m.sel, rng))
	if firing and group in ["asw"] and target != null and target.is_sub:
		for m in _group_mounts():
			if m.kind == "rocket":
				w.fire_rbu(player, m, target.pos, target.depth, true)


# ------------------------------------------------------------------ weapons
func _select_group(gname: String) -> void:
	var ms: Array = player.mounts.filter(func(m): return group_of(m) == gname)
	if ms.is_empty():
		hud.show_hint("No weapons in that group")
		return
	group = gname
	ammo_sel = ms[0].sel
	var names := {"main": "Main battery", "sec": "Secondary battery", "ashm": "Anti-ship missiles", "sam": "Surface-to-air missiles (manual)", "asw": "Anti-submarine weapons", "strike": "Strike and special weapons"}
	hud.show_hint(names.get(gname, gname))


func _cycle_ammo() -> void:
	var ms: Array = _group_mounts()
	if ms.is_empty():
		return
	ms[0].select_next()
	ammo_sel = ms[0].sel
	var md := Weapons.mun(ammo_sel)
	if md.has("nuke") and not mission.get("nuclear_release", false):
		hud.message("Flag", "Nuclear release has not been authorised. Weapon locked.", S.ALARM)
		ms[0].select_next()
		ammo_sel = ms[0].sel
	for m in ms:
		if m.ammo.has(ammo_sel):
			m.sel = ammo_sel
	hud.show_hint(Weapons.mun(ammo_sel).get("name", ammo_sel))


func _launch() -> void:
	var ms: Array = _group_mounts()
	if ms.is_empty():
		return
	var md := Weapons.mun(ammo_sel)
	if md.has("nuke") and not mission.get("nuclear_release", false):
		hud.message("Flag", "Nuclear release not authorised.", S.ALARM)
		return
	if md.has("nuke") and bridge != null and not bridge.nuke_armed():
		hud.message("Weapons", "Both release keys must be turned on the special weapons panel (bridge).", S.ALARM)
		return
	var role: String = md.get("role", "")
	var kind: String = md.get("kind", "")
	if kind == "shell":
		firing = true
		get_tree().create_timer(0.6).timeout.connect(func(): firing = false)
		return
	if role == "land" or (role == "ship" and target == null and aim_valid and group == "strike"):
		for m in ms:
			if m.ammo.has(ammo_sel) and m.ready():
				m.sel = ammo_sel
				if w.launch_missile(player, m, null, true, aim_point):
					hud.show_hint("%s away" % md.get("name", ""))
					return
		return
	if target == null:
		hud.show_hint("Designate a target first (T)")
		return
	if role == "sub" and not target.is_sub:
		hud.show_hint("That weapon is for submarines")
		return
	for m in ms:
		if not m.ammo.has(ammo_sel) or not m.ready():
			continue
		m.sel = ammo_sel
		var ok := false
		if kind == "torpedo":
			ok = w.launch_torpedo(player, m, target, true)
		else:
			ok = w.launch_missile(player, m, target, true)
		if ok:
			hud.show_hint("%s away" % md.get("name", ""))
			return
	hud.show_hint("No launcher ready")


func designate() -> void:
	var best = null
	var bs := 1e9
	var fwd := -cam.global_transform.basis.z
	for e in w.units:
		if e.side == player.side or not e.alive() or not w.known_to(player.side, e):
			continue
		var n: Node3D = view.ship_node(e)
		var to: Vector3 = (n.global_position if n else e.pos) - cam.global_position
		var ang := fwd.angle_to(to.normalized())
		var sc := ang * 4.0 + to.length() / 100000.0
		if mode == "bridge" or mode == "map":
			sc = to.length()
		if sc < bs:
			bs = sc
			best = e
	if best != null:
		if best != target:
			fc_q = 0.0
		target = best
		player.target = best
		hud.show_hint("Target: %s, %s" % [best.name, U.km(U.flat_dist(player.pos, best.pos))])
		sfx.play("beep")


func set_target(e) -> void:
	if e != target:
		fc_q = 0.0
	target = e
	player.target = e


# ------------------------------------------------------------------ input
func _unhandled_input(ev: InputEvent) -> void:
	if frozen:
		return
	if ev is InputEventMouseMotion:
		var sens := 0.12 * Settings.mouse_sens * (0.25 if zoom else 1.0)
		var inv := -1.0 if Settings.invert_y else 1.0
		match mode:
			"external":
				orbit_yaw = U.wrap360(orbit_yaw + ev.relative.x * sens)
				orbit_pitch = clampf(orbit_pitch - ev.relative.y * sens * inv * (0.35 if orbit_pitch > -3.0 else 1.0), -60.0, 15.0)
			"sight":
				sight_yaw = U.wrap360(sight_yaw + ev.relative.x * sens * 0.15)
				sight_pitch = clampf(sight_pitch - ev.relative.y * sens * 0.15 * inv, -8.0, 30.0)
			"bridge":
				if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
					look_yaw = clampf(look_yaw + ev.relative.x * sens, -170.0, 170.0)
					look_pitch = clampf(look_pitch - ev.relative.y * sens * inv, -60.0, 50.0)
				elif bridge != null:
					bridge.mouse_move(ev)
		return
	if ev is InputEventMouseButton:
		_mouse_button(ev)
		return
	if not (ev is InputEventKey) or not ev.pressed:
		if ev is InputEventKey and not ev.pressed and ev.keycode == KEY_SPACE:
			pass
		return
	var k: int = ev.keycode
	var shift: bool = ev.shift_pressed
	match k:
		KEY_ESCAPE:
			if mode == "map":
				set_mode(prev_mode)
			elif hud.help:
				hud.help = false
			else:
				pause_requested.emit()
		KEY_F1:
			hud.help = not hud.help
		KEY_V:
			set_mode("external" if mode == "bridge" else ("bridge" if mode == "external" else "external"))
		KEY_B:
			set_mode("sight" if mode != "sight" else prev_mode)
		KEY_M, KEY_TAB:
			set_mode("map" if mode != "map" else prev_mode)
		KEY_W, KEY_UP:
			order_speed(1)
		KEY_S, KEY_DOWN:
			order_speed(-1)
		KEY_A, KEY_LEFT:
			order_rudder(-35.0 if shift else player.rudder_order - 5.0)
		KEY_D, KEY_RIGHT:
			order_rudder(35.0 if shift else player.rudder_order + 5.0)
		KEY_X:
			order_rudder(0.0)
		KEY_C:
			player.steer(player.heading)
			hud.show_hint("Steady as she goes: steer %s" % U.p3(player.heading))
			sfx.play("bell")
		KEY_1:
			_select_group("main")
		KEY_2:
			_select_group("sec")
		KEY_3:
			_select_group("ashm")
		KEY_4:
			_select_group("sam")
		KEY_5:
			_select_group("asw")
		KEY_6:
			_select_group("strike")
		KEY_Z:
			_cycle_ammo()
		KEY_T:
			designate()
		KEY_F:
			director = not director
			hud.show_hint("Director %s" % ("ON: guns follow the fire-control lead" if director else "OFF: guns follow your crosshair"))
		KEY_SPACE, KEY_ENTER:
			_launch()
		KEY_Q:
			w.ad_mode = "hold" if w.ad_mode == "auto" else "auto"
			hud.show_hint("Air defence: %s" % w.ad_mode.to_upper())
		KEY_R:
			player.emcon = not player.emcon
			hud.show_hint("Radars %s" % ("SILENT (EMCON)" if player.emcon else "RADIATING"))
		KEY_G:
			toggle_gq()
		KEY_H:
			sfx.play("horn")
		KEY_PAGEUP:
			if player.is_sub:
				player.depth_order = maxf(0.0, player.depth_order - 10.0)
		KEY_PAGEDOWN:
			if player.is_sub:
				player.depth_order = minf(float(player.cls.get("crush_depth", 450.0)), player.depth_order + 10.0)
		KEY_PERIOD, KEY_EQUAL, KEY_KP_ADD:
			tc = minf(tc * 2.0, 32.0)
		KEY_COMMA, KEY_MINUS, KEY_KP_SUBTRACT:
			tc = maxf(tc * 0.5, 1.0)
		KEY_F11:
			var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _mouse_button(ev: InputEventMouseButton) -> void:
	match mode:
		"external", "sight":
			if ev.button_index == MOUSE_BUTTON_LEFT:
				var ms: Array = _group_mounts()
				if not ms.is_empty() and ms[0].kind == "gun":
					firing = ev.pressed
				elif ev.pressed:
					_launch()
			elif ev.button_index == MOUSE_BUTTON_RIGHT:
				zoom = ev.pressed
			elif ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed and mode == "external":
				orbit_dist = maxf(player.L * 0.6, orbit_dist * 0.88)
			elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed and mode == "external":
				orbit_dist = minf(player.L * 14.0, orbit_dist * 1.14)
		"bridge":
			if bridge != null:
				bridge.mouse_button(ev)
		"map":
			tac.click(ev)


func order_speed(d: int) -> void:
	player.plant.order_step(d)
	sfx.play("telegraph" if not player.plant.is_lever() else "click")


func order_rudder(deg: float) -> void:
	player.set_rudder(clampf(deg, -35.0, 35.0))
	sfx.play("click")


func toggle_gq() -> void:
	gq = not gq
	if gq:
		sfx.play("gq")
		hud.message("1MC", "General quarters, general quarters. All hands man your battle stations." if player.navy == "us"
			else "Боевая тревога! Battle stations!", S.ALARM)
		player.dc_teams += 2
	else:
		player.dc_teams = maxi(2, player.dc_teams - 2)


# ------------------------------------------------------------------ events
func _event(ev: Dictionary) -> void:
	view.handle_event(ev)
	sfx.event(ev, cam.global_position, player)
	match String(ev["t"]):
		"radio":
			hud.message(ev["from"], ev["text"], S.AMBER if ev.get("kind", "") != "story" else S.TEXT)
		"hit":
			var u = ev["unit"]
			if u == player:
				var plate: String = ev.get("plate", "")
				var res: String = ev.get("result", "hit")
				var txt := "We're hit"
				if res == "ricochet" or res == "nopen":
					txt = "Hit on the %s, no penetration" % (plate if plate != "" else "armour")
				elif ev.get("kind", "") == "torpedo":
					txt = "Torpedo hit! Flooding below the waterline"
				elif ev.get("kind", "") == "missile":
					txt = "Missile impact! Fire and damage reported"
				hud.message("Damage control", txt, S.ALARM)
				if not gq:
					toggle_gq()
			elif ev.get("player", false):
				var res: String = ev.get("result", "hit")
				var desc = {"pen": "penetrating hit", "overpen": "overpenetration", "ricochet": "ricochet", "nopen": "hit, no penetration", "hit": "hit"}.get(res, "hit")
				hud.message("Spotter", "%s on %s" % [desc.capitalize(), u.name], S.GOOD)
		"sinking":
			var u = ev["unit"]
			if u == player:
				hud.banner("ABANDON SHIP", 6.0)
			else:
				hud.message("CIC", "%s is sinking!" % u.name, S.GOOD if u.side != player.side else S.ALARM)
				hud.banner("%s SINKING" % u.name.to_upper(), 3.0)
		"contact":
			var u = ev["unit"]
			hud.message("CIC", "New contact: %s, bearing %s, %s" % [u.cls.get("class", "unknown") if not u.is_sub else "submarine", U.p3(U.brg(player.pos, u.pos)), U.km(U.flat_dist(player.pos, u.pos))], S.TEXT)
		"air_contact":
			var a = ev["air"]
			hud.message("CIC", "Air contact: %s, bearing %s" % [a.name(), U.p3(U.brg(player.pos, a.pos))], S.AMBER)
		"launch":
			if ev["unit"].side != player.side and w.known_to(player.side, ev["unit"]):
				hud.message("CIC", "Vampire! Missile launch from %s" % ev["unit"].name, S.ALARM)
		"air_launch":
			if ev["air"].side != player.side:
				hud.message("CIC", "Vampire, vampire! %s launching" % ev["air"].name(), S.ALARM)
		"intercept":
			if ev.get("by") == player:
				hud.message("CIC", "Splash one missile%s" % (" (CIWS)" if ev.get("ciws", false) else ""), S.GOOD)
		"air_kill":
			var a = ev["air"]
			var by = ev.get("by")
			var who := "Friendly fighters" if by is SimAir else ("Our missiles" if by == player else "Escorts")
			if by is SimAir and by.friendly_callsign != "":
				who = by.friendly_callsign
			hud.message(who, "Splash one %s" % a.name(), S.GOOD if a.side != player.side else S.ALARM)
		"objective":
			var o: Dictionary = ev["obj"]
			hud.message("Fleet", ("Objective complete: " if ev["state"] == "done" else "Objective failed: ") + String(o["text"]), S.GOOD if ev["state"] == "done" else S.ALARM)
		"ground_destroyed":
			hud.message("Spotter", "Target destroyed: %s" % ev["ground"]["name"], S.GOOD)
		"magazine":
			hud.banner("MAGAZINE EXPLOSION", 4.0)
		"nuke":
			hud.banner("NUCLEAR DETONATION", 6.0)
		"aground":
			if ev["unit"] == player:
				hud.message("Navigator", "We've run aground!", S.ALARM)
		"mission_end":
			ended = true
			result = ev["result"]
			hud.banner("MISSION ACCOMPLISHED" if result == "won" else "MISSION FAILED", 8.0)
			hud.message("Fleet", ev["why"], S.GOOD if result == "won" else S.ALARM)
			get_tree().create_timer(6.0).timeout.connect(func(): finished.emit(result, w.stats))


func shutdown() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
