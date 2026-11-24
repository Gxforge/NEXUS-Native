class_name VaultModule
extends Node3D
## Bóveda V–03: secuencia de apertura, estaciones de uso, cajones e ítems.
##
## Port de la lógica de `src/scene/Vault.ts` (737 líneas, casi todas geometría).
## Aquí vive lo que la web modela como estado: la secuencia de 22 s con sus siete
## fases, las estaciones de uso con radio de 4 m, los cajones que se abren por
## proximidad con caída de los objetos, la recogida de ítems y la persistencia.

signal phase_changed(phase: String)
signal opened
signal station_used(station_id: StringName, message: String)
signal drawer_changed(index: int, open: bool, factor: float)
signal item_collected(item_id: StringName)

const SEQUENCE_SECONDS := 22.0
const STATION_RADIUS := 4.0
const DRAWER_LATERAL := 0.97
const DRAWER_TRAVEL := 0.85
const DRAWER_APPROACH := 0.96
const DRAWER_DAMP := 5.0
const ITEM_VISIBLE_FACTOR := 0.22
## Paredes útiles de la galería V–03 (23–31) para puestos y cajones.
const EAST_X := 29.9
const WEST_X := 24.4

## Fases en el mismo orden y con los mismos umbrales que la web.
const PHASES := [
	{"name": "Validando", "from": 0.0},
	{"name": "Retirando cerrojos", "from": 0.8},
	{"name": "Liberando pestillos", "from": 5.2},
	{"name": "Girando corona", "from": 9.8},
	{"name": "Despresurizando", "from": 13.9},
	{"name": "Traslado hidráulico", "from": 16.2},
	{"name": "Abierta", "from": SEQUENCE_SECONDS},
]

@export var zone_id: StringName = &"v03_gallery"
@export var auto_start := false

## -1 = cerrada y sin secuencia; 0…22 = segundos de apertura.
var timer := -1.0
var opened_once := false
var phase := "Sellada"

## Estaciones de uso: {id, name, position, message}.
var stations: Array[Dictionary] = []
## Cajones: {id, item, bx, bz, open, factor, solid}.
var drawers: Array[Dictionary] = []
## Ítems: id → {name, collected, drawer}.
var items: Dictionary = {}

var _player_position := Vector3.ZERO
var _has_player := false


func _ready() -> void:
	add_to_group(&"vault_module")
	if stations.is_empty() and drawers.is_empty():
		apply_web_layout()
	var state := _game_state()
	if state != null:
		state.register_vault(self)


func _physics_process(delta: float) -> void:
	var position := _player_position
	if not _has_player:
		var player := get_tree().get_first_node_in_group(&"player") as Node3D
		position = player.global_position if player != null else Vector3.INF
	update(delta, position)


## Registra la posición del jugador para la apertura por proximidad.
func track_player(position: Vector3) -> void:
	_player_position = position
	_has_player = true


# --------------------------------------------------------------------------- #
# guion de la bóveda
# --------------------------------------------------------------------------- #
func begin_opening() -> bool:
	if opened_once or timer >= 0.0:
		return false
	timer = 0.0
	_set_phase(_phase_for(timer))
	return true


func is_opening() -> bool:
	return timer >= 0.0 and not opened_once


func progress() -> float:
	if timer < 0.0:
		return 0.0
	return clampf(timer / SEQUENCE_SECONDS, 0.0, 1.0)


func _phase_for(seconds: float) -> String:
	var name := "Validando"
	for entry in PHASES:
		if seconds >= float(entry["from"]):
			name = str(entry["name"])
	return name


func _set_phase(next: String) -> void:
	if next == phase:
		return
	phase = next
	phase_changed.emit(phase)


## Avanza la secuencia y la apertura de cajones. `player_position` puede ser
## `Vector3.INF` para ignorar la proximidad.
func update(delta: float, player_position: Vector3 = Vector3.INF) -> void:
	delta = maxf(delta, 0.0)
	if timer >= 0.0 and not opened_once:
		timer = minf(SEQUENCE_SECONDS, timer + delta)
		_set_phase(_phase_for(timer))
		if timer >= SEQUENCE_SECONDS:
			opened_once = true
			opened.emit()
	_step_drawers(delta, player_position)


func reset() -> void:
	timer = -1.0
	opened_once = false
	_set_phase("Sellada")
	for drawer in drawers:
		drawer["open"] = false
		drawer["factor"] = 0.0
	for item_id in items:
		items[item_id]["collected"] = false


