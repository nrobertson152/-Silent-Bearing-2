extends Control
## After-action report: the result, objectives, and what your ship did.

signal choice(what: String)

const S := preload("res://scripts/ui/style.gd")
const Fmt := preload("res://scripts/ui/fmt.gd")

const RESULT_TEXT := {"won": "MISSION ACCOMPLISHED", "lost": "MISSION FAILED", "sunk": "SHIP LOST", "abandoned": "MISSION ABANDONED"}


## info: {kicker, title, result, why, objectives: [[mark, text, state, optional]],
##   stats, time, hull, side, buttons: [[label, what], ...]}
func setup(info: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = S.theme()
	var shade := ColorRect.new()
	shade.color = Color(0, 0.008, 0.012, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var res: String = info.get("result", "lost")
	var good := res == "won"
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", S.box(Color(0.025, 0.033, 0.038, 0.95), S.GOOD if good else S.ALARM, 1, 3, 30))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1000, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(S.label(info.get("kicker", ""), 16, S.side_color(info.get("side", "us")), S.heavy()))
	v.add_child(S.label(RESULT_TEXT.get(res, res.to_upper()), 56, S.GOOD if good else S.ALARM, S.heavy()))
	v.add_child(S.label("%s.  %s" % [info.get("title", ""), info.get("why", "")], 19, S.TEXT, S.sans(), true))
	var rule := ColorRect.new()
	rule.color = S.EDGE
	rule.custom_minimum_size = Vector2(0, 1)
	v.add_child(rule)
	v.add_child(S.label("OBJECTIVES", 15, S.BRASS, S.heavy()))
	for o: Array in info.get("objectives", []):
		var st: String = o[2]
		var col := S.GOOD if st == "done" else (S.ALARM if st == "failed" else S.MUTED)
		var mark := "✓" if st == "done" else ("✗" if st == "failed" else "–")
		var txt := "%s  %s%s" % [mark, ("(optional) " if o[3] else ""), o[1]]
		v.add_child(S.label(txt, 18, col, S.sans(), true))
	v.add_child(_gap(4))
	v.add_child(S.label("YOUR SHIP", 15, S.BRASS, S.heavy()))
	var st: Dictionary = info.get("stats", {})
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 6)
	var shots := int(st.get("shots", 0))
	var hits := int(st.get("hits", 0))
	var cells := [
		["Time in action", Fmt.duration(float(info.get("time", 0.0)))],
		["Ship condition", "%d%%" % int(round(float(info.get("hull", 1.0)) * 100.0))],
		["Enemy ships sunk", str(int(st.get("kills", 0)))],
		["Missiles and aircraft shot down", str(int(st.get("intercepts", 0)))],
		["Rounds fired", str(shots)],
		["Hits", "%d%s" % [hits, (" (%d%%)" % int(round(100.0 * hits / shots))) if shots > 0 else ""]],
		["Missiles and torpedoes launched", str(int(st.get("missiles", 0)))],
		["Nuclear weapons used", str(int(st.get("nuclear", 0)))],
	]
	for c: Array in cells:
		var cv := VBoxContainer.new()
		cv.add_child(S.label(c[0], 14, S.MUTED, S.sans()))
		cv.add_child(S.label(c[1], 24, S.TEXT, S.heavy()))
		grid.add_child(cv)
	v.add_child(grid)
	v.add_child(_gap(10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	var first: Button = null
	for b: Array in info.get("buttons", []):
		var what: String = b[1]
		var btn := S.button(b[0], func(): choice.emit(what), 20, 200)
		row.add_child(btn)
		if first == null:
			first = btn
	v.add_child(row)
	if first != null:
		first.grab_focus.call_deferred()


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
