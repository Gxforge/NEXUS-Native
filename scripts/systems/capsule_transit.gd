class_name CapsuleTransit
extends Node3D
## Cápsula de tránsito del eje: llamada, embarque del coche, asientos y freno.
##
## Port de la lógica de `src/scene/Transit.ts` (669 líneas, la mayoría geometría):
## andenes A (102) y B (2042) sobre el eje X = 15, compuerta de la plataforma,
## hoja de puertas, asientos, transferencia del coche en 4 s y telemetría de la
## pantalla («ANDÉN 01», «ANDÉN 02», «RETENIDA», «74 km/h»).

signal status_changed(text: String)
signal arrived(station: String)
signal player_carried(position: Vector3)

const STATION_A := 102.0
const STATION_B := 2042.0
const AXIS_X := 15.0
const TRAVEL_SECONDS := 10.0
const DEPART_DELAY := 1.4
const TRANSFER_SECONDS := 4.0
const GATE_BAND := 6.0
const SEAT_OFFSETS := [
	Vector3(0.95, 1.47, -3.22),
	Vector3(0.95, 1.47, 2.8),
	Vector3(-0.98, 1.47, -3.22),
	Vector3(-0.98, 1.47, 2.8),
	Vector3(0.0, 1.47, -4.25),
]

var physics: VehiclePhysics = VehiclePhysics.new()

var at := STATION_B
var target := STATION_B
var origin := STATION_B
var time := -1.0
var door := 1.0
var gate := 0.0
var speed := 0.0
var seat := -1
var hold := false
var driving := false
var loaded := false
var transfer := -1.0
var unloading := false
var status := "ANDÉN 01"
var light_factor := 0.0

## Si es `false` la cápsula no avanza sola (QA y capturas la mueven a mano).
var simulation := true

var _board: Label3D = null
var _car_offset := Vector3(-12.0, 0.0, STATION_A + 7.0)
var _sx := 0.0
var _sz := 0.0


func _ready() -> void:
	add_to_group(&"capsule_transit")
	_board = get_node_or_null("Board") as Label3D
	reset()
	var state := get_tree().get_first_node_in_group(&"game_state") as GameState
	if state != null:
		state.register_transit(self)
	if _board != null:
		_board.text = status


func reset() -> void:
	at = STATION_A
	target = STATION_A
	origin = STATION_A
	time = -1.0
	door = 1.0
	gate = 0.0
	speed = 0.0
	seat = -1
	hold = false
	driving = false
	loaded = false
	transfer = -1.0
	unloading = false
	physics.reset(-12.0, STATION_A + 7.0, 0.0, true)
	_car_offset = Vector3(-12.0, 0.0, STATION_A + 7.0)
	status = ""
	_set_status(station_name())


func _physics_process(delta: float) -> void:
	if not simulation:
		return
	var player := get_tree().get_first_node_in_group(&"player") as NexusPlayer
	if player == null:
		return
	var forward := Input.get_axis(&"move_back", &"move_forward")
	var steer_input := Input.get_axis(&"move_left", &"move_right")
	var first_person := player.camera != null
	var next := step(delta, player.global_position, first_person, forward, steer_input)
	if driving and next != player.global_position:
		player.global_position = next


## Iluminación de la nave: 65 % de intensidad cuando el jugador está al norte.
func power(player_z: float) -> float:
	light_factor = 1.0 if player_z > 64.0 else 0.0
	return light_factor


func car_position() -> Vector3:
	return _car_offset


# --------------------------------------------------------------------------- #
# geografía
# --------------------------------------------------------------------------- #
## Zona caminable del andén y de la vía (contrato de `Transit.canStand`).
func can_stand(x: float, z: float) -> bool:
	if z < 70.65:
		return absf(x) < 3.94 * smoothstep(0.24, 1.0, gate) - 0.34
	if absf(x) > 19.8 or z > 2069.4:
		return false
	if z > 120.0 and z < 2020.0 and absf(x - 6.1) < 0.56:
		return false
	return true


## Dentro de la cápsula (`Transit.inside`).
func inside(point: Vector3) -> bool:
	return absf(point.x - AXIS_X) < 1.99 and absf(point.z - at + 1.5) < 6.02


