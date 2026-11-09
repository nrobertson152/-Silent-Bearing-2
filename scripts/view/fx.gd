extends Node3D
## Particle effects: muzzle blasts, splashes, explosions, fires, smoke, missile
## exhaust, tracers and the nuclear fireball. Textures are generated in code.

static var _smoke_tex: ImageTexture
static var _soft_tex: GradientTexture2D
static var _mats := {}

var _timed := []
var lights := []
var wind := Vector3(2.0, 0.0, 0.5)


func _init() -> void:
	name = "FX"


static func smoke_tex() -> Texture2D:
	if _smoke_tex != null:
		return _smoke_tex
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.06
	noise.fractal_octaves = 4
	for y in n:
		for x in n:
			var dx := (x - n * 0.5) / (n * 0.5)
			var dy := (y - n * 0.5) / (n * 0.5)
			var r := sqrt(dx * dx + dy * dy)
			var nv := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf((1.0 - r) * 1.6 * (0.45 + nv * 0.9) - 0.15, 0.0, 1.0)
			var shade := 0.75 + 0.25 * nv - dy * 0.12
			img.set_pixel(x, y, Color(shade, shade, shade, a * a))
	_smoke_tex = ImageTexture.create_from_image(img)
	return _smoke_tex


static func soft_tex() -> Texture2D:
	if _soft_tex != null:
		return _soft_tex
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.6))
	_soft_tex = GradientTexture2D.new()
	_soft_tex.gradient = g
	_soft_tex.fill = GradientTexture2D.FILL_RADIAL
	_soft_tex.fill_from = Vector2(0.5, 0.5)
	_soft_tex.fill_to = Vector2(1.0, 0.5)
	_soft_tex.width = 64
	_soft_tex.height = 64
	return _soft_tex


static func mat(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	match kind:
		"smoke":
			m.albedo_texture = smoke_tex()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
			m.proximity_fade_enabled = true
			m.proximity_fade_distance = 2.0
		"spray":
			m.albedo_texture = smoke_tex()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		"fire", "flash", "spark":
			m.albedo_texture = soft_tex()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mats[kind] = m
	return m


## Generic particle burst. vel is [min, max] initial speed, spread in degrees.
func burst(pos: Vector3, kind: String, amount: int, life: float, vel: Vector2, spread: float,
		size: Vector2, ramp: Gradient, dir := Vector3.UP, gravity := Vector3.ZERO, damp := 0.0,
		emit_r := 0.5, explos := 1.0, parent: Node3D = null) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = explos
	p.randomness = 0.4
	p.fixed_fps = 30
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-200, -50, -200), Vector3(400, 400, 400))
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = vel.x
	pm.initial_velocity_max = vel.y
	pm.gravity = gravity
	pm.damping_min = damp
	pm.damping_max = damp * 1.3
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = emit_r
	pm.scale_min = size.x
	pm.scale_max = size.x * 1.4
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.35))
	sc.add_point(Vector2(1, size.y / maxf(size.x, 0.01)))
	sc.max_value = maxf(1.0, size.y / maxf(size.x, 0.01))
	var ct := CurveTexture.new()
	ct.curve = sc
	pm.scale_curve = ct
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = mat(kind)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind != "smoke" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	(parent if parent else self).add_child(p)
	if parent:
		p.position = pos
	else:
		p.global_position = pos
	p.emitting = true
	_timed.append([p, life + 0.5])
	return p


