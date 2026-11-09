extends Control
## In-mission pause menu, with the mission objectives and the controls.

signal choice(what: String)

const S := preload("res://scripts/ui/style.gd")
const Hud := preload("res://scripts/ui/hud.gd")

var controls: PanelContainer


func setup(title: String, objective_lines: Array, can_restart := true) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = S.theme()
	var shade := ColorRect.new()
	shade.color = Color(0, 0.008, 0.012, 0.66)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.position = Vector2(120, 150)
	v.custom_minimum_size = Vector2(520, 0)
	add_child(v)
	v.add_child(S.label("PAUSED", 64, S.TEXT, S.heavy()))
	v.add_child(S.label(title, 22, S.BRASS, S.sans(), true))
	v.add_child(_gap(8))
	for o: Array in objective_lines:
		var st: String = o[2]
		var col := S.GOOD if st == "done" else (S.ALARM if st == "failed" else S.TEXT)
		v.add_child(S.label("%s  %s%s" % [o[0], "(optional) " if o[3] else "", o[1]], 17, col, S.sans(), true))
	v.add_child(_gap(16))
	var resume := S.button("Resume", func(): choice.emit("resume"), 21, 320)
	v.add_child(resume)
	if can_restart:
		v.add_child(S.button("Restart mission", func(): choice.emit("restart"), 19, 320))
	v.add_child(S.button("Controls", func(): controls.visible = not controls.visible, 19, 320))
	v.add_child(S.button("Settings", func(): choice.emit("settings"), 19, 320))
	v.add_child(S.button("Abandon mission", func(): choice.emit("abandon"), 19, 320))
	resume.grab_focus.call_deferred()
	controls = PanelContainer.new()
	controls.add_theme_stylebox_override("panel", S.box(Color(0.03, 0.04, 0.045, 0.94), S.EDGE, 1, 3, 26))
	controls.position = Vector2(760, 110)
	add_child(controls)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 2)
	controls.add_child(cv)
	for l: String in Hud.HELP:
		if l == "CONTROLS":
			cv.add_child(S.label(l, 24, S.AMBER, S.heavy()))
		else:
			cv.add_child(S.label(l, 16, S.TEXT, S.mono()))
	controls.visible = false


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE:
		choice.emit("resume")
		get_viewport().set_input_as_handled()
