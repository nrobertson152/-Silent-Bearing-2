extends RefCounted
## Colours, fonts and widget helpers for the interface.

const BG := Color(0.035, 0.045, 0.05, 0.86)
const PANEL := Color(0.06, 0.075, 0.08, 0.78)
const EDGE := Color(0.32, 0.38, 0.36, 0.7)
const TEXT := Color(0.86, 0.87, 0.82)
const MUTED := Color(0.55, 0.6, 0.58)
const PHOS := Color(0.45, 0.95, 0.62)
const AMBER := Color(1.0, 0.72, 0.28)
const ALARM := Color(1.0, 0.33, 0.25)
const GOOD := Color(0.55, 0.9, 0.5)
const US_BLUE := Color(0.45, 0.66, 1.0)
const SU_RED := Color(1.0, 0.4, 0.33)
const BRASS := Color(0.82, 0.66, 0.36)

## Called on every button press made with button(); main sets it to a click.
static var on_click := Callable()
static var _mono: Font
static var _sans: Font
static var _stencil: Font


static func mono() -> Font:
	if _mono == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Lucida Console", "Liberation Mono", "Courier New", "monospace"])
		f.multichannel_signed_distance_field = true
		_mono = f
	return _mono


static func sans() -> Font:
	if _sans == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["DejaVu Sans", "Segoe UI", "Arial", "Liberation Sans", "Helvetica", "sans-serif"])
		f.multichannel_signed_distance_field = true
		_sans = f
	return _sans


static func heavy() -> Font:
	if _stencil == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["DejaVu Sans Condensed", "Arial Narrow", "Impact", "Liberation Sans Narrow", "DejaVu Sans", "sans-serif"])
		f.font_weight = 800
		f.multichannel_signed_distance_field = true
		_stencil = f
	return _stencil


static func side_color(side: String) -> Color:
	return US_BLUE if side == "us" else SU_RED


static func box(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 3, pad := 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	return s


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = sans()
	t.default_font_size = 18
	t.set_stylebox("normal", "Button", box(Color(0.1, 0.12, 0.13, 0.92), EDGE, 1, 3, 12))
	t.set_stylebox("hover", "Button", box(Color(0.16, 0.19, 0.2, 0.95), BRASS, 1, 3, 12))
	t.set_stylebox("pressed", "Button", box(Color(0.22, 0.2, 0.14, 0.95), BRASS, 2, 3, 12))
	t.set_stylebox("disabled", "Button", box(Color(0.07, 0.08, 0.085, 0.8), Color(0.2, 0.22, 0.22), 1, 3, 12))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), BRASS, 1, 3, 12))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.8))
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.42, 0.4))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, EDGE, 1, 3, 14))
	t.set_stylebox("panel", "Panel", box(PANEL, EDGE, 1, 3, 14))
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("slider", "HSlider", box(Color(0.15, 0.17, 0.17), Color(0, 0, 0, 0), 0, 2, 3))
	return t


static func label(text: String, size := 18, color := TEXT, font: Font = null, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, cb: Callable, size := 18, min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func():
		if on_click.is_valid():
			on_click.call())
	b.pressed.connect(cb)
	if min_w > 0.0:
		b.custom_minimum_size = Vector2(min_w, 0)
	return b


static func text(ci: CanvasItem, s: String, pos: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, font: Font = null) -> void:
	var f := font if font != null else mono()
	ci.draw_string(f, pos, s, align, width, size, col)


static func panel(ci: CanvasItem, r: Rect2, col := PANEL) -> void:
	ci.draw_rect(r, col)
	ci.draw_rect(r, EDGE, false, 1.0)
