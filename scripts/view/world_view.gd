extends Node3D
## Draws the simulation: ships riding the waves, turrets, radars, recoil,
## smoke, wakes and fires; aircraft; missiles, shells and torpedoes; effects.

const U := preload("res://scripts/util.gd")
const ShipBuilder := preload("res://scripts/build/ship_builder.gd")
const SubBuilder := preload("res://scripts/build/sub_builder.gd")
const AirBuilder := preload("res://scripts/build/air_builder.gd")
const Fx := preload("res://scripts/view/fx.gd")
const WAKE := preload("res://shaders/wake.gdshader")

var w
var ocean
var atm
var fx
var ships := {}
var airs := {}
var mis := {}
var cam_pos := Vector3.ZERO
var wake_mat: ShaderMaterial
var shell_mm: MultiMeshInstance3D
var t := 0.0
var night := false


func setup(world, ocean_node, atm_node) -> void:
	w = world
	ocean = ocean_node
	atm = atm_node
	fx = Fx.new()
	add_child(fx)
	wake_mat = ShaderMaterial.new()
	wake_mat.shader = WAKE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 0
	var bm := BoxMesh.new()
	bm.size = Vector3(0.18, 0.18, 1.0)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(1.0, 0.75, 0.4)
	sm.emission_enabled = true
	sm.emission = Color(1.0, 0.6, 0.3)
	sm.emission_energy_multiplier = 4.0
	bm.material = sm
	mm.mesh = bm
	shell_mm = MultiMeshInstance3D.new()
	shell_mm.multimesh = mm
	shell_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell_mm)
	for u in w.units:
		add_ship(u)


func add_ship(u) -> void:
	var node: Node3D = SubBuilder.build(u.cls_id) if u.is_sub else ShipBuilder.build(u.cls_id)
	add_child(node)
	var rec := {"u": u, "node": node, "mounts": node.get_meta("mounts"), "radars": node.get_meta("radars"),
		"smoke": [], "fires": {}, "roll": 0.0, "roll_v": 0.0, "pitch": 0.0, "pitch_v": 0.0, "heave": 0.0,
		"recoil": {}, "wake": [], "wake_t": 0.0, "lights": [], "hidden": false}
	if not u.is_sub:
		var dark: bool = u.cls["plant"]["kind"] == "steam" or u.cls["plant"]["kind"] == "diesel"
		for s in node.get_meta("smoke"):
			rec["smoke"].append(fx.funnel_smoke(node, s, dark, clampf(u.L / 120.0, 0.8, 2.2)))
		for l in node.get_meta("lights"):
			var ol := OmniLight3D.new()
			ol.light_color = {"red": Color(1, 0.1, 0.05), "green": Color(0.1, 1, 0.3)}.get(l[1], Color(1, 0.95, 0.85))
			ol.light_energy = 1.2
			ol.omni_range = 12.0
			ol.position = l[0]
			ol.visible = false
			node.add_child(ol)
			rec["lights"].append(ol)
	var wm := MeshInstance3D.new()
	wm.mesh = ImmediateMesh.new()
	wm.material_override = wake_mat
	wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wm.extra_cull_margin = 5000.0
	add_child(wm)
	rec["wake_mi"] = wm
	ships[u.uid] = rec


func ship_node(u) -> Node3D:
	var r: Dictionary = ships.get(u.uid, {})
	return r.get("node", null)


func set_night(n: bool) -> void:
	night = n
	for uid in ships:
		for l in ships[uid]["lights"]:
			l.visible = n


# ------------------------------------------------------------------ per frame
## Frames are drawn between the last two simulation steps: alpha is how far
## (0..1) and step_dt how long a step is. The simulation runs at a fixed 30 Hz;
## without this, ships, the camera riding them and everything else would jump
## on step frames and stand still on the others.
var alpha := 1.0
var step_dt := 1.0 / 30.0


## Called before every simulation step: where each ship was.
func snapshot() -> void:
	for uid in ships:
		var r: Dictionary = ships[uid]
		r["p0"] = r["u"].pos
		r["h0"] = r["u"].heading


func sync(dt: float, camera_pos: Vector3) -> void:
	t += dt
	cam_pos = camera_pos
	wake_mat.set_shader_parameter("t", ocean.t)
	wake_mat.set_shader_parameter("amp", ocean.amp)
	wake_mat.set_shader_parameter("choppy", ocean.choppy)
	wake_mat.set_shader_parameter("wind", ocean.wind)
	for uid in ships:
		_sync_ship(ships[uid], dt)
	_sync_air(dt)
	_sync_muns(dt)
	fx.update(dt)