static func ramp(colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for i in colors.size():
		g.add_point(float(i) / maxf(colors.size() - 1, 1), colors[i])
	return g


func flash(pos: Vector3, energy: float, rng_m: float, col := Color(1.0, 0.75, 0.45), life := 0.12) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_m
	l.shadow_enabled = false
	add_child(l)
	l.global_position = pos
	lights.append([l, life, life, energy])


# ------------------------------------------------------------------ effects
func muzzle(pos: Vector3, dir: Vector3, cal: float) -> void:
	var s := clampf(cal / 127.0, 0.4, 3.6)
	burst(pos + dir * s, "flash", 6, 0.14, Vector2(10, 30) * s, 14.0, Vector2(2.5, 6.0) * s,
		ramp([Color(1, 0.95, 0.7, 1), Color(1, 0.5, 0.1, 0.8), Color(0.4, 0.1, 0.0, 0)]), dir)
	burst(pos + dir * s * 2.0, "smoke", int(10 + s * 6), 3.0 + s * 2.5, Vector2(6, 22) * s, 22.0, Vector2(3.0, 14.0) * s,
		ramp([Color(0.75, 0.72, 0.68, 0.0), Color(0.72, 0.7, 0.66, 0.55), Color(0.7, 0.7, 0.7, 0.0)]), dir, wind * 0.3, 1.8)
	flash(pos + dir * 3.0, 6.0 * s, 25.0 * s)
	if cal >= 300.0:
		burst(Vector3(pos.x, 0.3, pos.z) + dir * 8.0, "spray", 30, 1.6, Vector2(20, 40), 80.0, Vector2(3, 9),
			ramp([Color(0.9, 0.93, 0.95, 0.6), Color(0.9, 0.93, 0.95, 0.0)]), Vector3(dir.x, 0.15, dir.z).normalized(), Vector3(0, -6, 0), 2.0, 4.0)


func splash(pos: Vector3, size: float) -> void:
	var s := clampf(size, 0.3, 4.5)
	var h := 12.0 + s * 14.0
	burst(pos, "spray", int(18 + s * 10), 2.4 + s * 0.6, Vector2(h * 0.55, h * 0.95), 9.0, Vector2(2.0, 7.0) * sqrt(s),
		ramp([Color(0.95, 0.97, 1.0, 0.9), Color(0.9, 0.93, 0.96, 0.7), Color(0.88, 0.9, 0.92, 0.0)]), Vector3.UP, Vector3(0, -9.8, 0), 0.4, 1.0 * s)
	burst(pos + Vector3(0, h * 0.3, 0), "spray", int(10 + s * 6), 4.0 + s, Vector2(1, 4), 70.0, Vector2(6, 20) * sqrt(s),
		ramp([Color(0.92, 0.94, 0.96, 0.0), Color(0.92, 0.94, 0.96, 0.4), Color(0.92, 0.94, 0.96, 0.0)]), Vector3.UP, wind * 0.4, 1.0, 2.0 * s, 0.6)
	burst(pos, "spray", 14, 1.4, Vector2(6, 14) * sqrt(s), 85.0, Vector2(2, 5),
		ramp([Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.0)]), Vector3.UP, Vector3(0, -9.8, 0), 0.5, 0.8 * s)


func explosion(pos: Vector3, size: float, smoke := true) -> void:
	var s := clampf(size, 0.3, 8.0)
	burst(pos, "fire", int(14 + s * 6), 0.7 + s * 0.12, Vector2(4, 16) * s, 180.0, Vector2(4.0, 12.0) * s,
		ramp([Color(1, 0.92, 0.6, 1), Color(1, 0.45, 0.1, 0.9), Color(0.5, 0.12, 0.02, 0.0)]), Vector3.UP, Vector3(0, 2, 0), 3.0, 1.0 * s)
	burst(pos, "spark", int(20 + s * 10), 1.6, Vector2(20, 60) * sqrt(s), 180.0, Vector2(0.4, 0.2),
		ramp([Color(1, 0.8, 0.4, 1), Color(1, 0.4, 0.1, 0)]), Vector3.UP, Vector3(0, -9.8, 0), 0.5, 0.5)
	if smoke:
		burst(pos + Vector3(0, s, 0), "smoke", int(14 + s * 5), 7.0 + s * 1.5, Vector2(2, 8) * sqrt(s), 120.0, Vector2(5.0, 22.0) * s,
			ramp([Color(0.1, 0.09, 0.08, 0.0), Color(0.12, 0.1, 0.09, 0.85), Color(0.25, 0.24, 0.23, 0.0)]), Vector3.UP, Vector3(0, 3, 0) + wind * 0.5, 1.2, 1.5 * s)
	flash(pos + Vector3(0, 2, 0), 18.0 * s, 60.0 * s, Color(1.0, 0.6, 0.3), 0.35)


