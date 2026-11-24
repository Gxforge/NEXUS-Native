extends SceneTree
## Valida los bancos técnicos frente a `src/scene/BenchCycle.ts`.

var failures: Array[String] = []
var checks := 0
const SAVE_PATH := "user://nexus_native_bench_qa.json"

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("QA FAIL: %s" % message)
	else:
		print("QA PASS: ", message)

func _player(state: GameState) -> NexusPlayer:
	var player: NexusPlayer = load("res://scripts/world/player.gd").new()
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	player.add_child(camera)
	root.add_child(player)
	player.game_state = state
	return player

func _run() -> void:
	print("== Bancos: estado inicial ==")
	var state: GameState = GameState.new()
	state.power_simulation = false
	state.add_to_group(&"game_state")
	root.add_child(state)
	var charger := state.bench(BenchCycle.CHARGER)
	var analyzer := state.bench(BenchCycle.ANALYZER)
	_check(charger != null, "existe la cuna de carga")
	_check(analyzer != null, "existe la platina del analizador")
	_check(is_equal_approx(charger.duration(), 8.0), "la cuna tarda 8 s")
	_check(is_equal_approx(analyzer.duration(), 10.0), "el analizador tarda 10 s")
	_check(charger.item.is_empty(), "la cuna arranca vacía")
	_check(charger.stage == "EN ESPERA", "la pantalla dice EN ESPERA")
	_check(is_zero_approx(charger.kw()), "un banco vacío no consume")

	var player: NexusPlayer = _player(state)
	state.inventory.assign([&"lamp", &"cell", &"sample"] as Array[StringName])
	state.quick_slots.assign([&"cell", &"lamp", &"", &"", &""] as Array[StringName])
	player.flashlight_battery = 42.0
	player.energy = 30.0

	print("== Bancos: montaje en la cuna ==")
	player.selected_quick_slot = 0
	var mounted := charger.interact(player)
	_check(mounted.contains("Acoplando"), "montar la celda acopla los contactos")
	_check(charger.item == &"cell", "la cuna se queda con la celda")
	_check(not state.has_item(&"cell"), "la celda sale del inventario")
	_check(is_equal_approx(charger.kw(), 18.0), "la cuna consume 18 kW en marcha")
	_check(charger.interact(player) == "Ciclo en curso", "no se puede montar otro equipo a mitad")

	print("== Bancos: ciclo y corte por red ==")
	charger.update(0.5, player, false)
	_check(charger.stage == "ACOPLANDO", "al medio segundo acopla")
	charger.update(2.0, player, true)
	_check(charger.stage == "SIN RED", "sin red el ciclo se detiene y lo dice")
	_check(is_equal_approx(charger.elapsed, 0.5), "sin red el tiempo no avanza")
	charger.update(7.6, player, false)
	_check(charger.done, "con red el ciclo termina")
	_check(is_equal_approx(player.energy, 100.0), "el banco recarga la energía de la herramienta")
	_check(charger.stage == "CARGADO / RETIRAR", "la pantalla pide retirar la celda")
	_check(bool(state.bench_state.get("charged", false)), "la celda queda marcada como cargada")
	_check(is_zero_approx(charger.kw()), "terminado el ciclo deja de consumir")
	var retired := charger.interact(player)
	_check(retired == "Equipo retirado", "retirar devuelve el equipo")
	_check(state.has_item(&"cell"), "la celda vuelve al inventario")
	_check(charger.item.is_empty() and charger.stage == "EN ESPERA", "la cuna queda libre")

	print("== Bancos: selección de equipo ==")
	player.flashlight_battery = 100.0
	state.remove_item(&"lamp")
	_check(charger.interact(player).contains("Carga completa"),
		"una celda ya cargada no se vuelve a montar")
	state.add_item(&"lamp")
	state.quick_slots[1] = &"lamp"
	player.flashlight_battery = 20.0
	player.selected_quick_slot = 1
	var lamp_mount := charger.interact(player)
	_check(lamp_mount.contains("Acoplando"), "con la linterna seleccionada monta la linterna")
	_check(charger.item == &"lamp", "la cuna se queda con la linterna")
	_check(not player.flashlight_enabled, "montar la linterna la apaga")
	charger.update(9.0, player, false)
	_check(is_equal_approx(player.flashlight_battery, 100.0), "la linterna sale al 100 %")
	charger.interact(player)
	player.selected_quick_slot = 3
	player.flashlight_battery = 20.0
	state.inventory.assign([&"nothing"] as Array[StringName])
	_check(charger.interact(player).contains("celda o una linterna"),
		"sin equipo válido la cuna lo explica")

	print("== Bancos: analizador de muestras ==")
	state.add_item(&"sample")
	var analysis := analyzer.interact(player)
	_check(analysis.contains("Vial"), "el vial entra en transferencia")
	_check(analyzer.item == &"sample", "la platina se queda la muestra")
	_check(is_equal_approx(analyzer.kw(), 9.0), "el analizador consume 9 kW")
	analyzer.update(4.0, player, false)
	_check(analyzer.stage == "ENFOQUE", "al 40 % está en enfoque")
	analyzer.update(1.0, player, false)
	_check(analyzer.stage == "BARRIDO", "al 50 % barre la muestra")
	analyzer.update(3.0, player, false)
	_check(analyzer.stage == "VERIFICACIÓN", "al 80 % verifica")
	analyzer.update(3.0, player, false)
	_check(analyzer.done, "el ensayo termina a los 10 s")
	_check(analyzer.stage == "VERIFICADO / RETIRAR", "la pantalla pide retirar el vial")
	_check(bool(state.bench_state.get("analyzed", false)), "la muestra queda analizada")
	_check(analyzer.interact(player) == "Equipo retirado", "el vial se puede retirar")
	state.remove_item(&"sample")
	_check(analyzer.interact(player).contains("espera el vial"), "sin vial la platina no arranca")

	print("== Bancos: consumo en la red ==")
	state.add_item(&"cell")
	state.quick_slots[0] = &"cell"
	state.bench_state["charged"] = false
	player.selected_quick_slot = 0
	charger.interact(player)
	state.power.machines = 0.0
	state.power_simulation = true
	state.set_process(true)
	state._process(0.1)
	_check(is_equal_approx(state.power.machines, 18.0), "la cuna en marcha suma 18 kW a la carga de la red")
	state.power_simulation = false

	print("== Bancos: persistencia ==")
	var saved: bool = state.save_game(SAVE_PATH)
	_check(saved, "GameState guarda los bancos")
	var reloaded: GameState = GameState.new()
	reloaded.power_simulation = false
	root.add_child(reloaded)
	_check(reloaded.load_game(SAVE_PATH), "GameState relee la partida")
	var restored := reloaded.bench(BenchCycle.CHARGER)
	_check(restored.item == &"cell", "el equipo montado sigue en la cuna tras cargar")
	_check(is_equal_approx(restored.elapsed, charger.elapsed), "el tiempo del ciclo se conserva")
	_check(bool(reloaded.bench_state.get("charged", false)) == bool(state.bench_state.get("charged", false)),
		"los indicadores del banco se conservan")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	print("== Bancos: zonas reales ==")
	var hydraulics := load("res://zones/zone_h01_hydraulics.tscn") as PackedScene
	_check(hydraulics != null, "la zona H–01 carga")
	if hydraulics != null:
		var zone := hydraulics.instantiate()
		root.add_child(zone)
		var bench := zone.get_node_or_null("Bench/ChargerBench") as BenchStation
		_check(bench != null, "la zona H–01 instancia la cuna de carga")
		if bench != null:
			_check(bench.display_name.contains("Cuna"), "la cuna se rotula en la zona")
		zone.queue_free()
	var turbines := load("res://zones/zone_b02_turbines.tscn") as PackedScene
	_check(turbines != null, "la zona B–02 carga")
	if turbines != null:
		var zone := turbines.instantiate()
		root.add_child(zone)
		var bench := zone.get_node_or_null("Bench/AnalyzerBench") as BenchStation
		_check(bench != null, "la zona B–02 instancia la platina del analizador")
		zone.queue_free()

	if player != null and is_instance_valid(player):
		player.free()
	for node in [state, reloaded]:
		if is_instance_valid(node):
			node.queue_free()

	var passed := failures.is_empty()
	print(JSON.stringify({"checks": checks, "failures": failures, "passed": passed}))
	quit(0 if passed else 1)