func _osc(x: float, v: float, target: float, period: float, zeta: float, dt: float) -> Array:
	var wn := TAU / maxf(period, 0.5)
	var a := (target - x) * wn * wn - 2.0 * zeta * wn * v
	v += a * dt
	x += v * dt
	return [x, v]


func _sync_ship(r: Dictionary, dt: float) -> void:
	var u = r["u"]
	var node: Node3D = r["node"]
	if u.sunk:
		if not r["hidden"]:
			node.visible = false
			r["hidden"] = true
			r["wake_mi"].visible = false
		return
	var p0: Vector3 = r.get("p0", u.pos)
	var h0: float = r.get("h0", u.heading)
	var p: Vector3 = p0.lerp(u.pos, alpha)
	var hdg: float = h0 + wrapf(u.heading - h0, -180.0, 180.0) * alpha
	var f: Vector3 = U.fwd(hdg)
	var side_v := Vector3(-f.z, 0, f.x)
	var L: float = u.L
	var B: float = u.B
	var hb: float = ocean.height(p.x + f.x * L * 0.4, p.z + f.z * L * 0.4)
	var hs: float = ocean.height(p.x - f.x * L * 0.4, p.z - f.z * L * 0.4)
	var hp: float = ocean.height(p.x - side_v.x * B * 0.5, p.z - side_v.z * B * 0.5)
	var hst: float = ocean.height(p.x + side_v.x * B * 0.5, p.z + side_v.z * B * 0.5)
	var hc: float = ocean.height(p.x, p.z)
	var heave_t := (hb + hs + hp + hst + hc * 2.0) / 6.0
	var size := clampf(L / 120.0, 0.6, 2.3)
	r["heave"] = lerpf(r["heave"], heave_t, clampf(dt * 1.6 / size, 0.0, 1.0))
	var pt := rad_to_deg(atan2(hb - hs, L * 0.8)) * 0.8
	var rt := rad_to_deg(atan2(hst - hp, B)) * 0.9
	var pr := _osc(r["pitch"], r["pitch_v"], pt, 4.0 + L * 0.02, 0.45, dt)
	r["pitch"] = pr[0]
	r["pitch_v"] = pr[1]
	var rr := _osc(r["roll"], r["roll_v"], rt, 6.0 + B * 0.28, 0.12, dt)
	r["roll"] = rr[0]
	r["roll_v"] = rr[1]
	var y: float = r["heave"]
	var roll: float = r["roll"] + u.heel
	var pitch: float = r["pitch"] - u.trim_deg
	if u.is_sub:
		y = -u.depth + (r["heave"] * 0.6 if u.depth < 12.0 else 0.0)
		pitch = u.pitch_deg + (r["pitch"] * 0.5 if u.depth < 12.0 else 0.0)
		roll = u.heel * 0.6 + (r["roll"] * 0.4 if u.depth < 12.0 else 0.0)
		var masts: Node3D = node.get_meta("masts")
		masts.visible = u.depth < 22.0
		var prop: Node3D = node.get_meta("prop")
		prop.rotation.z += u.plant.rpm[0] * 12.0 * dt
	if u.sinking:
		var st: float = u.sink_t
		y -= st * st * 0.004 * (1.0 + 30.0 / maxf(L, 30.0))
		roll += clampf(st * 0.25, 0.0, 35.0) * signf(u.list_deg + 0.01)
		pitch += clampf(st * 0.08, 0.0, 12.0) * signf(u.trim_deg + 0.01)
	y -= U.curvature_drop(U.flat_dist(p, cam_pos))
	node.position = Vector3(p.x, y, p.z)
	node.rotation = Vector3(deg_to_rad(pitch), U.yaw(hdg), deg_to_rad(roll))
	# Turrets, launchers and recoil.
	var mounts: Dictionary = r["mounts"]
	for m in u.mounts:
		var mi: Dictionary = mounts.get(m.id, {})
		if mi.is_empty():
			continue
		var tn: Node3D = mi["node"]
		if not m.fixed:
			tn.rotation.y = -deg_to_rad(m.train)
		var el: Node3D = mi["elev"]
		if el != null:
			el.rotation.x = deg_to_rad(m.elev)
		var rc: float = r["recoil"].get(m.id, 0.0)
		if rc > 0.0:
			rc = maxf(0.0, rc - dt)
			r["recoil"][m.id] = rc
			var back := (rc / 0.7) * (1.2 if m.barrels > 1 and m.md.get("ammo", [""])[0].begins_with("406") else 0.6)
			for bn in mi["recoil"]:
				bn.position.z = back * (1.0 if rc > 0.55 else rc / 0.55)
	for rd in r["radars"]:
		var n: Node3D = rd[0]
		if rd[1] > 0.0:
			if not u.emcon and u.mod_hp("radar") > 0.1:
				n.rotation.y += rd[1] / 60.0 * TAU * dt
		elif u.target != null and is_instance_valid_target(u.target):
			var want := -deg_to_rad(U.adiff(u.heading, U.brg(u.pos, u.target.pos)))
			n.rotation.y = lerp_angle(n.rotation.y, want, clampf(dt * 2.0, 0.0, 1.0))
	_fires(r)
	_wake(r, dt)


