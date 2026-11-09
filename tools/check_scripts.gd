extends SceneTree
## Compiles every script in the project and reports failures.
## godot --headless --path . -s tools/check_scripts.gd


func _init() -> void:
	var bad := 0
	var files := []
	_scan("res://scripts", files)
	_scan("res://tools", files)
	_scan("res://tests", files)
	for f in files:
		var s = load(f)
		if s == null or not (s as GDScript).can_instantiate():
			bad += 1
			print("SCRIPT FAIL ", f)
	print("checked %d scripts, %d failed" % [files.size(), bad])
	quit(1 if bad > 0 else 0)


func _scan(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		_scan(dir + "/" + sub, out)
