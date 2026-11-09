extends RefCounted
## The player's bridge: a walk-in pilothouse attached to the ship model with
## working controls. Drag the helm wheel, telegraph handles and throttle levers,
## click buttons and switches; gauges, indicators and screens are live.
##
## Styles: us_modern (gas-turbine ship control console), us_battleship (brass
## wheel and pedestal telegraphs), su (Soviet console), su_old (1950s cruiser).

const U := preload("res://scripts/util.gd")
const MeshKit := preload("res://scripts/build/mesh_kit.gd")
const Mats := preload("res://scripts/build/materials.gd")
const Screens := preload("res://scripts/bridge/screens.gd")

var g
var u
var ship_node: Node3D
var root: Node3D
var style := "us_modern"
var su := false
var W := 10.0
var D := 7.0
var H := 2.9
var rake := 0.0
var mats := {}
var controls := []
var hover = null
var dragging = null
var drag_acc := 0.0
var head := Vector3(0.6, 1.72, 3.4)
var anim := {}
var nuke_keys := [false, false]
var nuke_cover := false
var lights_on := false
var shell: Node3D
var active := false
var screens := []


func setup(game, unit, node: Node3D) -> void:
	g = game
	u = unit
	ship_node = node
	var br: Dictionary = node.get_meta("bridge")
	style = u.cls.get("bridge", {}).get("style", "us_modern")
	su = style.begins_with("su")
	W = float(br.get("w", 10.0))
	D = float(br.get("z1", 8.0)) - float(br.get("z0", 0.0))
	H = float(br.get("h", 2.9))
	rake = float(br.get("rake", 0.0))
	root = Node3D.new()
	root.name = "BridgeInterior"
	root.position = Vector3(0, float(br.get("y", 10.0)), float(br.get("z0", 0.0)))
	node.add_child(root)
	shell = node.get_node_or_null("BridgeShell")
	_materials()
	_build_room()
	match style:
		"us_battleship", "su_old":
			_build_pilothouse()
		_:
			_build_console()
	_build_common()
	head = Vector3(0.0, 1.72, clampf(D * 0.55, 2.6, 4.2))
	root.visible = false


func set_active(on: bool) -> void:
	active = on
	root.visible = on
	if shell:
		shell.visible = not on
	for s in screens:
		s.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func head_transform() -> Transform3D:
	return root.global_transform * Transform3D(Basis.IDENTITY, head)


func nuke_armed() -> bool:
	return nuke_keys[0] and nuke_keys[1]


# ------------------------------------------------------------------ materials
func _materials() -> void:
	var c := Mats.common()
	mats = c.duplicate()
	var console := Color(0.46, 0.5, 0.52) if not su else Color(0.5, 0.58, 0.54)
	var panel := Color(0.16, 0.18, 0.19) if not su else Color(0.36, 0.42, 0.39)
	if style == "us_battleship" or style == "su_old":
		console = Color(0.42, 0.45, 0.46) if not su else Color(0.48, 0.55, 0.52)
	mats["console"] = Mats.std(console, 0.55, 0.15)
	mats["panel"] = Mats.std(panel, 0.6, 0.1)
	mats["wall"] = Mats.std(Color(0.78, 0.79, 0.76) if not su else Color(0.72, 0.78, 0.74), 0.8)
	mats["ceiling"] = Mats.std(Color(0.85, 0.85, 0.82), 0.85)
	mats["floor"] = Mats.std(Color(0.12, 0.14, 0.13) if not su else Color(0.32, 0.2, 0.14), 0.7)
	if style == "us_battleship":
		mats["floor"] = Mats.std(Color(0.42, 0.33, 0.24), 0.6)
	mats["glass_in"] = _glass()
	mats["dial"] = Mats.std(Color(0.93, 0.92, 0.86), 0.5)
	mats["dial_dark"] = Mats.std(Color(0.04, 0.045, 0.05), 0.4)
	mats["needle"] = Mats.std(Color(0.9, 0.1, 0.05), 0.4, 0.0, Color(0.9, 0.1, 0.05), 0.3)
	mats["needle_w"] = Mats.std(Color(0.95, 0.95, 0.9), 0.4)
	mats["wood"] = Mats.std(Color(0.42, 0.26, 0.14), 0.45)
	mats["leather"] = Mats.std(Color(0.12, 0.08, 0.06), 0.5)
	mats["lit_g"] = Mats.std(Color(0.2, 0.9, 0.3), 0.3, 0.0, Color(0.2, 1.0, 0.3), 2.5)
	mats["lit_a"] = Mats.std(Color(1.0, 0.7, 0.2), 0.3, 0.0, Color(1.0, 0.65, 0.15), 2.5)
	mats["lit_r"] = Mats.std(Color(1.0, 0.2, 0.15), 0.3, 0.0, Color(1.0, 0.15, 0.1), 2.5)
	mats["unlit"] = Mats.std(Color(0.15, 0.16, 0.16), 0.3)
	mats["red_cap"] = Mats.std(Color(0.75, 0.08, 0.06), 0.35)
	mats["yellow_black"] = Mats.std(Color(0.9, 0.75, 0.1), 0.5)
	mats["lamp"] = Mats.std(Color(1, 0.95, 0.85), 0.4, 0.0, Color(1, 0.95, 0.85), 1.5)
	mats["redlamp"] = Mats.std(Color(1, 0.2, 0.1), 0.4, 0.0, Color(1, 0.15, 0.08), 1.2)


func _glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.7, 0.75, 0.08)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.2
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _kit() -> MeshKit:
	return MeshKit.new(mats)


func _add(kt: MeshKit, parent: Node3D = null, name := "Mesh") -> MeshInstance3D:
	var mi := kt.instance(name)
	if mi:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		(parent if parent else root).add_child(mi)
	return mi


