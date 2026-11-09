extends Control
## Main menu, drawn over the 3D showcase: the two campaigns with their
## progress, free battle, settings and quit.

signal action(what: String, side: String)

const S := preload("res://scripts/ui/style.gd")
const Save := preload("res://scripts/core/save.gd")
const Campaigns := preload("res://scripts/data/campaigns.gd")
const Fmt := preload("res://scripts/ui/fmt.gd")

const SIDE_NAMES := {"us": "UNITED STATES NAVY", "su": "SOVIET NAVY"}

var _armed := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = S.theme()
	resized.connect(queue_redraw)
	Save.load_save()
	var col := VBoxContainer.new()
	col.position = Vector2(96, 92)
	col.custom_minimum_size = Vector2(660, 0)
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	col.add_child(S.label("SILENT BEARING 2", 82, S.TEXT, S.heavy()))
	col.add_child(S.label("THE COLD WAR HAS GONE HOT  ·  NORTH ATLANTIC, 1988", 21, S.BRASS, S.sans()))
	col.add_child(_gap(34))
	for side: String in ["us", "su"]:
		col.add_child(_campaign_card(side))
	col.add_child(_gap(8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(S.button("Free battle", func(): action.emit("free", ""), 20, 210))
	row.add_child(S.button("Settings", func(): action.emit("settings", ""), 20, 180))
	row.add_child(S.button("Quit", func(): action.emit("quit", ""), 20, 140))
	col.add_child(row)
	var foot := S.label("Silent Bearing 2 · v0.1  ·  GPL-3.0  ·  every model, sound and map is generated in code", 15, S.MUTED, S.sans())
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_top = -46.0
	foot.offset_bottom = -20.0
	foot.offset_left = 96.0
	add_child(foot)


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _campaign_card(side: String) -> Control:
	var camp := Campaigns.campaign(side)
	var col := S.side_color(side)
	var card := PanelContainer.new()
	var sb := S.box(Color(0.03, 0.04, 0.045, 0.82), Color(col, 0.55), 1, 3, 18)
	sb.border_width_left = 6
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	v.add_child(S.label(SIDE_NAMES[side], 16, col, S.heavy()))
	v.add_child(S.label(camp["title"], 40, S.TEXT, S.heavy()))
	var n := Campaigns.count(side)
	var done := Save.unlocked(side)
	var status := ""
	if Save.side_data(side).get("finished", false):
		status = "Campaign complete. Every mission can be replayed from the map."
	elif done == 0:
		var first := Campaigns.mission(side, 0)
		status = "%d missions, frigate to battleship. Begins %s aboard %s." % [n, Fmt.date(first["date"]), Fmt.ship_name(first["ship"])]
	else:
		var m := Campaigns.mission(side, done)
		status = "Mission %d of %d: %s, aboard %s" % [done + 1, n, m["title"], Fmt.ship_name(m["ship"])]
	v.add_child(S.label(status, 18, S.MUTED, S.sans(), true))
	var bar := _progress(side, done, n)
	v.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var go := S.button("Continue campaign" if done > 0 else "Begin campaign", func(): action.emit("campaign", side), 20, 250)
	row.add_child(go)
	if done > 0:
		var rb := Button.new()
		rb.text = "Start over"
		rb.add_theme_font_size_override("font_size", 16)
		rb.custom_minimum_size = Vector2(150, 0)
		rb.pressed.connect(func(): _restart(side, rb))
		row.add_child(rb)
	v.add_child(row)
	return card


func _progress(side: String, done: int, n: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(600, 14)
	var col := S.side_color(side)
	c.draw.connect(func():
		var w := c.size.x / n
		for i in n:
			var r := Rect2(Vector2(i * w + 1, 3), Vector2(w - 4, 8))
			c.draw_rect(r, col if i < done else Color(0.18, 0.2, 0.2), true)
	)
	return c


func _restart(side: String, b: Button) -> void:
	if _armed.get(side, false):
		Save.reset(side)
		action.emit("refresh", side)
		return
	_armed[side] = true
	b.text = "Erase progress?"
	b.add_theme_color_override("font_color", S.ALARM)


func _draw() -> void:
	# Darken the left of the screen so the text reads over the sea and sky.
	var h := size.y
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(1050, 0), Vector2(1050, h), Vector2(0, h)])
	var cols := PackedColorArray([Color(0, 0.01, 0.02, 0.78), Color(0, 0.01, 0.02, 0.0), Color(0, 0.01, 0.02, 0.0), Color(0, 0.01, 0.02, 0.78)])
	draw_polygon(pts, cols)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		_armed.clear()
