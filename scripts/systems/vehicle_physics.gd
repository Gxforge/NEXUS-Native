class_name VehiclePhysics
extends RefCounted
## Coche de vía: modelo de cuatro apoyos.
##
## Port de `src/vehicle/VehiclePhysics.ts`. La web usa `cannon-es` con un
## `RaycastVehicle`; aquí se reproduce el mismo contrato numérico (masa, fuerza
## de motor, caída de dirección con la velocidad, turbo con coste, integridad por
## impacto, freno de mano y telemetría de marcha y régimen) en pasos fijos de
## 1/120 s, e integrando posición y rumbo. Así el comportamiento es determinista
## y verificable sin depender de un motor de física distinto.

const MASS := 1260.0
const COM_Y := 0.48
const WHEELBASE := 2.76
const TRACK := 1.74
const WHEEL_RADIUS := 0.355
const TOP_SPEED := 49.0
const REVERSE_SPEED := 8.0
const MOTOR_FORCE := 4100.0
const THROTTLE_RESPONSE := 5.0
const STEER_LIMIT := 0.54
const STEER_FALLOFF := 0.045
const GRIP := 3.8
const DRIFT_GRIP := 0.85
const BOOST_COST := 24.0
const BOOST_RECOVERY := 9.0
const BOOST_COOLDOWN := 3.5
const STEP := 1.0 / 120.0
const IMPACT_THRESHOLD := 2.7
## Suspensión de los cuatro apoyos (`tune.spring`/`compression`/`rebound` de la web).
const SUSPENSION_REST := 0.32
const SUSPENSION_TRAVEL := 0.19
const SUSPENSION_STIFFNESS := 41.0
const SUSPENSION_COMPRESSION := 3.4
const SUSPENSION_REBOUND := 4.5
const MAX_SUSPENSION_FORCE := 18000.0
const ROLL_INFLUENCE := 0.12
## Frecuencia y amortiguación del cabeceo y el balanceo de la carrocería.
const BODY_FREQUENCY := 9.0
const BODY_DAMPING := 0.75
## Puntos de anclaje de las ruedas, en el orden de la web: delanteras primero.
const WHEEL_OFFSETS := [
	Vector3(-0.87, 0.14, 1.38),
	Vector3(0.87, 0.14, 1.38),
	Vector3(-0.87, 0.14, -1.38),
	Vector3(0.87, 0.14, -1.38),
]

var position := Vector3(-12.0, COM_Y + 0.045, 109.0)
var yaw := 0.0
var speed := 0.0
var steer := 0.0
var throttle := 0.0
var energy := 100.0
var integrity := 100.0
var boost := false
var cooldown := 0.0
var impact := 0.0
var slip := 0.0
var rpm := 850.0
var gear := "N"
var braking := false
var pressure := 0.0
var contacts := 4
var train_z := 0.0
## Altura del suelo bajo las ruedas (0 en la vía; el tren la sube cuando lo lleva).
var ground := 0.0
## Cabeceo (eje X) y balanceo (eje Z) de la carrocería, en radianes.
var pitch := 0.0
var roll := 0.0
var pitch_rate := 0.0
var roll_rate := 0.0
## Estado de cada apoyo: longitud de suspensión, ángulo de giro y de rodadura.
var wheel_suspension: Array[float] = [SUSPENSION_REST, SUSPENSION_REST, SUSPENSION_REST, SUSPENSION_REST]
var wheel_speed: Array[float] = [0.0, 0.0, 0.0, 0.0]
var wheel_steering: Array[float] = [0.0, 0.0, 0.0, 0.0]
var wheel_rotation: Array[float] = [0.0, 0.0, 0.0, 0.0]
var wheel_contact: Array[bool] = [true, true, true, true]
var wheel_world: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]

var _accumulator := 0.0
var _reverse_delay := 0.0
var _last_speed := 0.0
var _last_yaw := 0.0


func reset(x: float, z: float, new_yaw := 0.0, repair := false) -> void:
	position = Vector3(x, COM_Y + 0.045, z)
	yaw = new_yaw
	speed = 0.0
	steer = 0.0
	throttle = 0.0
	_accumulator = 0.0
	_reverse_delay = 0.0
	boost = false
	braking = false
	pressure = 0.0
	pitch = 0.0
	roll = 0.0
	pitch_rate = 0.0
	roll_rate = 0.0
	for index in 4:
		wheel_suspension[index] = SUSPENSION_REST
		wheel_speed[index] = 0.0
		wheel_steering[index] = 0.0
		wheel_rotation[index] = 0.0
		wheel_contact[index] = true
	contacts = 4
	_last_speed = 0.0
	_last_yaw = new_yaw
	if repair:
		integrity = 100.0
		energy = 100.0
		cooldown = 0.0
		impact = 0.0


