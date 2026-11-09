extends Node
## Entry point: menus, campaign flow and missions.
## Command line (after --): --sandbox <class>  start a test battle
##   --smoke <secs>  run headless for N seconds then quit (CI)
##   --shot <png> <secs> [view]  save a screenshot after N seconds

const Game := preload("res://scripts/game.gd")
const S := preload("res://scripts/ui/style.gd")
const Settings := preload("res://scripts/core/settings.gd")

var game = null
var args := {}
var shot_t := -1.0
var shot_path := ""
var smoke_t := -1.0
var elapsed := 0.0


func _ready() -> void:
	Settings.load_settings()
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		match a[i]:
			"--sandbox":
				args["sandbox"] = a[i + 1] if i + 1 < a.size() else "dd963"
				i += 1
			"--smoke":
				smoke_t = float(a[i + 1])
				i += 1
			"--shot":
				shot_path = a[i + 1]
				shot_t = float(a[i + 2])
				if i + 3 < a.size() and not a[i + 3].begins_with("--"):
					args["view"] = a[i + 3]
					i += 1
				i += 2
			"--warp":
				args["warp"] = float(a[i + 1])
				i += 1
			"--hour":
				args["hour"] = float(a[i + 1])
				i += 1
		i += 1
	var cls: String = args.get("sandbox", "dd963")
	start_mission(sandbox(cls))


func sandbox(cls: String) -> Dictionary:
	var su := cls in ["krivak", "akula", "sovremenny", "sverdlov", "kirov", "sovsoyuz"]
	var side := "su" if su else "us"
	var foe := "us" if su else "su"
	var enemy: Array = ["sovremenny", "krivak"] if not su else ["dd963", "ffg7"]
	return {
		"title": "Sandbox", "side": side, "ship": cls, "date": [1988, 9, 2], "time": float(args.get("hour", 15.5)),
		"lat": 66.0, "lon": 2.0, "location": "Norwegian Sea", "awacs": true,
		"weather": {"sea": 3.0, "wind": 240.0, "vis": 30.0, "clouds": 0.45},
		"player": {"pos": [0, 0], "hdg": 10.0, "speed": 18.0},
		"start_view": args.get("view", "bridge"),
		"units": [
			{"cls": enemy[0], "side": foe, "pos": [3, 26], "hdg": 190.0, "speed": 20.0, "tag": "enemy", "ai": "patrol", "waypoints": [[0, 0]]},
			{"cls": enemy[1], "side": foe, "pos": [6, 28], "hdg": 190.0, "speed": 20.0, "tag": "enemy", "ai": "patrol", "waypoints": [[2, 0]]},
			{"cls": "tanker", "side": side, "pos": [-3, -4], "hdg": 10.0, "speed": 12.0, "tag": "convoy", "ai": "convoy", "waypoints": [[-3, 80]], "name": "USNS Neosho" if not su else "Dubna"},
		],
		"objectives": [
			{"id": "o1", "text": "Destroy the enemy surface group", "type": "destroy", "tag": "enemy"},
			{"id": "o2", "text": "Protect the oiler", "type": "protect", "tag": "convoy", "min": 1},
		],
		"events": [{"at": 4.0, "radio": ["Fleet", "Surface contacts bearing 010, 26 km. Weapons free."]}],
	}


func start_mission(def: Dictionary) -> void:
	if game != null:
		game.shutdown()
		game.queue_free()
	game = Game.new()
	add_child(game)
	game.start(def)
	game.finished.connect(_on_finished)
	if args.has("warp"):
		game.tc = float(args["warp"])


func _on_finished(result: String, _stats: Dictionary) -> void:
	print("MISSION ", result)


func _process(delta: float) -> void:
	elapsed += delta
	if smoke_t > 0.0 and game != null and game.w != null and game.w.t >= smoke_t:
		print("SMOKE OK t=%.1f units=%d muns=%d" % [game.w.t, game.w.units.size(), game.w.muns.size()])
		get_tree().quit(0)
	if shot_t > 0.0 and game != null and game.w != null and game.w.t >= shot_t:
		shot_t = -1.0
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_path)
		print("SHOT ", shot_path)
		get_tree().quit(0)
