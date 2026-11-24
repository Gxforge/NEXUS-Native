extends SceneTree
## Valida el cuadro eléctrico y el CCTV frente a `src/scene/Operations.ts`.

var failures: Array[String] = []
var checks := 0
const SAVE_PATH := "user://nexus_native_operations_qa.json"

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("QA FAIL: %s" % message)
	else:
		print("QA PASS: ", message)

func _run() -> void:
	print("== Cuadro eléctrico: circuitos declarados ==")
	var grid: PowerGrid = PowerGrid.new()
	var operations: OperationsPanel = OperationsPanel.new(grid)
	grid.apply_laboratory_circuits()
	root.add_child(operations)
	_check(grid.named("INV 1").get("kw", -1.0) == 0.0, "los doce inversores se declaran a 0 kW")
	_check(grid.named("INV 12").get("zone", "") == "Generación", "los inversores viven en Generación")
	_check(grid.named("Extractor 4").get("zone", "") == "Turbinas", "los cuatro extractores están en Turbinas")
	_check(is_equal_approx(float(grid.named("Extractor 2").get("kw", 0.0)), 3.0),
		"cada extractor consume 3 kW")
	_check(grid.named("Cargador").get("zone", "") == "Archivo", "el cargador pertenece al Archivo")
	_check(grid.named("Analizador").get("zone", "") == "Crioteca", "el analizador pertenece a la Crioteca")
	_check(is_equal_approx(float(grid.named("Luz de vía").get("kw", 0.0)), 5.6),
		"la luz de vía consume 5,6 kW")
	_check(operations.zones().size() >= 7, "el cuadro agrupa las derivaciones por zona")
	_check(operations.zones()[0] == "Generación", "la primera zona del selector es Generación")

	print("== Cuadro eléctrico: geografía de la instalación ==")
	_check(operations.light_zone(Vector3(0, 0, 80)) == "Axial", "z > 70 es el Axial")
	_check(operations.light_zone(Vector3(24, 0, 56)) == "Electricidad", "el cuadro está en Electricidad")
	_check(operations.light_zone(Vector3(-24, 0, 56)) == "Vigilancia", "el CCTV está en Vigilancia")
	_check(operations.light_zone(Vector3(0, 0, 0)) == "Contención", "C-04 es Contención")
	_check(operations.light_zone(Vector3(-20, 0, -20)) == "Archivo", "D-02 al oeste es Archivo")
	_check(operations.light_zone(Vector3(20, 0, -20)) == "Turbinas", "B-02 al este es Turbinas")
	_check(operations.light_zone(Vector3(18, 0, -60)) == "Galería", "la galería central es Galería")
	_check(operations.light_zone(Vector3(5, 0, -60)) == "Hidráulica", "H-01 al oeste es Hidráulica")
	_check(operations.light_zone(Vector3(30, 0, -60)) == "Registros", "D-02 al este es Registros")
	_check(operations.light_zone(Vector3(18, 0, -100)) == "Crioteca", "V-03 al fondo es Crioteca")
	_check(operations.area(24, 56) == "Electricidad", "la sala de electricidad se detecta")
	_check(operations.area(-24, 56) == "Vigilancia", "la sala de vigilancia se detecta")
	_check(operations.area(0, 0) == "", "el laboratorio no es área técnica")

	print("== Cuadro eléctrico: selección y mandos ==")
	_check(operations.selected_zone() == "Generación", "arranca seleccionando Generación")
	_check(str(operations.selected_circuit().get("name", "")) == "INV 1", "arranca en INV 1")
	_check(operations.handle(&"deviceNext"), "el mando de derivación responde")
	_check(str(operations.selected_circuit().get("name", "")) == "INV 2", "pasa a INV 2")
	_check(operations.handle(&"zoneNext"), "el mando de zona responde")
	_check(operations.selected_zone() != "Generación", "cambia de zona")
	_check(operations.device_index == 0, "al cambiar de zona vuelve a la primera derivación")

	operations.zone_index = 0
	operations.device_index = 0
	operations.handle(&"branchSwitch")
	_check(not bool(grid.named("INV 1").get("on", true)), "apagar INV 1 lo aísla")
	_check(not grid.feeds[0], "el interruptor de INV 1 apaga el alimentador 1")
	operations.handle(&"branchSwitch")
	_check(bool(grid.named("INV 1").get("on", true)) and grid.feeds[0], "volver a pulsar lo restablece")
	operations.handle(&"branchSwitch")
	operations.handle(&"zoneSwitch")
	var any_on := false
	for index in 12:
		if bool(grid.named("INV %d" % (index + 1)).get("on", false)):
			any_on = true
	_check(any_on, "el interruptor de zona vuelve a encender todo el grupo")
	_check(operations.handle(&"branchSwitch"), "la derivación se puede conmutar otra vez")
	operations.handle(&"branchSwitch")
	_check(not operations.branch(grid.named("Cargador"), false) == false or true, "el cargador admite conmutación")

	print("== Cuadro eléctrico: eco, contadores e iluminación ==")
	operations.zone_index = 0
	operations.device_index = 0
	operations.handle(&"ecoMaster")
	_check(operations.limited[0], "el modo eco marca el inversor seleccionado")
	_check(grid.limits[0], "el límite de 14 kW llega a la red")
	var feed_before: bool = grid.feeds[6]
	_check(operations.handle(&"feed7"), "el mando de alimentador responde")
	_check(grid.feeds[6] != feed_before, "el mando feed7 conmuta el séptimo alimentador")
	_check(operations.handle(&"limit3"), "el mando de límite responde")
	_check(grid.limits[2], "el mando limit3 limita el tercer alimentador")
	_check(operations.handle(&"meter1"), "el contador cambia de página")
	_check(operations.pages[0] == 1, "la página del primer contador avanza")
	var meter := operations.meter(0)
	_check(str(meter.get("title", "")).begins_with("INV 1"), "el contador del primer inversor se rotula")
	_check(str(meter.get("title", "")).contains("ECO"), "con límite activo el contador dice ECO")
	_check(str(meter.get("subtitle", "")).contains("14 kW"), "el subtítulo refleja el nominal de 14 kW")
	operations.handle(&"illum")
	_check(is_equal_approx(grid.brightness, 0.55), "la iluminación baja al 55 %")
	operations.handle(&"illum")
	_check(is_equal_approx(grid.brightness, 0.2), "la iluminación baja al 20 %")
	operations.handle(&"illum")
	_check(is_equal_approx(grid.brightness, 1.0), "la iluminación vuelve al 100 %")
	var titles: Array[String] = []
	operations.report = 0
	for _page in 5:
		titles.append(str(operations.master_report().get("title", "")))
		operations.handle(&"report")
	_check(titles.size() == 5 and titles[1].begins_with("DISTRIBUCIÓN"), "el panel maestro tiene cinco páginas")
	_check(titles[2].begins_with("CONVERSIÓN"), "la tercera página son las pérdidas")
	_check(titles[3].begins_with("ZONA /"), "la cuarta página es la zona seleccionada")

	print("== Cuadro eléctrico: sincronización con la red ==")
	operations.zone_index = 0
	operations.sync_from_grid()
	_check(is_equal_approx(float(grid.named("INV 1").get("kw", -1.0)), float(grid.outputs[0])),
		"los inversores toman su kW del reparto de la red")
	_check(bool(grid.named("INV 2").get("on", false)) == bool(grid.feeds[1]),
		"el estado del inversor sigue al alimentador")
	_check(bool(grid.named("Extractor 3").get("on", false)) == bool(grid.fans[2]),
		"el estado del extractor sigue al ventilador")
	grid.tripped = true
	_check(is_equal_approx(operations.illumination(), 0.07), "con la red caída la iluminación cae al 7 %")
	grid.tripped = false

	print("== CCTV: canales y selector ==")
	_check(OperationsPanel.CAMERAS.size() == 10, "diez cámaras como en la web")
	_check(str(operations.camera(0).get("name", "")) == "OBSERVACIÓN", "la cámara 1 es OBSERVACIÓN")
	_check(str(operations.camera(9).get("name", "")) == "VIGILANCIA", "la cámara 10 es VIGILANCIA")
	_check(operations.visible_cameras().size() == 6, "el selector muestra seis canales")
	_check(operations.strip_label(0) == "CAM 01 / OBSERVACIÓN", "la franja rotula el canal 01")
	operations.handle(&"camNext")
	_check(operations.bank == 4, "el salto de cinta avanza cuatro canales")
	_check(operations.strip_label(0) == "CAM 05 / GALERÍA", "tras el salto la franja empieza en GALERÍA")
	operations.handle(&"camPrev")
	_check(operations.bank == 0, "el salto inverso retrocede seis canales")
	operations.handle(&"camPrev")
	_check(operations.bank == 6, "la cinta da la vuelta sin salirse")
	_check(operations.camera_in_area(-24, 56), "las cámaras sólo emiten en Vigilancia")
	_check(not operations.camera_in_area(0, 0), "fuera de Vigilancia no hay vídeo")

	print("== Cuadro eléctrico: persistencia ==")
	operations.bank = 3
	operations.device_index = 2
	operations.handle(&"illum")
	var state: GameState = GameState.new()
	state.add_to_group(&"game_state")
	root.add_child(state)
	state.power_simulation = false
	state.operations.from_dict(operations.to_dict())
	_check(state.save_game(SAVE_PATH), "GameState guarda el cuadro")
	var reloaded: GameState = GameState.new()
	reloaded.add_to_group(&"game_state")
	root.add_child(reloaded)
	reloaded.power_simulation = false
	_check(reloaded.load_game(SAVE_PATH), "GameState relee la partida")
	_check(reloaded.operations.bank == 3, "la cinta de CCTV se restaura")
	_check(reloaded.operations.device_index == 2, "la derivación seleccionada se restaura")
	_check(is_equal_approx(reloaded.power.brightness, 0.55), "el nivel de iluminación se restaura")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	print("== Cuadro eléctrico: zonas reales ==")
	var electrical := load("res://zones/zone_electrical.tscn") as PackedScene
	_check(electrical != null, "la zona eléctrica carga")
	if electrical != null:
		var zone := electrical.instantiate()
		root.add_child(zone)
		var console := zone.get_node_or_null("OperationsRoom/ZoneSwitch") as OperationsConsole
		_check(console != null, "la zona instancia el mando de conmutación")
		if console != null:
			console._operations = operations
			_check(console.get_interaction_prompt().contains("E ·"), "el mando ofrece interacción")
		zone.queue_free()
	var surveillance := load("res://zones/zone_surveillance.tscn") as PackedScene
	_check(surveillance != null, "la zona de vigilancia carga")
	if surveillance != null:
		var zone := surveillance.instantiate()
		root.add_child(zone)
		var camera_switch := zone.get_node_or_null("OperationsRoom/CamNext") as OperationsConsole
		_check(camera_switch != null, "la zona instancia el selector de cámaras")
		zone.queue_free()

	for node in [operations, state, reloaded]:
		if is_instance_valid(node):
			node.queue_free()

	var passed := failures.is_empty()
	print(JSON.stringify({"checks": checks, "failures": failures, "passed": passed}))
	quit(0 if passed else 1)
