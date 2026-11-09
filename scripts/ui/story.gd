extends Control
## Story pages: campaign introductions, situation reports on what the Army,
## the Air Force and the rest of the fleet are doing, and the endings.
## The text types out like a teleprinter; click or Space to hurry it along.
##
## A page is {"kicker": String, "title": String, "blocks": [[heading, text], ...],
##   "big": bool}. An empty heading gives a plain paragraph.

signal done

const S := preload("res://scripts/ui/style.gd")
const CampaignMap := preload("res://scripts/ui/campaign_map.gd")

const CPS := 95.0

var pages := []
var side := "us"
var page := 0
var shown := 0.0
var total := 0
var bodies := []
var col: VBoxContainer
var map
var hint: Label
var t := 0.0
var _over := false
## Called every few characters as the text types out.
var type_sound := Callable()
var _typed := 0


## map_side shows the strategic map behind the text, with front_state.
func setup(story_pages: Array, story_side: String, front_state := {}, highlight := -1) -> void:
	pages = story_pages
	side = story_side
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = S.theme()
	if not front_state.is_empty():
		map = CampaignMap.new()
		map.interactive = false
		map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(map)
		map.setup(side, front_state, -1)
		map.highlight = highlight
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.015, 0.8 if map != null else 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	col = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 14)
	col.set_anchors_preset(Control.PRESET_CENTER_TOP)
	col.custom_minimum_size = Vector2(1060, 0)
	col.offset_left = -530.0
	col.offset_right = 530.0
	col.offset_top = 150.0
	add_child(col)
	hint = S.label("", 16, S.MUTED, S.sans())
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.offset_left = -530.0
	hint.offset_right = 530.0
	hint.offset_top = -70.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	_show(0)


func _show(i: int) -> void:
	page = i
	for c in col.get_children():
		c.queue_free()
	bodies.clear()
	var p: Dictionary = pages[i]
	var accent := S.side_color(side)
	if p.get("kicker", "") != "":
		col.add_child(S.label(p["kicker"], 17, accent, S.mono()))
	if p.get("title", "") != "":
		col.add_child(S.label(p["title"], 54 if not p.get("big", false) else 46, S.TEXT, S.heavy(), true))
	var rule := ColorRect.new()
	rule.color = Color(accent, 0.6)
	rule.custom_minimum_size = Vector2(0, 2)
	col.add_child(rule)
	total = 0
	var first := true
	for b: Array in p.get("blocks", []):
		var head: String = b[0]
		if not first:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 8)
			col.add_child(gap)
		first = false
		if head != "":
			col.add_child(S.label(head, 18, S.BRASS, S.heavy()))
		var body := S.label(b[1], 30 if p.get("big", false) else 23, S.TEXT, S.sans(), true)
		body.add_theme_constant_override("line_spacing", 7)
		body.visible_characters = 0
		col.add_child(body)
		bodies.append(body)
		total += String(b[1]).length()
	shown = 0.0
	_typed = 0
	_update_text()


func _update_text() -> void:
	var left := int(shown)
	for b: Label in bodies:
		var n := b.text.length()
		b.visible_characters = clampi(left, 0, n) if left < n else -1
		left -= n
	var last := page == pages.size() - 1
	if shown < total:
		hint.text = "Click or press Space to show all  ·  Esc to skip"
	else:
		hint.text = ("Click or press Space to continue" if last else "Click or press Space for the next page") + "  ·  %d / %d" % [page + 1, pages.size()]


func _process(delta: float) -> void:
	t += delta
	if shown < total:
		shown = minf(shown + delta * CPS, float(total))
		_update_text()
		if int(shown) - _typed >= 3:
			_typed = int(shown)
			if type_sound.is_valid():
				type_sound.call()


func advance() -> void:
	if shown < total:
		shown = float(total)
		_update_text()
	elif page < pages.size() - 1:
		_show(page + 1)
	else:
		_finish()


func _finish() -> void:
	if not _over:
		_over = true
		done.emit()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	match ev.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_RIGHT:
			advance()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_finish()
			get_viewport().set_input_as_handled()
