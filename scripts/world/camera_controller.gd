class_name CameraController
extends RefCounted
## Modos de vista del explorador: órbita y primera persona.
##
## Port de `src/scene/CameraController.ts`. La web delega el modo órbita en
## `OrbitControls` de three.js y el movimiento en primera persona en el propio
## controlador. Aquí se reproduce el mismo contrato numérico sin depender de un
## motor externo: órbita esférica con amortiguación del 6 % por frame a 60 Hz,
## límites de distancia y ángulo polar, y marcha a pie con aguante, cadencia,
## balanceo de cabeza, agachado y radio de escape.

## Ángulos de la corona de escape, en radianes (contrato de la web).
const ESCAPE_ANGLES: Array[float] = [0.0, 0.7, -0.7, 1.4, -1.4, PI]
const ESCAPE_RADIUS := 6.8
const EYE_HEIGHT := 1.72
const CROUCH_DROP := 0.44
const LOOK_DISTANCE := 10.0
const PITCH_LIMIT := 1.45
const WALK_SPEED := 4.8
const RUN_SPEED := 8.25
const MOVE_DAMP := 18.0
const STAMINA_DRAIN := 14.0
const STAMINA_REGEN_MOVING := 8.0
const STAMINA_REGEN_IDLE := 13.0
const STAMINA_RECOVERY := 1.05
const STAMINA_REARM := 26.0
const GAIT_WALK := 4.0
const GAIT_RUN := 12.0
const BOB_WALK := 0.027
const BOB_RUN := 0.035
const STEP_LENGTH := 0.12

## Órbita (equivalente a `OrbitControls` en la web).
const ORBIT_TARGET := Vector3(0.0, 2.6, 22.0)
const ORBIT_CAMERA := Vector3(0.8, 3.25, 32.3)
const ORBIT_DAMPING := 0.06
const ORBIT_MIN_DISTANCE := 3.1
const ORBIT_MAX_DISTANCE := 13.0
const ORBIT_MIN_POLAR := 0.38
const ORBIT_MAX_POLAR := PI * 0.49
const ORBIT_ROTATE_SPEED := 0.48
const ORBIT_ZOOM_SPEED := 0.7
const FIRST_POSITION := Vector3(1.8, 1.72, 42.0)
const FIRST_PITCH := 0.12

## Entradas del vehículo de la web.
const BINDINGS := {
	"gas": "w", "reverse": "s", "left": "a", "right": "d",
	"boost": "shift", "brake": " ",
}

var mode: String = "orbit"
var focal_point := ORBIT_TARGET
var first_position := Vector3(0.0, EYE_HEIGHT, 9.6)
var yaw := 0.0
var pitch := 0.055
var sensitivity := 1.0
var stamina := 100.0
var crouch := false
var running := false
var spent := false
var gait := 0.0
var stick := Vector2.ZERO
var sprint_touch := false
var brake_touch := false
var boost_touch := false
var active := true

var _recovery := 0.0
var _keys: Dictionary = {}
var _velocity := Vector2.ZERO
## Estado esférico de la órbita: actual y objetivo.
var _theta := 0.0
var _phi := 0.0
var _radius := 0.0
var _theta_target := 0.0
var _phi_target := 0.0
var _radius_target := 0.0
var _can_stand: Callable = Callable()


func _init(can_stand := Callable()) -> void:
	_can_stand = can_stand
	reset()


func reset() -> void:
	crouch = false
	stamina = 100.0
	spent = false
	_recovery = 0.0
	_velocity = Vector2.ZERO
	clear_keys()
	mode = "orbit"
	focal_point = ORBIT_TARGET
	first_position = Vector3(0.0, EYE_HEIGHT, 9.6)
	yaw = 0.0
	pitch = 0.055
	_set_orbit_from(ORBIT_CAMERA, ORBIT_TARGET)


func clear_keys() -> void:
	_keys.clear()
	brake_touch = false
	boost_touch = false
	sprint_touch = false
	running = false
	stick = Vector2.ZERO
	_velocity = Vector2.ZERO


func held(key: String) -> bool:
	return _keys.has(key)


func move(key: String, on: bool) -> void:
	if on:
		_keys[key] = true
	else:
		_keys.erase(key)


func release() -> void:
	clear_keys()


# --------------------------------------------------------------------------- #
# modos
# --------------------------------------------------------------------------- #
func is_first_person() -> bool:
	return mode == "first-person"


