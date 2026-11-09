extends RefCounted
## Player settings, saved to user://settings.cfg.

const PATH := "user://settings.cfg"
const QUALITY := ["Low", "Medium", "High", "Ultra"]

static var quality := 2
static var volume := 0.8
static var music := 0.5
static var mouse_sens := 1.0
static var invert_y := false
static var fullscreen := false
static var difficulty := 1
static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	quality = cf.get_value("video", "quality", quality)
	fullscreen = cf.get_value("video", "fullscreen", fullscreen)
	volume = cf.get_value("audio", "volume", volume)
	music = cf.get_value("audio", "music", music)
	mouse_sens = cf.get_value("input", "mouse_sens", mouse_sens)
	invert_y = cf.get_value("input", "invert_y", invert_y)
	difficulty = cf.get_value("game", "difficulty", difficulty)


static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("video", "quality", quality)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.set_value("audio", "volume", volume)
	cf.set_value("audio", "music", music)
	cf.set_value("input", "mouse_sens", mouse_sens)
	cf.set_value("input", "invert_y", invert_y)
	cf.set_value("game", "difficulty", difficulty)
	cf.save(PATH)


## Viewport-wide settings for the chosen quality level.
static func apply_viewport(vp: Viewport) -> void:
	var q := quality
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q >= 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.positional_shadow_atlas_size = [1024, 2048, 4096, 4096][q]
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 4096, 8192][q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD,
		RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q])
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