func air_burst(pos: Vector3, size := 1.0) -> void:
	burst(pos, "fire", 10, 0.5, Vector2(6, 18) * size, 180.0, Vector2(3, 9) * size,
		ramp([Color(1, 0.9, 0.6, 1), Color(1, 0.4, 0.1, 0.6), Color(0.3, 0.1, 0.0, 0)]))
	burst(pos, "smoke", 10, 5.0, Vector2(2, 6), 180.0, Vector2(4, 14) * size,
		ramp([Color(0.2, 0.2, 0.2, 0), Color(0.25, 0.24, 0.23, 0.7), Color(0.4, 0.4, 0.4, 0)]), Vector3.UP, wind * 0.4, 1.0, 1.0)
	flash(pos, 10.0 * size, 50.0 * size, Color(1, 0.7, 0.4), 0.2)


func launch_plume(pos: Vector3, up: bool) -> void:
	var d := Vector3.UP if up else Vector3(0, 0.3, 0)
	burst(pos, "smoke", 34, 5.0, Vector2(4, 14), 60.0, Vector2(3.0, 16.0),
		ramp([Color(0.9, 0.88, 0.85, 0.0), Color(0.88, 0.86, 0.84, 0.75), Color(0.85, 0.85, 0.85, 0.0)]), d, wind * 0.4, 1.0, 1.5)
	burst(pos, "fire", 10, 0.5, Vector2(5, 18), 40.0, Vector2(2, 6),
		ramp([Color(1, 0.95, 0.75, 1), Color(1, 0.55, 0.2, 0)]), -d)
	flash(pos, 12.0, 40.0, Color(1, 0.8, 0.5), 0.6)


func depth_bomb(pos: Vector3, size: float) -> void:
	var p := Vector3(pos.x, 0.0, pos.z)
	var s := clampf(size, 0.4, 3.0)
	burst(p, "spray", 30, 3.5, Vector2(10, 30) * s, 20.0, Vector2(4, 12) * s,
		ramp([Color(0.95, 0.97, 1, 0.9), Color(0.9, 0.93, 0.95, 0.0)]), Vector3.UP, Vector3(0, -9.8, 0), 0.3, 4.0 * s)
	burst(p, "spray", 20, 5.0, Vector2(2, 5), 85.0, Vector2(8, 26) * s,
		ramp([Color(0.9, 0.93, 0.95, 0.6), Color(0.9, 0.93, 0.95, 0.0)]), Vector3.UP, wind * 0.3, 1.0, 6.0 * s)


func ground_hit(pos: Vector3, size: float) -> void:
	var s := clampf(size, 0.5, 6.0)
	burst(pos, "fire", 10, 0.5, Vector2(5, 15) * s, 70.0, Vector2(3, 8) * s,
		ramp([Color(1, 0.85, 0.5, 1), Color(0.9, 0.4, 0.1, 0)]))
	burst(pos, "smoke", 18, 8.0, Vector2(4, 14) * s, 50.0, Vector2(5, 22) * s,
		ramp([Color(0.3, 0.26, 0.22, 0), Color(0.32, 0.27, 0.22, 0.85), Color(0.45, 0.42, 0.4, 0)]), Vector3.UP, wind * 0.5, 1.5, 2.0 * s)
	flash(pos + Vector3(0, 3, 0), 10.0 * s, 50.0 * s, Color(1, 0.65, 0.35), 0.25)


