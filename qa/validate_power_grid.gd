extends SceneTree
## Valida el port de `Power.ts` (red eléctrica) frente a los números de la web.

var failures: Array[String] = []
var checks := 0
const SAVE_PATH := "user://nexus_native_power_qa.json"

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("QA FAIL: %s" % message)
	else:
		print("QA PASS: ", message)

func _close(a: float, b: float, tolerance := 0.01) -> bool:
	return absf(a - b) <= tolerance

func _run() -> void:
	print("== Red eléctrica: construcción ==")
	var grid: PowerGrid = PowerGrid.for_laboratory()
	grid.reset()
	grid.machines = 6.0
	grid.update(0.0, false, 0.0)
	_check(grid.feeds.size() == 12, "doce alimentadores declarados")
	_check(grid.feeds_on() == 4, "cuatro alimentadores activos por defecto")
	_check(_close(grid.capacity, 112.0), "capacidad inicial 112 kW")
	_check(grid.fans_on() == 4, "cuatro extractores activos")
	_check(grid.circuits.size() == 8, "ocho circuitos de laboratorio")
	_check(_close(grid.light_kw, 30.0), "circuitos de luces de Electricidad suman 30 kW")
	_check(grid.circuits_of("c04").size() == 1, "C-04 declara su circuito de instrumentación")
	_check(grid.named("Turbinas B-02").get("kw", 0.0) == 22.0, "circuito B-02 recuperable por nombre")
	_check(grid.named("CCTV").get("locked", false), "el circuito de CCTV está bloqueado")
	_check(not grid.set_circuit("CCTV", false), "no se puede apagar un circuito bloqueado")

	print("== Red eléctrica: régimen estable ==")
	grid.update(0.0, false, 0.0)
	_check(_close(grid.load_kw, 70.0), "carga estable 70 kW (22 + luces 30 + máquinas 6 + extractores 12)")
	_check(_close(grid.delivered, 70.0), "potencia entregada = carga cuando hay capacidad")
	_check(_close(grid.input_kw, 70.0 / 0.956, 0.05), "consumo de entrada con rendimiento 0.956")
	_check(_close(grid.outputs[0], 17.5, 0.05), "reparto del primer alimentador (70·28/112)")
	var kwh_before: float = grid.kwh[0]
	grid.update(1.0, false, 0.0)
	_check(grid.kwh[0] > kwh_before, "la energía acumulada crece con el tiempo")
	_check(not grid.tripped, "sin sobrecarga el interruptor sigue armado")

	print("== Red eléctrica: sobrecarga y disparo ==")
	grid.spike("extractor de bancada", 60.0, 6.0)
	grid.update(0.0, false, 0.0)
	_check(grid.load_kw > grid.capacity, "un pico grande supera la capacidad")
	var tripped_at: int = -1
	for step in 20:
		if grid.update(0.5, false, 0.0):
			tripped_at = step
			break
	_check(tripped_at >= 0, "el interruptor dispara por sobrecarga sostenida")
	_check(grid.tripped, "la red queda marcada como caída")
	_check(grid.cause.begins_with("Sobrecarga"), "la causa del disparo es sobrecarga")
	grid.update(0.0, false, 0.0)
	_check(_close(grid.load_kw, 17.0), "con la red caída la carga residual es 17 kW")
	_check(_close(grid.delivered, 0.0), "con la red caída no se entrega potencia")
	_check(grid.status_line().begins_with("RED CAÍDA"), "el HUD lee la red como caída")

	print("== Red eléctrica: rearme ==")
	grid.set_feed(1, false)
	grid.set_feed(2, false)
	grid.set_feed(3, false)
	grid.update(0.0, false, 0.0)
	var low_capacity: String = grid.rearm()
	_check(low_capacity.contains("84 kW"), "con poca capacidad el rearme pide restablecer 84 kW")
	_check(grid.tripped, "un rearme bloqueado por capacidad no arma el interruptor")
	grid.set_feed(1, true)
	grid.set_feed(2, true)
	grid.set_feed(3, true)
	grid.set_fan(0, false)
	grid.set_fan(1, false)
	grid.set_fan(2, false)
	grid.update(0.0, false, 0.0)
	var blocked: String = grid.rearm()
	_check(blocked.contains("refrigeración"),
		"el rearme avisa de la refrigeración cuando faltan extractores")
	_check(grid.tripped, "un rearme bloqueado por refrigeración no arma el interruptor")
	grid.set_fan(0, true)
	grid.set_fan(1, true)
	grid.set_fan(2, true)
	for step in 400:
		grid.update(0.25, false, 0.0)
		if grid.temp < 60.0:
			break
	_check(grid.temp < 65.0, "sin carga la temperatura baja de 65 °C")
	var restored: String = grid.rearm()
	_check(restored.contains("Red restablecida"), "con refrigeración y capacidad el rearme se acepta")
	_check(not grid.tripped, "el interruptor queda armado")
	_check(_close(grid.stress, 0.0), "el estrés vuelve a cero tras rearmar")

	print("== Red eléctrica: alimentadores, límites y motor ==")
	grid.cycle_feed(4)
	grid.update(0.0, false, 0.0)
	_check(_close(grid.capacity, 140.0), "cinco alimentadores dan 140 kW")
	grid.set_limit(0, true)
	grid.update(0.0, false, 0.0)
	_check(_close(grid.capacity, 126.0), "limitar un alimentador resta 14 kW")
	_check(_close(grid.outputs[0], grid.delivered * 14.0 / 126.0, 0.1),
		"el alimentador limitado reparte la mitad")
	var load_before: float = grid.load_kw
	grid.update(0.0, true, 0.0)
	_check(grid.load_kw - load_before >= 44.0, "el motor de V-03 añade 45 kW")
	grid.update(0.0, false, 1.0)
	_check(grid.load_kw - load_before >= 13.0, "la agresividad del sujeto añade carga")

	print("== Red eléctrica: persistencia ==")
	var other: PowerGrid = PowerGrid.for_laboratory()
	other.set_fan(2, false)
	other.cycle_feed(6)
	other.spike("prueba", 12.0, 30.0)
	other.update(0.5, false, 0.3)
	var restored_grid: PowerGrid = PowerGrid.for_laboratory()
	_check(restored_grid.from_dict(other.to_dict()), "el estado eléctrico se restaura desde diccionario")
	_check(restored_grid.feeds[6], "los alimentadores restaurados coinciden")
	_check(not restored_grid.fans[2], "los extractores restaurados coinciden")
	_check(restored_grid.surges.size() == 1, "los picos activos se conservan en el guardado")
	_check(_close(restored_grid.temp, other.temp, 0.001), "la temperatura sobrevive al guardado")

	var state: GameState = GameState.new()
	root.add_child(state)
	state.power_simulation = false
	state.power.set_fan(1, false)
	state.power.update(0.5, true, 0.45)
	var saved: bool = state.save_game(SAVE_PATH)
	_check(saved, "GameState guarda la red dentro de la partida")
	var reloaded: GameState = GameState.new()
	root.add_child(reloaded)
	reloaded.power_simulation = false
	_check(reloaded.load_game(SAVE_PATH), "GameState relee la partida con la red")
	_check(not reloaded.power.fans[1], "el extractor apagado sobrevive al ciclo guardar/cargar")
	_check(_close(reloaded.power.temp, state.power.temp, 0.001), "la temperatura sobrevive al ciclo guardar/cargar")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	state.queue_free()
	reloaded.queue_free()

	var passed := failures.is_empty()
	print(JSON.stringify({"checks": checks, "failures": failures, "passed": passed}))
	quit(0 if passed else 1)
