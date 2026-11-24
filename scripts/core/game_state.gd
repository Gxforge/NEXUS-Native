class_name GameState
extends Node

signal inventory_changed(items: Array)
signal quick_slots_changed(slots: Array)
signal survey_records_changed(records: Array)
signal zone_changed(previous_zone: StringName, current_zone: StringName)
signal power_state_changed(snapshot: Dictionary)

const SAVE_PATH := "user://nexus_native_save.json"
const SAVE_VERSION := 10

var persistence_path: String = SAVE_PATH
var current_zone: StringName = &""
var previous_zone: StringName = &""
var inventory: Array[StringName] = [&"pulse", &"cryo"]
var quick_slots: Array[StringName] = [&"pulse", &"cryo", &"", &"", &""]
var door_states: Dictionary = {}
var player_state: Dictionary = {}
var survey_records: Array[Dictionary] = []
var watcher_state: Dictionary = {
	"zone": "c04", "state": "WATCHING", "aggression": 0.2, "memory": 0.0,
}
## Bóveda V–03 (se registra sola al entrar en la zona).
var vault: VaultModule = null
var _vault_pending: Dictionary = {}
## Archivadores de D–02 (se registran al entrar en la zona).
var files: FilesModule = null
var _files_pending: Dictionary = {}
## Estado de la experiencia (energía, protocolos, ranuras y perfil de calidad).
var experience: ExperienceState = null
## Ajustes de sesión (calidad, sensibilidad, consejos y bitácora).
var session: SessionState = null
## Cápsula de tránsito y vehículo de vía (se registran al entrar en la zona).
var transit: CapsuleTransit = null
var _transit_pending: Dictionary = {}
## Red eléctrica: port de `Power.ts` de la versión web.
var power: PowerGrid = null
## Cuadro eléctrico y CCTV: port de `Operations.ts`.
var operations: OperationsPanel = null
## Bancos de carga (cuna) y de ensayo óptico: port de `BenchCycle.ts`.
var benches: Array[BenchCycle] = []
var bench_state: Dictionary = {"charged": false, "analyzed": false}
## Si es `false`, la red no avanza sola (QA y capturas controlan el paso a mano).
var power_simulation := true

func _init() -> void:
	experience = ExperienceState.new(inventory)
	session = SessionState.new(experience.quality)
	session.device = SessionState.detect_device(OS.has_feature("android") or OS.has_feature("mobile"),
		DisplayServer.is_touchscreen_available(), DisplayServer.is_touchscreen_available())
	power = PowerGrid.new()
	# Orden de la web: primero los doce inversores y los extractores del cuadro.
	operations = OperationsPanel.new(power)
	benches = [BenchCycle.new(BenchCycle.CHARGER), BenchCycle.new(BenchCycle.ANALYZER)]
	power.apply_laboratory_circuits()
	if not power.state_changed.is_connected(_on_power_state_changed):
		power.state_changed.connect(_on_power_state_changed)

func _ready() -> void:
	# El cuadro es un nodo más de la partida (evita nodos sueltos fuera del árbol).
	if operations != null and operations.get_parent() == null:
		add_child(operations)

func _process(delta: float) -> void:
	if not power_simulation or power == null:
		return
	var motor := bool(player_state.get("motor", false))
	var aggression := float(power_aggression_source())
	var player: NexusPlayer = null
	if is_inside_tree():
		player = get_tree().get_first_node_in_group(&"player") as NexusPlayer
	var running := 0.0
	for bench in benches:
		bench.update(delta, player, power.tripped)
		running += bench.kw()
	power.machines = running
	power.update(delta, motor, aggression)

## Gancho para que la IA de W-01 (o una prueba) module la carga. Por defecto usa
## la agresividad registrada del sujeto.
func power_aggression_source() -> float:
	return float(watcher_state.get("aggression", 0.2))

func _on_power_state_changed(snapshot: Dictionary) -> void:
	power_state_changed.emit(snapshot)

## La bóveda se registra al instanciarse la zona; si venía estado guardado, se aplica aquí.
func register_vault(module: VaultModule) -> void:
	vault = module
	if not _vault_pending.is_empty():
		vault.from_dict(_vault_pending)
		_vault_pending = {}

func register_files(module: FilesModule) -> void:
	files = module
	if not _files_pending.is_empty():
		files.from_dict(_files_pending)
		_files_pending = {}

func register_transit(module: CapsuleTransit) -> void:
	transit = module
	if not _transit_pending.is_empty():
		transit.from_dict(_transit_pending)
		_transit_pending = {}

func experience_snapshot() -> Dictionary:
	return experience.to_dict() if experience != null else {}

## Perfil gráfico activo (`low`/`medium`/`high`).
func quality() -> String:
	return experience.quality if experience != null else "medium"

func set_quality(preset: String) -> String:
	if experience == null:
		return "medium"
	var applied := experience.set_quality(preset)
	if session != null:
		session.set_quality(applied)
	return applied

