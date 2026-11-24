class_name BenchCycle
extends RefCounted
## Ciclo de banco de carga y de ensayo óptico.
##
## Port de `src/scene/BenchCycle.ts`: la cuna (cargador, 8 s, 18 kW) y la platina
## del analizador (10 s, 9 kW). La selección de objeto, las etapas del ciclo, el
## corte por caída de red y el consumo que se inyecta en `PowerGrid.machines` son
## los mismos que en la web.

signal stage_changed(bench_id: StringName, stage: String, progress: float)
signal finished(bench_id: StringName, item: StringName)

const CHARGER := &"charger"
const ANALYZER := &"analyzer"
const CHARGER_SECONDS := 8.0
const ANALYZER_SECONDS := 10.0
const CHARGER_KW := 18.0
const ANALYZER_KW := 9.0
const MOUNT_SECONDS := 1.3
const BATTERY_FULL := 99.9

var id: StringName = CHARGER
var item: StringName = &""
var slot := -1
var elapsed := 0.0
var done := false
var stage := "EN ESPERA"

var _player: NexusPlayer


func _init(bench_id: StringName = CHARGER) -> void:
	id = bench_id


func duration() -> float:
	return ANALYZER_SECONDS if id == ANALYZER else CHARGER_SECONDS


## Consumo instantáneo que entra en la red como "máquinas".
func kw() -> float:
	if item.is_empty() or done:
		return 0.0
	return ANALYZER_KW if id == ANALYZER else CHARGER_KW


func progress() -> float:
	var total := duration()
	return clampf(elapsed / total, 0.0, 1.0) if total > 0.0 else 0.0


func is_busy() -> bool:
	return not item.is_empty() and not done


## Estado que muestra la pantalla del banco, tal cual `BenchCycle.draw`.
func stage_for(tripped: bool) -> String:
	if item.is_empty():
		return "EN ESPERA"
	if done:
		return "VERIFICADO / RETIRAR" if id == ANALYZER else "CARGADO / RETIRAR"
	if tripped:
		return "SIN RED"
	if elapsed < MOUNT_SECONDS:
		return "ACOPLANDO"
	var ratio := progress()
	if id == ANALYZER:
		if ratio < 0.46:
			return "ENFOQUE"
		if ratio < 0.8:
			return "BARRIDO"
		return "VERIFICACIÓN"
	if ratio < 0.83:
		return "CARGANDO"
	return "EQUILIBRADO"


# --------------------------------------------------------------------------- #
# interacción
# --------------------------------------------------------------------------- #
## Pulsar en el banco: montar el equipo o retirarlo cuando el ciclo ha acabado.
func interact(player: NexusPlayer) -> String:
	_player = player
	var state := _state()
	if state == null:
		return "Banco sin inventario"
	if not item.is_empty():
		if not done:
			return "Ciclo en curso"
		var retired := item
		state.add_item(retired)
		reset()
		state.save_game()
		return "Equipo retirado"
	if id == ANALYZER:
		if not state.has_item(&"sample"):
			return "La platina espera el vial"
		return _mount(&"sample", -1, state)
	var chosen := _chosen_item(state)
	var candidate: StringName = &""
	if chosen == &"cell" and state.has_item(&"cell"):
		candidate = &"cell"
	elif state.has_item(&"lamp") and (player != null and player.flashlight_battery < BATTERY_FULL):
		candidate = &"lamp"
	elif state.has_item(&"cell"):
		candidate = &"cell"
	elif state.has_item(&"lamp"):
		candidate = &"lamp"
	if candidate.is_empty():
		return "La cuna admite una celda o una linterna"
	if candidate == &"cell" and bool(state.bench_state.get("charged", false)):
		return "Carga completa · no requiere recarga"
	if candidate == &"lamp" and player != null and player.flashlight_battery >= BATTERY_FULL:
		return "Carga completa · no requiere recarga"
	var slot_index := int(player.selected_quick_slot) if player != null else -1
	return _mount(candidate, slot_index, state)


func _mount(candidate: StringName, slot_index: int, state: GameState) -> String:
	state.remove_item(candidate)
	item = candidate
	slot = slot_index
	elapsed = 0.0
	done = false
	if candidate == &"lamp" and _player != null:
		_player.flashlight_enabled = false
	_set_stage(stage_for(false))
	return "Vial en transferencia" if id == ANALYZER else "Acoplando contactos"


func _chosen_item(state: GameState) -> StringName:
	if _player == null or _player.selected_quick_slot < 0:
		return &""
	if _player.selected_quick_slot >= state.quick_slots.size():
		return &""
	return state.quick_slots[_player.selected_quick_slot]


# --------------------------------------------------------------------------- #
# avance
# --------------------------------------------------------------------------- #
## Avanza el ciclo. Con la red caída no progresa y la pantalla dice SIN RED.
func update(delta: float, player: NexusPlayer, tripped: bool) -> void:
	if player != null:
		_player = player
	if item.is_empty():
		return
	if tripped or done:
		_set_stage(stage_for(tripped))
		return
	elapsed = minf(duration(), elapsed + maxf(delta, 0.0))
	if elapsed >= duration():
		done = true
		_finish()
	_set_stage(stage_for(tripped))


func _finish() -> void:
	var state := _state()
	if id == ANALYZER:
		if state != null:
			state.bench_state["analyzed"] = true
		finished.emit(id, item)
		return
	if _player != null:
		_player.energy = 100.0
		if item == &"lamp":
			_player.flashlight_battery = 100.0
	if state != null and item == &"cell":
		state.bench_state["charged"] = true
	finished.emit(id, item)


func reset() -> void:
	item = &""
	slot = -1
	elapsed = 0.0
	done = false
	_set_stage("EN ESPERA")


func _set_stage(next: String) -> void:
	if next == stage:
		return
	stage = next
	stage_changed.emit(id, stage, progress())


func _state() -> GameState:
	if _player != null and _player.game_state != null:
		return _player.game_state
	return null


# --------------------------------------------------------------------------- #
# persistencia
# --------------------------------------------------------------------------- #
func to_dict() -> Dictionary:
	return {
		"id": str(id),
		"item": str(item),
		"slot": slot,
		"elapsed": elapsed,
		"done": done,
		"stage": stage,
	}


func from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	item = StringName(str(data.get("item", "")))
	slot = int(data.get("slot", -1))
	elapsed = float(data.get("elapsed", 0.0))
	done = bool(data.get("done", false))
	stage = str(data.get("stage", stage_for(false)))
	stage_changed.emit(id, stage, progress())
	return true


func status_line() -> String:
	if item.is_empty():
		return "EN ESPERA"
	return "%s %d %% · %s" % [str(item).to_upper(), int(progress() * 100.0), stage]