func set_mode(next: String) -> void:
	if next == mode:
		return
	release()
	mode = next
	if next == "first-person":
		# La web guarda el objetivo de la órbita antes de soltarlo (`focalPoint.copy`).
		first_position = FIRST_POSITION
		yaw = 0.0
		pitch = FIRST_PITCH
	else:
		_set_orbit_from(ORBIT_CAMERA, focal_point)


func toggle_mode() -> String:
	set_mode("first-person" if mode == "orbit" else "orbit")
	return mode


# --------------------------------------------------------------------------- #
# órbita
# --------------------------------------------------------------------------- #
func _set_orbit_from(position: Vector3, target: Vector3) -> void:
	var offset := position - target
	var distance := maxf(offset.length(), 0.001)
	_radius = clampf(distance, ORBIT_MIN_DISTANCE, ORBIT_MAX_DISTANCE)
	_radius_target = _radius
	_theta = atan2(offset.x, offset.z)
	_theta_target = _theta
	_phi = clampf(acos(clampf(offset.y / distance, -1.0, 1.0)),
		ORBIT_MIN_POLAR, ORBIT_MAX_POLAR)
	_phi_target = _phi


## Giro de la órbita arrastrando (`rotateSpeed` de la web): arrastrar a la
## derecha gira la cámara a la izquierda y arrastrar hacia abajo la baja.
func orbit_rotate(delta_azimuth: float, delta_polar: float) -> void:
	_theta_target -= delta_azimuth * ORBIT_ROTATE_SPEED
	_phi_target = clampf(_phi_target + delta_polar * ORBIT_ROTATE_SPEED,
		ORBIT_MIN_POLAR, ORBIT_MAX_POLAR)


## Acercamiento de la órbita (`zoomSpeed` de la web, rueda negativa = acercar).
func orbit_zoom(amount: float) -> void:
	_radius_target = clampf(_radius_target * (1.0 + amount * ORBIT_ZOOM_SPEED),
		ORBIT_MIN_DISTANCE, ORBIT_MAX_DISTANCE)


## Avanza la amortiguación de la órbita y devuelve la posición de cámara.
func update_orbit(delta: float) -> Vector3:
	var blend := 1.0 - pow(1.0 - ORBIT_DAMPING, maxf(delta, 0.0) * 60.0)
	_theta = lerpf(_theta, _theta_target, blend)
	_phi = lerpf(_phi, _phi_target, blend)
	_radius = lerpf(_radius, _radius_target, blend)
	return orbit_position()


func orbit_position() -> Vector3:
	var sin_phi := sin(_phi)
	var offset := Vector3(sin_phi * sin(_theta), cos(_phi), sin_phi * cos(_theta)) * _radius
	return focal_point + offset


func orbit_distance() -> float:
	return _radius


func orbit_target() -> Vector3:
	return focal_point


# --------------------------------------------------------------------------- #
# primera persona
# --------------------------------------------------------------------------- #
## Movimiento del ratón o del dedo (`look` de la web).
func look(delta_x: float, delta_y: float, factor: float) -> void:
	yaw += delta_x * factor * sensitivity
	pitch = clampf(pitch - delta_y * factor * sensitivity, -PITCH_LIMIT, PITCH_LIMIT)


func face_rail(forward: bool) -> void:
	yaw = PI if forward else 0.0
	pitch = 0.0


## Vector de mirada unitario en el mundo.
func look_direction() -> Vector3:
	var cos_pitch := cos(pitch)
	return Vector3(sin(yaw) * cos_pitch, sin(pitch), -cos(yaw) * cos_pitch)


## Punto al que mira la cámara a `LOOK_DISTANCE` (contrato de `lookAt`).
func look_target(from: Vector3, distance := LOOK_DISTANCE) -> Vector3:
	return from + Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)) * distance


func eye_position() -> Vector3:
	var eye := first_position
	eye.y = EYE_HEIGHT - (CROUCH_DROP if crouch else 0.0)
	eye.y += bob_offset()
	return eye


## Balanceo de cabeza: cadencia en marcha más fatiga (contrato de la web).
func bob_offset() -> float:
	return sin(gait) * ((BOB_RUN if running else 0.0) + BOB_WALK * (1.0 - stamina / 100.0))


## Entrada [avance, dirección] del vehículo (contrato de `transitInput`).
func transit_input() -> Vector2:
	var forward := -stick.y \
		+ float(held(BINDINGS["gas"]) or held("arrowup")) \
		- float(held(BINDINGS["reverse"]) or held("arrowdown"))
	var steer := stick.x \
		+ float(held(BINDINGS["right"]) or held("arrowright")) \
		- float(held(BINDINGS["left"]) or held("arrowleft"))
	return Vector2(clampf(steer, -1.0, 1.0), clampf(forward, -1.0, 1.0))