# --------------------------------------------------------------------------- #
# estaciones
# --------------------------------------------------------------------------- #
func add_station(station_id: StringName, display_name: String, position: Vector3,
		message: String = "") -> Dictionary:
	var station := {
		"id": station_id,
		"name": display_name,
		"position": position,
		"message": message,
	}
	stations.append(station)
	return station


func station(station_id: StringName) -> Dictionary:
	for entry in stations:
		if StringName(str(entry["id"])) == station_id:
			return entry
	return {}


func station_near(position: Vector3, radius := STATION_RADIUS) -> StringName:
	for entry in stations:
		if (entry["position"] as Vector3).distance_to(position) <= radius:
			return StringName(str(entry["id"]))
	return &""


## Acción de una estación: abre la bóveda, rearma la red o informa.
func use_station(station_id: StringName, player: NexusPlayer) -> String:
	var state := _state_of(player)
	match station_id:
		&"rearm":
			var message := _rearm_power()
			station_used.emit(station_id, message)
			return message
		&"vault":
			if opened_once:
				return "Bóveda V–03 · ya está abierta"
			if is_opening():
				return "Bóveda V–03 · " + phase
			if state != null and not state.has_item(&"card"):
				return "Bóveda V–03 · falta la tarjeta de acceso"
			begin_opening()
			station_used.emit(station_id, "Bóveda V–03 · " + phase)
			return "Bóveda V–03 · " + phase
		_:
			var entry := station(station_id)
			if entry.is_empty():
				return ""
			var detail := str(entry.get("message", ""))
			if detail.is_empty():
				detail = "%s · sin respuesta" % str(entry.get("name", station_id))
			station_used.emit(station_id, detail)
			return detail


func _rearm_power() -> String:
	var state := _game_state()
	if state == null or state.power == null:
		return "Cuadro eléctrico no disponible"
	return state.power.rearm()


# --------------------------------------------------------------------------- #
# cajones e ítems
# --------------------------------------------------------------------------- #
func add_drawer(drawer_id: StringName, item_id: StringName, item_name: String,
		bx: float, bz: float) -> Dictionary:
	var drawer := {
		"id": drawer_id,
		"item": item_id,
		"bx": bx,
		"bz": bz,
		"open": false,
		"factor": 0.0,
		"solid": true,
	}
	drawers.append(drawer)
	if not items.has(item_id):
		items[item_id] = {"name": item_name, "collected": false, "drawer": drawer_id}
	return drawer


func open_drawer(index: int, open := true) -> bool:
	if index < 0 or index >= drawers.size():
		return false
	if opened_once == false and timer < 0.0:
		return false
	drawers[index]["open"] = open
	drawer_changed.emit(index, open, float(drawers[index]["factor"]))
	return true


## Apertura automática por proximidad, igual que `drawersStep` de la web.
func _step_drawers(delta: float, player_position: Vector3) -> void:
	for index in drawers.size():
		var drawer: Dictionary = drawers[index]
		var target := 0.0
		if bool(drawer["open"]):
			target = 1.0
			if player_position != Vector3.INF:
				var bx := float(drawer["bx"])
				var bz := float(drawer["bz"])
				if absf(player_position.x - bx) < DRAWER_LATERAL and player_position.z > bz:
					target = clampf((player_position.z - bz - DRAWER_APPROACH) / DRAWER_TRAVEL, 0.0, 1.0)
		var previous := float(drawer["factor"])
		var factor := lerpf(previous, target, 1.0 - exp(-DRAWER_DAMP * delta))
		drawer["factor"] = snappedf(factor, 0.0001)
		if absf(factor - previous) > 0.0005:
			drawer_changed.emit(index, bool(drawer["open"]), float(drawer["factor"]))


func drawer_factor(index: int) -> float:
	if index < 0 or index >= drawers.size():
		return 0.0
	return float(drawers[index]["factor"])


func drawer_visible_item(index: int) -> bool:
	return drawer_factor(index) > ITEM_VISIBLE_FACTOR


## Consulta de colisión para el cajón abierto (equivalente a `drawerSolid`).
func drawer_solid(x: float, z: float) -> bool:
	for drawer in drawers:
		if not bool(drawer["open"]):
			continue
		var bx := float(drawer["bx"])
		var bz := float(drawer["bz"])
		var depth := DRAWER_APPROACH + DRAWER_TRAVEL * float(drawer["factor"])
		if absf(x - bx) < 1.01 and z > bz and z < bz + depth:
			return true
	return false