func nuke(pos: Vector3, r: float) -> void:
	flash(pos + Vector3(0, r * 0.5, 0), 4000.0, r * 30.0, Color(1, 0.95, 0.9), 3.0)
	burst(pos + Vector3(0, r * 0.3, 0), "fire", 60, 6.0, Vector2(r * 0.05, r * 0.15), 180.0, Vector2(r * 0.25, r * 0.7),
		ramp([Color(1, 1, 0.9, 1), Color(1, 0.6, 0.2, 1), Color(0.6, 0.2, 0.05, 0.8), Color(0.2, 0.1, 0.05, 0)]), Vector3.UP, Vector3(0, r * 0.04, 0), 0.5, r * 0.15)
	burst(pos, "smoke", 80, 40.0, Vector2(r * 0.01, r * 0.03), 20.0, Vector2(r * 0.3, r * 1.2),
		ramp([Color(0.6, 0.5, 0.45, 0), Color(0.55, 0.47, 0.42, 0.9), Color(0.6, 0.58, 0.56, 0.6), Color(0.6, 0.6, 0.6, 0)]), Vector3.UP, Vector3(0, r * 0.05, 0), 0.05, r * 0.2, 0.3)
	burst(pos + Vector3(0, r * 2.5, 0), "smoke", 70, 45.0, Vector2(r * 0.03, r * 0.08), 90.0, Vector2(r * 0.5, r * 1.6),
		ramp([Color(0.7, 0.6, 0.55, 0), Color(0.62, 0.55, 0.5, 0.85), Color(0.7, 0.68, 0.66, 0)]), Vector3.UP, Vector3(0, r * 0.012, 0), 0.08, r * 0.5, 0.15)
	burst(pos, "spray", 90, 12.0, Vector2(r * 0.15, r * 0.25), 88.0, Vector2(r * 0.15, r * 0.5),
		ramp([Color(1, 1, 1, 0.8), Color(0.9, 0.92, 0.95, 0)]), Vector3.UP, Vector3.ZERO, 0.2, r * 0.3)


## Persistent smoke column (and flames) attached to a node; returns the emitters.
func fire_column(parent: Node3D, lpos: Vector3, scale_m: float) -> Array:
	var out := []
	var sm := GPUParticles3D.new()
	sm.amount = 36
	sm.lifetime = 14.0
	sm.local_coords = false
	sm.fixed_fps = 30
	sm.visibility_aabb = AABB(Vector3(-400, -20, -400), Vector3(800, 400, 800))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 9.0
	pm.gravity = wind * 0.6 + Vector3(0, 0.8, 0)
	pm.damping_min = 0.3
	pm.damping_max = 0.6
	pm.scale_min = 4.0 * scale_m
	pm.scale_max = 6.0 * scale_m
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.3))
	sc.add_point(Vector2(1, 1.0))
	var ct := CurveTexture.new()
	ct.curve = sc
	pm.scale_curve = ct
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 2.0 * scale_m
	var gt := GradientTexture1D.new()
	gt.gradient = ramp([Color(0.08, 0.07, 0.06, 0.0), Color(0.09, 0.08, 0.07, 0.8), Color(0.2, 0.2, 0.2, 0.35), Color(0.3, 0.3, 0.3, 0.0)])
	pm.color_ramp = gt
	sm.process_material = pm
	var q := QuadMesh.new()
	q.material = mat("smoke")
	sm.draw_pass_1 = q
	sm.scale_amount_min = 1.0
	parent.add_child(sm)
	sm.position = lpos
	out.append(sm)
	var fl := sm.duplicate() as GPUParticles3D
	fl.amount = 20
	fl.lifetime = 0.9
	var fpm := pm.duplicate() as ParticleProcessMaterial
	fpm.initial_velocity_min = 2.0
	fpm.initial_velocity_max = 5.0
	fpm.gravity = Vector3(0, 3, 0)
	fpm.scale_min = 1.5 * scale_m
	fpm.scale_max = 3.0 * scale_m
	var fgt := GradientTexture1D.new()
	fgt.gradient = ramp([Color(1, 0.8, 0.4, 0.0), Color(1, 0.55, 0.15, 0.95), Color(0.6, 0.15, 0.02, 0.0)])
	fpm.color_ramp = fgt
	fl.process_material = fpm
	var fq := QuadMesh.new()
	fq.material = mat("fire")
	fl.draw_pass_1 = fq
	parent.add_child(fl)
	fl.position = lpos
	out.append(fl)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.55, 0.25)
	lamp.light_energy = 3.0 * scale_m
	lamp.omni_range = 30.0 * scale_m
	parent.add_child(lamp)
	lamp.position = lpos + Vector3(0, 2, 0)
	out.append(lamp)
	return out


