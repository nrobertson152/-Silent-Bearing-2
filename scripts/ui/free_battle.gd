extends Control
## Free battle setup: any ship, any kind of fight, place, time and sea.

signal start(def: Dictionary)
signal ship_changed(cls: String)
signal back

const S := preload("res://scripts/ui/style.gd")
const ShipData := preload("res://scripts/data/ships.gd")
const Skirmish := preload("res://scripts/data/skirmish.gd")
const Fmt := preload("res://scripts/ui/fmt.gd")

var ships := []
var ship_opt: OptionButton
var kind_opt: OptionButton
var place_opt: OptionButton
var time_opt: OptionButton
var sea: HSlider
var sea_label: Label
var kind_desc: Label
var ship_desc: Label
var nuke: CheckButton
var nuke_note: Label


func setup(cls := "dd963") -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = S.theme()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", S.box(Color(0.025, 0.033, 0.038, 0.9), S.EDGE, 1, 3, 26))
	panel.position = Vector2(40, 40)
	panel.custom_minimum_size = Vector2(760, 0)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(S.label("FREE BATTLE", 46, S.TEXT, S.heavy()))
	ship_opt = OptionButton.new()
	for side: String in ["us", "su"]:
		for id: String in ShipData.ORDER[side]:
			ships.append(id)
			ship_opt.add_item("%s  —  %s" % [Fmt.ship_name(id), Fmt.ship_type(id)])
	ship_opt.selected = maxi(0, ships.find(cls))
	ship_opt.item_selected.connect(func(i: int):
		_describe()
		ship_changed.emit(ships[i]))
	_field(v, "Your ship", ship_opt)
	ship_desc = S.label("", 15, S.MUTED, S.sans(), true)
	ship_desc.custom_minimum_size = Vector2(700, 0)
	v.add_child(ship_desc)
	kind_opt = OptionButton.new()
	for k: Array in Skirmish.KINDS:
		kind_opt.add_item(k[1])
	kind_opt.item_selected.connect(func(_i: int): _describe())
	_field(v, "Battle", kind_opt)
	kind_desc = S.label("", 15, S.MUTED, S.sans(), true)
	v.add_child(kind_desc)
	place_opt = OptionButton.new()
	for p: Array in Skirmish.PLACES:
		place_opt.add_item(p[0])
	_field(v, "Waters", place_opt)
	time_opt = OptionButton.new()
	for t: Array in Skirmish.TIMES:
		time_opt.add_item(t[0])
	time_opt.selected = 2
	_field(v, "Time of day", time_opt)
	sea = HSlider.new()
	sea.min_value = 1
	sea.max_value = 7
	sea.step = 1
	sea.value = 3
	sea.custom_minimum_size = Vector2(500, 30)
	sea_label = S.label("", 17, S.TEXT, S.sans())
	sea.value_changed.connect(func(_x: float): _describe())
	_field(v, "Sea state", sea)
	v.add_child(sea_label)
	nuke = CheckButton.new()
	nuke.text = "Nuclear release authorised"
	nuke.add_theme_font_size_override("font_size", 18)
	v.add_child(nuke)
	nuke_note = S.label("The battleships carry nuclear weapons: 16-inch W23 shells and TLAM-N on Missouri, Granit missiles on Sovetsky Soyuz. "
		+ "With release authorised, turn both keys on the bridge's special weapons panel before firing.", 15, S.MUTED, S.sans(), true)
	nuke_note.custom_minimum_size = Vector2(700, 0)
	v.add_child(nuke_note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(S.button("◂  Main menu", func(): back.emit(), 18, 220))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var go := S.button("BATTLE STATIONS  ▸", _go, 22, 300)
	go.custom_minimum_size = Vector2(300, 56)
	row.add_child(go)
	v.add_child(row)
	_describe()


func _field(v: VBoxContainer, label: String, c: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := S.label(label, 19, S.BRASS, S.sans())
	l.custom_minimum_size = Vector2(170, 0)
	row.add_child(l)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(c)
	v.add_child(row)


func _describe() -> void:
	var cls: String = ships[ship_opt.selected]
	ship_desc.text = "  ·  ".join(PackedStringArray(Fmt.armament(cls).slice(0, 4)))
	kind_desc.text = Skirmish.KINDS[kind_opt.selected][2]
	var s := int(sea.value)
	sea_label.text = ["", "1: calm, rippled", "2: smooth, wavelets", "3: slight", "4: moderate", "5: rough", "6: very rough", "7: high"][s] + \
		"  (waves around %.1f m)" % [0.05, 0.15, 0.4, 0.9, 1.9, 3.2, 5.0, 7.5][s]
	var bb := cls in ["bb61", "sovsoyuz"]
	nuke.visible = bb
	nuke_note.visible = bb


func _go() -> void:
	var cls: String = ships[ship_opt.selected]
	var def := Skirmish.build(cls, Skirmish.KINDS[kind_opt.selected][0], place_opt.selected, time_opt.selected, sea.value)
	if nuke.visible and nuke.button_pressed:
		def["nuclear_release"] = true
	start.emit(def)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		back.emit()
		get_viewport().set_input_as_handled()
