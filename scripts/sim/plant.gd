class_name SimPlant
extends RefCounted
## Propulsion plant: turns bridge orders into shaft revolutions.
##
## Telegraph ships (steam, nuclear, Soviet gas turbines, diesels): the bridge
## rings a bell, the engine room answers a few seconds later, and the throttle
## men bring the shafts round. Shafts must pass through STOP before reversing,
## astern turbines are weaker than ahead ones, and a steam plant loses pressure
## if more speed is rung up than the lit boilers can supply.
##
## US gas-turbine ships (Perry, Spruance, Ticonderoga): one programmed-control
## lever per shaft sets controllable-pitch propeller pitch and shaft speed
## together. Turbines can be started (about 90 s) for more power.

const BELLS_US := ["BACK EMERG", "BACK FULL", "BACK 2/3", "BACK 1/3", "STOP", "AHEAD 1/3", "AHEAD 2/3", "AHEAD STD", "AHEAD FULL", "AHEAD FLANK"]
const BELLS_SU := ["ПОЛНЫЙ НАЗАД", "СРЕДНИЙ НАЗАД", "МАЛЫЙ НАЗАД", "САМЫЙ МАЛЫЙ НАЗАД", "СТОП", "САМЫЙ МАЛЫЙ ВПЕРЁД", "МАЛЫЙ ВПЕРЁД", "СРЕДНИЙ ВПЕРЁД", "ПОЛНЫЙ ВПЕРЁД", "САМЫЙ ПОЛНЫЙ ВПЕРЁД"]
const BELLS_SU_EN := ["FULL ASTERN", "HALF ASTERN", "SLOW ASTERN", "DEAD SLOW ASTERN", "STOP", "DEAD SLOW AHEAD", "SLOW AHEAD", "HALF AHEAD", "FULL AHEAD", "FLANK"]
const RPM_US := [-0.8, -0.6, -0.4, -0.2, 0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
const RPM_SU := [-0.7, -0.45, -0.28, -0.14, 0.0, 0.14, 0.3, 0.55, 0.8, 1.0]
const STOP := 4
const MAX_RPM := {"gt_cpp": 168.0, "steam": 210.0, "nuclear": 110.0, "gt": 280.0, "diesel": 120.0}
const START_TIME := {"gt_cpp": 90.0, "gt": 75.0, "steam": 150.0, "nuclear": 30.0, "diesel": 40.0}

var kind := "steam"
var nav := "us"
var shafts := 1
var shp := 10000.0
var units := []
var bell := []
var lever := []
var trim := []
var answered := []
var ans_timer := []
var rpm := []
var pitch := []
var rev_hold := []
var shaft_ok := []
var steam := 1.0
var apu := false
var has_apu := false
var nuclear := false
var events := []
var max_rpm := 200.0
var rng := RandomNumberGenerator.new()


func _init(spec: Dictionary, navy: String) -> void:
	kind = spec.get("kind", "steam")
	nav = navy
	shafts = spec.get("shafts", 1)
	shp = spec.get("shp", 10000.0)
	has_apu = spec.get("apu", false)
	nuclear = spec.get("nuclear", kind == "nuclear")
	max_rpm = MAX_RPM.get(kind, 200.0)
	if kind == "steam" and shp > 150000.0:
		max_rpm = 202.0
	var online: int = spec.get("online", 99)
	var ulist: Array = spec.get("units", [])
	for i in ulist.size():
		var ud: Dictionary = ulist[i]
		units.append({"name": ud["n"], "shaft": ud.get("s", -1), "power": float(ud.get("p", 0.0)),
			"state": "online" if i < online else "standby", "timer": 0.0})
	_normalise_power()
	for s in shafts:
		bell.append(STOP)
		answered.append(STOP)
		ans_timer.append(0.0)
		lever.append(0.0)
		trim.append(0.0)
		rpm.append(0.0)
		pitch.append(0.0)
		rev_hold.append(0.0)
		shaft_ok.append(1.0)
	rng.randomize()


## Units without an explicit power share split their shaft (or the plant) evenly.
func _normalise_power() -> void:
	var groups := {}
	for u in units:
		var key: int = u["shaft"]
		groups[key] = groups.get(key, 0) + (1 if u["power"] <= 0.0 else 0)
	for u in units:
		if u["power"] <= 0.0:
			u["power"] = 1.0 / float(groups[u["shaft"]])
	if kind == "gt" or kind == "steam":
		# Explicit shares in a common plant are fractions of total power.
		pass


func is_lever() -> bool:
	return kind == "gt_cpp"


func bells() -> Array:
	return BELLS_US if nav == "us" else BELLS_SU


func bell_names_en() -> Array:
	return BELLS_US if nav == "us" else BELLS_SU_EN


func bell_rpm(i: int) -> float:
	return (RPM_US if nav == "us" else RPM_SU)[clampi(i, 0, 9)]


# ------------------------------------------------------------------ orders
func ring(i: int, shaft := -1) -> void:
	i = clampi(i, 0, 9)
	for s in shafts:
		if shaft < 0 or shaft == s:
			if bell[s] != i:
				bell[s] = i
				ans_timer[s] = rng.randf_range(1.6, 3.6)
				events.append("ring")


func bell_step(d: int) -> void:
	ring(bell[0] + d)


func set_lever(v: float, shaft := -1) -> void:
	v = clampf(v, -1.0, 1.0)
	for s in shafts:
		if shaft < 0 or shaft == s:
			lever[s] = v


func lever_step(d: float) -> void:
	set_lever(snappedf(lever[0] + d, 0.05))


## Generic "more/less speed" used by keys and the AI: bells or lever.
func order_step(d: int) -> void:
	if is_lever():
		lever_step(0.1 * d)
	else:
		bell_step(d)


## Order a speed fraction (-1..1); used by the AI and the autopilot.
func order_fraction(f: float) -> void:
	if is_lever():
		set_lever(_lever_for(f))
	else:
		var best := STOP
		var bd := 9.0
		for i in 10:
			var d := absf(bell_rpm(i) - f)
			if d < bd:
				bd = d
				best = i
		ring(best)


func _lever_for(f: float) -> float:
	if absf(f) <= 0.33:
		return f / 0.33 * 0.4
	return signf(f) * (0.4 + (absf(f) - 0.33) / 0.67 * 0.6)


func start_unit(i: int) -> void:
	if i < 0 or i >= units.size():
		return
	var u: Dictionary = units[i]
	if u["state"] == "standby":
		u["state"] = "starting"
		u["timer"] = START_TIME.get(kind, 60.0) * (1.6 if (kind == "steam" and not nuclear) else 1.0)
		if nuclear and String(u["name"]).contains("reactor"):
			u["timer"] = 30.0
		events.append("unit_start")


func stop_unit(i: int) -> void:
	if i < 0 or i >= units.size():
		return
	var u: Dictionary = units[i]
	if u["state"] == "online" or u["state"] == "starting":
		u["state"] = "standby"
		events.append("unit_stop")


func toggle_unit(i: int) -> void:
	if i < 0 or i >= units.size():
		return
	if units[i]["state"] == "standby":
		start_unit(i)
	elif units[i]["state"] != "failed":
		stop_unit(i)


func online_count() -> int:
	var n := 0
	for u in units:
		if u["state"] == "online":
			n += 1
	return n


# ------------------------------------------------------------------ simulation
## Fraction of full power available to shaft s from online units.
func avail(s: int) -> float:
	var p := 0.0
	var tot := 0.0
	for u in units:
		var sh: int = u["shaft"]
		if sh == -1 or sh == s:
			tot += u["power"]
			if u["state"] == "online":
				p += u["power"]
	if tot <= 0.0:
		return 0.0
	return clampf(p / tot, 0.0, 1.0)


func update(dt: float) -> void:
	for u in units:
		if u["state"] == "starting":
			u["timer"] -= dt
			if u["timer"] <= 0.0:
				u["state"] = "online"
				events.append("unit_online")
	var demand := 0.0
	for s in shafts:
		demand += pow(absf(rpm[s] * (pitch[s] if is_lever() else 1.0)), 3.0)
	demand /= float(shafts)
	if kind == "steam" and not nuclear:
		var supply := avail(0)
		steam = clampf(steam + (supply * 1.04 - demand) * 0.06 * dt, 0.2, 1.05)
	else:
		steam = 1.0
	for s in shafts:
		if is_lever():
			_cpp(s, dt)
		else:
			_telegraph(s, dt)


func _telegraph(s: int, dt: float) -> void:
	if bell[s] != answered[s]:
		ans_timer[s] -= dt
		if ans_timer[s] <= 0.0:
			answered[s] = bell[s]
			events.append("answer")
	var target := clampf(bell_rpm(answered[s]) + trim[s], -1.0, 1.0)
	var cap = pow(avail(s), 1.0 / 3.0) * shaft_ok[s]
	if kind == "steam" and not nuclear:
		cap *= clampf(steam / 0.88, 0.45, 1.0)
	var astern_max := 0.7 if kind == "steam" else (0.75 if kind == "gt" else 0.65)
	target = clampf(target, -astern_max * cap, cap)
	var rate := {"steam": 0.045, "nuclear": 0.06, "gt": 0.09, "diesel": 0.07}.get(kind, 0.05) as float
	var brake := rate * 1.6
	var hold_t := {"steam": 4.0, "nuclear": 3.0, "gt": 9.0, "diesel": 12.0}.get(kind, 5.0) as float
	var r: float = rpm[s]
	if r != 0.0 and signf(target) != signf(r) and target != 0.0:
		r = move_toward(r, 0.0, brake * dt)
		if r == 0.0:
			rev_hold[s] = hold_t
	elif rev_hold[s] > 0.0:
		rev_hold[s] -= dt
	else:
		r = move_toward(r, target, (rate if absf(target) > absf(r) else brake) * dt)
	rpm[s] = r


func _cpp(s: int, dt: float) -> void:
	var l: float = lever[s]
	var p_t := signf(l) * minf(1.0, absf(l) / 0.4)
	p_t = maxf(p_t, -0.75)
	var r_t := 0.33 + 0.67 * maxf(0.0, (absf(l) - 0.4) / 0.6)
	var cap = pow(avail(s), 1.0 / 3.0) * shaft_ok[s]
	if avail(s) <= 0.0:
		r_t = 0.0
	r_t = minf(r_t, cap)
	pitch[s] = move_toward(pitch[s], p_t, 0.14 * dt)
	rpm[s] = move_toward(rpm[s], r_t, 0.1 * dt)


## Speed fraction the shafts are driving toward (-1..1).
func output() -> float:
	var o := 0.0
	for s in shafts:
		o += rpm[s] * (pitch[s] if is_lever() else 1.0)
	o /= float(shafts)
	if has_apu and apu and absf(o) < 0.2:
		o = maxf(o, 0.2)
	return o


## Yaw tendency from unequal shafts (+ turns to starboard).
func torque_bias() -> float:
	if shafts < 2:
		return 0.0
	var port := 0.0
	var stbd := 0.0
	for s in shafts:
		var v: float = rpm[s] * (pitch[s] if is_lever() else 1.0)
		if s < shafts / 2:
			port += v
		elif shafts % 2 == 0 or s > shafts / 2:
			stbd += v
	return (port - stbd) / maxf(shafts * 0.5, 1.0)


## Shaft revolutions per minute for the gauges.
func shaft_rpm(s: int) -> float:
	return absf(rpm[s]) * max_rpm


func status_line() -> String:
	var parts := []
	for u in units:
		var st: String = u["state"]
		var tag := "ON" if st == "online" else ("..%ds" % int(u["timer"]) if st == "starting" else ("OFF" if st == "standby" else "DMG"))
		parts.append("%s %s" % [u["name"], tag])
	return "  ".join(parts)
