extends Node3D
## Living 3D backdrop for the menus and briefings: a ship under way on the
## ocean and under the sky of a real place and time, filmed by a slow
## cinematic camera. It runs the real simulation and world view, so wakes,
## funnel smoke, radars and the sea all behave as they do in battle.

const Ocean := preload("res://scripts/view/ocean.gd")
const Atmos := preload("res://scripts/view/atmosphere.gd")
const WorldView := preload("res://scripts/view/world_view.gd")
const U := preload("res://scripts/util.gd")
const ShipData := preload("res://scripts/data/ships.gd")
const Settings := preload("res://scripts/core/settings.gd")

var w: SimWorld
var ocean
var atm
var view
var cam: Camera3D
var ship: SimUnit
var t := 0.0
var start_hour := 12.0
var cls_id := ""
var shot := 0
var shot_t := 0.0
var cam_pos := Vector3.ZERO
var cam_look := Vector3.ZERO
## Where the ship sits on screen, as a fraction of the half-width (positive
## is right of centre) and of the half-height (positive is above centre).
var frame_x := 0.0
var frame_y := 0.0
## Camera distance multiplier.
var dist_mult := 1.0


func setup(cls: String, side: String, weather: Dictionary, lat: float, day: int, hour: float, extra := []) -> void:
	cls_id = cls
	start_hour = hour
	w = SimWorld.new(11)
	w.weather = weather
	var sub := ShipData.is_sub(cls)
	ship = w.add_unit(cls, side, Vector3.ZERO, 300.0, 9.0 if sub else 15.0, {"player": true, "depth": 0.0})
	if sub:
		ship.depth = 0.0
		ship.depth_order = 0.0
		ship.pos.y = 0.0
	for e: Dictionary in extra:
		var p: Vector3 = e.get("pos", Vector3(300, 0, 400))
		var u := w.add_unit(e["cls"], side, p, 300.0, 15.0, {"ai": "patrol", "waypoints": [], "cruise": 15.0 / 30.0})
		u.course_order = 300.0
	ocean = Ocean.new()
	add_child(ocean)
	atm = Atmos.new()
	add_child(atm)
	atm.setup(weather, lat, day, hour, ocean)
	w.night = atm.is_night()
	view = WorldView.new()
	add_child(view)
	view.setup(w, ocean, atm)
	view.set_night(atm.sun_el < 2.0)
	cam = Camera3D.new()
	cam.fov = 42.0
	cam.near = 0.3
	cam.far = 120000.0
	add_child(cam)
	cam.make_current()
	shot = 0
	shot_t = 0.0
	_place_camera(0.0, true)


func _process(delta: float) -> void:
	if w == null:
		return
	delta = minf(delta, 0.1)
	t += delta
	w.step(delta)
	w.events.clear()
	atm.set_time(start_hour + t / 3600.0)
	atm.update(w.t)
	_place_camera(delta, false)
	ocean.follow(cam.global_position, w.t)
	view.sync(delta, cam.global_position)


## Three slow camera moves, changed every 24 seconds.
func _place_camera(dt: float, snap: bool) -> void:
	shot_t += dt
	if shot_t > 24.0:
		shot_t = 0.0
		shot = (shot + 1) % 3
		snap = true
	var L := ship.L
	var f := ship.fwd()
	var s := Vector3(-f.z, 0, f.x)
	var c := ship.pos
	var k := shot_t / 24.0
	var p := Vector3.ZERO
	var look := Vector3.ZERO
	var m := dist_mult
	match shot:
		0:
			# Low on the bow quarter, drifting aft along the ship.
			p = c + f * L * lerpf(0.75, 0.1, k) * m + s * L * 1.5 * m + Vector3.UP * (L * 0.07 + 4.0)
			look = c + f * L * 0.1 + Vector3.UP * L * 0.05
		1:
			# Wide broadside, slowly pulling back.
			p = c - f * L * 0.2 * m + s * L * lerpf(2.3, 2.7, k) * m + Vector3.UP * (L * 0.14 + 6.0)
			look = c + Vector3.UP * L * 0.04
		_:
			# Over the stern quarter, looking forward along the wake.
			p = c - f * L * lerpf(1.5, 1.2, k) * m - s * L * 0.8 * m + Vector3.UP * (L * 0.2 + 6.0)
			look = c + f * L * 0.3 + Vector3.UP * L * 0.04
	# Aim beside the ship so it sits where the menu panels leave room.
	var view_dir := (look - p).normalized()
	var right := view_dir.cross(Vector3.UP).normalized()
	var up := right.cross(view_dir).normalized()
	var vp := get_viewport().get_visible_rect().size
	var th := tan(deg_to_rad(cam.fov) * 0.5)
	var dist := p.distance_to(look)
	look -= right * frame_x * dist * th * (vp.x / maxf(vp.y, 1.0))
	look -= up * frame_y * dist * th
	p.y = maxf(p.y, ocean.height(p.x, p.z) + 3.0)
	if snap:
		cam_pos = p
		cam_look = look
	else:
		var a := clampf(dt * 2.0, 0.0, 1.0)
		cam_pos = cam_pos.lerp(p, a)
		cam_look = cam_look.lerp(look, a)
	cam.global_position = cam_pos
	cam.look_at(cam_look, Vector3.UP)