func session_snapshot() -> Dictionary:
	return session.to_dict() if session != null else {}

## Registra un evento en la bitácora de sesión.
func log_event(text: String) -> void:
	if session != null:
		session.log_entry(text)

func transit_snapshot() -> Dictionary:
	return transit.to_dict() if transit != null else {}


func files_snapshot() -> Dictionary:
	return files.to_dict() if files != null else {}

func vault_snapshot() -> Dictionary:
	return vault.to_dict() if vault != null else {}

func bench(id: StringName) -> BenchCycle:
	for bench_cycle in benches:
		if bench_cycle.id == id:
			return bench_cycle
	return null

func benches_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for bench in benches:
		result[str(bench.id)] = bench.to_dict()
	result["state"] = bench_state.duplicate(true)
	return result

func operations_snapshot() -> Dictionary:
	return operations.to_dict() if operations != null else {}

func power_snapshot() -> Dictionary:
	return power.snapshot() if power != null else {}

func has_item(item_id: StringName) -> bool:
	return inventory.has(item_id)

func add_item(item_id: StringName) -> bool:
	if item_id.is_empty() or has_item(item_id):
		return false
	inventory.append(item_id)
	inventory_changed.emit(inventory.duplicate())
	return true

func remove_item(item_id: StringName) -> bool:
	if not inventory.has(item_id):
		return false
	inventory.erase(item_id)
	var slots_changed := false
	for index in quick_slots.size():
		if quick_slots[index] == item_id:
			quick_slots[index] = &""
			slots_changed = true
	inventory_changed.emit(inventory.duplicate())
	if slots_changed:
		quick_slots_changed.emit(quick_slots.duplicate())
	return true

func set_quick_slot(index: int, item_id: StringName) -> bool:
	if index < 0 or index >= quick_slots.size():
		return false
	if not item_id.is_empty() and not has_item(item_id):
		return false
	if not item_id.is_empty():
		for other_index in quick_slots.size():
			if other_index != index and quick_slots[other_index] == item_id:
				quick_slots[other_index] = &""
	quick_slots[index] = item_id
	inventory_changed.emit(inventory.duplicate())
	quick_slots_changed.emit(quick_slots.duplicate())
	return true

func store_survey_records(records: Array[Dictionary]) -> void:
	survey_records.assign(records.duplicate(true))
	survey_records_changed.emit(survey_records.duplicate(true))

func commit_zone(next_zone: StringName) -> void:
	previous_zone = current_zone
	current_zone = next_zone
	zone_changed.emit(previous_zone, current_zone)

