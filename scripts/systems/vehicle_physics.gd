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

var _accumulator := 0.0
var _reverse_delay := 0.0


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

	gear = "N" if absolute < 0.45 else ("R" if speed < 0.0 else str(mini(6, 1 + int(floor(absolute / 8.0)))))
	rpm = round(850.0 + minf(1.0, fmod(absolute, 8.0) / 8.0) * 4100.0 + absf(throttle) * 750.0)


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
