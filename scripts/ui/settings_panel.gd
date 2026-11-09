extends Control
## Settings overlay: graphics quality, display, sound, controls, difficulty.

signal closed
signal changed

const S := preload("res://scripts/ui/style.gd")
const Settings := preload("res://scripts/core/settings.gd")

const DIFFICULTY := ["Recruit (your ships take 30% less damage)", "Regular", "Veteran (your ships take 25% more damage)"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = S.theme()
	Settings.load_settings()
	var shade := ColorRect.new()
	shade.color = Color(0, 0.008, 0.012, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", S.box(Color(0.03, 0.04, 0.045, 0.97), S.EDGE, 1, 3, 30))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(760, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(S.label("SETTINGS", 40, S.TEXT, S.heavy()))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 14)
	v.add_child(grid)
	var q := OptionButton.new()
	for i in Settings.QUALITY.size():
		q.add_item(Settings.QUALITY[i], i)
	q.selected = Settings.quality
	q.item_selected.connect(func(i: int):
		Settings.quality = i
		_apply())
	_row(grid, "Graphics quality", q)
	var fs := CheckButton.new()
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(func(on: bool):
		Settings.fullscreen = on
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
		_apply())
	_row(grid, "Fullscreen", fs)
	_row(grid, "Volume", _slider(0.0, 1.0, Settings.volume, func(x: float):
		Settings.volume = x
		_apply()))
	_row(grid, "Mouse sensitivity", _slider(0.25, 3.0, Settings.mouse_sens, func(x: float):
		Settings.mouse_sens = x
		_apply()))
	var inv := CheckButton.new()
	inv.button_pressed = Settings.invert_y
	inv.toggled.connect(func(on: bool):
		Settings.invert_y = on
		_apply())
	_row(grid, "Invert mouse Y", inv)
	var d := OptionButton.new()
	for i in DIFFICULTY.size():
		d.add_item(DIFFICULTY[i], i)
	d.selected = Settings.difficulty
	d.item_selected.connect(func(i: int):
		Settings.difficulty = i
		_apply())
	_row(grid, "Difficulty", d)
	v.add_child(S.label("Quality sets shadows, reflections, ambient occlusion, volumetric fog and wave detail. "
		+ "Difficulty applies from the next mission.", 15, S.MUTED, S.sans(), true))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	var ok := S.button("Done", func(): closed.emit(), 20, 180)
	row.add_child(ok)
	v.add_child(row)
	ok.grab_focus.call_deferred()


func _row(grid: GridContainer, label: String, c: Control) -> void:
	grid.add_child(S.label(label, 19, S.TEXT, S.sans()))
	c.custom_minimum_size = Vector2(380, 36)
	grid.add_child(c)


func _slider(lo: float, hi: float, val: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = val
	s.value_changed.connect(cb)
	return s


func _apply() -> void:
	Settings.save()
	Settings.apply_viewport(get_viewport())
	changed.emit()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()