func is_instance_valid_target(tg) -> bool:
	return tg != null and (tg.alive() if tg is SimUnit else tg.alive)


func _fires(r: Dictionary) -> void:
	var u = r["u"]
	var node: Node3D = r["node"]
	for i in u.NCOMP:
		var on: bool = u.fire[i] > 0.12 or (u.sinking and i % 4 == 1)
		var have: bool = r["fires"].has(i)
		if on and not have:
			var x: float = (i + 0.5) / u.NCOMP * u.L
			var lp := Vector3(0, u.deck_h() + 1.0, x - u.L * 0.5)
			r["fires"][i] = fx.fire_column(node, lp, clampf(u.L / 130.0, 0.6, 1.8))
		elif not on and have:
			for e in r["fires"][i]:
				e.queue_free()
			r["fires"].erase(i)


func _wake(r: Dictionary, dt: float) -> void:
	var u = r["u"]
	var pts: Array = r["wake"]
	var mi: MeshInstance3D = r["wake_mi"]
	var spd: float = absf(u.speed)
	r["wake_t"] -= dt
	var bow: Vector3 = u.pos - u.fwd() * u.L * 0.42
	if u.is_sub and u.depth > 15.0:
		spd = 0.0
	if r["wake_t"] <= 0.0:
		r["wake_t"] = 0.5
		pts.push_front([bow, t, spd])
		while pts.size() > 90:
			pts.pop_back()
	var im: ImmediateMesh = mi.mesh
	im.clear_surfaces()
	if pts.size() < 2 or U.flat_dist(u.pos, cam_pos) > 9000.0:
		return
	var life := 45.0
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var list := [[bow, t, spd]] + pts
	var prev: Vector3 = list[0][0]
	for i in list.size():
		var e: Array = list[i]
		var age := clampf((t - float(e[1])) / life, 0.0, 1.0)
		var pos: Vector3 = e[0]
		var dir: Vector3 = (prev - pos) if i > 0 else u.fwd()
		dir.y = 0.0
		if dir.length() < 0.01:
			dir = u.fwd()
		dir = dir.normalized()
		var sv := Vector3(-dir.z, 0, dir.x)
		var width: float = u.B * 0.5 + (t - float(e[1])) * float(e[2]) * 0.354
		var strength := clampf(float(e[2]) / (8.0 * U.KN), 0.0, 1.0)
		var c := Color(1, 1, 1, strength)
		im.surface_set_color(c)
		im.surface_set_uv(Vector2(-1.0, age))
		im.surface_add_vertex(pos - sv * width)
		im.surface_set_color(c)
		im.surface_set_uv(Vector2(1.0, age))
		im.surface_add_vertex(pos + sv * width)
		prev = pos
		if age >= 1.0:
			break
	im.surface_end()


func _sync_air(dt: float) -> void:
	for a in w.air:
		var rec: Dictionary = airs.get(a.uid, {})
		if rec.is_empty():
			if not a.alive:
				continue
			var n := AirBuilder.aircraft(a.type)
			add_child(n)
			rec = {"node": n, "a": a}
			airs[a.uid] = rec
		var n: Node3D = rec["node"]
		if not a.alive:
			if n.visible:
				n.visible = false
			continue
		var pos: Vector3 = a.pos - a.vel * (1.0 - alpha) * step_dt
		pos.y -= U.curvature_drop(U.flat_dist(pos, cam_pos))
		n.position = pos
		n.rotation = Vector3(0.0, U.yaw(a.heading), deg_to_rad(-a.bank))
		if n.has_meta("rotor"):
			n.get_meta("rotor").rotation.y += 25.0 * dt