func _node(name: String, pos: Vector3, parent: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	(parent if parent else root).add_child(n)
	return n


func _label(text: String, pos: Vector3, size := 0.05, col := Color(0.92, 0.92, 0.88), parent: Node3D = null,
		rot := Vector3.ZERO, center := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.pixel_size = size / 48.0
	l.modulate = col
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	l.position = pos
	l.rotation = rot
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	(parent if parent else root).add_child(l)
	return l


## Register an interactive control. box is a local AABB in `node` space.
func _control(id: String, kind: String, node: Node3D, box: AABB, tip: String, data := {}) -> Dictionary:
	var c := {"id": id, "kind": kind, "node": node, "box": box, "tip": tip}
	for k in data:
		c[k] = data[k]
	controls.append(c)
	return c


# ------------------------------------------------------------------ room
func _build_room() -> void:
	var k := _kit()
	var hw := W * 0.5
	var old := style == "us_battleship" or style == "su_old"
	k.box("floor", Vector3(0, -0.05, D * 0.5), Vector3(W, 0.1, D))
	k.box("ceiling", Vector3(0, H + 0.05, D * 0.5), Vector3(W, 0.1, D))
	var sill := 1.1
	var top := H - 0.35
	var r := rake
	# Front wall: bulkhead below, window band, header.
	k.box("wall", Vector3(0, sill * 0.5, 0.05), Vector3(W, sill, 0.1))
	k.quad_dir("wall", Vector3(-hw, top, r * (top / H)), Vector3(hw, top, r * (top / H)), Vector3(hw, H, r), Vector3(-hw, H, r), Vector3(0, 0, 1))
	var nwin := int(W / (1.15 if not old else 0.95))
	var pane := W / nwin
	for i in nwin + 1:
		var x := -hw + i * pane
		k.bar("wall", Vector3(x, sill, 0.0), Vector3(x, top, r * (top / H)), 0.09 if not old else 0.16)
	var gl := _kit()
	gl.quad_dir("glass_in", Vector3(-hw, sill, 0.0), Vector3(hw, sill, 0.0), Vector3(hw, top, r * (top / H)), Vector3(-hw, top, r * (top / H)), Vector3(0, 0, 1))
	# Sides: windows forward, doors to the wings, solid aft.
	var win_d := minf(D * 0.55, 4.5)
	for s: float in [-1.0, 1.0]:
		var x := s * hw
		k.quad_dir("wall", Vector3(x, 0, 0), Vector3(x, 0, D), Vector3(x, sill, D), Vector3(x, sill, 0), Vector3(-s, 0, 0))
		k.quad_dir("wall", Vector3(x, top, 0), Vector3(x, top, D), Vector3(x, H, D), Vector3(x, H, 0), Vector3(-s, 0, 0))
		k.quad_dir("wall", Vector3(x, sill, win_d + 1.2), Vector3(x, sill, D), Vector3(x, top, D), Vector3(x, top, win_d + 1.2), Vector3(-s, 0, 0))
		for i in int(win_d / 1.2) + 1:
			k.bar("wall", Vector3(x, sill, i * 1.2), Vector3(x, top, i * 1.2), 0.08)
		gl.quad_dir("glass_in", Vector3(x, sill, 0), Vector3(x, sill, win_d), Vector3(x, top, win_d), Vector3(x, top, 0), Vector3(-s, 0, 0))
		# Door frame (open door to the bridge wing).
		k.box("console", Vector3(x - s * 0.04, sill * 0.5 + 0.4, win_d + 0.6), Vector3(0.08, 2.0, 0.08))
		gl.quad_dir("glass_in", Vector3(x, sill, win_d), Vector3(x, sill, win_d + 1.2), Vector3(x, top, win_d + 1.2), Vector3(x, top, win_d), Vector3(-s, 0, 0))
	k.box("wall", Vector3(0, H * 0.5, D - 0.05), Vector3(W, H, 0.1))
	k.box("panel", Vector3(-W * 0.3, 1.0, D - 0.12), Vector3(0.9, 2.0, 0.06))
	k.box("chrome", Vector3(-W * 0.3 + 0.35, 1.0, D - 0.16), Vector3(0.05, 0.25, 0.05))
	# Deckhead details: cable trays, lights.
	for x: float in [-hw * 0.6, 0.0, hw * 0.6]:
		k.box("panel", Vector3(x, H - 0.06, D * 0.5), Vector3(0.3, 0.08, D - 0.4))
	for i in 3:
		var z := D * (0.3 + i * 0.25)
		k.box("lamp" if not lights_on else "lamp", Vector3(-hw * 0.3, H - 0.04, z), Vector3(0.9, 0.04, 0.2))
		k.box("redlamp", Vector3(hw * 0.3, H - 0.04, z), Vector3(0.3, 0.04, 0.15))
	# Forward console under the windows.
	k.box("console", Vector3(0, 0.5, 0.42), Vector3(W - 0.4, 1.0, 0.7))
	k.quad_dir("panel", Vector3(-hw + 0.25, 1.0, 0.1), Vector3(hw - 0.25, 1.0, 0.1), Vector3(hw - 0.25, 1.02, 0.75), Vector3(-hw + 0.25, 1.02, 0.75), Vector3.UP)
	_add(k)
	var gm := _add(gl, null, "Glass")
	if gm:
		gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Interior lighting: soft day lights; red at night handled in update.
	var l := OmniLight3D.new()
	l.position = Vector3(0, H - 0.4, D * 0.5)
	l.omni_range = maxf(W, D) * 1.1
	l.light_energy = 1.1
	l.light_color = Color(1.0, 0.95, 0.88)
	l.shadow_enabled = false
	root.add_child(l)
	anim["room_light"] = l


# ------------------------------------------------------------------ modern console bridge
func _build_console() -> void:
	var k := _kit()
	var cz := 1.9
	var cw := 2.6
	# Ship control console: angled top, kick plate.
	k.hexa("console", [Vector3(-cw * 0.5, 0, cz - 0.4), Vector3(cw * 0.5, 0, cz - 0.4), Vector3(cw * 0.5, 0, cz + 0.35), Vector3(-cw * 0.5, 0, cz + 0.35),
		Vector3(-cw * 0.5, 1.15, cz - 0.4), Vector3(cw * 0.5, 1.15, cz - 0.4), Vector3(cw * 0.5, 0.95, cz + 0.35), Vector3(-cw * 0.5, 0.95, cz + 0.35)])
	k.hexa("panel", [Vector3(-cw * 0.5 + 0.05, 0.96, cz + 0.33), Vector3(cw * 0.5 - 0.05, 0.96, cz + 0.33), Vector3(cw * 0.5 - 0.05, 1.14, cz - 0.38), Vector3(-cw * 0.5 + 0.05, 1.14, cz - 0.38),
		Vector3(-cw * 0.5 + 0.05, 0.97, cz + 0.34), Vector3(cw * 0.5 - 0.05, 0.97, cz + 0.34), Vector3(cw * 0.5 - 0.05, 1.15, cz - 0.37), Vector3(-cw * 0.5 + 0.05, 1.15, cz - 0.37)])
	k.box("console", Vector3(0, 1.45, cz - 0.38), Vector3(cw, 0.62, 0.12))
	k.box("panel", Vector3(0, 1.45, cz - 0.31), Vector3(cw - 0.1, 0.55, 0.02))
	_add(k)
	var slope := atan2(0.2, 0.75)
	var top_basis := Basis(Vector3.RIGHT, slope)
	var panel_c := Vector3(0, 1.06, cz)
	# Helm wheel on the console front (facing aft toward the helmsman).
	var wheel_c := Vector3(-0.55, 1.12, cz + 0.42)
	_wheel(wheel_c, 0.24, 6, false, Vector3(0, 0, 1))
	_label("HELM" if not su else "ШТУРВАЛ", wheel_c + Vector3(0, -0.31, 0.02), 0.04, Color(0.9, 0.9, 0.85), null, Vector3(0, 0, 0))
	# Rudder angle and order indicator on the upright panel.
	_dial("rudder", Vector3(-0.55, 1.5, cz - 0.30), 0.2, -35.0, 35.0, [-30, -20, -10, 0, 10, 20, 30], "RUDDER" if not su else "РУЛЬ", true, true)
	_dial("gyro", Vector3(0.05, 1.5, cz - 0.30), 0.2, 0.0, 360.0, [], "GYRO" if not su else "ГИРОКОМПАС", false, false, true)
	# Throttles / telegraph levers on the right.
	var sh: int = u.plant.shafts
	if u.plant.is_lever():
		for s in sh:
			var x := 0.45 + s * 0.32
			_throttle(s, Vector3(x, 1.1, cz - 0.02), top_basis)
		_label("PROGRAMMED CONTROL" if sh > 0 else "", Vector3(0.45 + (sh - 1) * 0.16, 1.21, cz - 0.38), 0.035, Color(0.9, 0.9, 0.85))
		for s in sh:
			_dial("rpm%d" % s, Vector3(0.62 + s * 0.42 - (0.2 if sh == 1 else 0.0), 1.5, cz - 0.30), 0.13, 0.0, u.plant.max_rpm, [0, 50, 100, 150], ("SHAFT %d RPM" % (s + 1)) if sh > 1 else "SHAFT RPM", false, false)
	else:
		for s in sh:
			var x := 0.4 + s * 0.34
			_telegraph_lever(s, Vector3(x, 1.08, cz), top_basis)
		for s in sh:
			_dial("rpm%d" % s, Vector3(0.62 + s * 0.42 - (0.2 if sh == 1 else 0.0), 1.5, cz - 0.30), 0.13, 0.0, u.plant.max_rpm, [0, 100, 200], ("ОБ/МИН %d" % (s + 1)) if su else "RPM %d" % (s + 1), false, false)
	# Course knob and autopilot switch.
	var kn := _node("course_knob", panel_c + top_basis * Vector3(-1.05, 0.03, 0.05))
	var kk := _kit()
	kk.cyl("dark", Vector3.ZERO, Vector3(0, 0.05, 0), 0.05, 0.045, 14)
	kk.box("needle_w", Vector3(0, 0.052, -0.025), Vector3(0.008, 0.004, 0.04))
	_add(kk, kn)
	kn.basis = top_basis
	_control("course", "knob", kn, AABB(Vector3(-0.06, 0, -0.06), Vector3(0.12, 0.08, 0.12)), "Ordered course knob: wheel or drag (helmsman steers it)")
	anim["course_knob"] = kn
	_label("COURSE" if not su else "КУРС", kn.position + Vector3(0, 0.09, 0.02), 0.03)
	var sw := _switch("autopilot", panel_c + top_basis * Vector3(-0.85, 0.02, 0.12), "Helmsman: steer ordered course / hand steering", top_basis)
	_label("AUTO" if not su else "АВТО", sw.position + Vector3(0, 0.07, 0.02), 0.028)
	if u.plant.has_apu:
		var ab := _button("apu", panel_c + top_basis * Vector3(-0.2, 0.02, 0.18), "Auxiliary propulsion units (lower/raise)", "lit_a", top_basis)
		_label("APU", ab.position + Vector3(0, 0.06, 0.02), 0.028)
	# Plant start/stop buttons on the console top (gas turbines) or engineering panel.
	_plant_panel(Vector3(0, 0, 0), true, panel_c, top_basis)


# ------------------------------------------------------------------ pilothouse (battleship / old cruiser)
func _build_pilothouse() -> void:
	var cz := 2.1
	# Pedestal with the big wheel; binnacle ahead of it.
	var k := _kit()
	k.cyl("wood", Vector3(0, 0, cz + 0.35), Vector3(0, 1.0, cz + 0.35), 0.18, 0.14, 12)
	k.box("brass", Vector3(0, 1.08, cz + 0.35), Vector3(0.32, 0.18, 0.32))
	k.cyl("brass", Vector3(0, 0, cz - 0.55), Vector3(0, 1.0, cz - 0.55), 0.22, 0.2, 14)
	k.sphere("brass", Vector3(0, 1.08, cz - 0.55), 0.24, 14, 8, Vector3(1, 0.6, 1))
	_add(k)
	_wheel(Vector3(0, 1.22, cz + 0.55), 0.62, 8, true, Vector3(0, 0, 1))
	var gyro := _dial("gyro", Vector3(0, 1.25, cz - 0.55), 0.17, 0.0, 360.0, [], "", false, false, true, Vector3(0, 0.9, 0.45).normalized())
	_dial("rudder", Vector3(0, H - 0.45, 0.65), 0.28, -35.0, 35.0, [-30, -20, -10, 0, 10, 20, 30], "RUDDER ANGLE" if not su else "АКСИОМЕТР", true, true, false, Vector3(0, -0.3, 1).normalized())
	# Telegraph pedestals on the port side, one per shaft.
	var sh: int = u.plant.shafts
	for s in sh:
		var x := -1.4 - s * 0.62
		_telegraph_pedestal(s, Vector3(x, 0, cz - 0.1))
	# RPM indicators on the forward bulkhead.
	for s in sh:
		_dial("rpm%d" % s, Vector3(1.0 + s * 0.42, 1.72, 0.12), 0.15, 0.0, u.plant.max_rpm, [0, 50, 100, 150, 200], ("SHAFT %d" % (s + 1)) if not su else ("ВАЛ %d" % (s + 1)), false, false, false, Vector3(0, 0, 1))
	_plant_panel(Vector3(W * 0.5 - 0.06, 1.35, D * 0.5), false, Vector3.ZERO, Basis.IDENTITY)
	var kn := _node("course_knob", Vector3(0.32, 1.2, cz + 0.35))
	var kk := _kit()
	kk.cyl("dark", Vector3.ZERO, Vector3(0, 0.05, 0), 0.05, 0.045, 14)
	kk.box("needle_w", Vector3(0, 0.052, -0.025), Vector3(0.008, 0.004, 0.04))
	_add(kk, kn)
	_control("course", "knob", kn, AABB(Vector3(-0.06, 0, -0.06), Vector3(0.12, 0.08, 0.12)), "Ordered course knob")
	anim["course_knob"] = kn
	var sw := _switch("autopilot", Vector3(-0.32, 1.18, cz + 0.35), "Helmsman: steer ordered course / hand steering", Basis.IDENTITY)
	_label("AUTO", sw.position + Vector3(0, 0.07, 0.04), 0.028)


# ------------------------------------------------------------------ common equipment
func _build_common() -> void:
	var hw := W * 0.5
	# Radar repeater on the port side.
	var rp := Vector3(-hw + 1.2, 0, 1.8)
	var k := _kit()
	k.box("console", rp + Vector3(0, 0.5, 0), Vector3(0.9, 1.0, 0.8))
	k.hexa("console", [rp + Vector3(-0.45, 1.0, -0.4), rp + Vector3(0.45, 1.0, -0.4), rp + Vector3(0.45, 1.0, 0.4), rp + Vector3(-0.45, 1.0, 0.4),
		rp + Vector3(-0.45, 1.25, -0.4), rp + Vector3(0.45, 1.25, -0.4), rp + Vector3(0.45, 1.05, 0.4), rp + Vector3(-0.45, 1.05, 0.4)])
	_add(k)
	var radar := Screens.new()
	radar.kind = "radar"
	radar.g = g
	radar.su = su
	var vp := _screen(radar, rp + Vector3(0, 1.16, 0.0), 0.36, Basis(Vector3.RIGHT, -PI * 0.5 + atan2(0.2, 0.8)))
	_label("SURFACE SEARCH" if not su else "НАВИГАЦИОННАЯ РЛС", rp + Vector3(0, 1.27, -0.36), 0.035, Color(0.9, 0.9, 0.85), null, Vector3(-0.3, 0, 0))
	# Chart table aft, with the live chart.
	var ct := Vector3(hw - 1.3 if style.begins_with("us_b") or style == "su_old" else -hw + 1.2, 0, D - 1.0)
	k = _kit()
	k.box("wood" if style == "us_battleship" else "console", ct + Vector3(0, 0.45, 0), Vector3(1.4, 0.9, 0.9))
	k.box("panel", ct + Vector3(0, 0.92, 0), Vector3(1.45, 0.04, 0.95))
	k.cyl("dark", ct + Vector3(0.6, 0.94, -0.35), ct + Vector3(0.6, 1.3, -0.35), 0.015, 0.015, 6)
	k.cyl("dark", ct + Vector3(0.6, 1.3, -0.35), ct + Vector3(0.35, 1.25, -0.2), 0.08, 0.05, 10)
	_add(k)
	var chart := Screens.new()
	chart.kind = "chart"
	chart.g = g
	chart.su = su
	_screen(chart, ct + Vector3(0, 0.945, 0), 0.42, Basis(Vector3.RIGHT, -PI * 0.5), Vector2(1.3, 0.85), false)
	var cl := OmniLight3D.new()
	cl.position = ct + Vector3(0.35, 1.2, -0.2)
	cl.omni_range = 1.4
	cl.light_energy = 0.8
	cl.light_color = Color(1.0, 0.85, 0.6)
	root.add_child(cl)
	# Captain's chair (starboard forward).
	var cc := Vector3(hw - 1.4, 0, 1.4)
	k = _kit()
	k.cyl("chrome", cc, cc + Vector3(0, 0.7, 0), 0.06, 0.06, 8)
	k.cyl("chrome", cc + Vector3(0, 0.02, 0), cc + Vector3(0, 0.04, 0), 0.32, 0.32, 12)
	k.box("leather", cc + Vector3(0, 0.78, 0), Vector3(0.6, 0.14, 0.6))
	k.box("leather", cc + Vector3(0, 1.15, 0.27), Vector3(0.6, 0.65, 0.12))
	k.box("leather", cc + Vector3(-0.32, 0.95, 0), Vector3(0.06, 0.08, 0.55))
	k.box("leather", cc + Vector3(0.32, 0.95, 0), Vector3(0.06, 0.08, 0.55))
	_add(k)
	_label("CO" if not su else "КОМАНДИР", cc + Vector3(0, 1.52, 0.33), 0.06, Color(0.85, 0.75, 0.4), null, Vector3(0, PI, 0))
	# Systems panel: alarms, whistle, lights, radar, air defence, special weapons.
	var sp := Vector3(hw - 0.07, 1.3, D - 2.0)
	k = _kit()
	k.box("panel", sp, Vector3(0.08, 0.9, 1.5))
	_add(k)
	var face := Basis(Vector3.UP, -PI * 0.5)
	var items := [
		["gq", "GENERAL\nQUARTERS" if not su else "БОЕВАЯ\nТРЕВОГА", "red_cap", "General quarters alarm"],
		["horn", "WHISTLE" if not su else "ТИФОН", "dark", "Ship's whistle"],
		["navlights", "NAV LIGHTS" if not su else "ХОД. ОГНИ", "dark", "Navigation lights"],
		["emcon", "RADAR\nRADIATE" if not su else "РЛС\nИЗЛУЧЕНИЕ", "dark", "Radars on / silent (EMCON)"],
		["ad", "AIR DEF\nAUTO" if not su else "ПВО\nАВТО", "dark", "Air defence auto / hold fire"],
		["director", "GUN DIR" if not su else "ПУС", "dark", "Gun director follows fire-control lead"],
	]
	for i in items.size():
		var it: Array = items[i]
		var pos := sp + Vector3(-0.05, 0.25 - (i / 3) * 0.42, -0.45 + (i % 3) * 0.45)
		var b := _button(it[0], pos, it[3], it[2], face)
		_label(it[1], pos + Vector3(-0.02, 0.1, 0.0), 0.026, Color(0.9, 0.9, 0.85), null, Vector3(0, -PI * 0.5, 0))
	if u.cls.get("nuclear", false):
		_nuke_panel(Vector3(hw - 0.07, 1.3, D - 3.5), face)
	# Overhead repeaters for the console bridges.
	if style == "us_modern" or style == "su":
		_dial("rudder2", Vector3(0, H - 0.42, 0.75), 0.24, -35.0, 35.0, [-30, -20, -10, 0, 10, 20, 30], "", true, false, false, Vector3(0, -0.35, 1).normalized())
	var speed := _label("00.0 KTS", Vector3(1.2, H - 0.42, 0.72), 0.09, Color(1.0, 0.55, 0.15), null, Vector3(-0.35, PI, 0))
	speed.rotation = Vector3(0.35, 0, 0)
	speed.rotation = Vector3(-0.35, 0.0, 0.0)
	anim["speed_label"] = speed
	k = _kit()
	k.box("dial_dark", Vector3(1.2, H - 0.42, 0.68), Vector3(0.7, 0.18, 0.06))
	k.box("dial_dark", Vector3(-1.2, H - 0.42, 0.68), Vector3(0.7, 0.18, 0.06))
	_add(k)
	var hdg := _label("HDG 000", Vector3(-1.2, H - 0.42, 0.72), 0.09, Color(1.0, 0.55, 0.15))
	hdg.rotation = Vector3(-0.35, 0.0, 0.0)
	anim["hdg_label"] = hdg
	var clock := _dial("clock", Vector3(hw - 0.08, H - 0.6, 1.2), 0.16, 0.0, 12.0, [], "", false, false, false, Vector3(-1, 0, 0))
	speed.rotation = Vector3(-0.35, 0.0, 0.0)


# ------------------------------------------------------------------ control builders
func _wheel(c: Vector3, r: float, spokes: int, big: bool, face: Vector3) -> void:
	var n := _node("wheel", c)
	var k := _kit()
	var axis := Vector3(0, 0, 1)
	k.torus("wood" if big else "rubber", Vector3.ZERO, axis, r, 0.035 if big else 0.022, 32, 8)
	k.cyl("brass" if big else "chrome", Vector3(0, 0, -0.06), Vector3(0, 0, 0.06), 0.07 if big else 0.05, 0.07 if big else 0.05, 12)
	for i in spokes:
		var a := TAU * i / spokes
		var d := Vector3(cos(a), sin(a), 0)
		k.cyl("brass" if big else "chrome", d * 0.05, d * (r + (0.16 if big else 0.0)), 0.018 if big else 0.012, 0.014 if big else 0.012, 6)
		if big:
			k.cyl("wood", d * (r + 0.05), d * (r + 0.2), 0.026, 0.02, 8)
			k.sphere("wood", d * (r + 0.21), 0.028, 8, 5)
	k.box("needle", Vector3(0, r - 0.01, 0.03), Vector3(0.04 if big else 0.03, 0.06, 0.02))
	_add(k, n)
	anim["wheel"] = n
	var R := r + (0.22 if big else 0.05)
	_control("wheel", "wheel", n, AABB(Vector3(-R, -R, -0.12), Vector3(R * 2.0, R * 2.0, 0.24)),
		"Helm wheel: drag left/right or use the mouse wheel (A/D keys)", {"big": big})


func _dial(id: String, c: Vector3, r: float, vmin: float, vmax: float, marks: Array, title: String,
		center_zero: bool, order_pointer: bool, compass := false, face := Vector3(0, 0, 1)) -> Node3D:
	var n := _node("dial_" + id, c)
	n.basis = Basis.looking_at(-face, Vector3.UP if absf(face.y) < 0.95 else Vector3.FORWARD)
	var k := _kit()
	k.cyl("brass" if style == "us_battleship" else "dark", Vector3(0, 0, -0.03), Vector3(0, 0, 0.0), r * 1.12, r * 1.12, 24)
	k.disc("dial" if not compass else "dial_dark", Vector3(0, 0, 0.002), Vector3(0, 0, 1), r, 32)
	var arc := 270.0 if not compass else 360.0
	var span := vmax - vmin
	var nt := 36 if compass else 14
	for i in nt + 1:
		var f := float(i) / nt
		var a := deg_to_rad(-arc * 0.5 + f * arc) if not compass else f * TAU
		if compass and i == nt:
			break
		var d := Vector3(sin(a), cos(a), 0)
		var big := i % (3 if not compass else 3) == 0
		k.box("dark" if not compass else "needle_w", d * r * (0.86 if big else 0.9) + Vector3(0, 0, 0.004), Vector3(0.006, r * (0.12 if big else 0.06), 0.002), Basis(Vector3(0, 0, 1), -a))
	_add(k, n)
	if not title.is_empty():
		_label(title, Vector3(0, -r * 0.45, 0.006), r * 0.17, Color(0.1, 0.1, 0.1), n)
	for m in marks:
		var f := (float(m) - vmin) / span
		var a := deg_to_rad(-arc * 0.5 + f * arc)
		var txt := str(absi(int(m)))
		if center_zero and int(m) != 0:
			txt = ("R" if int(m) > 0 else "L") + txt
		_label(txt, Vector3(sin(a), cos(a), 0) * r * 0.66 + Vector3(0, -r * 0.05, 0.006), r * 0.16, Color(0.08, 0.08, 0.08), n)
	if center_zero:
		var kk := _kit()
		for s: float in [-1.0, 1.0]:
			kk.box("red_cap" if s < 0 else "lit_g", Vector3(s * r * 0.55, r * 0.55, 0.004), Vector3(r * 0.25, 0.01, 0.002), Basis(Vector3(0, 0, 1), s * 0.785))
		_add(kk, n)
	var needle := Node3D.new()
	needle.position = Vector3(0, 0, 0.01)
	n.add_child(needle)
	var kn := _kit()
	if compass:
		var card := Node3D.new()
		needle.add_child(card)
		for i in 12:
			var a := TAU * i / 12.0
			var txt = ["N", "3", "6", "E", "12", "15", "S", "21", "24", "W", "30", "33"][i]
			_label(txt, Vector3(sin(a), cos(a), 0) * r * 0.7, r * 0.2, Color(1.0, 0.6, 0.2) if i % 3 == 0 else Color(0.85, 0.85, 0.8), card, Vector3(0, 0, -a))
		kn.box("needle", Vector3(0, r * 0.95, 0.01), Vector3(0.01, r * 0.12, 0.004))
		_add(kn, n)
		anim[id] = card
	else:
		kn.box("needle", Vector3(0, r * 0.38, 0), Vector3(r * 0.05, r * 0.82, 0.004))
		kn.cyl("dark", Vector3(0, 0, -0.002), Vector3(0, 0, 0.008), r * 0.08, r * 0.08, 10)
		_add(kn, needle)
		anim[id] = needle
		if order_pointer:
			var op := Node3D.new()
			op.position = Vector3(0, 0, 0.006)
			n.add_child(op)
			var ko := _kit()
			ko.box("needle_w", Vector3(0, r * 0.9, 0), Vector3(r * 0.08, r * 0.18, 0.003))
			_add(ko, op)
			anim[id + "_order"] = op
	n.set_meta("range", [vmin, vmax, arc, compass])
	return n


func _throttle(s: int, c: Vector3, basis: Basis) -> void:
	var base := _node("throttle%d" % s, c)
	base.basis = basis
	var k := _kit()
	k.box("dark", Vector3(0, 0.005, 0), Vector3(0.09, 0.01, 0.38))
	k.box("black", Vector3(0, 0.011, 0), Vector3(0.025, 0.004, 0.34))
	for i in 9:
		var z := -0.16 + i * 0.04
		k.box("needle_w", Vector3(0.05, 0.011, z), Vector3(0.02 if i % 2 == 0 else 0.012, 0.002, 0.004))
	_add(k, base)
	_label("AHEAD" if not su else "ВПЕРЁД", Vector3(0, 0.02, -0.21), 0.025, Color(0.9, 0.9, 0.85), base, Vector3(-PI * 0.5, 0, 0))
	_label("ASTERN" if not su else "НАЗАД", Vector3(0, 0.02, 0.22), 0.025, Color(1.0, 0.4, 0.3), base, Vector3(-PI * 0.5, 0, 0))
	var arm := Node3D.new()
	arm.name = "Arm"
	base.add_child(arm)
	var ka := _kit()
	ka.box("chrome", Vector3(0, 0.07, 0), Vector3(0.02, 0.14, 0.02))
	ka.box("black", Vector3(0, 0.15, 0), Vector3(0.07, 0.035, 0.035))
	_add(ka, arm)
	anim["throttle%d" % s] = arm
	_control("throttle%d" % s, "throttle", base, AABB(Vector3(-0.05, 0, -0.2), Vector3(0.1, 0.2, 0.4)),
		"Shaft %d programmed-control lever: drag fore/aft (W/S moves both)" % (s + 1), {"shaft": s})


func _telegraph_lever(s: int, c: Vector3, basis: Basis) -> void:
	var base := _node("tlever%d" % s, c)
	base.basis = basis
	var k := _kit()
	k.box("dark", Vector3(0, 0.02, 0), Vector3(0.24, 0.04, 0.44))
	k.box("black", Vector3(0, 0.041, 0), Vector3(0.03, 0.004, 0.4))
	_add(k, base)
	var names: Array = u.plant.bells()
	for i in 10:
		var z := 0.18 - i * 0.04
		var col := Color(1.0, 0.45, 0.35) if i < 4 else (Color(0.95, 0.9, 0.5) if i == 4 else Color(0.9, 0.92, 0.88))
		_label(String(names[i]).replace("САМЫЙ ", "С.").replace("ВПЕРЁД", "ВП.").replace("НАЗАД", "НАЗ."), Vector3(0.11, 0.045, z), 0.014, col, base, Vector3(-PI * 0.5, 0, 0), false)
	var arm := Node3D.new()
	base.add_child(arm)
	var ka := _kit()
	ka.box("chrome", Vector3(0, 0.1, 0), Vector3(0.022, 0.16, 0.022))
	ka.box("red_cap" if su else "black", Vector3(0, 0.19, 0), Vector3(0.05, 0.04, 0.05))
	_add(ka, arm)
	anim["tlever%d" % s] = arm
	var ans := Node3D.new()
	base.add_child(ans)
	var kn := _kit()
	kn.box("lit_a", Vector3(-0.085, 0.046, 0), Vector3(0.03, 0.006, 0.02))
	_add(kn, ans)
	anim["tans%d" % s] = ans
	_control("tel%d" % s, "telegraph", base, AABB(Vector3(-0.12, 0, -0.22), Vector3(0.24, 0.24, 0.44)),
		"Engine telegraph, shaft %d: drag or wheel to ring a bell (W/S rings all)" % (s + 1), {"shaft": s, "lever": true})


func _telegraph_pedestal(s: int, c: Vector3) -> void:
	var base := _node("telegraph%d" % s, c)
	base.rotation.y = deg_to_rad(-25.0)
	var k := _kit()
	k.cyl("brass", Vector3(0, 0, 0), Vector3(0, 0.95, 0), 0.12, 0.09, 14)
	k.cyl("brass", Vector3(0, 0, 0), Vector3(0, 0.05, 0), 0.22, 0.22, 16)
	k.cyl("brass", Vector3(0, 1.18, -0.08), Vector3(0, 1.18, 0.1), 0.27, 0.27, 28)
	k.disc("dial", Vector3(0, 1.18, 0.105), Vector3(0, 0, 1), 0.245, 32)
	k.box("brass", Vector3(0, 0.97, 0.0), Vector3(0.2, 0.12, 0.16))
	_add(k, base)
	var names: Array = u.plant.bells() if not su else u.plant.bells()
	for i in 10:
		var a := deg_to_rad(-135.0 + i * 30.0)
		var col := Color(0.6, 0.06, 0.04) if i < 4 else (Color(0.1, 0.1, 0.1) if i == 4 else Color(0.08, 0.08, 0.08))
		var txt := String(names[i]).replace("BACK ", "BK ").replace("AHEAD ", "").replace("САМЫЙ ", "С. ")
		_label(txt, Vector3(sin(a), cos(a), 0) * 0.17 + Vector3(0, 1.18, 0.112), 0.018, col, base, Vector3(0, 0, -a))
	_label("SHAFT %d" % (s + 1) if not su else "ВАЛ %d" % (s + 1), Vector3(0, 1.0, 0.09), 0.03, Color(0.2, 0.15, 0.05), base)
	var arm := Node3D.new()
	arm.position = Vector3(0, 1.18, 0.12)
	base.add_child(arm)
	var ka := _kit()
	ka.box("brass", Vector3(0, 0.15, 0.02), Vector3(0.03, 0.32, 0.02))
	ka.cyl("wood", Vector3(0, 0.33, 0.0), Vector3(0, 0.33, 0.12), 0.025, 0.025, 8)
	_add(ka, arm)
	anim["tped%d" % s] = arm
	var ans := Node3D.new()
	ans.position = Vector3(0, 1.18, 0.114)
	base.add_child(ans)
	var kn := _kit()
	kn.box("needle", Vector3(0, 0.2, 0), Vector3(0.02, 0.06, 0.003))
	_add(kn, ans)
	anim["tpans%d" % s] = ans
	_control("tel%d" % s, "telegraph", base, AABB(Vector3(-0.3, 0.85, -0.1), Vector3(0.6, 0.7, 0.4)),
		"Engine order telegraph, shaft %d: drag the handle or use the wheel (W/S rings all)" % (s + 1), {"shaft": s, "lever": false})


func _button(id: String, pos: Vector3, tip: String, cap: String, basis: Basis) -> Node3D:
	var n := _node("btn_" + id, pos)
	n.basis = basis
	var k := _kit()
	k.cyl("dark", Vector3(0, 0, 0), Vector3(0, 0.015, 0), 0.045, 0.045, 14)
	_add(k, n)
	var capn := Node3D.new()
	n.add_child(capn)
	var kc := _kit()
	kc.cyl(cap, Vector3(0, 0.015, 0), Vector3(0, 0.035, 0), 0.032, 0.032, 14)
	var mi := _add(kc, capn)
	var lamp := _kit()
	lamp.cyl("unlit", Vector3(0.06, 0.0, 0.0), Vector3(0.06, 0.012, 0.0), 0.012, 0.012, 10)
	var lm := _add(lamp, n)
	anim["btn_" + id] = capn
	anim["lamp_" + id] = lm
	_control(id, "button", n, AABB(Vector3(-0.05, 0, -0.05), Vector3(0.1, 0.06, 0.1)), tip)
	return n


func _switch(id: String, pos: Vector3, tip: String, basis: Basis) -> Node3D:
	var n := _node("sw_" + id, pos)
	n.basis = basis
	var k := _kit()
	k.box("dark", Vector3(0, 0.005, 0), Vector3(0.06, 0.01, 0.08))
	_add(k, n)
	var bat := Node3D.new()
	n.add_child(bat)
	var kb := _kit()
	kb.cyl("chrome", Vector3(0, 0.01, 0), Vector3(0, 0.06, 0), 0.006, 0.005, 8)
	kb.sphere("chrome", Vector3(0, 0.062, 0), 0.01, 8, 5)
	_add(kb, bat)
	anim["sw_" + id] = bat
	_control(id, "switch", n, AABB(Vector3(-0.04, 0, -0.05), Vector3(0.08, 0.08, 0.1)), tip)
	return n


func _plant_panel(pos: Vector3, on_console: bool, panel_c: Vector3, top_basis: Basis) -> void:
	var units: Array = u.plant.units
	var title := "GAS TURBINES" if u.plant.kind.begins_with("gt") else ("REACTORS / BOILERS" if u.plant.nuclear else "BOILERS")
	if su:
		title = "ГТД" if u.plant.kind.begins_with("gt") else "КОТЛЫ"
	var n := units.size()
	if on_console:
		for i in n:
			var p := panel_c + top_basis * Vector3(-0.15 + (i % 4) * 0.13 - 0.25, 0.02, -0.25 + (i / 4) * 0.12)
			if u.plant.is_lever():
				p = panel_c + top_basis * Vector3(0.02 + (i % 4) * 0.12 - 0.35, 0.02, -0.26)
			var b := _button("unit%d" % i, p, "%s: start / stop" % units[i]["name"], "dark", top_basis)
			_label(String(units[i]["name"]).replace("Cruise ", "C").replace("Boost ", "B").replace("Boiler ", "B").replace(" reactor", ""), b.position + top_basis * Vector3(0, 0.02, 0.065), 0.022, Color(0.9, 0.9, 0.85), null, Vector3(-PI * 0.5 + atan2(0.2, 0.75), 0, 0))
		return
	# Bulkhead panel (pilothouse): starboard wall.
	var k := _kit()
	k.box("panel", pos, Vector3(0.08, 0.7, 0.3 + n * 0.17))
	_add(k)
	var face := Basis(Vector3.UP, -PI * 0.5)
	_label(title, pos + Vector3(-0.05, 0.28, 0), 0.04, Color(0.9, 0.85, 0.6), null, Vector3(0, -PI * 0.5, 0))
	for i in n:
		var p := pos + Vector3(-0.05, 0.05, -n * 0.085 + i * 0.17 + 0.085)
		var b := _button("unit%d" % i, p, "%s: light off / secure" % units[i]["name"], "dark", face)
		_label(str(i + 1), p + Vector3(-0.01, -0.09, 0), 0.04, Color(0.9, 0.9, 0.85), null, Vector3(0, -PI * 0.5, 0))
	if u.plant.kind == "steam" and not u.plant.nuclear:
		_dial("steam", pos + Vector3(-0.06, -0.2, 0), 0.12, 0.0, 1.05, [0, 0.5, 1.0], "STEAM" if not su else "ПАР", false, false, false, Vector3(-1, 0, 0))


func _nuke_panel(pos: Vector3, face: Basis) -> void:
	var k := _kit()
	k.box("yellow_black", pos, Vector3(0.09, 0.62, 0.7))
	k.box("dark", pos + Vector3(-0.005, 0, 0), Vector3(0.09, 0.56, 0.64))
	_add(k)
	_label("SPECIAL WEAPONS RELEASE" if not su else "СПЕЦБОЕПРИПАСЫ", pos + Vector3(-0.05, 0.24, 0), 0.032, Color(1.0, 0.8, 0.2), null, Vector3(0, -PI * 0.5, 0))
	for i in 2:
		var kp := pos + Vector3(-0.05, 0.08, -0.18 + i * 0.36)
		var n := _node("key%d" % i, kp)
		n.basis = face
		var kk := _kit()
		kk.cyl("chrome", Vector3(0, 0, 0), Vector3(0, 0.02, 0), 0.03, 0.03, 14)
		_add(kk, n)
		var key := Node3D.new()
		n.add_child(key)
		var kk2 := _kit()
		kk2.box("brass", Vector3(0, 0.035, 0), Vector3(0.012, 0.03, 0.035))
		kk2.cyl("brass", Vector3(0, 0.06, 0), Vector3(0, 0.065, 0), 0.022, 0.022, 10)
		_add(kk2, key)
		anim["key%d" % i] = key
		_control("key%d" % i, "key", n, AABB(Vector3(-0.04, 0, -0.04), Vector3(0.08, 0.08, 0.08)), "Release key %d (both must be turned)" % (i + 1))
		_label("KEY %d" % (i + 1) if not su else "КЛЮЧ %d" % (i + 1), kp + Vector3(-0.01, -0.07, 0), 0.025, Color(0.9, 0.9, 0.85), null, Vector3(0, -PI * 0.5, 0))
	var bp := pos + Vector3(-0.05, -0.15, 0)
	var b := _button("release", bp, "Guarded release button: lift the cover, then press", "red_cap", face)
	var cov := Node3D.new()
	cov.position = Vector3(0, 0.0, 0.05)
	b.add_child(cov)
	var kc := _kit()
	kc.box("glass_in", Vector3(0, 0.03, -0.05), Vector3(0.09, 0.06, 0.1))
	kc.box("red_cap", Vector3(0, 0.061, -0.05), Vector3(0.09, 0.003, 0.1))
	_add(kc, cov)
	anim["cover"] = cov


func _screen(drawer: Control, c: Vector3, r: float, basis: Basis, size := Vector2.ZERO, round_scr := true) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 512) if size == Vector2.ZERO else Vector2i(640, int(640 * size.y / size.x))
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drawer.custom_minimum_size = Vector2(vp.size)
	vp.add_child(drawer)
	root.add_child(vp)
	screens.append(vp)
	var m := StandardMaterial3D.new()
	m.albedo_texture = vp.get_texture()
	m.emission_enabled = round_scr
	m.emission_texture = vp.get_texture()
	m.emission_energy_multiplier = 0.9
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if round_scr else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	var k := MeshKit.new({"s": m})
	if round_scr:
		k.xf = Transform3D(basis, c)
		k.disc_uv("s", Vector3.ZERO, Vector3(0, 0, 1), r, 40)
	else:
		k.xf = Transform3D(basis, c)
		k.rect_uv("s", Vector3.ZERO, Vector3(0, 0, 1), Vector3.UP, size)
	var mi := k.instance("Screen", false)
	root.add_child(mi)
	return vp


# ------------------------------------------------------------------ interaction
func _ray() -> Array:
	var cam: Camera3D = g.cam
	var mp = g.get_viewport().get_mouse_position()
	return [cam.project_ray_origin(mp), cam.project_ray_normal(mp)]


func _pick():
	var r := _ray()
	var best = null
	var bt := 3.5
	for c in controls:
		var n: Node3D = c["node"]
		var inv := n.global_transform.affine_inverse()
		var o: Vector3 = inv * r[0]
		var d: Vector3 = (inv.basis * r[1]).normalized()
		var t := _ray_box(o, d, c["box"])
		if t >= 0.0 and t < bt:
			bt = t
			best = c
	return best


static func _ray_box(o: Vector3, d: Vector3, b: AABB) -> float:
	var t0 := 0.0
	var t1 := 1e9
	for i in 3:
		if absf(d[i]) < 1e-8:
			if o[i] < b.position[i] or o[i] > b.end[i]:
				return -1.0
		else:
			var ta := (b.position[i] - o[i]) / d[i]
			var tb := (b.end[i] - o[i]) / d[i]
			if ta > tb:
				var tmp := ta
				ta = tb
				tb = tmp
			t0 = maxf(t0, ta)
			t1 = minf(t1, tb)
			if t0 > t1:
				return -1.0
	return t0


func mouse_move(ev: InputEventMouseMotion) -> void:
	if dragging != null:
		_drag(dragging, ev.relative)
		return
	var h = _pick()
	if h != hover:
		hover = h
		if h != null:
			g.hud.show_hint(h["tip"], 2.5)


func mouse_button(ev: InputEventMouseButton) -> void:
	if ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			var c = _pick()
			if c == null:
				return
			match String(c["kind"]):
				"wheel", "throttle", "telegraph", "knob":
					dragging = c
					drag_acc = 0.0
				"button", "switch", "key":
					_press(c)
		else:
			dragging = null
	elif ev.pressed and (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var c = _pick()
		var d := 1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else -1
		if c == null:
			g.zoom = d > 0
			return
		match String(c["kind"]):
			"wheel":
				g.order_rudder(u.rudder_order + d * 2.0)
			"throttle":
				u.plant.set_lever(u.plant.lever[c["shaft"]] + d * 0.05, c["shaft"])
				g.sfx.play("click")
			"telegraph":
				u.plant.ring(u.plant.bell[c["shaft"]] + d, c["shaft"])
				g.sfx.play("telegraph")
			"knob":
				u.steer(U.wrap360((u.course_order if u.course_order >= 0.0 else u.heading) + d * 1.0))
				g.sfx.play("click")


func _drag(c: Dictionary, rel: Vector2) -> void:
	match String(c["kind"]):
		"wheel":
			var k := 0.12 if c.get("big", false) else 0.18
			u.set_rudder(u.rudder_order + rel.x * k)
		"throttle":
			u.plant.set_lever(u.plant.lever[c["shaft"]] - rel.y * 0.006, c["shaft"])
		"telegraph":
			drag_acc += -rel.y if c.get("lever", false) else rel.x
			if absf(drag_acc) > 22.0:
				var s: int = c["shaft"]
				u.plant.ring(u.plant.bell[s] + int(signf(drag_acc)), s)
				g.sfx.play("telegraph")
				drag_acc = 0.0
		"knob":
			drag_acc += rel.x
			if absf(drag_acc) > 4.0:
				u.steer(U.wrap360((u.course_order if u.course_order >= 0.0 else u.heading) + signf(drag_acc)))
				drag_acc = 0.0


func _press(c: Dictionary) -> void:
	var id: String = c["id"]
	g.sfx.play("click")
	if id.begins_with("unit"):
		var i := int(id.substr(4))
		u.plant.toggle_unit(i)
		var un: Dictionary = u.plant.units[i]
		g.hud.message("Engineering", "%s: %s" % [un["name"], {"starting": "starting" if u.plant.kind.begins_with("gt") else "lighting off, raising steam", "standby": "secured", "online": "on line"}.get(un["state"], un["state"])])
		return
	match id:
		"gq":
			g.toggle_gq()
		"horn":
			g.sfx.play("horn")
		"navlights":
			lights_on = not lights_on
			g.view.set_night(lights_on)
		"emcon":
			u.emcon = not u.emcon
			g.hud.show_hint("Radars %s" % ("silent" if u.emcon else "radiating"))
		"ad":
			g.w.ad_mode = "hold" if g.w.ad_mode == "auto" else "auto"
			g.hud.show_hint("Air defence: %s" % g.w.ad_mode.to_upper())
		"director":
			g.director = not g.director
		"autopilot":
			if u.autopilot:
				u.set_rudder(u.rudder)
			else:
				u.steer(u.heading if u.course_order < 0.0 else u.course_order)
		"apu":
			u.plant.apu = not u.plant.apu
			g.hud.message("Engineering", "Auxiliary propulsion units %s" % ("lowered and running" if u.plant.apu else "raised"))
		"key0", "key1":
			var i := int(id.substr(3))
			nuke_keys[i] = not nuke_keys[i]
			g.sfx.play("click")
			if nuke_armed():
				g.hud.message("Weapons", "Both keys turned. Special weapons release ENABLED.", Color(1, 0.35, 0.25))
		"release":
			if not nuke_cover:
				nuke_cover = true
				g.hud.show_hint("Cover raised")
			elif nuke_armed():
				g.hud.message("Weapons", "Release consent given. Select the special weapon (Z) and fire.", Color(1, 0.35, 0.25))
				g.sfx.play("alarm")


# ------------------------------------------------------------------ animation
func update(dt: float) -> void:
	if not active:
		return
	var p = u.plant
	if anim.has("wheel"):
		var n: Node3D = anim["wheel"]
		n.rotation.z = -deg_to_rad(u.rudder_order) * (5.0 if style == "us_battleship" or style == "su_old" else 3.5)
	_set_dial("rudder", u.rudder, u.rudder_order)
	_set_dial("rudder2", u.rudder, u.rudder_order)
	if anim.has("gyro"):
		anim["gyro"].rotation.z = deg_to_rad(u.heading)
	for s in p.shafts:
		_set_dial("rpm%d" % s, p.shaft_rpm(s))
		if anim.has("throttle%d" % s):
			anim["throttle%d" % s].position.z = -p.lever[s] * 0.16
			anim["throttle%d" % s].rotation.x = -p.lever[s] * 0.5
		if anim.has("tlever%d" % s):
			anim["tlever%d" % s].position.z = 0.18 - p.bell[s] * 0.04
			anim["tans%d" % s].position.z = 0.18 - p.answered[s] * 0.04
		if anim.has("tped%d" % s):
			anim["tped%d" % s].rotation.z = -deg_to_rad(-135.0 + p.bell[s] * 30.0)
			anim["tpans%d" % s].rotation.z = -deg_to_rad(-135.0 + p.answered[s] * 30.0)
	if p.kind == "steam":
		_set_dial("steam", p.steam)
	for i in p.units.size():
		var st: String = p.units[i]["state"]
		var lm = anim.get("lamp_unit%d" % i)
		if lm != null:
			lm.material_override = mats["lit_g"] if st == "online" else (mats["lit_a"] if st == "starting" and int(g.w.t * 2.0) % 2 == 0 else mats["unlit"])
	_lamp("gq", g.gq, "lit_r")
	_lamp("navlights", lights_on, "lit_g")
	_lamp("emcon", not u.emcon, "lit_g")
	_lamp("ad", g.w.ad_mode == "auto", "lit_g")
	_lamp("director", g.director, "lit_a")
	_lamp("apu", p.apu, "lit_a")
	_lamp("release", nuke_armed(), "lit_r")
	if anim.has("sw_autopilot"):
		anim["sw_autopilot"].rotation.x = -0.5 if u.autopilot else 0.5
	if anim.has("course_knob") and u.course_order >= 0.0:
		anim["course_knob"].rotation.y = -deg_to_rad(u.course_order)
	for i in 2:
		if anim.has("key%d" % i):
			anim["key%d" % i].rotation.y = PI * 0.5 if nuke_keys[i] else 0.0
	if anim.has("cover"):
		anim["cover"].rotation.x = -1.6 if nuke_cover else 0.0
	if anim.has("speed_label"):
		anim["speed_label"].text = "%04.1f KTS" % (u.speed / U.KN)
	if anim.has("hdg_label"):
		anim["hdg_label"].text = "HDG %s" % U.p3(u.heading)
	if anim.has("clock"):
		var hr: float = g.local_hour()
		anim["clock"].rotation.z = -fposmod(hr, 12.0) / 12.0 * TAU
	var night: bool = g.atm.sun_el < 0.0
	var l: OmniLight3D = anim["room_light"]
	l.light_color = Color(1.0, 0.25, 0.15) if night else Color(1.0, 0.95, 0.88)
	l.light_energy = 0.45 if night else 1.1


func _set_dial(id: String, v: float, order := INF) -> void:
	if not anim.has(id):
		return
	var n: Node3D = anim[id]
	var dial: Node3D = n.get_parent()
	var r: Array = dial.get_meta("range")
	var f := (v - float(r[0])) / maxf(float(r[1]) - float(r[0]), 1e-4)
	var a := deg_to_rad(-float(r[2]) * 0.5 + clampf(f, 0.0, 1.0) * float(r[2]))
	n.rotation.z = -a
	if order != INF and anim.has(id + "_order"):
		var fo := (order - float(r[0])) / maxf(float(r[1]) - float(r[0]), 1e-4)
		anim[id + "_order"].rotation.z = -deg_to_rad(-float(r[2]) * 0.5 + clampf(fo, 0.0, 1.0) * float(r[2]))


func _lamp(id: String, on: bool, mat: String) -> void:
	var lm = anim.get("lamp_" + id)
	if lm != null:
		lm.material_override = mats[mat] if on else mats["unlit"]
