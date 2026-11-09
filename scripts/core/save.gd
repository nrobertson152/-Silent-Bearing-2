extends RefCounted
## Campaign progress, saved to user://campaign.json.

## Where progress is kept; tests point this somewhere else.
static var path := "user://campaign.json"

static var data := {}
static var _loaded := false


static func _blank() -> Dictionary:
	return {"done": [], "results": {}, "nuclear": false, "intro_seen": false, "finished": false}


static func load_save(force := false) -> void:
	if _loaded and not force:
		return
	_loaded = true
	data = {"us": _blank(), "su": _blank()}
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		for side in ["us", "su"]:
			if d.has(side) and d[side] is Dictionary:
				var b := _blank()
				for k in d[side]:
					b[k] = d[side][k]
				data[side] = b


static func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))


static func side_data(side: String) -> Dictionary:
	load_save()
	return data[side]


## Index of the furthest mission the player may play.
static func unlocked(side: String) -> int:
	var d := side_data(side)
	return (d["done"] as Array).size()


static func is_done(side: String, id: String) -> bool:
	return (side_data(side)["done"] as Array).has(id)


static func complete(side: String, id: String, stats: Dictionary) -> void:
	var d := side_data(side)
	if not (d["done"] as Array).has(id):
		(d["done"] as Array).append(id)
	var prev: Dictionary = d["results"].get(id, {})
	var rec := {"hits": stats.get("hits", 0), "shots": stats.get("shots", 0), "kills": stats.get("kills", 0),
		"missiles": stats.get("missiles", 0), "intercepts": stats.get("intercepts", 0), "times": int(prev.get("times", 0)) + 1}
	d["results"][id] = rec
	if int(stats.get("nuclear", 0)) > 0:
		d["nuclear"] = true
	save()


static func mark(side: String, key: String, value) -> void:
	side_data(side)[key] = value
	save()


static func reset(side: String) -> void:
	load_save()
	data[side] = _blank()
	save()
