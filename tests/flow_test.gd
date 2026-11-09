extends SceneTree
## Drives the whole game flow headless: menu, campaign intro, map, briefing,
## mission, pause, debrief, situation report, ending, settings and free battle,
## then loads every campaign mission and runs it for a few seconds.
## godot --headless --path . -s tests/flow_test.gd
## Prints FLOW OK on success; any SCRIPT ERROR in the output is a failure too.

const Main := preload("res://scripts/main.gd")
const Save := preload("res://scripts/core/save.gd")
const Campaigns := preload("res://scripts/data/campaigns.gd")
const Skirmish := preload("res://scripts/data/skirmish.gd")

var m
var fails := 0
var checks := 0


func _init() -> void:
	Save.path = "user://flow_test_campaign.json"
	Save.load_save(true)
	Save.reset("us")
	Save.reset("su")
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL ", what)
	else:
		print("ok   ", what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func finish_story() -> void:
	for i in 40:
		if m.state != "story":
			return
		m.screen.advance()
		await process_frame


func _run() -> void:
	m = Main.new()
	root.add_child(m)
	await frames(3)
	check(m.state == "menu" and m.showcase != null, "main menu with a ship behind it")
	m._menu_action("campaign", "us")
	await frames(2)
	check(m.state == "story", "first campaign start shows the introduction")
	await finish_story()
	await frames(2)
	check(m.state == "map", "introduction leads to the campaign map")
	check(Save.side_data("us")["intro_seen"], "introduction is marked as seen")
	m.go_briefing(0)
	await frames(2)
	check(m.state == "briefing" and m.showcase != null, "briefing with the mission ship")
	m.start_mission(m.current)
	await frames(10)
	check(m.state == "mission" and m.game != null and m.game.w.player != null, "mission starts")
	m._on_pause()
	await frames(2)
	check(m.overlay != null and m.game.frozen, "pause menu freezes the battle")
	m._pause_choice("settings")
	await frames(2)
	check(m.overlay != null, "settings open from the pause menu")
	m.overlay.closed.emit()
	await frames(2)
	check(m.overlay != null and m.game.frozen, "closing settings returns to the pause menu")
	m._pause_choice("resume")
	await frames(2)
	check(m.overlay == null and not m.game.frozen, "resume")
	m._on_finished("won", m.game.w.stats)
	await frames(2)
	check(m.state == "debrief", "debrief after the mission")
	check(Save.is_done("us", "us1") and Save.unlocked("us") == 1, "victory is saved and unlocks mission 2")
	m._debrief_choice("continue")
	await frames(2)
	check(m.state == "story", "situation report after a victory")
	await finish_story()
	await frames(2)
	check(m.state == "map" and m.screen.sel == 1, "map opens on the next mission")
	# Losing keeps the mission locked.
	m.go_briefing(1)
	await frames(2)
	m.start_mission(m.current)
	await frames(5)
	m._on_finished("lost", m.game.w.stats)
	await frames(2)
	check(m.state == "debrief" and not Save.is_done("us", "us2"), "a lost mission is not saved")
	m._debrief_choice("map")
	await frames(2)
	check(m.state == "map", "back to the map")
	# The ending.
	m.side = "us"
	m.idx = Campaigns.count("us") - 1
	m._after_win()
	await frames(2)
	check(m.state == "story", "campaign ending")
	await finish_story()
	await frames(2)
	check(m.state == "menu" and Save.side_data("us")["finished"], "ending returns to the menu, campaign finished")
	# Settings from the menu.
	m.open_settings()
	await frames(2)
	check(m.overlay != null, "settings from the menu")
	m.overlay.closed.emit()
	await frames(1)
	check(m.overlay == null, "settings close")
	# Free battle, every kind.
	m.go_free()
	await frames(2)
	check(m.state == "free", "free battle setup")
	for k: Array in Skirmish.KINDS:
		m.start_mission(Skirmish.build("cg47", k[0], 1, 2, 4.0))
		await frames(6)
		check(m.state == "mission" and m.game.w.units.size() > 1, "free battle: " + k[1])
	m._on_finished("lost", m.game.w.stats)
	await frames(2)
	m._debrief_choice("menu")
	await frames(2)
	check(m.state == "menu", "free battle debrief back to the menu")
	# Every campaign mission loads and runs.
	for s: String in ["us", "su"]:
		m.side = s
		m.mode = "campaign"
		for i in Campaigns.count(s):
			m.idx = i
			var def: Dictionary = Campaigns.mission(s, i).duplicate(true)
			m.start_mission(def)
			for j in 40:
				m.game.w.step(0.25)
				await process_frame
			var w = m.game.w
			check(w.player != null and w.player.alive() and w.units.size() > 1, "%s: %s runs (%d units, terrain %s)" % [def["id"], def["title"], w.units.size(), w.terrain != null])
	m._clear_game()
	Save.reset("us")
	Save.reset("su")
	print("%d checks, %d failed" % [checks, fails])
	if fails == 0:
		print("FLOW OK")
	quit(1 if fails > 0 else 0)
