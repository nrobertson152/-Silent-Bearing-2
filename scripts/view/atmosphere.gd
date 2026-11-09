extends Node3D
## Sky, sun, moon, fog and post-processing. Drives the ocean's lighting too.
## weather: {sea, wind (deg the wind blows from), vis (km), clouds (0..1),
##           dark (storm 0..1), aurora (0..1)}

const U := preload("res://scripts/util.gd")
const Settings := preload("res://scripts/core/settings.gd")
const SKY_SHADER := preload("res://shaders/sky.gdshader")

var env: Environment
var we: WorldEnvironment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var ocean
var weather := {"sea": 3.0, "wind": 250.0, "vis": 30.0, "clouds": 0.4, "dark": 0.0, "aurora": 0.0}
var sun_dir := Vector3(0.3, 0.6, -0.7)
var sun_el := 30.0
var lat := 60.0
var day := 240
var hour := 12.0


func _init() -> void:
	name = "Atmosphere"
	env = Environment.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 1.0
	env.fog_sun_scatter = 0.08
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.6
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.6
	env.volumetric_fog_density = 0.0016
	env.volumetric_fog_anisotropy = 0.72
	env.volumetric_fog_length = 360.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_albedo = Color(0.92, 0.94, 0.96)
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.05
	we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 1400.0
	sun.directional_shadow_split_1 = 0.04
	sun.directional_shadow_split_2 = 0.13
	sun.directional_shadow_split_3 = 0.38
	sun.directional_shadow_blend_splits = true
	sun.shadow_normal_bias = 1.2
	sun.shadow_bias = 0.04
	sun.light_angular_distance = 0.5
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.62, 0.7, 0.9)
	moon.shadow_enabled = false
	add_child(moon)


func setup(w: Dictionary, latitude: float, day_of_year: int, hour_of_day: float, sea_node = null) -> void:
	for key in w:
		weather[key] = w[key]
	lat = latitude
	day = day_of_year
	hour = hour_of_day
	ocean = sea_node
	apply_quality()
	_apply_weather()
	set_time(hour)


func apply_quality() -> void:
	var q := Settings.quality
	env.ssao_enabled = q >= 1
	env.ssr_enabled = q >= 2
	env.ssr_max_steps = 32 if q == 2 else 64
	env.ssil_enabled = q >= 3
	env.volumetric_fog_enabled = q >= 2
	env.sdfgi_enabled = false
	env.glow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q >= 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = [500.0, 900.0, 1400.0, 2000.0][q]
	if ocean:
		ocean.set_detail([0.4, 0.7, 1.0, 1.0][q])


func _apply_weather() -> void:
	var vis_m: float = maxf(float(weather["vis"]), 0.5) * 1000.0
	env.fog_density = 2.2 / vis_m
	env.volumetric_fog_density = 0.00012 + 0.0025 / maxf(float(weather["vis"]), 1.0)
	sky_mat.set_shader_parameter("cloud_cover", weather["clouds"])
	sky_mat.set_shader_parameter("cloud_dark", weather["dark"])
	sky_mat.set_shader_parameter("haze", clampf(8.0 / maxf(float(weather["vis"]), 1.0), 0.1, 1.0))
	sky_mat.set_shader_parameter("aurora", weather.get("aurora", 0.0))
	if ocean:
		var wd := deg_to_rad(float(weather["wind"]) + 180.0)
		ocean.set_sea(float(weather["sea"]), Vector2(sin(wd), -cos(wd)))


## Local solar time in hours.
func set_time(h: float) -> void:
	hour = fposmod(h, 24.0)
	var sp := U.sun_position(lat, day, hour)
	sun_el = sp.x
	sun_dir = U.sky_dir(sp.x, sp.y)
	var moon_dir := U.sky_dir(clampf(25.0 - sp.x * 0.3, 8.0, 50.0), fposmod(sp.y + 160.0, 360.0))
	sky_mat.set_shader_parameter("sun_dir", sun_dir)
	sky_mat.set_shader_parameter("moon_dir", moon_dir)
	var e := sin(deg_to_rad(sun_el))
	var day_f := smoothstep(-0.06, 0.2, e)
	var low := 1.0 - smoothstep(0.0, 0.45, e)
	var cloud := float(weather["clouds"])
	var sun_col := Color(1.0, 0.94, 0.86).lerp(Color(1.0, 0.56, 0.28), low)
	sun.light_color = sun_col
	sun.light_energy = 2.4 * day_f * (1.0 - cloud * 0.55) * (1.0 - float(weather["dark"]) * 0.5)
	sun.visible = sun.light_energy > 0.01
	sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.FORWARD)
	moon.light_energy = 0.16 * (1.0 - day_f) * (1.0 - cloud * 0.6)
	moon.visible = moon.light_energy > 0.005
	if moon.visible:
		moon.look_at_from_position(Vector3.ZERO, -moon_dir, Vector3.UP)
	env.ambient_light_energy = lerpf(0.35, 1.0, day_f)
	env.tonemap_exposure = lerpf(2.6, 1.0, day_f)
	var hor_day := Color(0.66, 0.74, 0.82).lerp(Color(0.6, 0.6, 0.62), float(weather["dark"]))
	var hor := Color(0.02, 0.028, 0.045).lerp(hor_day, day_f)
	hor = hor.lerp(Color(0.85, 0.55, 0.38), low * day_f * 0.35)
	env.fog_light_color = hor
	env.fog_light_energy = 1.0
	env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	if ocean:
		ocean.set_sun(sun_dir, sun_col, maxf(sun.light_energy, 0.05))
		var deep := Color(0.010, 0.040, 0.065).lerp(Color(0.003, 0.008, 0.014), 1.0 - day_f)
		var scat := Color(0.03, 0.20, 0.22) if lat < 55.0 else Color(0.03, 0.15, 0.17)
		ocean.set_colors(deep, scat * lerpf(0.15, 1.0, day_f), Color(0.02, 0.09, 0.12) * lerpf(0.1, 1.0, day_f))


func update(time_s: float) -> void:
	sky_mat.set_shader_parameter("t", time_s)


func is_night() -> bool:
	return sun_el < -4.0