## Un paso a pie: aguante, cadencia, velocidad con amortiguación y colisión.
## `can_stand` recibe `(x, z)` y decide si el punto es caminable.
func update_walk(delta: float, input: Vector2, sprint := false,
		can_stand: Callable = Callable()) -> Vector3:
	var norm := maxf(1.0, input.length())
	var direction := input / norm
	var moving := direction.length() > 0.1
	running = moving and not spent and (sprint or sprint_touch)
	if running:
		stamina = maxf(0.0, stamina - delta * STAMINA_DRAIN)
		_recovery = STAMINA_RECOVERY
		if stamina == 0.0:
			spent = true
			sprint_touch = false
	else:
		_recovery -= delta
		if _recovery <= 0.0:
			stamina = minf(100.0, stamina + delta * (STAMINA_REGEN_MOVING if moving else STAMINA_REGEN_IDLE))
		if stamina >= STAMINA_REARM:
			spent = false
	gait += delta * (GAIT_RUN if running else GAIT_WALK)
	var speed := RUN_SPEED if running else WALK_SPEED
	_velocity.x = _damp(_velocity.x, direction.x * speed, MOVE_DAMP, delta)
	_velocity.y = _damp(_velocity.y, direction.y * speed, MOVE_DAMP, delta)
	# Reparto por el rumbo: +y es avanzar, +x es desplazarse a la derecha.
	var step_x := (cos(yaw) * _velocity.x + sin(yaw) * _velocity.y) * delta
	var step_z := (sin(yaw) * _velocity.x - cos(yaw) * _velocity.y) * delta
	var probe: Callable = can_stand if can_stand.is_valid() else _can_stand
	var steps := maxi(1, int(ceil(Vector2(step_x, step_z).length() / STEP_LENGTH)))
	for _i in steps:
		var try_x := first_position.x + step_x / steps
		if not probe.is_valid() or _standable(probe, try_x, first_position.z):
			first_position.x = try_x
		var try_z := first_position.z + step_z / steps
		if not probe.is_valid() or _standable(probe, first_position.x, try_z):
			first_position.z = try_z
	return first_position


func _standable(probe: Callable, x: float, z: float) -> bool:
	var result: Variant = probe.call(x, z)
	return bool(result)


func _damp(current: float, target: float, lambda: float, delta: float) -> float:
	# Equivalente a `THREE.MathUtils.damp`.
	return lerpf(current, target, 1.0 - exp(-lambda * delta))


func velocity() -> Vector2:
	return _velocity


## Coloca al jugador en la primera corona caminable (contrato de `escape`).
func escape(origin: Vector3, can_stand: Callable = Callable()) -> Vector3:
	var probe: Callable = can_stand if can_stand.is_valid() else _can_stand
	for angle in ESCAPE_ANGLES:
		var point := origin + Vector3(sin(angle) * ESCAPE_RADIUS, 0.0, cos(angle) * ESCAPE_RADIUS)
		point.y = EYE_HEIGHT
		if not probe.is_valid() or _standable(probe, point.x, point.z):
			first_position = point
			break
	clear_keys()
	return first_position


func camera_position() -> Vector3:
	return orbit_position() if mode == "orbit" else eye_position()


func distance_to_focus() -> float:
	return camera_position().distance_to(focal_point)


# --------------------------------------------------------------------------- #
# persistencia
# --------------------------------------------------------------------------- #
func to_dict() -> Dictionary:
	return {
		"mode": mode,
		"yaw": yaw,
		"pitch": pitch,
		"stamina": stamina,
		"crouch": crouch,
		"first_position": [first_position.x, first_position.y, first_position.z],
	}


func from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var next_mode := str(data.get("mode", mode))
	mode = next_mode if next_mode == "orbit" or next_mode == "first-person" else mode
	yaw = float(data.get("yaw", yaw))
	pitch = clampf(float(data.get("pitch", pitch)), -PITCH_LIMIT, PITCH_LIMIT)
	stamina = clampf(float(data.get("stamina", stamina)), 0.0, 100.0)
	crouch = bool(data.get("crouch", crouch))
	var raw: Variant = data.get("first_position", [])
	if raw is Array and (raw as Array).size() >= 3:
		first_position = Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return true