func set_train(z: float) -> void:
	train_z = z - 0.6


## Un paso de simulación con subpasos fijos, como la web.
func step(delta: float, pedal: float, turn: float, hand: bool, turbo: bool) -> void:
	_accumulator += clampf(delta, 0.0, 0.2)
	while _accumulator >= STEP:
		_tick(STEP, pedal, turn, hand, turbo)
		_accumulator -= STEP


func _tick(h: float, pedal_in: float, turn: float, hand: bool, turbo: bool) -> void:
	var pedal := clampf(pedal_in, -1.0, 1.0)
	var absolute := absf(speed)
	impact = maxf(0.0, impact - h * 3.0)
	cooldown = maxf(0.0, cooldown - h)
	boost = turbo and pedal > 0.1 and not hand and cooldown == 0.0 and energy > 0.0
	energy = clampf(energy + h * (-BOOST_COST if boost else (0.0 if cooldown > 0.0 else BOOST_RECOVERY)), 0.0, 100.0)
	if boost and energy == 0.0:
		cooldown = BOOST_COOLDOWN

	braking = hand or pedal * speed < -0.18
	pressure += (float(int(braking)) * absf(pedal) - pressure) * (1.0 - exp(-h * 9.0))
	if pedal < 0.0 and absolute < 0.7:
		_reverse_delay = minf(0.34, _reverse_delay + h)
	elif pedal >= 0.0:
		_reverse_delay = 0.0

	var drive := 0.0 if (braking or (pedal < 0.0 and _reverse_delay < 0.32)) else pedal
	throttle += (drive - throttle) * (1.0 - exp(-h * THROTTLE_RESPONSE))
	steer += ((-turn * STEER_LIMIT) / (1.0 + absolute * STEER_FALLOFF) - steer) * (1.0 - exp(-h * 8.0))

	var limit := REVERSE_SPEED if drive < 0.0 else TOP_SPEED * (1.18 if boost else 1.0)
	var headroom := clampf((limit - absolute) / 5.0, 0.0, 1.0)
	var force := throttle * MOTOR_FORCE * (1.75 if boost else 1.0) \
		* (0.48 + 0.52 * integrity / 100.0) * headroom
	if braking or absf(drive) < 0.01:
		force = 0.0

	var acceleration := force / MASS
	speed += acceleration * h
	# Resistencia y frenada: el coche no se queda deslizando indefinidamente.
	var drag := (0.9 if braking else 0.12) + absolute * 0.006
	speed = move_toward(speed, 0.0, drag * h) if absf(speed) > 0.0 else 0.0
	contacts = 4
	slip = lerpf(slip, (0.35 if hand else 0.02) + absf(steer) * absolute / TOP_SPEED * 0.2, 1.0 - exp(-h * 6.0))

	var travel := speed * h
	# Reparto de tracción: el morro sigue al volante de forma proporcional a la
	# velocidad (contrato de la web: `steer` cae con la velocidad).
	yaw -= steer * travel * 0.62
	var nose := Vector3(sin(yaw), 0.0, cos(yaw))
	position += nose * travel

	_solve_suspension(h)
	gear = "N" if absolute < 0.45 else ("R" if speed < 0.0 else str(mini(6, 1 + int(floor(absolute / 8.0)))))
	rpm = round(850.0 + minf(1.0, fmod(absolute, 8.0) / 8.0) * 4100.0 + absf(throttle) * 750.0)


