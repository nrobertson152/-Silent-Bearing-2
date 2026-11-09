extends Control
## Campaign map screen: the strategic map with the missions, and a panel with
## the mission list and the selected mission's summary.

signal brief(idx: int)
signal intro
signal back

const S := preload("res://scripts/ui/style.gd")
const Save := preload("res://scripts/core/save.gd")
const Campaigns := preload("res://scripts/data/campaigns.gd")
const CampaignMap := preload("res://scripts/ui/campaign_map.gd")
const Fmt := preload("res://scripts/ui/fmt.gd")

const SIDE_NAMES := {"us": "UNITED STATES NAVY  ·  ATLANTIC FLEET", "su": "SOVIET NAVY  ·  NORTHERN FLEET"}

var side := "us"
var sel := 0
var map
var rows := []
var info: VBoxContainer
var brief_btn: Button


func setup(campaign_side: String, selected := -1) -> void:
	side = campaign_side
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = S.theme()
	Save.load_save()
	var unlocked := mini(Save.unlocked(side), Campaigns.count(side) - 1)
	sel = unlocked if selected < 0 else mini(selected, unlocked)
	map = CampaignMap.new()
	map.anchor_right = 1.0
	map.anchor_bottom = 1.0
	map.offset_left = 20.0
	map.offset_top = 62.0
	map.offset_right = -560.0
	map.offset_bottom = -20.0
	add_child(map)
	map.mission_selected.connect(_select)
	var camp := Campaigns.campaign(side)
	var head := VBoxContainer.new()
	head.position = Vector2(34, 16)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)
	var title := S.label("%s  —  %s" % [camp["title"], camp["subtitle"]], 26, S.TEXT, S.heavy())
	head.add_child(title)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", S.box(Color(0.03, 0.04, 0.045, 0.94), S.EDGE, 1, 3, 18))
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -540.0
	panel.offset_right = -20.0
	panel.offset_top = 20.0
	panel.offset_bottom = -20.0
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(S.label(SIDE_NAMES[side], 15, S.side_color(side), S.heavy()))
	var ms: Array = camp["missions"]
	for i in ms.size():
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 18)
		b.toggle_mode = true
		b.pressed.connect(_select.bind(i))
		v.add_child(b)
		rows.append(b)
	v.add_child(_gap(6))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	scroll.add_child(info)
	brief_btn = S.button("OPEN BRIEFING  ▸", func(): brief.emit(sel), 22)
	brief_btn.custom_minimum_size = Vector2(0, 54)
	brief_btn.add_theme_color_override("font_color", S.side_color(side))
	v.add_child(brief_btn)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var a := S.button("The story so far", func(): intro.emit(), 17)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(a)
	var bk := S.button("Main menu", func(): back.emit(), 17)
	bk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bk)
	v.add_child(row)
	_select(sel)


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _select(i: int) -> void:
	var unlocked := Save.unlocked(side)
	if i > unlocked:
		return
	sel = i
	var ms: Array = Campaigns.campaign(side)["missions"]
	var m: Dictionary = ms[i]
	map.setup(side, m.get("front", {}), i)
	for j in rows.size():
		var b: Button = rows[j]
		var done := Save.is_done(side, ms[j]["id"])
		var mark := "✓" if done else ("▸  next" if j == unlocked else ("locked" if j > unlocked else ""))
		b.text = "%d.  %s    %s" % [j + 1, ms[j]["title"], mark]
		b.disabled = j > unlocked
		b.button_pressed = j == i
	for c in info.get_children():
		c.queue_free()
	info.add_child(S.label(m["title"].to_upper(), 30, S.TEXT, S.heavy()))
	info.add_child(S.label("%s  ·  %s local" % [Fmt.date(m["date"]), Fmt.hhmm(m["time"])], 17, S.BRASS, S.sans()))
	info.add_child(S.label(m.get("location", ""), 17, S.MUTED, S.sans(), true))
	info.add_child(S.label("%s, %s" % [Fmt.ship_name(m["ship"]), Fmt.ship_type(m["ship"])], 17, S.side_color(side), S.sans(), true))
	var brief_txt: String = String(m.get("briefing", "")).split("\n\n")[0]
	var bl := S.label(brief_txt, 17, S.TEXT, S.sans(), true)
	bl.custom_minimum_size = Vector2(470, 0)
	info.add_child(bl)
	var res: Dictionary = Save.side_data(side)["results"].get(m["id"], {})
	if not res.is_empty():
		info.add_child(S.label("Completed: %d enemy ships sunk, %d missiles and aircraft shot down." % [int(res.get("kills", 0)), int(res.get("intercepts", 0))], 16, S.GOOD, S.sans(), true))
	brief_btn.disabled = i > unlocked


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed:
		return
	match ev.keycode:
		KEY_UP:
			_select(maxi(0, sel - 1))
		KEY_DOWN:
			_select(mini(Save.unlocked(side), mini(rows.size() - 1, sel + 1)))
		KEY_ENTER, KEY_KP_ENTER:
			brief.emit(sel)
		KEY_ESCAPE:
			back.emit()
		_:
			return
	get_viewport().set_input_as_handled()
