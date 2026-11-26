extends SceneTree
## Genera `data/load_plan.json`: qué recursos necesita cada zona y cuánto pesan.
##
##   godot --headless --script tools/gen_load_plan.gd
##
## La pantalla de carga se apoya en este manifiesto porque en el juego
## exportado los `.tscn` y `.glb` van remapeados a `.scn` y su texto ya no se
## puede leer. Se regenera en `tools/build.sh` y se versiona con el proyecto.

const OUTPUT := "res://data/load_plan.json"
const DEPTH := 2

func _initialize() -> void:
	var zones := {}
	var total_files := 0
	var total_kb := 0.0
	var directory := DirAccess.open("res://zones")
	if directory == null:
		push_error("No se pudo abrir res://zones")
		quit(1)
		return
	var names := directory.get_files()
	names.sort()
	for name in names:
		if not name.ends_with(".tscn"):
			continue
		var module_path := "res://zones/" + name
		var files: Array = []
		var kilobytes := 0.0
		# `false` = escanear siempre en disco, nunca leer el manifiesto viejo.
		for path: String in LoadingProgress.plan(module_path, DEPTH, false):
			var size := LoadingProgress.file_kb(path)
			files.append({"path": path, "kb": snappedf(size, 0.1)})
			kilobytes += size
		if files.is_empty():
			continue
		zones[module_path] = {
			"files": files,
			"kb": snappedf(kilobytes, 0.1),
			"count": files.size(),
		}
		total_files += files.size()
		total_kb += kilobytes
	var payload := {
		"engine": Engine.get_version_info().get("string", ""),
		"generated": Time.get_datetime_string_from_system(true),
		"depth": DEPTH,
		"zones": zones,
	}
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo escribir %s" % OUTPUT)
		quit(1)
		return
	file.store_string(JSON.stringify(payload, "  ", false) + "\n")
	file.close()
	print("load plan: %d zonas · %d recursos · %.1f MB" % [zones.size(), total_files, total_kb / 1024.0])
	quit()