## Suspensión y actitud de la carrocería sobre los cuatro apoyos.
##
## La web lo resuelve con `cannon-es`: cuatro muelles de 41 N/mm con 0,19 m de
## recorrido y 18 kN de tope, y una carrocería de 1 260 kg que cabecea y balancea
## sola. Aquí el muelle de cada rueda se integra con su rigidez y su
## amortiguación (más compresión que extensión, como `dampingCompression` y
## `dampingRelaxation`), y la actitud se obtiene de la aceleración longitudinal y
## del par de guiñada, que es lo que la carrocería siente en la web.
func _solve_suspension(h: float) -> void:
	if h <= 0.0:
		return
	var acceleration := (speed - _last_speed) / h
	var yaw_rate := (yaw - _last_yaw) / h
	_last_speed = speed
	_last_yaw = yaw
	# Morro arriba al acelerar y hundido al frenar; vuelco hacia fuera del giro.
	var pitch_target := clampf(-acceleration * 0.010, -0.11, 0.11)
	var roll_target := clampf(-yaw_rate * speed * 0.0075, -0.10, 0.10)
	var w := BODY_FREQUENCY
	pitch_rate += (pitch_target - pitch) * w * w * h
	pitch_rate *= exp(-h * 2.0 * BODY_DAMPING * w)
	pitch += pitch_rate * h
	roll_rate += (roll_target - roll) * w * w * h
	roll_rate *= exp(-h * 2.0 * BODY_DAMPING * w)
	roll += roll_rate * h
	# Anclajes en el mundo: la carrocería está girada por el rumbo y la actitud.
	var base := position.y + WHEEL_OFFSETS[0].y
	var nose := Vector3(sin(yaw), 0.0, cos(yaw))
	var side := Vector3(cos(yaw), 0.0, -sin(yaw))
	var contact_count := 0
	for index in 4:
		var offset: Vector3 = WHEEL_OFFSETS[index]
		# Altura del anclaje con la actitud de la carrocería: `rotation.x = pitch`
		# hunde el morro y `rotation.z = roll` sube el costado derecho.
		var along := -offset.z * pitch + offset.x * roll
		var anchor_y := base + along
		var target := clampf(anchor_y - ground - WHEEL_RADIUS,
			SUSPENSION_REST - SUSPENSION_TRAVEL, SUSPENSION_REST + SUSPENSION_TRAVEL)
		# Muelle de la rueda: la frecuencia sale de la rigidez real y el
		# amortiguamiento es mayor al comprimir que al extender, como la web.
		var omega := sqrt(SUSPENSION_STIFFNESS)
		var zeta := 0.62 * (SUSPENSION_COMPRESSION if target < wheel_suspension[index]
			else SUSPENSION_REBOUND) / 4.0
		wheel_speed[index] += ((target - wheel_suspension[index]) * omega * omega
			- wheel_speed[index] * 2.0 * zeta * omega) * h
		var length := clampf(wheel_suspension[index] + wheel_speed[index] * h,
			SUSPENSION_REST - SUSPENSION_TRAVEL, SUSPENSION_REST + SUSPENSION_TRAVEL)
		wheel_suspension[index] = length
		wheel_contact[index] = absf(anchor_y - ground - WHEEL_RADIUS - length) < 0.06
		if wheel_contact[index]:
			contact_count += 1
		wheel_steering[index] = steer if index < 2 else 0.0
		wheel_rotation[index] = fposmod(wheel_rotation[index] + speed / WHEEL_RADIUS * h, TAU)
		var wheel_position := position + nose * offset.z + side * offset.x \
			+ Vector3(0.0, offset.y + along - length, 0.0)
		wheel_world[index] = wheel_position
	contacts = contact_count


## Estado de un apoyo para la malla del vehículo (`VehicleRig`).
func wheel_state(index: int) -> Dictionary:
	var i := clampi(index, 0, 3)
	return {
		"index": i,
		"offset": WHEEL_OFFSETS[i],
		"suspension": wheel_suspension[i],
		"steering": wheel_steering[i],
		"rotation": wheel_rotation[i],
		"contact": wheel_contact[i],
		"position": wheel_world[i],
	}


## Cabeceo y balanceo en grados, para la telemetría.
func attitude_degrees() -> Vector2:
	return Vector2(rad_to_deg(pitch), rad_to_deg(roll))


## Registra un choque con la velocidad normal de impacto (m/s).
func register_impact(impact_velocity: float) -> void:
	if impact_velocity <= IMPACT_THRESHOLD:
		return
	impact = maxf(impact, minf(1.0, impact_velocity / 16.0))
	integrity = clampf(integrity - (impact_velocity - IMPACT_THRESHOLD) * 1.65, 0.0, 100.0)


func kmh() -> float:
	return speed * 3.6


func telemetry() -> Dictionary:
	return {
		"speed": speed,
		"kmh": kmh(),
		"gear": gear,
		"rpm": rpm,
		"energy": energy,
		"integrity": integrity,
		"boost": boost,
		"slip": slip,
		"impact": impact,
		"contacts": contacts,
		"pressure": pressure,
		"pitch": pitch,
		"roll": roll,
		"suspension": wheel_suspension.duplicate(),
		"wheel_speed": wheel_speed.duplicate(),
	}


func to_dict() -> Dictionary:
	return {
		"position": [position.x, position.y, position.z],
		"yaw": yaw,
		"speed": speed,
		"energy": energy,
		"integrity": integrity,
		"cooldown": cooldown,
	}


func from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var raw: Variant = data.get("position", [])
	if raw is Array and (raw as Array).size() >= 3:
		position = Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	yaw = float(data.get("yaw", yaw))
	speed = float(data.get("speed", 0.0))
	energy = clampf(float(data.get("energy", energy)), 0.0, 100.0)
	integrity = clampf(float(data.get("integrity", integrity)), 0.0, 100.0)
	cooldown = maxf(0.0, float(data.get("cooldown", 0.0)))
	return true
