extends SceneTree
## Valida los archivadores D–02 frente a `src/scene/Files.ts`.

var failures: Array[String] = []
var checks := 0
const SAVE_PATH := "user://nexus_native_files_qa.json"

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("QA FAIL: %s" % message)
	else:
		print("QA PASS: ", message)

func _new_files() -> FilesModule:
	var files := FilesModule.new()
	files.apply_web_layout()
	root.add_child(files)
	return files

func _settle(files: FilesModule, index: int, player: Vector3, steps := 90) -> void:
	for _step in steps:
		files.update(1.0 / 30.0, player)

func _run() -> void:
	print("== Archivo D–02: estructura ==")
	var files := _new_files()
	_check(files.tray_count() == 10, "diez bandejas como en la web")
	_check(files.DOSSIERS.size() == 6, "seis expedientes con contenido")
	_check(str(files.dossier_of(0).get("title", "")) == "Ciclo de retorno",
		"el primer expediente es Ciclo de retorno")
	_check(str(files.dossier_of(5).get("title", "")) == "Parte de inspección",
		"el sexto expediente es Parte de inspección")
	_check(str(files.dossier_of(0).get("text", "")).contains("líquido verde"),
		"el texto del expediente se conserva tal cual")
	_check(not files.tray_open(0), "las bandejas empiezan cerradas")

	print("== Archivo D–02: apertura y tope por proximidad ==")
	var home: Vector3 = files.trays[0]["home"]
	_check(files.toggle(0), "la bandeja acepta apertura")
	_check(files.tray_open(0), "la bandeja queda marcada como abierta")
	_settle(files, 0, home + Vector3(6.0, 0.0, 0.0))
	_check(files.tray_factor(0) > 0.95, "sin nadie delante la bandeja sale del todo")
	_check(files.tray_revealed(0), "con la bandeja fuera el folio es legible")
	_check(files.solid(home.x, two_metres_ahead(files, 0)), "la bandeja abierta bloquea el paso")
	_settle(files, 0, home + _forward(files, 0) * 1.3)
	_check(files.tray_factor(0) < 0.15, "de pie delante la bandeja se detiene sin empujar")
	_check(not files.tray_revealed(0), "con la bandeja detenida el folio no se puede leer")
	_check(files.toggle(0), "la bandeja se puede cerrar")
	_settle(files, 0, home + Vector3(6.0, 0.0, 0.0))
	_check(files.tray_factor(0) < 0.05, "cerrada vuelve a su sitio")
	_check(not files.solid(home.x, two_metres_ahead(files, 0)), "cerrada ya no bloquea el paso")

	print("== Archivo D–02: lectura y bitácora ==")
	var state: GameState = GameState.new()
	state.add_to_group(&"game_state")
	root.add_child(state)
	state.power_simulation = false
	state.register_files(files)
	var closed_read := files.read_tray(0, null)
	_check(closed_read.contains("cerrada") or closed_read.contains("cerrado"),
		"no se lee un expediente con la bandeja cerrada")
	files.toggle(0)
	_settle(files, 0, home + Vector3(6.0, 0.0, 0.0))
	var read := files.read_tray(0, null)
	_check(read.contains("Ciclo de retorno"), "la lectura devuelve el título del expediente")
	_check(state.survey_records.size() == 1, "el expediente entra en la bitácora")
	_check(str(state.survey_records[0].get("id", "")) == "dossier_0",
		"el registro lleva identificador estable")
	_check(str(state.survey_records[0].get("zone", "")) == "d02", "el registro anota la zona D–02")
	files.read_tray(0, null)
	_check(state.survey_records.size() == 1, "releer no duplica el registro")
	_check(files.is_read(0), "el expediente queda marcado como leído")
	files.toggle(6)
	_settle(files, 6, (files.trays[6]["home"] as Vector3) + Vector3(0.0, 0.0, 6.0))
	files.read_tray(6, null)
	_check(state.survey_records.size() == 2, "un segundo expediente añade otro registro")

	print("== Archivo D–02: persistencia ==")
	var saved: bool = state.save_game(SAVE_PATH)
	_check(saved, "GameState guarda el estado del archivo")
	var reloaded: GameState = GameState.new()
	reloaded.add_to_group(&"game_state")
	root.add_child(reloaded)
	reloaded.power_simulation = false
	_check(reloaded.load_game(SAVE_PATH), "GameState relee la partida")
	var restored := _new_files()
	reloaded.register_files(restored)
	_check(restored.tray_open(6), "la bandeja abierta sigue abierta tras cargar")
	_check(restored.is_read(0), "los expedientes leídos se conservan")
	restored.reset()
	_check(not restored.tray_open(6) and not restored.is_read(0), "reset limpia bandejas y lecturas")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	print("== Archivo D–02: zona real ==")
	var packed := load("res://zones/zone_d02_records.tscn") as PackedScene
	_check(packed != null, "la zona D–02 carga con el archivo")
	if packed != null:
		var zone := packed.instantiate()
		root.add_child(zone)
		var module := zone.get_node_or_null("FilesModule") as FilesModule
		_check(module != null, "la zona instancia el módulo de archivo")
		if module != null:
			var tray := module.get_node_or_null("Tray0") as FilesTray
			_check(tray != null, "hay una bandeja interactiva en la zona")
			if tray != null:
				tray._files = module
				_check(tray.get_interaction_prompt().contains("Abrir"), "la bandeja ofrece abrir")
		zone.queue_free()

	for node in [files, restored, state, reloaded]:
		if is_instance_valid(node):
			node.queue_free()

	var passed := failures.is_empty()
	print(JSON.stringify({"checks": checks, "failures": failures, "passed": passed}))
	quit(0 if passed else 1)

## Vector unitario "hacia fuera" de la bandeja según su giro.
func _forward(files: FilesModule, index: int) -> Vector3:
	var rotation: float = files.trays[index]["rotation"]
	return Vector3(-sin(rotation), 0.0, cos(rotation))

func two_metres_ahead(files: FilesModule, index: int) -> float:
	var home: Vector3 = files.trays[index]["home"]
	return home.z + _forward(files, index).z * 2.0