func station_name(value: float = INF) -> String:
	var position := at if is_inf(value) else value
	return "ANDÉN 01" if is_equal_approx(position, STATION_A) else "ANDÉN 02"


# --------------------------------------------------------------------------- #
# uso
# --------------------------------------------------------------------------- #
## Acción de un puesto: devuelve mensaje y, si toca, la nueva posición del jugador.
func use(id: StringName, player_position: Vector3) -> Dictionary:
	var result := {"message": "", "position": player_position}
	match id:
		&"railStand":
			if driving:
				if absf(physics.speed) > 2.5:
					result["message"] = "Frena antes de salir"
					return result
				var exit := _find_exit()
				if exit == Vector3.INF:
					result["message"] = "Sin espacio para abrir"
					return result
				result["position"] = Vector3(exit.x, 1.72, exit.z)
			if seat >= 0:
				result["position"] = Vector3(AXIS_X, 1.72, at + SEAT_OFFSETS[seat].z + 1.0)
			seat = -1
			driving = false
			result["message"] = "Control a pie"
			return result
		&"railCar":
			if loaded or transfer >= 0.0:
				result["message"] = "Vehículo enclavado en la transferencia"
				return result
			physics.reset(_car_offset.x, _car_offset.z, physics.yaw)
			driving = true
			result["message"] = "Carro · avance/retroceso y dirección · E para bajar"
			return result
		&"railBrake":
			if time >= 0.0:
				hold = not hold
				result["message"] = "Freno de retención activo" if hold else "Marcha restablecida"
				return result
			result["message"] = "Freno de andén aplicado"
			return result
		&"railLoad":
			return _use_load(player_position)
	if str(id).begins_with("railSeat"):
		var index := int(str(id).substr(8))
		if index < 0 or index >= SEAT_OFFSETS.size():
			result["message"] = "Asiento no disponible"
			return result
		seat = index
		result["message"] = "Asiento asegurado · E para levantarse"
		return result
	if time >= 0.0 or transfer >= 0.0:
		result["message"] = "Espera a que termine la maniobra"
		return result
	var destination := STATION_A if str(id) == "railCallA" else STATION_B
	if str(id) != "railCallA" and str(id) != "railCallB":
		destination = STATION_B if is_equal_approx(at, STATION_A) else STATION_A
	if is_equal_approx(destination, at):
		result["message"] = "Cápsula en andén · acceso abierto"
		return result
	origin = at
	target = destination
	time = 0.0
	hold = false
	result["message"] = "Cierre de puertas · marcha autorizada"
	return result


func _use_load(player_position: Vector3) -> Dictionary:
	var result := {"message": "", "position": player_position}
	if transfer >= 0.0:
		result["message"] = "Maniobra de transferencia en curso"
		return result
	var station := STATION_A if player_position.z < 1000.0 else STATION_B
	if not is_equal_approx(at, station):
		result["message"] = "Llama primero a la cápsula"
		return result
	if not loaded:
		var delta := Vector2(_car_offset.x + 12.0, _car_offset.z - station - 7.0)
		if delta.length() > 3.4:
			result["message"] = "Aparca el carro dentro del marco ámbar"
			return result
	unloading = loaded
	_sx = _car_offset.x
	_sz = _car_offset.z
	transfer = 0.0
	result["message"] = "Descargando carro" if loaded else "Plataforma · embarcando carro"
	return result


func _find_exit() -> Vector3:
	var candidates := [
		Vector3(_car_offset.x + 1.84, 0.0, _car_offset.z),
		Vector3(_car_offset.x - 1.84, 0.0, _car_offset.z),
		Vector3(_car_offset.x, 0.0, _car_offset.z - 2.74),
	]
	for candidate in candidates:
		if can_stand(candidate.x, candidate.z) and candidate.x < 5.5 and candidate.z > 71.5:
			return candidate
	return Vector3.INF


