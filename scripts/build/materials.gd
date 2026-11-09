extends RefCounted
## Shared materials, cached per navy so every ship of a side reuses them.

const PAINT := preload("res://shaders/paint.gdshader")
const DECK := preload("res://shaders/deck.gdshader")

const NAVY := {
	"us": {"paint": Color(0.47, 0.505, 0.535), "super": Color(0.50, 0.535, 0.565), "deck": Color(0.20, 0.21, 0.22),
		"boot": Color(0.045, 0.045, 0.05), "bottom": Color(0.36, 0.12, 0.09), "weather": 0.45},
	"su": {"paint": Color(0.53, 0.575, 0.61), "super": Color(0.56, 0.60, 0.635), "deck": Color(0.29, 0.20, 0.165),
		"boot": Color(0.05, 0.05, 0.055), "bottom": Color(0.42, 0.14, 0.10), "weather": 0.6},
	"merchant": {"paint": Color(0.16, 0.20, 0.26), "super": Color(0.86, 0.84, 0.78), "deck": Color(0.34, 0.20, 0.16),
		"boot": Color(0.08, 0.08, 0.08), "bottom": Color(0.48, 0.15, 0.10), "weather": 0.8},
}

static var _cache := {}


static func std(color: Color, rough := 0.8, metal := 0.0, emit := Color.BLACK, emit_e := 0.0, cull := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if not cull:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_e
	return m


static func paint(base: Color, hull: bool, n: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PAINT
	m.set_shader_parameter("paint", base)
	m.set_shader_parameter("boot", n["boot"])
	m.set_shader_parameter("bottom", n["bottom"])
	m.set_shader_parameter("hull", 1.0 if hull else 0.0)
	m.set_shader_parameter("weather", n["weather"])
	if not hull:
		m.set_shader_parameter("plate_h", 1.4)
		m.set_shader_parameter("frame_l", 3.0)
		m.set_shader_parameter("dish", 0.02)
	return m


## Full material set for a navy ("us", "su" or "merchant").
static func navy(side: String) -> Dictionary:
	if _cache.has(side):
		return _cache[side]
	var n: Dictionary = NAVY.get(side, NAVY["us"])
	var d := {}
	d["hull"] = paint(n["paint"], true, n)
	d["super"] = paint(n["super"], false, n)
	var deck := ShaderMaterial.new()
	deck.shader = DECK
	deck.set_shader_parameter("deck_col", n["deck"])
	deck.set_shader_parameter("weather", n["weather"])
	d["deck"] = deck
	var wood := ShaderMaterial.new()
	wood.shader = DECK
	wood.set_shader_parameter("wood", 1.0)
	wood.set_shader_parameter("weather", n["weather"])
	d["wood"] = wood
	var shared := common()
	for k in shared:
		d[k] = shared[k]
	d["pale"] = std(Color(n["super"]).lightened(0.12), 0.7)
	_cache[side] = d
	return d


## Materials that do not depend on the navy.
static func common() -> Dictionary:
	if _cache.has("_common"):
		return _cache["_common"]
	var d := {
		"dark": std(Color(0.17, 0.18, 0.19), 0.45, 0.55),
		"gun": std(Color(0.30, 0.32, 0.33), 0.5, 0.35),
		"black": std(Color(0.025, 0.025, 0.028), 0.75),
		"soot": std(Color(0.05, 0.045, 0.04), 0.95),
		"glass": std(Color(0.05, 0.08, 0.10), 0.04, 0.4),
		"white": std(Color(0.86, 0.86, 0.84), 0.6),
		"red": std(Color(0.62, 0.08, 0.06), 0.6),
		"yellow": std(Color(0.85, 0.66, 0.12), 0.6),
		"orange": std(Color(0.92, 0.42, 0.10), 0.65),
		"radar": std(Color(0.66, 0.68, 0.69), 0.55, 0.2),
		"dome": std(Color(0.88, 0.88, 0.85), 0.45),
		"canvas": std(Color(0.70, 0.69, 0.63), 0.98),
		"rubber": std(Color(0.06, 0.06, 0.065), 0.9),
		"brass": std(Color(0.80, 0.62, 0.32), 0.3, 1.0),
		"steel": std(Color(0.62, 0.63, 0.64), 0.32, 0.85),
		"chrome": std(Color(0.85, 0.86, 0.88), 0.12, 1.0),
		"wire": std(Color(0.12, 0.12, 0.12), 0.6, 0.5, Color.BLACK, 0.0, false),
		"lamp_r": std(Color(1, 0.2, 0.15), 0.4, 0.0, Color(1, 0.1, 0.05), 6.0),
		"lamp_g": std(Color(0.2, 1, 0.3), 0.4, 0.0, Color(0.1, 1, 0.3), 6.0),
		"lamp_w": std(Color(1, 1, 0.9), 0.4, 0.0, Color(1, 0.95, 0.8), 6.0),
		"sub": std(Color(0.035, 0.037, 0.04), 0.88),
		"sub_red": std(Color(0.22, 0.07, 0.06), 0.9),
		"prop": std(Color(0.72, 0.55, 0.30), 0.25, 1.0),
	}
	_cache["_common"] = d
	return d
