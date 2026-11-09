extends SceneTree
## Headless simulation tests: godot --headless --path . -s tests/run_tests.gd

const U := preload("res://scripts/util.gd")
const ShipData := preload("res://scripts/data/ships.gd")

var fails := 0
var passes := 0


func check(cond: bool, label: String) -> void:
	if cond:
		passes += 1
		print("  ok   ", label)
	else:
		fails += 1
		print("  FAIL ", label)


func run_for(w: SimWorld, secs: float, dt := 0.1) -> void:
	var n := int(secs / dt)
	for i in n:
		w.step(dt)


func _init() -> void:
	print("== ballistics")
	var r16: float = SimBallistics.max_range("406_ap")
	check(absf(r16 - 38720.0) < 1500.0, "16-inch max range %.1f km (published 38.7)" % (r16 / 1000.0))
	var tof := SimBallistics.time_for("406_ap", 20000.0)
	check(tof > 25.0 and tof < 45.0, "16-inch time of flight to 20 km: %.1f s" % tof)
	var fall: Array = SimBallistics.solve("406_ap", 30000.0)
	check(fall.size() == 5 and fall[3] > 20.0, "16-inch angle of fall at 30 km: %.1f deg" % (fall[3] if fall.size() == 5 else -1.0))
	var r5: float = SimBallistics.max_range("127_he")
	check(absf(r5 - 23100.0) < 1500.0, "5-inch/54 max range %.1f km" % (r5 / 1000.0))

	print("== propulsion")
	var w := SimWorld.new(42)
	var bb := w.add_unit("bb61", "us", Vector3.ZERO, 0.0, 0.0, {"player": true})
	bb.plant.ring(9)
	run_for(w, 900.0)
	var kn6: float = bb.speed / U.KN
	check(kn6 > 27.0 and kn6 < 31.5, "Iowa on 6 of 8 boilers at flank: %.1f kn" % kn6)
	bb.plant.start_unit(6)
	bb.plant.start_unit(7)
	run_for(w, 900.0)
	var kn8: float = bb.speed / U.KN
	check(kn8 > 31.0 and kn8 < 34.0, "Iowa with all boilers lit: %.1f kn" % kn8)
	check(bb.plant.steam > 0.85, "steam pressure holds at %.2f" % bb.plant.steam)
	bb.plant.ring(4)
	w.step(0.5)
	check(bb.plant.answered[0] == 9, "engine room has not answered STOP after 0.5 s")
	run_for(w, 5.0)
	check(bb.plant.answered[0] == 4, "engine room answered STOP")

	var w2 := SimWorld.new(7)
	var ff := w2.add_unit("ffg7", "us", Vector3.ZERO, 0.0, 0.0, {"player": true})
	ff.plant.set_lever(1.0)
	run_for(w2, 600.0)
	var k1: float = ff.speed / U.KN
	check(k1 > 20.0 and k1 < 25.5, "Perry on one gas turbine: %.1f kn" % k1)
	ff.plant.start_unit(1)
	run_for(w2, 30.0)
	check(ff.plant.units[1]["state"] == "starting", "GTM 1B is starting")
	run_for(w2, 400.0)
	var k2: float = ff.speed / U.KN
	check(k2 > 27.5 and k2 < 30.0, "Perry on both turbines: %.1f kn" % k2)
	ff.set_rudder(35.0)
	var h0: float = ff.heading
	var p0: Vector3 = ff.pos
	var maxd := 0.0
	var turned := 0.0
	var prev := ff.heading
	while turned < 360.0 and w2.t < 2000.0:
		w2.step(0.1)
		turned += absf(U.adiff(prev, ff.heading))
		prev = ff.heading
		maxd = maxf(maxd, ff.pos.distance_to(p0))
	check(maxd > 500.0 and maxd < 1300.0, "Perry tactical diameter ~%d m at speed with full rudder" % int(maxd))
	check(ff.speed / U.KN < k2 * 0.85, "speed falls off in the turn: %.1f kn" % (ff.speed / U.KN))

	print("== combat")
	var w3 := SimWorld.new(99)
	var dd := w3.add_unit("dd963", "us", Vector3(0, 0, 0), 90.0, 25.0, {"player": true})
	var kv := w3.add_unit("krivak", "su", Vector3(16000, 0, 0), 270.0, 22.0, {"ai": "patrol"})
	w3.add_unit("sovremenny", "su", Vector3(18000, 0, 3000), 270.0, 22.0, {"ai": "patrol"})
	var hits := 0
	var fired := 0
	var launched := 0
	var intercepts := 0
	for i in 3000:
		w3.step(0.1)
		for m in dd.mounts:
			if m.kind == "gun" and kv.alive():
				var tof5 := SimBallistics.time_for(m.sel, U.flat_dist(dd.pos, kv.pos))
				w3.fire_gun(dd, m, kv.pos + kv.vel() * tof5, true, 1.0)
		for e in w3.events:
			match e["t"]:
				"hit": hits += 1
				"fire": fired += 1
				"launch": launched += 1
				"intercept": intercepts += 1
		w3.events.clear()
	print("    fired %d gun salvos, %d hits, %d missiles, %d intercepts" % [fired, hits, launched, intercepts])
	check(fired > 20, "guns fired")
	check(hits > 0, "shells hit")
	check(launched > 0, "the Sovremenny launched Moskits")
	check(kv.hp < kv.hp_max or not kv.alive(), "the Krivak took damage")
	print("== result: %d passed, %d failed" % [passes, fails])
	quit(1 if fails > 0 else 0)