## Continuous exhaust from a funnel.
func funnel_smoke(parent: Node3D, lpos: Vector3, dark: bool, size: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 9.0
	p.local_coords = false
	p.fixed_fps = 30
	p.visibility_aabb = AABB(Vector3(-300, -20, -300), Vector3(600, 200, 600))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 7.0
	pm.gravity = wind * 0.5 + Vector3(0, 0.3, 0)
	pm.damping_min = 0.5
	pm.damping_max = 0.8
	pm.scale_min = 2.0 * size
	pm.scale_max = 3.0 * size
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 1.0))
	var ct := CurveTexture.new()
	ct.curve = sc
	pm.scale_curve = ct
	var c := Color(0.25, 0.23, 0.22) if dark else Color(0.6, 0.6, 0.6)
	var gt := GradientTexture1D.new()
	gt.gradient = ramp([Color(c, 0.0), Color(c, 0.32 if dark else 0.14), Color(c.lightened(0.3), 0.0)])
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.material = mat("smoke")
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.position = lpos
	return p


## Missile exhaust and smoke trail; attach to the missile node.
func missile_trail(parent: Node3D, big: bool) -> Array:
	var f := GPUParticles3D.new()
	f.amount = 16
	f.lifetime = 0.15
	f.local_coords = true
	var fpm := ParticleProcessMaterial.new()
	fpm.direction = Vector3(0, 0, 1)
	fpm.spread = 6.0
	fpm.initial_velocity_min = 12.0
	fpm.initial_velocity_max = 20.0
	fpm.scale_min = 0.8 if not big else 1.4
	fpm.scale_max = 1.4 if not big else 2.4
	var fgt := GradientTexture1D.new()
	fgt.gradient = ramp([Color(1, 0.95, 0.8, 1), Color(1, 0.5, 0.15, 0.6), Color(0.5, 0.15, 0.0, 0)])
	fpm.color_ramp = fgt
	f.process_material = fpm
	var fq := QuadMesh.new()
	fq.material = mat("fire")
	f.draw_pass_1 = fq
	parent.add_child(f)
	var s := GPUParticles3D.new()
	s.amount = 90
	s.lifetime = 6.0
	s.local_coords = false
	s.fixed_fps = 30
	s.visibility_aabb = AABB(Vector3(-2000, -200, -2000), Vector3(4000, 2000, 4000))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 5.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 3.0
	pm.gravity = wind * 0.2
	pm.scale_min = 1.2
	pm.scale_max = 2.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.5))
	sc.add_point(Vector2(1, 3.0))
	sc.max_value = 3.0
	var ct := CurveTexture.new()
	ct.curve = sc
	pm.scale_curve = ct
	var gt := GradientTexture1D.new()
	gt.gradient = ramp([Color(0.9, 0.9, 0.9, 0.55), Color(0.85, 0.85, 0.85, 0.25), Color(0.9, 0.9, 0.9, 0)])
	pm.color_ramp = gt
	s.process_material = pm
	var q := QuadMesh.new()
	q.material = mat("smoke")
	s.draw_pass_1 = q
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(s)
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.7, 0.4)
	l.light_energy = 2.0
	l.omni_range = 18.0
	l.position = Vector3(0, 0, 1.0)
	parent.add_child(l)
	return [f, s, l]


## Tracer line segment (CIWS bursts, shell tracers).
func tracer(a: Vector3, b: Vector3, col := Color(1.0, 0.7, 0.3), life := 0.08) -> void:
	var im := ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 6.0
	im.surface_begin(Mesh.PRIMITIVE_LINES, m)
	im.surface_add_vertex(a)
	im.surface_add_vertex(b)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_timed.append([mi, life])


func update(dt: float) -> void:
	var keep := []
	for e in _timed:
		e[1] -= dt
		if e[1] <= 0.0:
			if is_instance_valid(e[0]):
				e[0].queue_free()
		else:
			keep.append(e)
	_timed = keep
	var lk := []
	for l in lights:
		l[1] -= dt
		if l[1] <= 0.0:
			l[0].queue_free()
		else:
			l[0].light_energy = l[3] * (l[1] / l[2])
			lk.append(l)
	lights = lk
