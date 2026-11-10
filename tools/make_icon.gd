extends SceneTree
## Renders icon.svg to a square PNG, for desktop packaging (the AppImage).
## godot --headless --path . -s tools/make_icon.gd -- <size> <out.png>

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var px := int(a[0]) if a.size() > 0 else 256
	var out: String = a[1] if a.size() > 1 else "icon.png"
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	var img := Image.new()
	# The SVG is drawn at 128 px; scale it to the size asked for.
	var err := img.load_svg_from_string(svg, px / 128.0)
	if err != OK or img.get_width() != px:
		push_error("could not render icon.svg at %d px" % px)
		quit(1)
		return
	err = img.save_png(out)
	print("ICON %s %dx%d" % [out, img.get_width(), img.get_height()])
	quit(0 if err == OK else 1)