func item_state(item_id: StringName) -> Dictionary:
	return items.get(item_id, {}) as Dictionary


## Recoge un ítem del cajón abierto y lo mete en el inventario.
func collect(item_id: StringName, player: NexusPlayer) -> String:
	var entry := item_state(item_id)
	if entry.is_empty():
		return ""
	if bool(entry.get("collected", false)):
		return str(entry.get("name", item_id)) + " · ya recogido"
	var drawer_id: StringName = StringName(str(entry.get("drawer", "")))
	var index := -1
	for position in drawers.size():
		if StringName(str(drawers[position]["id"])) == drawer_id:
			index = position
			break
	if index >= 0 and not drawer_visible_item(index):
		return str(entry.get("name", item_id)) + " · el cajón está cerrado"
	entry["collected"] = true
	items[item_id] = entry
	var state := _state_of(player)
	if state != null:
		state.add_item(item_id)
		state.save_game()
	item_collected.emit(item_id)
	return str(entry.get("name", item_id)) + " · guardado en el inventario"


# --------------------------------------------------------------------------- #
# persistencia
# --------------------------------------------------------------------------- #
func to_dict() -> Dictionary:
	var drawer_array: Array[Dictionary] = []
	for drawer in drawers:
		drawer_array.append({
			"id": str(drawer["id"]),
			"open": bool(drawer["open"]),
			"factor": float(drawer["factor"]),
		})
	var collected: Array[String] = []
	for item_id in items:
		if bool(items[item_id].get("collected", false)):
			collected.append(str(item_id))
	return {
		"phase": phase,
		"timer": timer,
		"opened": opened_once,
		"drawers": drawer_array,
		"collected": collected,
	}


func from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	timer = float(data.get("timer", -1.0))
	opened_once = bool(data.get("opened", false))
	_set_phase(str(data.get("phase", "Sellada")))
	var raw_drawers: Variant = data.get("drawers", [])
	if raw_drawers is Array:
		for raw in raw_drawers:
			if not raw is Dictionary:
				continue
			var drawer_id := str(raw.get("id", ""))
			for index in drawers.size():
				if str(drawers[index]["id"]) == drawer_id:
					drawers[index]["open"] = bool(raw.get("open", false))
					drawers[index]["factor"] = float(raw.get("factor", 0.0))
					break
	for item_id in items:
		items[item_id]["collected"] = false
	var raw_collected: Variant = data.get("collected", [])
	if raw_collected is Array:
		for raw in raw_collected:
			var item_id := StringName(str(raw))
			if items.has(item_id):
				items[item_id]["collected"] = true
	return true


func _state_of(player: NexusPlayer) -> GameState:
	if player != null and player.game_state != null:
		return player.game_state
	return _game_state()

func _game_state() -> GameState:
	return get_tree().get_first_node_in_group(&"game_state") as GameState


# --------------------------------------------------------------------------- #
# disposición de la web
# --------------------------------------------------------------------------- #
## Estaciones y cajones dentro de la galería V–03 nativa (23–31 × −82..−24).
##
## `Vault.ts` sitúa cada estación en su sala de la planta web (rearme 24/−37,64,
## hidráulica 7,5/−69,77, archivo 29,5/−89,77), coordenadas que aquí caen fuera
## del módulo. El módulo nativo vive en la galería, así que sus puestos se
## alinean en las dos paredes del pasillo, entre los arcos (z = −31,2, −37,6,
## −44, −50,4, −56,8, −63,2 y −69,6).
func apply_web_layout() -> void:
	add_station(&"vault", "Consola de la bóveda V–03", Vector3(EAST_X, 1.64, -44.0))
	add_station(&"rearm", "Rearme del cuadro eléctrico", Vector3(WEST_X, 1.64, -44.0))
	add_station(&"hydro", "Estación hidráulica H–01", Vector3(EAST_X, 1.64, -56.8))
	add_station(&"records", "Archivo de expedientes D–02", Vector3(WEST_X, 1.64, -56.8))
	add_drawer(&"bank_a", &"lamp", "Linterna de repuesto", EAST_X, -31.2)
	add_drawer(&"bank_b", &"cell", "Celda de energía", EAST_X, -37.6)
	add_drawer(&"bank_c", &"sample", "Muestra criogénica", WEST_X, -31.2)
	add_drawer(&"bank_d", &"card", "Tarjeta de acceso V–03", WEST_X, -37.6)
	add_drawer(&"bank_e", &"recorder", "Registrador de campo", WEST_X, -50.4)
