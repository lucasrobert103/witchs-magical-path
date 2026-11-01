extends SceneTree
## Loads every script and shader so parse errors fail fast.

func _initialize() -> void:
	await process_frame
	var failed := 0
	for path in _files("res://scripts") + _files("res://shaders"):
		var res = load(path)
		if res == null:
			push_error("Failed to load " + path)
			failed += 1
		elif res is GDScript and not (res as GDScript).can_instantiate():
			push_error("Cannot compile " + path)
			failed += 1
	print("compile_all: %d failures" % failed)
	quit(1 if failed else 0)

func _files(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".gdshader"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out += _files(dir + "/" + sub)
	return out
