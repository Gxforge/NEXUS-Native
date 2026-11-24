class_name FilesModule
extends Node3D
## Archivadores de expedientes (D–02).
##
## Port de `src/scene/Files.ts`: diez bandejas con orientación propia que se abren
## en coordenadas locales a la bandeja, se detienen antes de tocar al jugador y
## dejan leer el expediente cuando el folio está elevado. El contenido textual es
## el de la web, palabra por palabra.

signal tray_changed(index: int, open: bool, factor: float)
signal dossier_read(index: int, dossier: Dictionary)

const TRAY_TRAVEL := 0.86
const TRAY_DAMP := 7.0
const TRAY_LATERAL := 1.73
const TRAY_APPROACH := 1.24
const TRAY_REVEAL := 0.65

## Expedientes de la web, en el mismo orden que las bandejas.
const DOSSIERS := [
	{
		"title": "Ciclo de retorno",
		"category": "Hidráulica",
		"text": "El líquido verde de los vasos de observación no es combustible. El circuito exterior recoge calor y lo cede a los intercambiadores. El baño interior está aislado: conserva los fragmentos sin mezclarlos con el refrigerante de la planta.",
	},
	{
		"title": "Memoria del perímetro",
		"category": "Observación",
		"text": "Tras dos aproximaciones por el mismo sector, el sujeto cambió de rumbo antes de alcanzar el campo. El registro de sectores persiste en la memoria local del observatorio. No confundir inspección con contacto.",
	},
	{
		"title": "Transferencia de carga",
		"category": "Turbinas",
		"text": "La corona libera los cierres antes de que el carro desplace el disco. Si cae la alimentación, los cilindros mantienen la posición. Recuperada la red, el movimiento continúa desde ese punto.",
	},
	{
		"title": "Cadena de custodia",
		"category": "Crioteca",
		"text": "El vial se conserva en el banco frío. El cabezal del analizador ilumina la muestra desde arriba. El ensayo solo es válido si el operador presenta el vial correspondiente.",
	},
	{
		"title": "Inventario de turno",
		"category": "Archivo",
		"text": "El equipo de campo se trasladó al banco del fondo. El cargador tiene tres alojamientos y contactos de latón. Una celda de reserva permite recuperar la linterna lejos del banco.",
	},
	{
		"title": "Parte de inspección",
		"category": "Registros",
		"text": "Las hojas originales permanecen en bandejas extraíbles. La copia de consulta se puede leer sin retirar el original. Cerrar la bandeja protege los folios de la humedad.",
	},
]

## Bandejas: {home, rotation, doc, open, factor}.
var trays: Array[Dictionary] = []
## Expedientes ya leídos (índices).
var read_dossiers: Array[int] = []

var _player_position := Vector3.INF

## Muro oeste del archivo D–02 y separación entre bandejas (z de −28 a −62).
const WALL_X := 32.2
const SLOT_STEP := 3.78


func _ready() -> void:
	add_to_group(&"files_module")
	if trays.is_empty():
		apply_web_layout()
	var state := _game_state()
	if state != null:
		state.register_files(self)


func _physics_process(delta: float) -> void:
	update(delta, _player_position)


## Bandejas repartidas por el archivo D–02 nativo.
##
## La web las coloca en coordenadas globales de su propia planta
## (`(-25, -37,3)`, `(36,6, -86,2)`, `(-35,2, -25,8)`…), que en el módulo portado
## caen fuera de la sala (31–46 × −82..−24). Se conservan el número, el orden y
## los giros hacia el pasillo, pero anclados al muro oeste del archivo, de z = −28
## a z = −62, con la boca del cajón hacia +X (el pasillo).
func apply_web_layout() -> void:
	var layout := []
	for index in 10:
		layout.append([Vector3(WALL_X, 0.0, -28.0 - float(index) * SLOT_STEP), PI / 2.0])
	for index in layout.size():
		trays.append({
			"home": layout[index][0],
			"rotation": float(layout[index][1]),
			"doc": index % DOSSIERS.size(),
			"open": false,
			"factor": 0.0,
		})


# --------------------------------------------------------------------------- #
# bandejas
# --------------------------------------------------------------------------- #
func tray_count() -> int:
	return trays.size()


func tray_open(index: int) -> bool:
	if index < 0 or index >= trays.size():
		return false
	return bool(trays[index]["open"])


func toggle(index: int) -> bool:
	if index < 0 or index >= trays.size():
		return false
	trays[index]["open"] = not bool(trays[index]["open"])
	tray_changed.emit(index, bool(trays[index]["open"]), float(trays[index]["factor"]))
	return true


func tray_factor(index: int) -> float:
	if index < 0 or index >= trays.size():
		return 0.0
	return float(trays[index]["factor"])


## El folio se puede leer cuando la bandeja ha salido más del 65 %.
func tray_revealed(index: int) -> bool:
	return tray_factor(index) > TRAY_REVEAL


