extends Node
## Entry point and screen flow: main menu, campaign map, story, briefing,
## mission, debrief and situation reports, free battle and settings.
##
## Command line (after --):
##   --sandbox <class>   start a test battle at once (CI smoke runs)
##   --mission <id>      start a campaign mission at once, e.g. us5
##   --screen <name>     open a screen: menu, free, map:<side>, brief:<id>,
##                       intro:<side>, sitrep:<id>, ending:<side>, debrief:<id>
##   --smoke <secs>      quit after N seconds of battle time (CI)
##   --shot <png> <secs> [view]   save a screenshot after N seconds
##   --warp N            time compression in battle
##   --hour H            local time (sandbox, or override a mission's)
##   --vis KM            override a mission's visibility
##   --at X Y            put your ship X km east, Y km north of the mission origin

const Game := preload("res://scripts/game.gd")
const S := preload("res://scripts/ui/style.gd")
const Settings := preload("res://scripts/core/settings.gd")
const Save := preload("res://scripts/core/save.gd")
const Campaigns := preload("res://scripts/data/campaigns.gd")
const ShipData := preload("res://scripts/data/ships.gd")
const U := preload("res://scripts/util.gd")
const Fmt := preload("res://scripts/ui/fmt.gd")
const Showcase := preload("res://scripts/ui/showcase.gd")
const Menu := preload("res://scripts/ui/menu.gd")
const MapScreen := preload("res://scripts/ui/map_screen.gd")
const Story := preload("res://scripts/ui/story.gd")
const Briefing := preload("res://scripts/ui/briefing.gd")
const Debrief := preload("res://scripts/ui/debrief.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const FreeBattle := preload("res://scripts/ui/free_battle.gd")

## Backdrops for the main menu: [class, side, local hour, latitude, weather].
const MENU_SCENES := [
	["bb61", "us", 17.4, 66.0, {"sea": 3.0, "wind": 250.0, "vis": 30.0, "clouds": 0.45}],
	["sovsoyuz", "su", 15.2, 70.0, {"sea": 4.0, "wind": 40.0, "vis": 22.0, "clouds": 0.6}],
	["kirov", "su", 17.9, 69.0, {"sea": 3.0, "wind": 300.0, "vis": 26.0, "clouds": 0.35}],
	["ca139", "us", 9.0, 64.0, {"sea": 2.0, "wind": 200.0, "vis": 30.0, "clouds": 0.3}],
	["dd963", "us", 13.0, 42.0, {"sea": 4.0, "wind": 260.0, "vis": 24.0, "clouds": 0.5}],
	["sverdlov", "su", 7.2, 69.5, {"sea": 2.0, "wind": 90.0, "vis": 20.0, "clouds": 0.55}],
]

const SIDE_NAMES := {"us": "UNITED STATES NAVY", "su": "SOVIET NAVY"}

var game = null
var showcase = null
var layer: CanvasLayer
var screen: Control = null
var overlay: Control = null
var args := {}
var shot_t := -1.0
var shot_path := ""
var smoke_t := -1.0
var elapsed := 0.0
var state := ""
## "campaign", "free" or "sandbox".
var mode := ""
var side := "us"
var idx := 0
var current := {}
var free_cls := "dd963"
var last_result := ""
var last_stats := {}


func _ready() -> void:
	Settings.load_settings()
	Save.load_save()
	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_parse_args()
	Settings.apply_viewport(get_viewport())
	if args.has("sandbox"):
		mode = "sandbox"
		start_mission(sandbox(args["sandbox"]))
	elif args.has("mission"):
		var id: String = args["mission"]
		side = id.substr(0, 2)
		idx = _index_of(side, id)
		mode = "campaign"
		var def: Dictionary = Campaigns.mission(side, idx).duplicate(true)
		if args.has("view"):
			def["start_view"] = args["view"]
		if args.has("hour"):
			def["time"] = args["hour"]
		if args.has("vis"):
			def["weather"]["vis"] = args["vis"]
		start_mission(def)
	elif args.has("screen"):
		_open_screen(args["screen"])
	else:
		go_menu()


func _parse_args() -> void:
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		match a[i]:
			"--sandbox":
				args["sandbox"] = a[i + 1] if i + 1 < a.size() else "dd963"
				i += 1
			"--mission":
				args["mission"] = a[i + 1]
				i += 1
			"--screen":
				args["screen"] = a[i + 1]
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
			"--vis":
				args["vis"] = float(a[i + 1])
				i += 1
			"--at":
				args["at"] = Vector2(float(a[i + 1]), float(a[i + 2]))
				i += 2
		i += 1


func _index_of(s: String, id: String) -> int:
	var ms: Array = Campaigns.campaign(s).get("missions", [])
	for i in ms.size():
		if ms[i]["id"] == id:
			return i
	return 0


# ------------------------------------------------------------------ plumbing
func _set_screen(c: Control) -> void:
	_clear_screen()
	screen = c
	layer.add_child(c)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _clear_screen() -> void:
	_close_overlay()
	if screen != null:
		layer.remove_child(screen)
		screen.queue_free()
		screen = null


func _set_overlay(c: Control) -> void:
	_close_overlay()
	overlay = c
	layer.add_child(c)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_overlay() -> void:
	if overlay != null:
		layer.remove_child(overlay)
		overlay.queue_free()
		overlay = null


func _clear_showcase() -> void:
	if showcase != null:
		remove_child(showcase)
		showcase.queue_free()
		showcase = null


func _clear_game() -> void:
	if game != null:
		game.shutdown()
		remove_child(game)
		game.queue_free()
		game = null


## A ship under way behind the menus. fx and fy place it on screen, as a
## fraction of the half-width and half-height from the centre.
func _show_ship(cls: String, s: String, weather: Dictionary, lat: float, day: int, hour: float, fx: float, fy := 0.0, dm := 1.0) -> void:
	_clear_showcase()
	showcase = Showcase.new()
	showcase.frame_x = fx
	showcase.frame_y = fy
	showcase.dist_mult = dm
	add_child(showcase)
	showcase.setup(cls, s, weather, lat, day, hour)


func _show_mission_ship(def: Dictionary, fx: float, fy: float) -> void:
	var d: Array = def.get("date", [1988, 9, 22])
	_show_ship(def["ship"], def.get("side", "us"), def.get("weather", {}), float(def.get("lat", 60.0)),
		U.day_of_year(int(d[1]), int(d[2])), float(def.get("time", 12.0)), fx, fy, 1.35)


# ------------------------------------------------------------------ screens
func go_menu(new_ship := true) -> void:
	state = "menu"
	mode = ""
	_clear_game()
	if new_ship or showcase == null:
		var sc: Array = MENU_SCENES[randi() % MENU_SCENES.size()]
		_show_ship(sc[0], sc[1], sc[4], sc[3], 265, sc[2], 0.36, 0.05)
	var m := Menu.new()
	m.action.connect(_menu_action)
	_set_screen(m)


func _menu_action(what: String, s: String) -> void:
	match what:
		"campaign":
			open_campaign(s)
		"free":
			go_free()
		"settings":
			open_settings()
		"quit":
			get_tree().quit()
		"refresh":
			go_menu(false)


func open_campaign(s: String) -> void:
	side = s
	mode = "campaign"
	if not Save.side_data(s).get("intro_seen", false):
		Save.mark(s, "intro_seen", true)
		go_story(_intro_pages(s), _front(s, 0), 0, func(): go_map(-1))
	else:
		go_map(-1)


func go_map(sel := -1) -> void:
	state = "map"
	mode = "campaign"
	_clear_game()
	_clear_showcase()
	var ms := MapScreen.new()
	ms.setup(side, sel)
	ms.brief.connect(go_briefing)
	ms.intro.connect(func(): go_story(_intro_pages(side), _front(side, 0), 0, func(): go_map(ms.sel)))
	ms.back.connect(func(): go_menu())
	_set_screen(ms)


func go_story(pages: Array, front: Dictionary, highlight: int, next: Callable) -> void:
	if pages.is_empty():
		next.call()
		return
	state = "story"
	_clear_game()
	_clear_showcase()
	var st := Story.new()
	st.setup(pages, side, front, highlight)
	st.done.connect(next)
	_set_screen(st)


func go_briefing(i: int) -> void:
	idx = i
	mode = "campaign"
	state = "briefing"
	current = Campaigns.mission(side, i).duplicate(true)
	_show_mission_ship(current, 0.42, 0.42)
	var b := Briefing.new()
	b.setup(current, "MISSION %d OF %d" % [i + 1, Campaigns.count(side)])
	b.sail.connect(func(): start_mission(current))
	b.back.connect(func(): go_map(i))
	_set_screen(b)


func go_free() -> void:
	state = "free"
	mode = "free"
	_clear_game()
	_free_ship(free_cls)
	var fb := FreeBattle.new()
	fb.setup(free_cls)
	fb.ship_changed.connect(func(c: String):
		free_cls = c
		_free_ship(c))
	fb.start.connect(func(d: Dictionary):
		mode = "free"
		start_mission(d))
	fb.back.connect(func(): go_menu())
	_set_screen(fb)


func _free_ship(cls: String) -> void:
	_show_ship(cls, ShipData.spec(cls).get("side", "us"), {"sea": 3.0, "wind": 230.0, "vis": 28.0, "clouds": 0.45}, 66.0, 265, 15.0, 0.45, 0.1, 1.15)


func open_settings(after := Callable()) -> void:
	var sp := SettingsPanel.new()
	sp.closed.connect(func():
		_close_overlay()
		if after.is_valid():
			after.call())
	sp.changed.connect(_settings_changed)
	_set_overlay(sp)


func _settings_changed() -> void:
	if game != null and game.atm != null:
		game.atm.apply_quality()
	if showcase != null and showcase.atm != null:
		showcase.atm.apply_quality()


# ------------------------------------------------------------------ missions
func start_mission(def: Dictionary) -> void:
	current = def
	state = "mission"
	_clear_screen()
	_clear_showcase()
	_clear_game()
	game = Game.new()
	add_child(game)
	game.start(def.duplicate(true))
	game.finished.connect(_on_finished)
	game.pause_requested.connect(_on_pause)
	if args.has("warp"):
		game.tc = float(args["warp"])
	if args.has("at"):
		var at: Vector2 = args["at"]
		game.player.pos = Vector3(at.x * 1000.0, game.player.pos.y, -at.y * 1000.0)


func _on_pause() -> void:
	if game == null or overlay != null or state != "mission" or game.ended:
		return
	get_viewport().set_input_as_handled()
	_show_pause()


func _show_pause() -> void:
	game.frozen = true
	var p := PauseMenu.new()
	p.setup(String(current.get("title", "")), game.sim_mission.objective_lines(), true)
	p.choice.connect(_pause_choice)
	_set_overlay(p)


func _pause_choice(what: String) -> void:
	match what:
		"resume":
			_close_overlay()
			_resume()
		"restart":
			start_mission(current)
		"settings":
			open_settings(_show_pause)
		"abandon":
			_close_overlay()
			_leave()


func _resume() -> void:
	if game == null:
		return
	game.frozen = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if game.mode in ["external", "sight"] else Input.MOUSE_MODE_VISIBLE


## Back to wherever the mission was started from.
func _leave() -> void:
	match mode:
		"campaign":
			go_map(idx)
		"free":
			go_free()
		_:
			go_menu()


func _on_finished(result: String, stats: Dictionary) -> void:
	print("MISSION ", result)
	if state != "mission" or game == null or result == "smoke":
		return
	if args.has("smoke") or args.has("shot"):
		return
	_close_overlay()
	last_result = result
	last_stats = stats.duplicate()
	if mode == "campaign" and result == "won":
		Save.complete(side, String(current.get("id", "")), stats)
	state = "debrief"
	game.frozen = true
	game.canvas.visible = false
	var d := Debrief.new()
	d.setup(_debrief_info(result, stats))
	d.choice.connect(_debrief_choice)
	_set_screen(d)


func _debrief_info(result: String, stats: Dictionary) -> Dictionary:
	var p = game.player
	var res := result
	if result == "lost" and p != null and (p.sinking or p.sunk):
		res = "sunk"
	var kicker := ""
	match mode:
		"campaign":
			kicker = "MISSION %d OF %d  ·  %s" % [idx + 1, Campaigns.count(side), String(current.get("title", "")).to_upper()]
		"free":
			kicker = "FREE BATTLE  ·  %s" % String(current.get("location", "")).to_upper()
		_:
			kicker = "SANDBOX"
	var buttons := []
	match mode:
		"campaign":
			if result == "won":
				buttons = [["Continue  ▸", "continue"], ["Replay mission", "retry"], ["Campaign map", "map"]]
			else:
				buttons = [["Try again", "retry"], ["Campaign map", "map"]]
		"free":
			buttons = [["Fight again", "retry"], ["New battle", "free"], ["Main menu", "menu"]]
		_:
			buttons = [["Again", "retry"], ["Main menu", "menu"]]
	return {
		"kicker": kicker, "title": current.get("title", ""), "result": res, "why": game.why, "side": current.get("side", "us"),
		"objectives": game.sim_mission.objective_lines(), "stats": stats, "time": game.w.t,
		"hull": clampf(p.hp / maxf(p.hp_max, 1.0), 0.0, 1.0) if p != null and not p.sunk else 0.0,
		"buttons": buttons,
	}


func _debrief_choice(what: String) -> void:
	match what:
		"continue":
			_after_win()
		"retry":
			start_mission(current)
		"map":
			go_map(idx)
		"free":
			go_free()
		_:
			go_menu()


func _after_win() -> void:
	var n := Campaigns.count(side)
	if idx < n - 1:
		var nxt := idx + 1
		go_story(_sitrep_pages(side, idx), _front(side, nxt), nxt, func(): go_map(nxt))
	else:
		Save.mark(side, "finished", true)
		go_story(_ending_pages(side), _front(side, idx), idx, func(): go_menu())


# ------------------------------------------------------------------ story text
func _front(s: String, i: int) -> Dictionary:
	return Campaigns.mission(s, i).get("front", {})


func _intro_pages(s: String) -> Array:
	var camp := Campaigns.campaign(s)
	var paras: Array = camp["intro"]
	var kicker := "%s  ·  %s" % [SIDE_NAMES[s], camp["subtitle"]]
	var pages := []
	var body := paras.slice(0, paras.size() - 1)
	var i := 0
	while i < body.size():
		var blocks := []
		for p: String in body.slice(i, i + 2):
			blocks.append(["", p])
		pages.append({"kicker": kicker, "title": camp["title"] if i == 0 else "", "blocks": blocks})
		i += 2
	pages.append({"kicker": kicker, "title": "", "blocks": [["", paras[paras.size() - 1]]], "big": true})
	return pages


func _sitrep_pages(s: String, i: int) -> Array:
	var m := Campaigns.mission(s, i)
	var sr: Dictionary = m.get("sitrep", {})
	if sr.is_empty():
		return []
	var heads: Array = ["ARMY", "AIR FORCE", "NAVY"] if s == "us" else ["GROUND FORCES", "AIR FORCES", "THE FLEET"]
	var kicker := ("FLASH  ·  CINCLANTFLT TO ALL COMMANDS  ·  %s" if s == "us" else "MOLNIYA  ·  NORTHERN FLEET HQ, SEVEROMORSK, TO ALL UNITS  ·  %s") % Fmt.short_date(m["date"], 1)
	return [{"kicker": kicker, "title": "SITUATION REPORT" if s == "us" else "OPERATIONAL SUMMARY",
		"blocks": [[heads[0], sr.get("army", "")], [heads[1], sr.get("air", "")], [heads[2], sr.get("navy", "")]]}]


func _ending_pages(s: String) -> Array:
	var camp := Campaigns.campaign(s)
	var d := Save.side_data(s)
	var nuc: bool = d.get("nuclear", false)
	var paras: Array = camp["endings"]["won_nuclear" if nuc else "won"]
	var pages := []
	var blocks := []
	for p: String in paras.slice(0, paras.size() - 1):
		blocks.append(["", p])
	pages.append({"kicker": "EPILOGUE  ·  " + SIDE_NAMES[s], "title": "THE THRESHOLD" if nuc else "CEASEFIRE", "blocks": blocks})
	pages.append({"kicker": "EPILOGUE  ·  " + SIDE_NAMES[s], "title": "", "blocks": [["", paras[paras.size() - 1]]], "big": true})
	var kills := 0
	var downs := 0
	var shots := 0
	var hits := 0
	for r: Dictionary in (d["results"] as Dictionary).values():
		kills += int(r.get("kills", 0))
		downs += int(r.get("intercepts", 0))
		shots += int(r.get("shots", 0))
		hits += int(r.get("hits", 0))
	var summary := "Enemy ships sunk: %d\nMissiles and aircraft shot down: %d\nRounds fired: %d, hits: %d" % [kills, downs, shots, hits]
	pages.append({"kicker": camp["title"], "title": "CAMPAIGN COMPLETE", "blocks": [["YOUR WAR", summary],
		["", "Every mission can now be replayed from the campaign map, and every ship is waiting in Free battle."]]})
	return pages


# ------------------------------------------------------------------ CLI and CI
func _open_screen(name: String) -> void:
	var parts := name.split(":")
	var key: String = parts[0]
	var arg: String = parts[1] if parts.size() > 1 else ""
	if arg.length() >= 2:
		side = arg.substr(0, 2)
	match key:
		"map":
			go_map(-1)
		"brief":
			go_briefing(_index_of(side, arg))
		"intro":
			go_story(_intro_pages(side), _front(side, 0), 0, func(): go_map(-1))
		"sitrep":
			var i := _index_of(side, arg)
			idx = i
			go_story(_sitrep_pages(side, i), _front(side, i + 1), i + 1, func(): go_map(i + 1))
		"ending":
			go_story(_ending_pages(side), _front(side, Campaigns.count(side) - 1), Campaigns.count(side) - 1, func(): go_menu())
		"free":
			go_free()
		"debrief":
			idx = _index_of(side, arg)
			current = Campaigns.mission(side, idx).duplicate(true)
			_show_mission_ship(current, 0.0, 0.0)
			var d := Debrief.new()
			d.setup({"kicker": "MISSION %d OF 7  ·  %s" % [idx + 1, String(current["title"]).to_upper()], "title": current["title"],
				"result": "won", "why": "All objectives complete.", "side": side, "time": 1312.0, "hull": 0.82,
				"objectives": [["[x]", current["objectives"][0]["text"], "done", false]],
				"stats": {"shots": 214, "hits": 37, "kills": 3, "intercepts": 5, "missiles": 6},
				"buttons": [["Continue  ▸", "continue"], ["Replay mission", "retry"], ["Campaign map", "map"]]})
			_set_screen(d)
		_:
			go_menu()


func sandbox(cls: String) -> Dictionary:
	var su := cls in ["krivak", "akula", "sovremenny", "sverdlov", "kirov", "sovsoyuz"]
	var s := "su" if su else "us"
	var foe := "us" if su else "su"
	var enemy: Array = ["sovremenny", "krivak"] if not su else ["dd963", "ffg7"]
	return {
		"title": "Sandbox", "side": s, "ship": cls, "date": [1988, 9, 2], "time": float(args.get("hour", 15.5)),
		"lat": 66.0, "lon": 2.0, "location": "Norwegian Sea", "awacs": true,
		"weather": {"sea": 3.0, "wind": 240.0, "vis": 30.0, "clouds": 0.45},
		"player": {"pos": [0, 0], "hdg": 10.0, "speed": 18.0},
		"start_view": args.get("view", "bridge"),
		"units": [
			{"cls": enemy[0], "side": foe, "pos": [3, 26], "hdg": 190.0, "speed": 20.0, "tag": "enemy", "ai": "patrol", "waypoints": [[0, 0]]},
			{"cls": enemy[1], "side": foe, "pos": [6, 28], "hdg": 190.0, "speed": 20.0, "tag": "enemy", "ai": "patrol", "waypoints": [[2, 0]]},
			{"cls": "tanker", "side": s, "pos": [-3, -4], "hdg": 10.0, "speed": 12.0, "tag": "convoy", "ai": "convoy", "waypoints": [[-3, 80]], "name": "USNS Neosho" if not su else "Dubna"},
		],
		"objectives": [
			{"id": "o1", "text": "Destroy the enemy surface group", "type": "destroy", "tag": "enemy"},
			{"id": "o2", "text": "Protect the oiler", "type": "protect", "tag": "convoy", "min": 1},
		],
		"events": [{"at": 4.0, "radio": ["Fleet", "Surface contacts bearing 010, 26 km. Weapons free."]}],
	}


func _process(delta: float) -> void:
	elapsed += delta
	var in_battle := game != null and game.w != null
	if smoke_t > 0.0 and in_battle and game.w.t >= smoke_t:
		print("SMOKE OK t=%.1f units=%d muns=%d" % [game.w.t, game.w.units.size(), game.w.muns.size()])
		get_tree().quit(0)
	var clock: float = game.w.t if in_battle else elapsed
	if shot_t > 0.0 and clock >= shot_t:
		shot_t = -1.0
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_path)
		print("SHOT ", shot_path)
		get_tree().quit(0)
