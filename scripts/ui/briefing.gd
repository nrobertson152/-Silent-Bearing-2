extends Control
## Mission briefing, drawn over the showcase of your ship in the mission's own
## weather and light: the situation, intelligence, support, objectives,
## captain's notes and the ship's particulars.

signal sail
signal back

const S := preload("res://scripts/ui/style.gd")
const Fmt := preload("res://scripts/ui/fmt.gd")
const Campaigns := preload("res://scripts/data/campaigns.gd")

const SIDE_NAMES := {"us": "UNITED STATES NAVY", "su": "SOVIET NAVY"}

var def := {}


## kicker: the line above the title, e.g. "MISSION 3 OF 7".
func setup(mission: Dictionary, kicker: String, back_text := "◂  Campaign map") -> void:
	def = mission
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = S.theme()
	var side: String = def.get("side", "us")
	var accent := S.side_color(side)
	# Left: the orders.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", S.box(Color(0.025, 0.033, 0.038, 0.9), S.EDGE, 1, 3, 26))
	panel.anchor_bottom = 1.0
	panel.offset_left = 40.0
	panel.offset_right = 900.0
	panel.offset_top = 40.0
	panel.offset_bottom = -40.0
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)
	outer.add_child(S.label("%s  ·  %s" % [SIDE_NAMES.get(side, ""), kicker], 16, accent, S.heavy()))
	outer.add_child(S.label(String(def.get("title", "")).to_upper(), 50, S.TEXT, S.heavy(), true))
	var when := "%s  ·  %s local  ·  %s" % [Fmt.date(def.get("date", [1988, 9, 1])), Fmt.hhmm(def.get("time", 12.0)), def.get("location", "")]
	outer.add_child(S.label(when, 18, S.BRASS, S.sans(), true))
	outer.add_child(S.label(Fmt.weather(def.get("weather", {})), 16, S.MUTED, S.sans(), true))
	var rule := ColorRect.new()
	rule.color = Color(accent, 0.55)
	rule.custom_minimum_size = Vector2(0, 2)
	outer.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	scroll.add_child(v)
	_section(v, "SITUATION", def.get("briefing", ""))
	if def.get("nuclear_release", false):
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", S.box(Color(0.25, 0.03, 0.02, 0.6), S.ALARM, 2, 2, 14))
		var bl := S.label("SPECIAL WEAPONS RELEASE AUTHORISED.  Nuclear weapons are armed aboard your ship. "
			+ "Using one will be remembered, by your side and by history.", 17, Color(1.0, 0.8, 0.75), S.sans(), true)
		bl.custom_minimum_size = Vector2(780, 0)
		box.add_child(bl)
		v.add_child(box)
	_section(v, "INTELLIGENCE", def.get("intel", ""))
	_section(v, "SUPPORT", def.get("support", ""))
	var objs := []
	for o: Dictionary in def.get("objectives", []):
		objs.append(("○  Optional: " if o.get("optional", false) else "■  ") + String(o["text"]))
	_section(v, "OBJECTIVES", "\n".join(objs))
	_section(v, "CAPTAIN'S NOTES", def.get("tip", ""), S.MUTED)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var bk := S.button(back_text, func(): back.emit(), 18, 230)
	row.add_child(bk)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var go := S.button("SAIL  ▸", func(): sail.emit(), 26, 260)
	go.custom_minimum_size = Vector2(260, 58)
	go.add_theme_color_override("font_color", accent)
	go.add_theme_stylebox_override("normal", S.box(Color(0.08, 0.1, 0.11, 0.95), accent, 2, 3, 14))
	row.add_child(go)
	outer.add_child(row)
	go.grab_focus.call_deferred()
	# Right: the ship.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", S.box(Color(0.025, 0.033, 0.038, 0.86), S.EDGE, 1, 3, 20))
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.offset_left = -640.0
	card.offset_right = -40.0
	card.offset_bottom = -40.0
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 5)
	card.add_child(cv)
	var cls: String = def.get("ship", "")
	cv.add_child(S.label("YOUR SHIP", 14, accent, S.heavy()))
	cv.add_child(S.label(Fmt.ship_name(cls), 30, S.TEXT, S.heavy(), true))
	cv.add_child(S.label(Fmt.ship_type(cls), 17, S.BRASS, S.sans(), true))
	cv.add_child(_gap(4))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 3)
	for sp: Array in Fmt.ship_specs(cls):
		grid.add_child(S.label(sp[0], 15, S.MUTED, S.sans()))
		var val := S.label(sp[1], 15, S.TEXT, S.sans(), true)
		val.custom_minimum_size = Vector2(420, 0)
		grid.add_child(val)
	cv.add_child(grid)
	cv.add_child(_gap(4))
	cv.add_child(S.label("ARMAMENT", 14, accent, S.heavy()))
	for a: String in Fmt.armament(cls):
		var al := S.label("·  " + a, 15, S.TEXT, S.sans(), true)
		al.custom_minimum_size = Vector2(560, 0)
		cv.add_child(al)


func _section(v: VBoxContainer, head: String, body: String, col := S.TEXT) -> void:
	if body == "":
		return
	v.add_child(_gap(4))
	v.add_child(S.label(head, 16, S.BRASS, S.heavy()))
	var l := S.label(body, 19, col, S.sans(), true)
	l.add_theme_constant_override("line_spacing", 4)
	l.custom_minimum_size = Vector2(790, 0)
	v.add_child(l)


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	match ev.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			sail.emit()
		KEY_ESCAPE:
			back.emit()
		_:
			return
	get_viewport().set_input_as_handled()
