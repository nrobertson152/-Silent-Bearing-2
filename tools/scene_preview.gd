extends SceneTree
## Renders a ship at sea with the full sky, ocean and lighting.
## xvfb-run godot --path . -s tools/scene_preview.gd -- <out.png> <class> <hour> <sea> [view] [lat] [clouds]

const ShipBuilder := preload("res://scripts/build/ship_builder.gd")
const ShipData := preload("res://scripts/data/ships.gd")
const Ocean := preload("res://scripts/view/ocean.gd")
const Atmos := preload("res://scripts/view/atmosphere.gd")
const Settings := preload("res://scripts/core/settings.gd")

var out := "/tmp/scene.png"
var frame := 0
var cam: Camera3D
var ship: Node3D
var ocean
var atm
var t := 0.0
var L := 100.0
var view := "quarter"


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else out
	var id: String = a[1] if a.size() > 1 else "ffg7"
	var hour := float(a[2]) if a.size() > 2 else 14.0
	var sea := float(a[3]) if a.size() > 3 else 3.0
	view = a[4] if a.size() > 4 else "quarter"
	var lat := float(a[5]) if a.size() > 5 else 62.0
	var clouds := float(a[6]) if a.size() > 6 else 0.45
	Settings.quality = 2
	ocean = Ocean.new()
	root.add_child(ocean)
	atm = Atmos.new()
	root.add_child(atm)
	atm.setup({"sea": sea, "wind": 240.0, "vis": 25.0, "clouds": clouds, "dark": 0.0, "aurora": 1.0 if hour < 5.0 or hour > 21.0 else 0.0}, lat, 240, hour, ocean)
	ship = ShipBuilder.build(id)
	root.add_child(ship)
	L = ShipData.spec(id)["length"]
	cam = Camera3D.new()
	cam.fov = 50
	cam.far = 120000
	cam.near = 0.3
	root.add_child(cam)


func _process(d: float) -> bool:
	frame += 1
	t = 30.0 + frame * 0.05
	var y: float = ocean.height(0, 0)
	var nf: float = ocean.height(0, -L * 0.4) - ocean.height(0, L * 0.4)
	var ns: float = ocean.height(8, 0) - ocean.height(-8, 0)
	ship.position = Vector3(0, y * 0.6, 0)
	ship.rotation = Vector3(atan2(nf, L * 0.8) * 0.5, deg_to_rad(-20.0), -atan2(ns, 16.0) * 0.4)
	var p: Vector3
	var look: Vector3
	match view:
		"low":
			p = Vector3(L * 0.55, 4.0, -L * 0.75)
			look = Vector3(0, 6, 0)
		"far":
			p = Vector3(L * 2.6, L * 0.25, -L * 2.0)
			look = Vector3(0, 0, 0)
		"bridge":
			var br: Dictionary = ship.get_meta("bridge")
			p = ship.to_global(Vector3(0, br["y"] + 1.7, br["z0"] - 3.0))
			look = ship.to_global(Vector3(0, br["y"] - 2.0, -L * 0.5))
		_:
			p = Vector3(L * 0.7, L * 0.16, -L * 0.6)
			look = Vector3(0, 2, -L * 0.05)
	cam.position = p
	cam.look_at(look)
	ocean.follow(cam.position, t)
	atm.update(t)
	if frame == 8:
		root.get_viewport().get_texture().get_image().save_png(out)
		return true
	return false