func save_game(path: String = "") -> bool:
	if path.is_empty():
		path = persistence_path
	var saved_inventory: Array[String] = []
	for item_id in inventory:
		saved_inventory.append(str(item_id))
	var saved_slots: Array[String] = []
	for item_id in quick_slots:
		saved_slots.append(str(item_id))
	var saved_records: Array[Dictionary] = []
	for record in survey_records:
		var position: Variant = record.get("position", Vector3.ZERO)
		var position_array: Array[float] = [0.0, 0.0, 0.0]
		if position is Vector3:
			position_array = [position.x, position.y, position.z]
		elif position is Array and position.size() >= 3:
			position_array = [float(position[0]), float(position[1]), float(position[2])]
		saved_records.append({
			"id": str(record.get("id", "")),
			"name": str(record.get("name", "")),
			"zone": str(record.get("zone", "unknown")),
			"detail": str(record.get("detail", "")),
			"position": position_array,
		})
	var data := {
		"version": SAVE_VERSION,
		"current_zone": str(current_zone),
		"previous_zone": str(previous_zone),
		"inventory": saved_inventory,
		"quick_slots": saved_slots,
		"door_states": _to_json_value(door_states),
		"player_state": _to_json_value(player_state),
		"survey_records": saved_records,
		"watcher_state": _to_json_value(watcher_state),
		"power": power.to_dict() if power != null else {},
		"vault": vault.to_dict() if vault != null else _vault_pending,
		"files": files.to_dict() if files != null else _files_pending,
		"operations": operations.to_dict() if operations != null else {},
		"benches": benches_snapshot(),
		"transit": transit_snapshot() if transit != null else _transit_pending,
		"experience": experience.to_dict() if experience != null else {},
		"session": session.to_dict() if session != null else {},
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("No se pudo guardar la partida: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(data, "\t"))
	var error := file.get_error()
	file.close()
	return error == OK

func load_game(path: String = "") -> bool:
	if path.is_empty():
		path = persistence_path
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("No se pudo leer la partida: %s" % FileAccess.get_open_error())
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or int(parsed.get("version", 0)) > SAVE_VERSION:
		push_warning("El archivo de partida no es válido o pertenece a una versión más nueva.")
		return false

	var raw_inventory: Variant = parsed.get("inventory", null)
	if raw_inventory is Array:
		var loaded_inventory: Array[StringName] = []
		for raw_item in raw_inventory:
			var item_id := StringName(str(raw_item))
			if not item_id.is_empty() and not loaded_inventory.has(item_id):
				loaded_inventory.append(item_id)
		inventory = loaded_inventory

	var loaded_slots: Array[StringName] = [&"pulse", &"cryo", &"", &"", &""]
	var raw_slots: Variant = parsed.get("quick_slots", null)
	if raw_slots is Array:
		loaded_slots = [&"", &"", &"", &"", &""]
		for index in mini(raw_slots.size(), loaded_slots.size()):
			var item_id := StringName(str(raw_slots[index]))
			if item_id.is_empty() or inventory.has(item_id):
				loaded_slots[index] = item_id
	quick_slots = loaded_slots

	previous_zone = StringName(str(parsed.get("previous_zone", "")))
	current_zone = StringName(str(parsed.get("current_zone", "")))
	var saved_doors: Variant = parsed.get("door_states", {})
	if saved_doors is Dictionary:
		door_states = saved_doors.duplicate(true)
	var saved_player: Variant = parsed.get("player_state", {})
	if saved_player is Dictionary:
		player_state = saved_player.duplicate(true)

	var loaded_records: Array[Dictionary] = []
	var raw_records: Variant = parsed.get("survey_records", [])
	if raw_records is Array:
		for raw_record in raw_records:
			if not raw_record is Dictionary:
				continue
			var record: Dictionary = raw_record.duplicate(true)
			var position: Variant = record.get("position", [0.0, 0.0, 0.0])
			if position is Array and position.size() >= 3:
				record["position"] = Vector3(float(position[0]), float(position[1]), float(position[2]))
			loaded_records.append(record)
	survey_records = loaded_records

	var saved_watcher: Variant = parsed.get("watcher_state", {})
	if saved_watcher is Dictionary:
		watcher_state = saved_watcher.duplicate(true)

	var saved_vault: Variant = parsed.get("vault", {})
	if saved_vault is Dictionary and not (saved_vault as Dictionary).is_empty():
		if vault != null:
			vault.from_dict(saved_vault)
		else:
			_vault_pending = (saved_vault as Dictionary).duplicate(true)

	var saved_files: Variant = parsed.get("files", {})
	if saved_files is Dictionary and not (saved_files as Dictionary).is_empty():
		if files != null:
			files.from_dict(saved_files)
		else:
			_files_pending = (saved_files as Dictionary).duplicate(true)

	var saved_benches: Variant = parsed.get("benches", {})
	if saved_benches is Dictionary:
		var bench_data := saved_benches as Dictionary
		for key in bench_data:
			if key == "state":
				var raw_state: Variant = bench_data[key]
				if raw_state is Dictionary:
					bench_state["charged"] = bool((raw_state as Dictionary).get("charged", false))
					bench_state["analyzed"] = bool((raw_state as Dictionary).get("analyzed", false))
				continue
			var saved_bench: Variant = bench_data[key]
			if saved_bench is Dictionary:
				for bench_cycle in benches:
					if str(bench_cycle.id) == str(key):
						bench_cycle.from_dict(saved_bench)
						break

	var saved_session: Variant = parsed.get("session", {})
	if saved_session is Dictionary and not (saved_session as Dictionary).is_empty():
		if session == null:
			session = SessionState.new(quality())
		session.from_dict(saved_session)
		if experience != null:
			experience.set_quality(session.quality)

	var saved_experience: Variant = parsed.get("experience", {})
	if saved_experience is Dictionary and not (saved_experience as Dictionary).is_empty():
		experience = ExperienceState.new(inventory)
		experience.from_dict(saved_experience)

	var saved_transit: Variant = parsed.get("transit", {})
	if saved_transit is Dictionary and not (saved_transit as Dictionary).is_empty():
		if transit != null:
			transit.from_dict(saved_transit)
		else:
			_transit_pending = (saved_transit as Dictionary).duplicate(true)

	var saved_operations: Variant = parsed.get("operations", {})
	if saved_operations is Dictionary and operations != null:
		operations.from_dict(saved_operations)

	var saved_power: Variant = parsed.get("power", {})
	if saved_power is Dictionary and power != null:
		power.from_dict(saved_power)
	power_state_changed.emit(power.snapshot() if power != null else {})
	inventory_changed.emit(inventory.duplicate())
	quick_slots_changed.emit(quick_slots.duplicate())
	survey_records_changed.emit(survey_records.duplicate(true))
	return true

func _to_json_value(value: Variant) -> Variant:
	if value is StringName:
		return str(value)
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Vector2:
		return [value.x, value.y]
	if value is Dictionary:
		var converted: Dictionary = {}
		for key in value:
			converted[str(key)] = _to_json_value(value[key])
		return converted
	if value is Array:
		var converted: Array = []
		for entry in value:
			converted.append(_to_json_value(entry))
		return converted
	return value