func _sync_muns(dt: float) -> void:
	var shells := []
	var seen := {}
	for m in w.muns:
		if not m.alive:
			continue
		if m.kind == "shell":
			if float(m.md.get("cal", 0)) >= 100.0 and m.pos.distance_to(cam_pos) < 30000.0:
				shells.append(m)
			continue
		seen[m.uid] = true
		var rec: Dictionary = mis.get(m.uid, {})
		if rec.is_empty():
			var n: Node3D
			if m.kind == "missile":
				n = AirBuilder.missile(m.mid, float(m.md.get("len", 4.0)), float(m.md.get("dia", 0.3)))
				add_child(n)
				fx.missile_trail(n, float(m.md.get("len", 4.0)) > 6.0)
			elif m.kind == "torpedo":
				n = Node3D.new()
				add_child(n)
				var tr = fx.missile_trail(n, false)
				tr[0].visible = false
				tr[2].visible = false
				var pm: ParticleProcessMaterial = tr[1].process_material
				pm.gravity = Vector3.ZERO
			else:
				n = Node3D.new()
				add_child(n)
			rec = {"node": n}
			mis[m.uid] = rec
		var node: Node3D = rec["node"]
		var pos: Vector3 = m.pos - m.vel * (1.0 - alpha) * step_dt
		if m.kind == "torpedo":
			pos.y = 0.2 if m.depth < 20.0 else -40.0
		pos.y -= U.curvature_drop(U.flat_dist(pos, cam_pos))
		node.position = pos
		if m.vel.length() > 1.0:
			var tgt: Vector3 = pos + m.vel.normalized()
			if absf(m.vel.normalized().y) < 0.99:
				node.look_at(tgt, Vector3.UP)
	for uid in mis.keys():
		if not seen.has(uid):
			var n: Node3D = mis[uid]["node"]
			for c in n.get_children():
				if c is GPUParticles3D:
					c.emitting = false
			mis.erase(uid)
			get_tree().create_timer(6.0).timeout.connect(n.queue_free)
	var mm := shell_mm.multimesh
	mm.instance_count = shells.size()
	for i in shells.size():
		var s = shells[i]
		var v: Vector3 = s.vel
		var len := clampf(v.length() * 0.025, 2.0, 18.0)
		var b := Basis.looking_at(v.normalized(), Vector3.UP if absf(v.normalized().y) < 0.99 else Vector3.RIGHT)
		b = b.scaled(Vector3(1.0 + float(s.md.get("cal", 100)) / 200.0, 1.0 + float(s.md.get("cal", 100)) / 200.0, len))
		var pos: Vector3 = s.pos - v * (1.0 - alpha) * step_dt
		pos.y -= U.curvature_drop(U.flat_dist(pos, cam_pos))
		mm.set_instance_transform(i, Transform3D(b, pos))


# ------------------------------------------------------------------ events
func handle_event(ev: Dictionary) -> void:
	match String(ev["t"]):
		"fire":
			var u = ev["unit"]
			var m = ev["mount"]
			var r: Dictionary = ships.get(u.uid, {})
			if r.is_empty():
				return
			var mi: Dictionary = r["mounts"].get(m.id, {})
			r["recoil"][m.id] = 0.7
			if mi.is_empty() or mi["elev"] == null:
				fx.muzzle(ev["pos"], u.fwd(), float(ev["cal"]))
				return
			var el: Node3D = mi["elev"]
			var dirv: Vector3 = -el.global_transform.basis.z
			for mz in mi["muzzles"]:
				fx.muzzle(el.to_global(mz), dirv, float(ev["cal"]))
		"splash":
			fx.splash(ev["pos"], float(ev.get("size", 1.0)))
		"hit":
			var sz := 1.0
			match String(ev.get("kind", "shell")):
				"shell": sz = clampf(float(ev.get("cal", 100)) / 120.0, 0.4, 4.0)
				"missile": sz = 4.0
				"torpedo":
					sz = 5.0
					fx.splash(ev["pos"], 4.5)
				"depth": sz = 0.0
			if sz > 0.0:
				fx.explosion(ev["pos"], sz)
		"launch", "sam_launch", "air_launch":
			fx.launch_plume(ev["pos"], ev["t"] == "sam_launch" or ev.get("mount", null) != null and ev["mount"].kind == "vls")
		"intercept", "air_kill":
			fx.air_burst(ev["pos"], 1.5 if ev["t"] == "air_kill" else 1.0)
		"ciws":
			var a: Vector3 = ev["pos"]
			var b: Vector3 = ev["target"]
			for i in 3:
				var j := Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
				fx.tracer(a.lerp(b, randf() * 0.3), a.lerp(b + j, 0.6 + randf() * 0.4))
		"depth_bomb":
			fx.depth_bomb(ev["pos"], float(ev.get("size", 1.0)))
		"ground_hit":
			fx.ground_hit(ev["pos"], float(ev.get("size", 1.0)))
		"ground_destroyed":
			fx.explosion(ev["pos"] + Vector3(0, 5, 0), 3.5)
		"magazine":
			fx.explosion(ev["pos"], 8.0)
			fx.explosion(ev["pos"] + Vector3(0, 30, 0), 6.0)
		"nuke":
			fx.nuke(ev["pos"], float(ev["r"]))
		"battery_fire":
			fx.muzzle(ev["pos"] + Vector3(0, 5, 0), Vector3.UP, 152.0)
		"torpedo_launch":
			fx.splash(Vector3(ev["pos"].x, 0, ev["pos"].z), 0.6)