func dossier_of(index: int) -> Dictionary:
	if index < 0 or index >= trays.size():
		return {}
	return DOSSIERS[int(trays[index]["doc"])] as Dictionary


## Coordenadas locales a la bandeja, igual que el giro de `Files.update`.
func local_offset(index: int, position: Vector3) -> Vector2:
	var home: Vector3 = trays[index]["home"]
	var rotation := float(trays[index]["rotation"])
	var dx := position.x - home.x
	var dz := position.z - home.z
	var u := dx * cos(rotation) - dz * sin(rotation)
	var v := dz * cos(rotation) + dx * sin(rotation)
	return Vector2(u, v)


func update(delta: float, player_position: Vector3 = Vector3.INF) -> void:
	delta = maxf(delta, 0.0)
	_player_position = player_position
	for index in trays.size():
		var tray: Dictionary = trays[index]
		var target := 0.0
		if bool(tray["open"]):
			target = 1.0
			if player_position != Vector3.INF:
				var offset := local_offset(index, player_position)
				if absf(offset.x) < TRAY_LATERAL and offset.y > 0.0:
					target = clampf((offset.y - TRAY_APPROACH) / TRAY_TRAVEL, 0.0, 1.0)
		var previous := float(tray["factor"])
		var factor := lerpf(previous, target, 1.0 - exp(-TRAY_DAMP * delta))
		factor = snappedf(factor, 0.0001)
		tray["factor"] = factor
		if absf(factor - previous) > 0.0005:
			tray_changed.emit(index, bool(tray["open"]), factor)


## Consulta de colisión de las bandejas abiertas (`Files.solid`).
func solid(x: float, z: float) -> bool:
	for index in trays.size():
		var tray: Dictionary = trays[index]
		var offset := local_offset(index, Vector3(x, 0.0, z))
		var depth := TRAY_APPROACH + TRAY_TRAVEL * float(tray["factor"])
		if absf(offset.x) < 1.82 and offset.y > -0.72 and offset.y < depth:
			return true
	return false


# --------------------------------------------------------------------------- #
# lectura
# --------------------------------------------------------------------------- #
## Lee el expediente de una bandeja abierta y lo guarda en la bitácora.
func read_tray(index: int, player: NexusPlayer) -> String:
	if index < 0 or index >= trays.size():
		return ""
	if not tray_revealed(index):
		return "Bandeja cerrada · abre el cajón para leerlo"
	var dossier := dossier_of(index)
	if dossier.is_empty():
		return ""
	var title := str(dossier.get("title", ""))
	var state := _state_of(player)
	if state != null:
		if not read_dossiers.has(index):
			read_dossiers.append(index)
			var records := state.survey_records.duplicate(true)
			var entry := {
				"id": "dossier_%d" % index,
				"name": title,
				"zone": "d02",
				"detail": "%s · %s" % [str(dossier.get("category", "")), str(dossier.get("text", ""))],
				"position": Vector3(trays[index]["home"]),
			}
			var replaced := false
			for position in records.size():
				if str(records[position].get("id", "")) == entry["id"]:
					records[position] = entry
					replaced = true
					break
			if not replaced:
				records.append(entry)
			state.store_survey_records(records)
		dossier_read.emit(index, dossier)
		return "%s · %s" % [title, str(dossier.get("category", ""))]
	dossier_read.emit(index, dossier)
	return title


func is_read(index: int) -> bool:
	return read_dossiers.has(index)


func reset() -> void:
	for tray in trays:
		tray["open"] = false
		tray["factor"] = 0.0
	read_dossiers.clear()


# --------------------------------------------------------------------------- #
# persistencia
# --------------------------------------------------------------------------- #
func to_dict() -> Dictionary:
	var tray_array: Array[Dictionary] = []
	for tray in trays:
		tray_array.append({
			"open": bool(tray["open"]),
			"factor": float(tray["factor"]),
		})
	var read_array: Array[int] = []
	read_array.append_array(read_dossiers)
	return {"trays": tray_array, "read": read_array}


func from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var raw_trays: Variant = data.get("trays", [])
	if raw_trays is Array:
		for index in mini((raw_trays as Array).size(), trays.size()):
			var raw: Variant = (raw_trays as Array)[index]
			if raw is Dictionary:
				trays[index]["open"] = bool(raw.get("open", false))
				trays[index]["factor"] = float(raw.get("factor", 0.0))
	read_dossiers.clear()
	var raw_read: Variant = data.get("read", [])
	if raw_read is Array:
		for raw in raw_read:
			read_dossiers.append(int(raw))
	return true


func _state_of(player: NexusPlayer) -> GameState:
	if player != null and player.game_state != null:
		return player.game_state
	return _game_state()


func _game_state() -> GameState:
	return get_tree().get_first_node_in_group(&"game_state") as GameState
