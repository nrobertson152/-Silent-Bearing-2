extends SceneTree
## Renders ship models to PNG files for review.
## xvfb-run godot --path . -s tools/model_preview.gd -- <out_dir> [class_id] [view]
## view: side (default), quarter, top, bow, close

const ShipBuilder := preload("res://scripts/build/ship_builder.gd")
const ShipData := preload("res://scripts/data/ships.gd")

var out_dir := "/tmp"
var frame := 0
var shots := []
var cam: Camera3D
var holder: Node3D
var view := "quarter"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var only: String = args[1] if args.size() > 1 else ""
	if args.size() > 2:
		view = args[2]
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.66, 0.73, 0.79)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.7)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 600.0
	root.add_child(sun)
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000, 4000)
	sea.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.1, 0.18, 0.22)
	sm.roughness = 0.2
	sea.material_override = sm
	root.add_child(sea)
	cam = Camera3D.new()
	cam.fov = 32
	cam.far = 8000
	root.add_child(cam)
	holder = Node3D.new()
	root.add_child(holder)
	for id in ShipData.CLASSES:
		if ShipData.is_sub(id):
			continue
		if only == "" or only == id:
			shots.append(id)


func _process(_d: float) -> bool:
	frame += 1
	if frame % 4 == 1:
		if shots.is_empty():
			return true
		for c in holder.get_children():
			c.queue_free()
		var id: String = shots[0]
		var t0 := Time.get_ticks_msec()
		var node := ShipBuilder.build(id)
		print("built %s in %d ms" % [id, Time.get_ticks_msec() - t0])
		holder.add_child(node)
		var L: float = ShipData.spec(id)["length"]
		match view:
			"side":
				cam.position = Vector3(L * 1.15, L * 0.06, 0)
				cam.look_at(Vector3(0, L * 0.05, 0))
			"top":
				cam.position = Vector3(0.01, L * 1.6, 0)
				cam.look_at(Vector3(0, 0, 0), Vector3.FORWARD)
			"bow":
				cam.position = Vector3(L * 0.35, L * 0.12, -L * 0.85)
				cam.look_at(Vector3(0, L * 0.05, -L * 0.15))
			"close":
				cam.position = Vector3(L * 0.28, L * 0.13, -L * 0.18)
				cam.look_at(Vector3(0, L * 0.06, -L * 0.08))
			"stern":
				cam.position = Vector3(L * 0.45, L * 0.18, L * 0.75)
				cam.look_at(Vector3(0, L * 0.04, L * 0.1))
			_:
				cam.position = Vector3(L * 0.78, L * 0.26, -L * 0.62)
				cam.look_at(Vector3(0, L * 0.03, 0))
	elif frame % 4 == 0:
		var id: String = shots.pop_front()
		print("frame %d at %d ms" % [frame, Time.get_ticks_msec()])
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s/ship_%s_%s.png" % [out_dir, id, view])
	return false