# --------------------------------------------------------------------------- #
# simulación
# --------------------------------------------------------------------------- #
## Un paso de la cápsula. Devuelve la posición resultante del jugador.
func step(delta: float, player_position: Vector3, first_person: bool,
		forward: float, steer_input: float) -> Vector3:
	delta = maxf(delta, 0.0)
	var near_gate := first_person and absf(player_position.x) < GATE_BAND \
		and absf(player_position.z - 70.0) < GATE_BAND
	gate = clampf(gate + ((delta if near_gate else -delta) * 0.7), 0.0, 1.0)
	var aboard := inside(player_position) or seat >= 0
	var previous_at := at

	if time >= 0.0 and not hold:
		time += delta
		door = 1.0 - smoothstep(0.0, 1.2, time)
		if time > DEPART_DELAY:
			var ratio := clampf((time - DEPART_DELAY) / TRAVEL_SECONDS, 0.0, 1.0)
			var eased := ratio * ratio * ratio * (ratio * (ratio * 6.0 - 15.0) + 10.0)
			at = lerpf(origin, target, eased)
			if ratio >= 1.0:
				time = -1.0
				at = target
				arrived.emit(station_name())
		elif time >= 0.0:
			at = origin
	elif time < 0.0:
		door = minf(1.0, door + delta * 0.86)

	speed = (absf(at - previous_at) / delta) if delta > 0.0 else 0.0
	var result := player_position
	if aboard:
		result.z += at - previous_at

	if transfer >= 0.0:
		transfer += delta
		var factor := smoothstep(0.0, TRANSFER_SECONDS, transfer)
		_car_offset = Vector3(
			lerpf(_sx, -12.0 if unloading else AXIS_X, factor),
			0.24 * ((1.0 - factor) if unloading else factor),
			lerpf(_sz, at + 6.7, factor))
		if factor >= 1.0:
			loaded = not unloading
			transfer = -1.0
	elif loaded or transfer >= 0.0:
		_car_offset = Vector3(AXIS_X, 0.32, at + 6.7)

	if driving:
		physics.set_train(at)
		physics.step(delta, forward, steer_input, hold, false)
		_car_offset = Vector3(physics.position.x, 0.0, physics.position.z)
		result = physics.position + Vector3(0.38, 1.055, -0.24).rotated(Vector3.UP, physics.yaw)

	if seat >= 0:
		var offset: Vector3 = SEAT_OFFSETS[seat]
		result = Vector3(offset.x + AXIS_X, offset.y, offset.z + at)

	if aboard and result != player_position:
		player_carried.emit(result)

	if hold and time >= 0.0:
		_set_status("RETENIDA")
	elif time >= 0.0:
		_set_status("%d km/h" % int(round(speed * 3.6)))
	else:
		_set_status(station_name())
	return result


func _set_status(next: String) -> void:
	if next == status:
		return
	status = next
	if _board != null:
		_board.text = next
	status_changed.emit(status)


# --------------------------------------------------------------------------- #
# persistencia
# --------------------------------------------------------------------------- #
func to_dict() -> Dictionary:
	return {
		"at": at,
		"target": target,
		"origin": origin,
		"time": time,
		"door": door,
		"gate": gate,
		"seat": seat,
		"hold": hold,
		"driving": driving,
		"loaded": loaded,
		"transfer": transfer,
		"car": [_car_offset.x, _car_offset.y, _car_offset.z],
		"vehicle": physics.to_dict(),
	}


func from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	at = float(data.get("at", at))
	target = float(data.get("target", target))
	origin = float(data.get("origin", origin))
	time = float(data.get("time", -1.0))
	door = clampf(float(data.get("door", 1.0)), 0.0, 1.0)
	gate = clampf(float(data.get("gate", 0.0)), 0.0, 1.0)
	seat = int(data.get("seat", -1))
	hold = bool(data.get("hold", false))
	driving = bool(data.get("driving", false))
	loaded = bool(data.get("loaded", false))
	transfer = float(data.get("transfer", -1.0))
	var raw_car: Variant = data.get("car", [])
	if raw_car is Array and (raw_car as Array).size() >= 3:
		_car_offset = Vector3(float(raw_car[0]), float(raw_car[1]), float(raw_car[2]))
	var raw_vehicle: Variant = data.get("vehicle", {})
	if raw_vehicle is Dictionary:
		physics.from_dict(raw_vehicle)
	return true


func status_line() -> String:
	if driving:
		return "%s · %s · %d %% energía" % [status, physics.gear, int(physics.energy)]
	if time >= 0.0:
		return "%s · %s" % [status, station_name(target)]
	return status
